# Builtin `hash()` divergence investigation -- E5092 fallback route (wave-18 follow-up)

Date: 2026-08-23 · Branch: `jac-python` @ `6d5b101ca` · READ-ONLY investigation

## Executive summary

**Reproduced: YES.** The original hypothesis (PyHostProxy FNV fallthrough) is a
*separate latent issue*, not the cause of OakArrow's wave-18 numbers. The actual bug:

> **The `jac` launcher's embedded CPython initializes with `use_environment = 0`
> and never sets `use_hash_seed`. Ambient `PYTHONHASHSEED` is therefore invisible
> to the interpreter, and str/bytes hashing uses a fresh random SipHash secret on
> every process start** -- regardless of what `PYTHONHASHSEED` says. Any guest code
> that reaches *host* builtin `hash()` (i.e. everything executed via the E5092
> "server codespace" transpile-and-run route) gets per-process-random values that
> can never match CPython-under-`PYTHONHASHSEED=0` oracle expectations.

The jacpython VM's own `str_hash_obj` SipHash (pyhash.jac, seed 0 baked in) is NOT
affected -- the divergence is purely about which hash implementation answers the call,
and it is route-dependent exactly as OakArrow reported.

## Repro (3 lines, verified this session at HEAD 6d5b101ca)

```jac
# /tmp/h.jac
with entry { print(hash("spam"), hash(b"abc")); }
```

```
$ for i in 1 2 3; do PYTHONHASHSEED=0 .venv/bin/jac run /tmp/h.jac; done
note: /tmp/h.jac preferred native but did not lower; compiled in the server codespace
      (error[E5092]: Native lowering failed for builtin call 'hash')
442179762958835958 4447613303222717962     # run 1
8386623294822559773 1160553475816915038    # run 2  <- different
-9219919252330923179 -5515754125182125064  # run 3  <- different again
```

Host reference under identical env (`PYTHONHASHSEED=0 python3 -c ...`):

| expression | host value | guest (E5092 route) |
|---|---|---|
| `hash("spam")` | `-7643603308804133256` | new random value every run |
| `hash(b"abc")` | `-4594863902769663758` | new random value every run |

Within a single process the values are self-consistent (`hash("spam") == hash("spam")`),
so dict/set behavior inside one run is fine -- only cross-run/cross-host determinism
and oracle parity are broken.

## Root-cause trace

1. `.venv/bin/jac` → `/home/jac/.local/bin/jac`: a ~215 MB Zig launcher embedding
   `libpython3.14.so`.
2. `jac/launcher/embed.zig`, `Embed.initInterpreter()` builds a PEP 741
   `PyInitConfig` and calls `Py_InitializeFromInitConfig`. Relevant settings:

   ```zig
   // Total hermeticity + no-leak: ignore ambient PYTHON* entirely.
   try check(GetError, cfg, SetInt(cfg, "use_environment", 0));
   ```

   There is **no `SetInt(cfg, "use_hash_seed", ...)` anywhere in embed.zig**
   (grep confirms zero occurrences).
3. With `use_environment = 0`, CPython's `config_init_hash_seed` cannot read
   `PYTHONHASHSEED`; an absent seed means "randomize". So the embedded interpreter
   always starts with a random secret.
4. Empirical proof from inside a guest program:

   ```jac
   # prints under `PYTHONHASHSEED=0 jac run`:
   #   os.environ["PYTHONHASHSEED"] -> "0"        (env var IS present)
   #   sys.flags.hash_randomization -> 1          (...but interpreter ignored it)
   ```

   Host python under the same env reports `hash_randomization = 0`. Setting
   `PYTHONHASHSEED=12345` or unsetting it changes nothing: randomization stays on.
5. On the E5092 route the program body executes as transpiled Python *inside that
   embedded interpreter*, so its `hash(str)` resolves to the host builtin with the
   random secret. This is why values differ per run and never equal the
   seed-0 oracle.

### Why the exec_code/pyc_first route was believed exact

The VM-native lane computes string hashes with its own SipHash implementation
(`jac-py/jacpython/pyhash.jac` via `strobject.str_hash_obj`, dispatched by
`hash_dispatch.hash_element` for `PyStr`) with the seed-0 constants baked in --
byte-exact `-7643603308804133256` for `"spam"`, independent of interpreter state.
The parity suites that pin exact values pass only when answers come from that lane;
OakArrow's suite mixed in host-side `hash()` calls (e.g. seeding paths, runtime
consistency checks), which on this box resolve through the launcher's randomized
interpreter.

Honest caveat: this session I could not re-drive the exec_code probe end-to-end
(`unmarshal()` returned an error object through my ad-hoc bridge→list[int] harness);
the `-7643603308804133256` figure rests on the prior-wave pyhash corpus/parity
verification, which remains valid. The E5092-side numbers above are all freshly
reproduced here.

## Impact

