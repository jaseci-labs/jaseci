# PACKET: W2 subprocess (libc fork/exec/waitpid bindings + guest subprocess facade)

Executor contract: follow the steps in order. Do not redesign. Every template
named below exists on disk today; read it before writing code.

## 1. Prerequisites

- Working `.venv` jac toolchain; local gate is `.venv/bin/jac check <file>`.
- Reference CPython tree checked out at `reference/cpython/`
  (`reference/cpython/Lib/test/test_subprocess.py` exists).
- FFI smoke test passes (Step 0 below). This is the go/no-go gate.
- You own these files exclusively (shared-tree rule): everything under
  `jac-py/jacpython/` matching `*subprocess*` plus the two registry edit
  sites named below. Commit within minutes of each green step.

## 2. Step 0: FFI smoke test (go/no-go)

No guest-runtime module uses `import from c` yet. Before building anything,
prove externs link inside the guest runtime build:

1. Create `jac-py/jacpython/_subprocess_native.jac` containing exactly:

   ```
   import from c { def getpid -> i32; }
   def:pub sys_getpid -> int {
       return getpid();
   }
   ```

2. Run `.venv/bin/jac check jac-py/jacpython/_subprocess_native.jac`, then
   run one existing CI test file that imports nothing new
   (`.venv/bin/jac test jac-py/jacpython/test_small_slots.jac`) to confirm
   the module graph still builds and links with the new file present.
3. If linking fails or the checker rejects `import from c` in this tree:
   STOP. Escalate per Section 9. Delete the smoke file only after reporting.

## 3. Files to create / touch

Create:

- `jac-py/jacpython/_subprocess_native.jac` - libc externs plus thin signed /
  errno-normalizing wrappers. Template: `jac/jaclang/runtimelib/na_stdlib/_zlib_native.jac`
  (wrapper style) and `_socket_native.jac` (errno pattern via
  `__errno_location` + `strerror`).
- `jac-py/jacpython/subprocess.jac` - guest-facing facade. Template:
  `jac/jaclang/runtimelib/na_stdlib/socket.jac` (facade-over-native split).
- `jac-py/jacpython/test_subprocess_native.jac` - acceptance pins. Template:
  `jac-py/jacpython/test_stdlib_delegate.jac` (pin style) using
  `p2_libtest_expect_ok(snippet, expect_stdout=...)` from
  `jac-py/jacpython/layer_p2_libtest.jac`.

Touch:

- `jac-py/jacpython/ceval.jac` - remove `"zlib": "full"` ONLY if you also
  land PACKET-compression; for this packet touch nothing there except, if
  needed, a bootstrap call site. Registration of the new shim follows the
  existing pattern in `jac-py/jacpython/layer_p2_libtest.jac` lines 780-830:
  build `attrs: dict[str, PyObj]`, then
  `register_shim_module("subprocess", PyModule(t="module", name="subprocess", attrs=attrs))`.
  Native facades win over delegation automatically (precedence documented at
  ceval.jac shim_modules glob).

## 4. Binding function list (exact C signatures)

Declare in `_subprocess_native.jac` with `import from c { ... }` blocks:

```
def pipe2(fds: bytes, flags: i32) -> i32;              # int pipe2(int [2], int)
def fork -> i64;                                       # pid_t fork(void)
def execvp(file: str, argv_flat: bytes) -> i64;        # see note A
def waitpid(pid: i64, status: bytes, options: i32) -> i64;
def _exit(status: i32);                                # void _exit(int)
def dup2(oldfd: i32, newfd: i32) -> i32;
def close(fd: i32) -> i32;
def read(fd: i32, buf: bytes, n: u64) -> i64;
def write(fd: i32, buf: bytes, n: u64) -> i64;
def kill(pid: i64, sig: i32) -> i32;
def getpid -> i64;
def __errno_location -> int;                           # errno pattern, socket template
def strerror(errnum: i32) -> str;
```

Note A: `execvp` takes `char *const argv[]`. Assemble it in Jac glue:
NUL-terminate each arg into one flat bytes blob, build a pointer array as a
second bytes blob of little-endian u64 offsets into a single allocated
buffer, pass the pointer-array blob. Copy the pointer-marshaling idiom from
`_socket_native.jac` (`getaddrinfo` result walking with `int.from_bytes` +
offset globs). If your first attempt segfaults, do not improvise: re-read
that file and mirror its buffer discipline exactly.

