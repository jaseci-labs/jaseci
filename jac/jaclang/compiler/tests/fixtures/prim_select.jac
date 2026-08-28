"""Bundled native `select` cross-backend equivalence fixture (Mechanism F).

`import select` binds CPython's `select` on sv and `na_stdlib/select.jac` on na.
Pipe fds: `os.pipe()` on sv, libc `pipe(2)` on na. ES/JS opts out (POSIX-only).

DIVERGENCE: na uses `-1.0` as the block-forever sentinel (not `None`); this
fixture sticks to `timeout=0.0` probes only.
"""

import os;
import select;
import from c {
    def pipe(fds: bytes) -> i32;
    def write(fd: i32, buf: bytes, n: u64) -> i64;
    def close(fd: i32) -> i32;
}


def _pipe_na() -> tuple[(int, int)] {
    fds: bytes = b"\x00\x00\x00\x00\x00\x00\x00\x00";
    pipe(fds);
    r: int = fds[0] + fds[1] * 256 + fds[2] * 65536 + fds[3] * 16777216;
    w: int = fds[4] + fds[5] * 256 + fds[6] * 65536 + fds[7] * 16777216;
    return (r, w);
}


def _w_ready(wfd: int) -> int {
    (_r, wlist, _x) = select.select([], [wfd], [], 0.0);
    return 1 if len(wlist) > 0 else 0;
}


def select_py -> dict {
    (rfd, wfd) = os.pipe();
    os.write(wfd, b"x");
    write_ready: int = _w_ready(wfd);
    (er, ew, ex) = select.select([], [], [], 0.0);
    empty_ok: int = 1 if len(er) == 0 and len(ew) == 0 and len(ex) == 0 else 0;
    os.close(rfd);
    os.close(wfd);
    return {"write_ready": write_ready, "empty_ok": empty_ok};
}


def select_cl -> dict {
    return {};
}


def select_na -> dict[str, any] {
    (rfd, wfd) = _pipe_na();
    write(wfd, b"x", 1);
    write_ready: int = _w_ready(wfd);
    (er, ew, ex) = select.select([], [], [], 0.0);
    empty_ok: int = 1 if len(er) == 0 and len(ew) == 0 and len(ex) == 0 else 0;
    close(rfd);
    close(wfd);
    return {"write_ready": write_ready, "empty_ok": empty_ok};
}