- Every `jac run` execution on this machine has randomized str/bytes hashes.
  Consequences: non-reproducible dict/set iteration order across runs for str-keyed
  containers built on the host lane, parity tests that compare host `hash()` output
  flake unless they re-derive expected values in-process, and any wave gate that
  pins absolute hash constants fails intermittently (wave 18 symptom).
- Not affected: int/float/tuple-of-ints hashing (algorithm is seed-independent),
  and the VM-internal `tp_hashkey` protocol (FNV over a spelling, deterministic).

## Fix spec (assignee: jac0core/native territory -- `jac/launcher/`, NOT ceval.jac)

**File: `jac/launcher/embed.zig`, function `Embed.initInterpreter`.**

Since `use_environment = 0` must stay (hermeticity is deliberate, see comment block
re #7047), read `PYTHONHASHSEED` explicitly in Zig and forward it as config:

```zig
// After the existing SetInt/SetStr calls:
if (std.posix.getenv("PYTHONHASHSEED")) |seed_text| {
    if (!std.mem.eql(u8, seed_text, "random")) {
        const seed = std.fmt.parseInt(u64, seed_text, 10) catch {
            // mirror CPython: fatal config error on non-integer seeds
            std.debug.print("jac (embed): invalid PYTHONHASHSEED '{s}'\n", .{seed_text});
            return Error.InitFailed;
        };
        try check(GetError, cfg, SetInt(cfg, "use_hash_seed", 1));
        try check(GetError, cfg, SetInt(cfg, "hash_seed", @intCast(seed)));
    } // else: "random" -> leave default (randomized)
}
```

Semantics check against CPython `config_init_hash_seed` (pycore_initconfig.c):
unset/"random" ⇒ `use_hash_seed=0` (randomized); integer N ⇒ `use_hash_seed=1`,
`hash_seed=N`; N=0 gives the deterministic seed-0 secret used by the oracle.

Acceptance checks:

1. `PYTHONHASHSEED=0 jac run h.jac` prints `-7643603308804133256 -4594863902769663758`
   stably across runs, matching host python under the same env.
2. `sys.flags.hash_randomization == 0` inside the guest when `PYTHONHASHSEED=0`.
3. Unset/var/random seeds keep today's randomized behavior (no security regression).
4. Wave-18 `_random` bytes/str-seeded parity gates un-block: once the launcher honors
   seed 0, the runtime-SipHash-match guard in `test_random_parity.jac` passes without
   special-casing.

## Separate latent issue: PyHostProxy tp_hashkey FNV fallthrough (do not conflate)

Statically confirmed in code (not exercised this session):

- `hash_dispatch.hash_element` handles PyInt/PyBool/PyStr/PyFloat/PyBytes/PySlice;
  everything else falls through to `v.tp_hashkey()` + `_hashkey_digest` (FNV-1a fold).
- `PyHostProxy.tp_hashkey` (ceval.jac) returns `"host:" + str(hash(val))` -- correct
  for internal dict/set bucketing, but if a `PyHostProxy` ever reaches user-facing
  `py_hash`/`hash_element`, the result is an FNV digest of the string
  `"host:<hosthash>"`, i.e. neither SipHash nor the host value.
- Reachability inside the proper VM is narrow: plain host strs are flattened by
  `from_host` into native `PyStr`; proxies survive for non-flat types
  (builtin-subclass instances, opaque objects). Note `host_builtin()`
  (ceval.jac:2276) returns raw `PyHostProxy`s for non-native builtin names without
  `from_host`, so e.g. `hex(255)` yields a proxy wrapping `'0xff'`; whether that
  proxy can reach `hash()` in practice depends on later dispatch. If it does, spec
  the fix there too: an `isinstance(v, PyHostProxy)` arm early in `hash_element`
  that routes wrapped **str/bytes/int/float** through `to_host` + the corresponding
  native hash lane (or through `from_host` flattening first), keeps current
  tp_hashkey bucketing for other types, and raises a faithful
  `TypeError: unhashable type: '<host type>'` when the host value is unhashable
  (map `_jac_host_hashkey == ""` to `PyObject_HashNotImplemented`).

## Probe log (this session)

| probe | route | result |
|---|---|---|
| `jac run` of `print(hash("spam"), hash(b"abc"))`, 3 runs, seed 0 | E5092 server codespace | 3 distinct value pairs; matches OakArrow symptom |
| `sys.flags.hash_randomization` in guest, env seed 0 | embedded interp | `1` (env var present but ignored) |
| same, env seed 12345 / unset | embedded interp | `1` (always randomized) |
| `.venv/bin/python -c hash("spam")`, seed 0 | real CPython | stable `-7643603308804133256` |
| `hex(255)` then `hash(...)` in guest | E5092 route | host-str identity, randomized per-run hash (route effect, not FNV -- server codespace has no PyHostProxy) |
| exec_code/unmarshal smoke | VM lane | harness-level failure (`unmarshal` returned error obj); not concluded, see caveat above |
