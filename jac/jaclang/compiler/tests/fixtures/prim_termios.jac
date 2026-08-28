"""Bundled native `termios` cross-backend equivalence fixture (Mechanism F).

`import from termios { ... }` binds CPython's `termios` on sv and
`na_stdlib/termios.jac` on na. A pseudo-terminal slave fd from libc `openpty(3)`
is used because `tcgetattr` requires a tty (pipes return ENOTTY). ES/JS opts out
(POSIX-only).
"""

import os;
import from termios {
    tcgetattr,
    tcsetattr,
    TCSADRAIN,
    ECHO,
    ICANON,
    VMIN
}
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


def termios_py -> dict {
    sfd: int = _pty_slave();
    attrs = tcgetattr(sfd);
    alen: int = len(attrs);
    cclen: int = len(attrs[6]);
    saved_iflag: int = attrs[0];
    tcsetattr(sfd, TCSADRAIN, attrs);
    attrs2 = tcgetattr(sfd);
    iflag_match: int = 1 if attrs2[0] == saved_iflag else 0;
    os.close(sfd);
    return {
        "attrs_len": alen,
        "cc_len": cclen,
        "iflag_roundtrip": iflag_match,
        "TCSADRAIN": TCSADRAIN,
        "ECHO": ECHO,
        "ICANON": ICANON,
        "VMIN": VMIN
    };
}


def termios_cl -> dict {
    return {};
}


def termios_na -> dict[str, any] {
    sfd: int = _pty_slave();
    attrs = tcgetattr(sfd);
    alen: int = len(attrs);
    cclen: int = len(attrs[6]);
    saved_iflag: int = attrs[0];
    tcsetattr(sfd, TCSADRAIN, attrs);
    attrs2 = tcgetattr(sfd);
    iflag_match: int = 1 if attrs2[0] == saved_iflag else 0;
    close(sfd);
    return {
        "attrs_len": alen,
        "cc_len": cclen,
        "iflag_roundtrip": iflag_match,
        "TCSADRAIN": TCSADRAIN,
        "ECHO": ECHO,
        "ICANON": ICANON,
        "VMIN": VMIN
    };
}
