"""FFI floor for the `termios` surface (Mechanism F over libc).

`struct termios` (glibc, LP64): four `tcflag_t` (u32) flags, `cc_t c_line`,
`cc_t c_cc[32]`, padding to the 4-byte alignment of `speed_t`, then
`c_ispeed` / `c_ospeed` -- 60 bytes total:

    off  0  c_iflag     off 32..47  c_cc[16..31]
    off  4  c_oflag     off 49..51  pad
    off  8  c_cflag     off 52      c_ispeed
    off 12  c_lflag     off 56      c_ospeed
    off 16  c_line
    off 17  c_cc[0..15]

Buffers travel as `bytes` (raw element pointer per the clib ABI), so the
surface can hold an opaque attribute blob and hand it straight back.
"""
import from c { def tcgetattr(fd: i32, buf: bytes) -> i32;  }
import from c { def tcsetattr(fd: i32, act: i32, buf: bytes) -> i32;  }
import from c { def cfgetispeed(buf: bytes) -> u32;  }
import from c { def cfgetospeed(buf: bytes) -> u32;  }

glob _T_SIZE: int = 60,
     _OFF_IFLAG: int = 0,
     _OFF_OFLAG: int = 4,
     _OFF_CFLAG: int = 8,
     _OFF_LFLAG: int = 12,
     _OFF_LINE: int = 16,
     _OFF_CC: int = 17,
     _NCCS: int = 32,
     _OFF_ISPEED: int = 52,
     _OFF_OSPEED: int = 56;


def _u32_at(buf: bytes, off: int) -> int {
    return (
        buf[off]
        + buf[off + 1] * 256
        + buf[off + 2] * 65536
        + buf[off + 3] * 16777216
    );
}


def _put_u32(buf: bytes, off: int, v: int) {
    buf[off] = v & 0xFF;
    buf[off + 1] = (v >> 8) & 0xFF;
    buf[off + 2] = (v >> 16) & 0xFF;
    buf[off + 3] = (v >> 24) & 0xFF;
}


def _new_buf() -> bytes {
    return b"\x00" * _T_SIZE;
}


def _fail_flags() -> list[int] {
    out: list[int] = [];
    k: int = 0;
    while k < 6 {
        out.append(-1);
        k += 1;
    }
    return out;
}


# tcgetattr(3): opaque blob plus [iflag, oflag, cflag, lflag, ispeed, ospeed],
# or -1 markers on failure.
def:pub get_attrs(fd: int) -> tuple[(bytes, list[int])] {
    buf: bytes = _new_buf();
    rc: int = tcgetattr(fd, buf);
    if rc != 0 {
        return (buf, _fail_flags());
    }
    return (
        buf,
        [
            _u32_at(buf, _OFF_IFLAG),
            _u32_at(buf, _OFF_OFLAG),
            _u32_at(buf, _OFF_CFLAG),
            _u32_at(buf, _OFF_LFLAG),
            cfgetispeed(buf),
            cfgetospeed(buf),
        ],
    );
}


def:pub set_attrs(fd: int, when: int, blob: bytes) -> int {
    return tcsetattr(fd, when, blob);
}


def:pub set_flags(
    fd: int, when: int, iflag: int, oflag: int, cflag: int, lflag: int
) -> int {
    buf: bytes = _new_buf();
    if tcgetattr(fd, buf) != 0 {
        return -1;
    }
    _put_u32(buf, _OFF_IFLAG, iflag);
    _put_u32(buf, _OFF_OFLAG, oflag);
    _put_u32(buf, _OFF_CFLAG, cflag);
    _put_u32(buf, _OFF_LFLAG, lflag);
    return tcsetattr(fd, when, buf);
}
