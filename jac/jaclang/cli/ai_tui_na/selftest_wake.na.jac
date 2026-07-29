"""Native selftest: self-pipe wake plumbing for the event-driven TUI loop.

Guards the native half of the wakeup redesign:
  - tty_drain_wake() fully empties a nonblocking pipe (backlog -> idle),
  - tty_set_wake_fd/tty_clear_wake_fd/tty_wake_ready track registration state,
  - the 3-pollfd buffer layout (24 bytes) reads revents at the right offsets so
    a wake on pollfd[2] is detected without false positives on [0]/[1].

Pure native: imports only .libc_tty helpers + libc primitives (no CPython), so
it builds and runs wherever the jac native toolchain exists.
"""

import from .libc_tty {
    tty_set_wake_fd,
    tty_clear_wake_fd,
    tty_wake_ready,
    tty_drain_wake,
    read_u32,
    u16le,
    poke_u32
}
import from .tty_plat {
    read,
    write,
    poll,
    fcntl,
    calloc,
    free,
    memset,
    O_NONBLOCK
}

import from "libc.so.6" {
    def pipe(fds: str) -> i32;
}

glob _POLLIN: int = 1,
     _F_SETFL: int = 4;


obj Pipe2 {
    has rfd: int = -1,
        wfd: int = -1;
}


def _check(label: str, ok: bool) {
    if ok {
        print("PASS " + label);
    } else {
        print("FAIL " + label);
    }
}


def _make_pipe -> Pipe2 {
    # Both ends nonblocking, like the Python-owned pipe.
    buf: str = calloc(8, 1);
    rc: int = pipe(buf);
    if rc != 0 {
        free(buf);
        return Pipe2(rfd=-1, wfd=-1);
    }
    rfd: int = read_u32(buf, 0);
    wfd: int = read_u32(buf, 4);
    free(buf);
    fcntl(rfd, _F_SETFL, O_NONBLOCK);
    fcntl(wfd, _F_SETFL, O_NONBLOCK);
    return Pipe2(rfd=rfd, wfd=wfd);
}


def _drain_count(fd: int) -> int {
    total: int = 0;
    buf: str = calloc(64, 1);
    while True {
        n: int = read(fd, buf, 64);
        # i32 -1 (EAGAIN) widens to 0xFFFFFFFF, so stop outside the 1..64 window.
        if n <= 0 or n > 64 {
            break;
        }
        total += n;
    }
    free(buf);
    return total;
}


with entry {
    # 1. tty_drain_wake empties the whole backlog, leaving the pipe drained.
    pipe0: Pipe2 = _make_pipe();
    _check("wake_pipe_created", pipe0.rfd >= 0 and pipe0.wfd >= 0);
    payload: str = "12345";
    write(pipe0.wfd, payload, 5);
    tty_set_wake_fd(pipe0.rfd);
    tty_drain_wake();
    # After draining, nothing remains to read (EAGAIN -> read <= 0).
    _check("drain_empties_pipe", _drain_count(pipe0.rfd) == 0);

    # 2. A fresh byte after draining is still observable (fd stayed valid).
    write(pipe0.wfd, payload, 1);
    _check("post_drain_byte_readable", _drain_count(pipe0.rfd) == 1);

    # 3. Registration state: clear resets wake_fd + wake_ready.
    tty_clear_wake_fd();
    _check("wake_ready_false_after_clear", tty_wake_ready() == False);

    # 4. 3-pollfd layout: only pollfd[2] (the wake fd) carries data. Mirrors the
    #    exact calloc/poke/u16le arithmetic in tty_poll so a bad offset is caught.
    pa: Pipe2 = _make_pipe();
    pb: Pipe2 = _make_pipe();
    pc: Pipe2 = _make_pipe();
    write(pc.wfd, payload, 1);          # data only on the 3rd (wake) fd
    p: int = calloc(24, 1);
    poke_u32(p, 0, pa.rfd);
    memset(p + 4, _POLLIN, 1);
    poke_u32(p, 8, pb.rfd);
    memset(p + 12, _POLLIN, 1);
    poke_u32(p, 16, pc.rfd);
    memset(p + 20, _POLLIN, 1);
    fds: str = p;
    nready: int = poll(fds, 3, 200);
    rev0: int = u16le(fds, 6);
    rev1: int = u16le(fds, 14);
    rev2: int = u16le(fds, 22);
    free(p);
    _check("poll_reports_one_ready", nready == 1);
    _check("pollfd0_not_ready", rev0 & _POLLIN == 0);
    _check("pollfd1_not_ready", rev1 & _POLLIN == 0);
    _check("pollfd2_wake_ready", rev2 & _POLLIN != 0);
}
