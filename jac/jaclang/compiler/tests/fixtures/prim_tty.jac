"""Bundled native `tty` cross-backend equivalence fixture (Mechanism F).

`import from tty { setcbreak }` / `import from termios { ... }` bind CPython on
sv and bundled na_stdlib on na. Uses a pty slave fd from `openpty(3)` (pipes
are ENOTTY for termios). `setcbreak` must clear ICANON and ECHO in `mode[3]`
(lflag), then original attrs are restored. ES/JS opts out (POSIX-only).
"""

import os;
import from termios { tcgetattr, tcsetattr, TCSADRAIN, ICANON, ECHO }
import from tty { setcbreak }
import from c {
    def openpty(am: bytes, asl: bytes, name: bytes, t: bytes, w: bytes) -> i32;
    def close(fd: i32) -> i32;
}


def _pty_slave() -> int {
    am: bytes = b"\x00\x00\x00\x00";
    asl: bytes = b"\x00\x00\x00\x00";
    openpty(am, asl, b"\x00", b"\x00", b"\x00");
    m: int = am[0] + am[1] * 256 + am[2] * 65536 + am[3] * 16777216;
    s: int = asl[0] + asl[1] * 256 + asl[2] * 65536 + asl[3] * 16777216;
    close(m);
    return s;
}


def tty_py -> dict {
    sfd: int = _pty_slave();
    orig = tcgetattr(sfd);
    setcbreak(sfd);
    after = tcgetattr(sfd);
    lflag: int = after[3];
    icanon_off: int = 1 if (lflag & ICANON) == 0 else 0;
    echo_off: int = 1 if (lflag & ECHO) == 0 else 0;
    tcsetattr(sfd, TCSADRAIN, orig);
    os.close(sfd);
    return {"icanon_off": icanon_off, "echo_off": echo_off};
}


def tty_cl -> dict {
    return {};
}


def tty_na -> dict[str, any] {
    sfd: int = _pty_slave();
    orig = tcgetattr(sfd);
    setcbreak(sfd);
    after = tcgetattr(sfd);
    lflag: int = after[3];
    icanon_off: int = 1 if (lflag & ICANON) == 0 else 0;
    echo_off: int = 1 if (lflag & ECHO) == 0 else 0;
    tcsetattr(sfd, TCSADRAIN, orig);
    close(sfd);
    return {"icanon_off": icanon_off, "echo_off": echo_off};
}
