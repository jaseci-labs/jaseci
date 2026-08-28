"""Native `termios` floor (Mechanism F over libc, POSIX host only).

`tcgetattr(fd)` / `tcsetattr(fd, when, attrs)` matching CPython's shape:
`attrs` is `[iflag, oflag, cflag, lflag, ispeed, ospeed, cc]` where `cc`
is the 32-entry control-character list (ints on Linux, exactly what
CPython's Linux `termios` returns). `tcsetattr` accepts either a full
attrs list from `tcgetattr` or an opaque blob tuple produced here.

The raw struct bytes travel opaquely between calls (see
`_termios_native.jac` for the layout), so save/restore round-trips are
byte-exact even for fields this surface does not interpret.

DIVERGENCES: errors raise ValueError with a static message where CPython
raises `termios.error` (an OSError subclass); `tcsetattr` does not map
the optional `when` constants through `os.TCSA*` aliases.
"""
import from _termios_native {
    get_attrs,
    set_attrs,
    _NCCS,
    _OFF_CC
}

glob TCSANOW: int = 0,
     TCSADRAIN: int = 1,
     TCSAFLUSH: int = 2;

glob TIOCGWINSZ: int = 21523;

# c_cc indices (Linux)
glob VINTR: int = 0,
     VQUIT: int = 1,
     VERASE: int = 2,
     VKILL: int = 3,
     VEOF: int = 4,
     VTIME: int = 5,
     VMIN: int = 6,
     VSWTC: int = 7,
     VSTART: int = 8,
     VSTOP: int = 9,
     VSUSP: int = 10,
     VEOL: int = 11,
     VREPRINT: int = 12,
     VDISCARD: int = 13,
     VWERASE: int = 14,
     VLNEXT: int = 15,
     VEOL2: int = 16;

# input flags
glob BRKINT: int = 2,
     ICRNL: int = 256,
     INPCK: int = 16,
     ISTRIP: int = 64,
     IXON: int = 1024,
     IGNBRK: int = 1,
     IGNCR: int = 128,
     INLCR: int = 64,
     IXANY: int = 2048,
     PARMRK: int = 8;

# output flags
glob OPOST: int = 1,
     ONLCR: int = 4;

# control flags
glob CSIZE: int = 48,
     CSTOPB: int = 64,
     CREAD: int = 128,
     PARENB: int = 256,
     PARODD: int = 512,
     CS7: int = 32,
     CS8: int = 48,
     HUPCL: int = 1024;

# local flags
glob ECHO: int = 8,
     ICANON: int = 2,
     IEXTEN: int = 32768,
     ISIG: int = 1,
     NOFLSH: int = 128,
     TOSTOP: int = 256;


def:pub tcgetattr(fd: int) -> list {
    (blob, flags) = get_attrs(fd);
    if flags[0] == -1 and flags[1] == -1 {
        raise ValueError("tcgetattr failed");
    }
    out: list = [flags[0], flags[1], flags[2], flags[3], flags[4], flags[5]];
    cc: list[int] = [];
    k: int = 0;
    while k < _NCCS {
        cc.append(blob[_OFF_CC + k]);
        k += 1;
    }
    out.append(cc);
    return out;
}


def _pack_attrs(attrs: list) -> bytes {
    blob: bytes = b"\x00" * 60;
    blob[0] = attrs[0] & 0xFF;
    blob[1] = (attrs[0] >> 8) & 0xFF;
    blob[2] = (attrs[0] >> 16) & 0xFF;
    blob[3] = (attrs[0] >> 24) & 0xFF;
    blob[4] = attrs[1] & 0xFF;
    blob[5] = (attrs[1] >> 8) & 0xFF;
    blob[6] = (attrs[1] >> 16) & 0xFF;
    blob[7] = (attrs[1] >> 24) & 0xFF;
    blob[8] = attrs[2] & 0xFF;
    blob[9] = (attrs[2] >> 8) & 0xFF;
    blob[10] = (attrs[2] >> 16) & 0xFF;
    blob[11] = (attrs[2] >> 24) & 0xFF;
    blob[12] = attrs[3] & 0xFF;
    blob[13] = (attrs[3] >> 8) & 0xFF;
    blob[14] = (attrs[3] >> 16) & 0xFF;
    blob[15] = (attrs[3] >> 24) & 0xFF;
    cc: list[int] = attrs[6];
    k: int = 0;
    while k < _NCCS {
        blob[_OFF_CC + k] = cc[k] & 0xFF;
        k += 1;
    }
    blob[52] = attrs[4] & 0xFF;
    blob[53] = (attrs[4] >> 8) & 0xFF;
    blob[54] = (attrs[4] >> 16) & 0xFF;
    blob[55] = (attrs[4] >> 24) & 0xFF;
    blob[56] = attrs[5] & 0xFF;
    blob[57] = (attrs[5] >> 8) & 0xFF;
    blob[58] = (attrs[5] >> 16) & 0xFF;
    blob[59] = (attrs[5] >> 24) & 0xFF;
    return blob;
}


def:pub tcsetattr(fd: int, when: int, attrs: any) -> None {
    if isinstance(attrs, list) {
        # full CPython-shaped attrs: repack into the struct layout
        if len(attrs) < 7 {
            raise ValueError("tcsetattr: attrs must have 7 elements");
        }
        rc: int = set_attrs(fd, when, _pack_attrs(attrs));
        if rc != 0 {
            raise ValueError("tcsetattr failed");
        }
        return;
    }
    # opaque blob path (exact saved bytes)
    rc: int = set_attrs(fd, when, attrs);
    if rc != 0 {
        raise ValueError("tcsetattr failed");
    }
}
