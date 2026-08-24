# Guest `sys` Surface Audit (delegate-snapshot correctness)

Scope: which commonly-used `sys` attributes/functions are wrong or missing on the
guest because they bridge to the host interpreter. Probed with in-VM
`exec_code_frame` fixtures against the delegate snapshot installed at both lazy
import sites in `ceval.jac` (see 7f743e089 for the pattern). Baseline: commit
7f743e089 + this audit's fixes.

## Findings table

| Surface | Guest behavior | vs CPython | Verdict |
|---|---|---|---|
| `sys.maxsize` | 9223372036854775807 | same | OK |
| `sys.version` / `version_info` | 3.14.6 host values | same | OK |
| `sys.platform`, `byteorder`, `maxunicode` | linux / little / 1114111 | same | OK |
| `sys.path.append(x)` then guest import from `x` | **ImportError**; mutation persists across execs (shared snapshot) but layer3 import machinery never reads guest-mutated path | WRONG -- CPython honors it | Known limitation; post-cliff live-view family, NOT fixed here |
| `sys.argv` | host argv of the `jac run` process (`[probe.jac]`) | shape-approximate; leaks host args | Note only; acceptable while embedded |
| `sys.stdout` / `stderr` `.write()` | reach real streams | same | OK |
| `print()` in guest | reaches real stdout | same | OK |
| `sys.modules` membership | shows HOST-loaded modules (`json` pre-present) | diverges | Note |
| guest `import X` registration | **not** registered into `sys.modules` (verified with fresh module: absent after import, both views) | WRONG -- CPython registers | Post-cliff live-view family, NOT fixed here |
| `sys.modules['x'] is reimported-x` | n/a (nothing registers) | WRONG | Same family |
| `sys.exc_info()` | reads GUEST handled-exc stack | same | Fixed in 7f743e089 |
| **`sys.exception()`** | returned `None` inside a guest `except` block (host bridge sees no guest state), while `exc_info()[0]` said `ValueError` | **WRONG** | **FIXED here** -- native branch over `_handled_exc_stack`; nested-handler restore matches CPython |
| **`sys.intern(s)`** | returned equal-but-new string (`intern(s) is s` → False); CPython contract is identity | **WRONG** | **FIXED here** -- native branch returns arg itself; TypeError message matches CPython |
| `sys.is_finalizing()` | False via delegation | same (correct during run) | OK; delegation would misbehave at host shutdown only -- left delegated |
| `sys.getrefcount` | returns int; count necessarily differs (native objects) | differs by design | Note only |
| `sys.exit`, `float_info`, `flags`, `implementation.name`, `getrecursionlimit` (12000), `stdout.encoding/isatty` | present and sane | ~same | OK |
| `sys.executable`, `sys.prefix` | `/home/jac/.local/bin/jac`, jac runtime cache dir | divergent values (host/jac runtime context) | Note only; low value to fake |
| `sys._getframe/settrace/gettrace/setprofile/getsizeof/audit/...` | present via host bridge | operate on HOST frames/state if invoked | Flagged for future exception-scoped/native treatment where guest-visible semantics matter (e.g. `_getframe`) |
| `sys.ps1` / `ps2` | missing | same as non-interactive CPython | OK |

## Fixes applied (both install sites + `PyNativeBuiltin.tp_call`)

1. `sys.exception()` → top of `_handled_exc_stack` or None (mirrors the
   `exc_info` branch exactly).
2. `sys.intern(s)` → returns its single str argument itself (identity preserved);
   arity/type errors raise CPython-shaped TypeError.

## Deliberately NOT attempted

- Live `sys.path` / `sys.modules` views: conversion-policy family (import
  machinery must read/write the shared view), not expressible as snapshot
  attribute overrides.
- `_getframe`/tracing family: needs frame-object bridging design, not small.

## Probe method

Temp `.jac` drivers calling `exec_code_frame(unmarshal(host_compile_marshal(...)))`
(removed after audit). Shadow tree at `/var/tmp/sysprobe-shadow` used to run
probes while `tracebackmodule.jac` was mid-edit by a concurrent lane.