Wrapper rules (mirror `_zlib_native.jac`):

- Wrap every return in a `_signed64` / `_signed32` helper before comparing.
- Expose `last_errno()` and `errno_message()` verbatim from the socket
  template so glue can raise OSError(errno, msg).

## 5. Facade surface (subprocess.jac)

Implement, in this order, testing after each item:

1. Constants: PIPE, STDOUT, DEVNULL (-1, -2, -3), and the Popen class.
2. `Popen.__init__(args, shell=False, stdout=None, stderr=None,
   stdin=None, env=None, cwd=None)`:
   pipe2() for each requested stream, fork(), child side: dup2 + chdir
   (add `chdir(path: str) -> i32` to the bind list if os shim lacks it) +
   execvp; parent side: close child ends, store fds and pid.
3. `Popen.wait()` - waitpid loop; decode status with bit ops:
   WIFEXITED = (s & 0x7f) == 0; WEXITSTATUS = (s >> 8) & 0xff;
   WIFSIGNALED = ((s & 0x7f) + 1) >> 1 > 0; negative returncode -signum.
4. `Popen.communicate(input=None)` - sequential fd reads to EOF, join,
   return (stdout_bytes, stderr_bytes). No timeout support in v1.
5. Module-level `run(args, capture_output=False, input=None, env=None,
   cwd=None, shell=False)` returning a CompletedProcess-like object with
   `.returncode/.stdout/.stderr`.
6. Raise `OSError(errno, strerror, filename)` on pipe2/fork/exec failures in
   the parent; in the child, write errno to the errpipe fd conventionally OR
   simply `_exit(127)` for v1 (exec failure). Choose the simple option; do
   not build CPython's errpipe protocol in v1.

## 6. Acceptance criteria

Pin suite `test_subprocess_native.jac` must reach ALL green locally:

- Exactly 25 pins minimum, each a guest snippet string executed through
  `p2_libtest_expect_ok`, oracle values captured by running the same snippet
  under host `python3` first and pasting its stdout into `expect_stdout`.
- Required pin behaviors (map 1:1 onto reference/cpython/Lib/test/test_subprocess.py
  tests, cite the source test name in a comment per pin):
  exit code propagation (test_exitcode style), stdout/stderr capture,
  capture_output=True, input= feeding stdin, communicate roundtrip,
  shell=True echo, env override, cwd change, returncode after signal
  (kill -9 child, expect -9), sequential Popen reuse, DEVNULL, pipe chain
  `p1 | p2`, binary mode output, unicode arg passthrough, empty output,
  large output (256KB), many args (512), cwd failure raises
  (FileNotFoundError), executable-not-found raises FileNotFoundError,
  run().check semantics if CompletedProcess carries it, two concurrent
  children interleaved read.
- CI: add one line to `.github/workflows/jacpy-gates.yml` test matrix:
  `run: jac test jac-py/jacpython/test_subprocess_native.jac`.

Expected counts: 25/25 pins green locally before push; farm conversion of
the full Lib/test/test_subprocess.py is EXPLICITLY OUT OF SCOPE for this
packet (threading/signal dependencies belong to W3/W6).

## 7. Verification commands

```bash
.venv/bin/jac check jac-py/jacpython/_subprocess_native.jac
.venv/bin/jac check jac-py/jacpython/subprocess.jac
.venv/bin/jac test jac-py/jacpython/test_subprocess_native.jac
git log origin/..HEAD --oneline   # confirm only your commits
```

## 8. Effort estimate

5 to 8 working days for the executor: day 1 smoke + externs, days 2-3
fork/exec plumbing, days 4-5 communicate/waitpid/status, day 6 pins to
green, remainder buffer for flaky-pin debugging.

## 9. STOP conditions (escalate back to stronger model)

- Step 0 FFI smoke fails to link in the guest runtime build.
- Any segfault in the parent VM process during or after fork. Fork copies
  the whole VM heap state; if the child cannot safely exec from inside a
  running VM without corrupting the parent, this needs an architecture
  decision, not persistence.
- waitpid returning ECHILD or reaping failures that pins cannot stabilize.
- Pin count stuck below 20 green after 2 full debugging days.
- Discovery that ceval holds locks or signal masks across the fork point
  (would need design work owned by a stronger model).
