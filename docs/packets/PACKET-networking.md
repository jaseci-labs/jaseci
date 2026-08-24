# PACKET: W1 networking stack (socket -> select -> ssl -> http/urllib)

Executor contract: build in the exact phase order below. Each phase has its
own commit and green gate. Do not start a phase before the previous one is
green. Templates referenced exist on disk; read each before coding.

## 1. Prerequisites

- Working `.venv` jac toolchain; local gate is `.venv/bin/jac check <file>`.
- Reference CPython tree at `reference/cpython/` (test_socket.py,
  test_select.py, test_ssl.py, test_httplib.py all present under Lib/test/).
- System libraries present (AWS-free local box): libc (always), OpenSSL dev
  headers/lib (`ldconfig -p | grep libssl`). If libssl is missing, phases 3
  and 4 are blocked but phases 1-2 proceed.
- PACKET-subprocess.md Step 0 smoke already proved `import from c` links in
  the guest runtime. If that packet has not landed, run its Section 2 smoke
  yourself first; if it fails, STOP.
- File ownership: all `*socket*`, `*select*`, `*ssl*`, `*http*`, `*urllib*`
  files you create under `jac-py/jacpython/`. Commit each green phase within
  minutes.

## 2. Phase 1: socket native + facade

Files to create:

- `jac-py/jacpython/_socket_native.jac` - externs + errno wrappers.
- `jac-py/jacpython/socket.jac` - facade.
- `jac-py/jacpython/test_socket_native.jac` - pins.

Templates to copy the approach from (read fully first):

- `jac/jaclang/runtimelib/na_stdlib/_socket_native.jac` - THE template. It
  already declares socket/connect/send/recv/close/shutdown/getaddrinfo/
  freeaddrinfo/gai_strerror/memcpy/__errno_location/strerror with working
  struct-offset globs for the addrinfo walk. Copy it wholesale into
  jac-py/jacpython/ and EXTEND with the functions below rather than
  rewriting from scratch.
- `jac/jaclang/runtimelib/na_stdlib/socket.jac` - facade layering style.
- Registration: follow the `register_shim_module(name, PyModule(...))`
  pattern from `jac-py/jacpython/layer_p2_libtest.jac` lines 780-830.
  Native shims win over delegation automatically per ceval.jac precedence.

Binding functions to ADD beyond the copied set (exact C signatures):

```
def bind(fd: i32, addr: bytes, addrlen: i32) -> i32;      # int bind(int, const struct sockaddr*, socklen_t)
def listen(fd: i32, backlog: i32) -> i32;
def accept(fd: i32, addr: bytes, addrlen: bytes) -> i32;  # addrlen is value-result: pass len-slot bytes like dest_len idiom
def getsockopt(fd: i32, level: i32, optname: i32, optval: bytes, optlen: bytes) -> i32;
def setsockopt(fd: i32, level: i32, optname: i32, optval: bytes, optlen: u64) -> i32;
def getsockname(fd: i32, addr: bytes, addrlen: bytes) -> i32;
def getpeername(fd: i32, addr: bytes, addrlen: bytes) -> i32;
def sendto(fd: i32, buf: bytes, n: u64, flags: i32, addr: bytes, addrlen: i32) -> i64;
def recvfrom(fd: i32, buf: bytes, n: u64, flags: i32, addr: bytes, addrlen: bytes) -> i64;
def inet_pton(af: i32, src: str, dst: bytes) -> i32;
def inet_ntop(af: i32, src: bytes, dst: bytes, size: u64) -> str;
def htons(x: u16) -> u16;
def fcntl(fd: i32, cmd: i32, arg: i64) -> i32;            # F_GETFL 3 / F_SETFL 4, O_NONBLOCK 0x800 for timeout support
```

sockaddr_in layout constants for AF_INET (port at offset 2 big-endian,
address at offset 4 little-endian, total 16): encode/decode helpers in the
facade named `pack_sockaddr_in(host, port)` / `unpack_sockaddr_in(bytes)`.
Model them on the `_AI_*_OFF` glob pattern in the copied file.

Facade surface order (test after each):

1. `socket(family=AF_INET, type=SOCK_STREAM)` object wrapping fd;
   connect/bind/listen/accept/send/recv/close/shutdown.
2. getsockname/getpeername/setsockopt(SO_REUSEADDR)/getsockopt.
3. inet_aton-style helpers via inet_pton/inet_ntop; hostname resolution via
   the copied getaddrinfo walk.
4. `settimeout(sec)` via fcntl O_NONBLOCK + poll-before-recv (needs Phase 2
   select primitive; stub raising NotImplementedError until then).
5. `socketpair` via two connected sockets on loopback (CPython does this on
   some platforms; acceptable v1) OR `socketpair` syscall added to binds.

Phase 1 acceptance: 20 pins minimum in test_socket_native.jac using
`p2_libtest_expect_ok`, oracle stdout captured from host python3 runs of
identical snippets. Required behaviors mapped to
reference/cpython/Lib/test/test_socket.py names cited per pin:
loopback TCP echo (testSockOpen style), sendall/recv split across packets,
bind to port 0 then getsockname reveals ephemeral port, SO_REUSEADDR
rebinding, ConnectionRefusedError on closed port, connection to
nonexistent host raises OSError family with errno, inet_pton roundtrip
v4 and v6, getaddrinfo('localhost') non-empty, shutdown(SHUT_RDWR) then
recv returns b'', UDP sendto/recvfrom roundtrip, two clients accepted
sequentially by one server, 64KB transfer, unicode-free binary payload
integrity, close-twice is no-op, fd negative on closed, timeout stub
raises until Phase 2. Expected: 18+ of 20 green locally (the two timeout
pins flip green in Phase 2; mark them with `# PENDING-PHASE-2` comments).

