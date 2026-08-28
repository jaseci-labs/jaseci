"""Bundled native `fcntl` cross-backend equivalence fixture (Mechanism F).

`import fcntl` / `import from termios { TIOCGWINSZ }` bind CPython on sv and
bundled na_stdlib on na. Pipe fds: `os.pipe()` on sv, libc `pipe(2)` on na.
`ioctl(TIOCGWINSZ)` on stdin fd 0 is attempted; on failure `ws_rows=0` marks skip.
ES/JS opts out (POSIX-only).
"""

import os;
import fcntl;
import from termios { TIOCGWINSZ }
import from c { def pipe(fds: bytes) -> i32; def close(fd: i32) -> i32;  }


def _pipe_na() -> tuple[(int, int)] {
    fds: bytes = b"\x00\x00\x00\x00\x00\x00\x00\x00";
    pipe(fds);
    r: int = fds[0] + fds[1] * 256 + fds[2] * 65536 + fds[3] * 16777216;
    w: int = fds[4] + fds[5] * 256 + fds[6] * 65536 + fds[7] * 16777216;
    return (r, w);
}


def _i16_le(buf: bytes, off: int) -> int {
    v: int = buf[off] + buf[off + 1] * 256;
    if v >= 32768 {
        v = v - 65536;
    }
    return v;
}


def fcntl_py -> dict {
    (rfd, wfd) = os.pipe();
    flags0: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_on: int = flags0 | os.O_NONBLOCK;
    fcntl.fcntl(rfd, fcntl.F_SETFL, nb_on);
    flags1: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    fcntl.fcntl(rfd, fcntl.F_SETFL, flags0);
    flags2: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_toggled: int = 1 if (flags1 & os.O_NONBLOCK) != 0 else 0;
    restored: int = 1 if flags2 == flags0 else 0;
    os.close(rfd);
    os.close(wfd);

    ws_ok: int = 0;
    ws_rows: int = 0;
    ws_cols: int = 0;
    ws_bytes: int = 0;
    try {
        buf: bytes = b"\x00\x00\x00\x00\x00\x00\x00\x00";
        buf = fcntl.ioctl(0, TIOCGWINSZ, buf);
        ws_ok = 1;
        ws_bytes = len(buf);
        ws_rows = buf[0] + buf[1] * 256;
        if ws_rows >= 32768 {
            ws_rows = ws_rows - 65536;
        }
        ws_cols = buf[2] + buf[3] * 256;
        if ws_cols >= 32768 {
            ws_cols = ws_cols - 65536;
        }
    } except OSError {
        ws_rows = 0;
    }
    return {
        "nb_toggled": nb_toggled,
        "restored": restored,
        "ws_ok": ws_ok,
        "ws_rows": ws_rows,
        "ws_cols": ws_cols,
        "ws_bytes": ws_bytes,
        "O_NONBLOCK": os.O_NONBLOCK
    };
}


def fcntl_cl -> dict {
    return {};
}


def fcntl_na -> dict[str, any] {
    (rfd, wfd) = _pipe_na();
    flags0: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_on: int = flags0 | fcntl.O_NONBLOCK;
    fcntl.fcntl(rfd, fcntl.F_SETFL, nb_on);
    flags1: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    fcntl.fcntl(rfd, fcntl.F_SETFL, flags0);
    flags2: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_toggled: int = 1 if (flags1 & fcntl.O_NONBLOCK) != 0 else 0;
    restored: int = 1 if flags2 == flags0 else 0;
    close(rfd);
    close(wfd);

    ws_ok: int = 0;
    ws_rows: int = 0;
    ws_cols: int = 0;
    ws_bytes: int = 0;
    try {
        buf: bytes = b"\x00\x00\x00\x00\x00\x00\x00\x00";
        buf = fcntl.ioctl(0, TIOCGWINSZ, buf);
        ws_ok = 1;
        ws_bytes = len(buf);
        ws_rows = _i16_le(buf, 0);
        ws_cols = _i16_le(buf, 2);
    } except ValueError {
        ws_rows = 0;
    }
    return {
        "nb_toggled": nb_toggled,
        "restored": restored,
        "ws_ok": ws_ok,
        "ws_rows": ws_rows,
        "ws_cols": ws_cols,
        "ws_bytes": ws_bytes,
        "O_NONBLOCK": fcntl.O_NONBLOCK
    };
}