Commit: `feat(jac-py): guest socket facade over libc bindings`.

## 3. Phase 2: select/poll primitives

Create:

- `jac-py/jacpython/_select_native.jac`:

  ```
  def select(nfds: i32, rset: bytes, wset: bytes, eset: bytes, timeout: bytes) -> i32;  # timeout is pointer-to-struct-timeval (bytes len-slot)
  ```

  fd_set is a fixed 1024-bit bitmap (128 bytes). Build/clear bits with Jac
  byte indexing; copy buffer discipline from_socket_native.jac.
- `jac-py/jacpython/select.jac`: select(rlist, wlist, xlist, timeout)
  returning three lists, plus a minimal `poll` class backed by the same
  select syscall (poll() itself optional; do not add if select suffices).
- Wire socket.settimeout from Phase 1 item 4 through select-before-io.
- Flip the two `# PENDING-PHASE-2` pins green.

Acceptance: 8 pins (select detects readable pipe-less sockets, zero
timeout returns empty immediately after data consumed, timeout=None blocks
until echo server writes, settimeout(0.5) raises socket.timeout, writable
socket ready after connect). Gate: `.venv/bin/jac test
jac-py/jacpython/test_socket_native.jac` still fully green plus new
`test_select_native.jac` 8/8.

## 4. Phase 3: ssl over OpenSSL

Template: `jac/jaclang/runtimelib/na_stdlib/_ssl_native.jac` ALREADY declares
the full needed surface (TLS_client_method, SSL_CTX_new, SSL_set_verify,
SSL_CTX_load_verify_locations, SSL_CTX_set_default_verify_paths, SSL_new,
SSL_set_fd, SSL_ctrl for SNI, SSL_set1_host, SSL_connect, SSL_get_error,
SSL_read, SSL_write, SSL_shutdown, SSL_free, verify-result + crypto error
strings). Copy it and `_ssl_native`'s companion facade
`jac/jaclang/runtimelib/na_stdlib/ssl.jac` into jac-py/jacpython/, adapt
imports to the local `_socket_native`, register as shim "ssl".

Add only these if missing:

```
def SSL_write_all not needed - loop SSL_write in glue instead.
def SSL_get_fd(ssl: int) -> i32;
```

Facade surface: `ssl.SSLSocket` wrapping the Phase 1 socket object
(wrap_socket / create_default_context), `SSLContext.load_verify_locations`,
default context creation with system verify paths, SNI via the SSL_ctrl
glob pattern already in the template, certificate error mapping to
ssl.SSLError / ssl.SSLCertVerificationError with text from
X509_verify_cert_error_string.

Acceptance against real endpoints needs network; keep AWS-free by testing
against a LOCAL TLS server: launch `openssl s_server` or a tiny host-python
https.server with a self-signed cert in a fixture, plus one pin hitting
https://example.com marked skip-if-offline (guard with try/except around a
DNS probe snippet). 10 pins minimum: handshake success, read/write
roundtrip over TLS, wrong-hostname verification failure message matches
host oracle, untrusted-ca rejection, trusted-ca via load_verify_locations
passes, SNI sent (verify with s_server -servername output), EOF handling,
shutdown clean, SSLError raised on plaintext socket wrap, context reuse
for two connections.

## 5. Phase 4: http.client / urllib.request

These are pure Python in CPython. Route: convert with py2jac from
reference/cpython/Lib/http/client.py and Lib/urllib/request.py ONLY IF the
guest can already import converted pure-Python stdlib files today
(D3 import path). Check by attempting to import any previously converted
pure-Python module in a guest snippet. If that machinery is not ready,
STOP here, report Phases 1-3 complete, and leave Phase 4 as a documented
handoff. Do not hand-reimplement HTTP in Jac.

## 6. Verification commands (every phase)

```bash
.venv/bin/jac check jac-py/jacpython/<files>.jac
.venv/bin/jac test jac-py/jacpython/test_socket_native.jac
.venv/bin/jac test jac-py/jacpython/test_select_native.jac   # phase 2+
git log origin/..HEAD --oneline
```

CI: append matrix lines in `.github/workflows/jacpy-gates.yml` for each new
test file as its phase lands.

## 7. Effort estimate

Phase 1: 4 days. Phase 2: 2 days. Phase 3: 4 days. Phase 4: 0 (handoff) or
2 days if D3 imports exist. Total 10-12 executor-days.

## 8. STOP conditions

- FFI smoke fails (see prerequisites).
- accept()/getsockname() value-result length slots misbehave after 2
  debugging attempts with the dest_len idiom: escalate, the marshaling
  convention may need a compiler-side fix.
- OpenSSL handshake crashes the VM process rather than returning errors.
- Phase 4 reached without pure-Python stdlib import machinery: handoff,
  not failure.
