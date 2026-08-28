"""Native `select` floor (Mechanism F over libc, POSIX host only).

`select(rlist, wlist, xlist, timeout=-1.0) -> (r, w, x)` over `poll(2)`.
poll is used instead of the raw BSD select syscall because its timeout
has a real "block forever" value (-1), which sidesteps needing a NULL
timeval pointer through the bytes-buffer ABI.

DIVERGENCES from CPython:
- "block forever" is the default `-1.0` sentinel instead of `None`
  (a typed float parameter cannot carry None natively); a non-negative
  value is a seconds timeout like CPython.
- fd readiness maps POLLERR/POLLHUP into both the readable and writable
  results (CPython's select reports them readable); POLLPRI is never
  requested, so the exceptional list is always empty -- pass `[]`.
- fd >= FD_SETSIZE (1024) raise ValueError like CPython; poll failures
  raise ValueError where CPython raises OSError variants.
"""
import from c { def poll(fds: bytes, nfds: u64, timeout: i32) -> i32;  }

glob _FD_SETSIZE: int = 1024,
     _POLLIN: int = 1,
     _POLLOUT: int = 4,
     _POLLERR: int = 8,
     _POLLHUP: int = 16;


def _add_entry(buf: bytes, slot: int, fd: int, events: int) {
    base: int = slot * 8;
    buf[base] = fd & 0xFF;
    buf[base + 1] = (fd >> 8) & 0xFF;
    buf[base + 2] = (fd >> 16) & 0xFF;
    buf[base + 3] = (fd >> 24) & 0xFF;
    # events / revents are little-endian i16 halves at +4 / +6
    buf[base + 4] = events & 0xFF;
    buf[base + 5] = (events >> 8) & 0xFF;
}


def _revents_at(buf: bytes, slot: int) -> int {
    base: int = slot * 8;
    return buf[base + 6] + buf[base + 7] * 256;
}


def _fd_at(buf: bytes, slot: int) -> int {
    base: int = slot * 8;
    return (
        buf[base]
        + buf[base + 1] * 256
        + buf[base + 2] * 65536
        + buf[base + 3] * 16777216
    );
}


def _check_fd(fd: int) {
    if fd < 0 or fd >= _FD_SETSIZE {
        raise ValueError("filedescriptor out of range in select()");
    }
}


def:pub select(
    rlist: list[int],
    wlist: list[int],
    xlist: list[int],
    timeout: float = -1.0
) -> tuple[(list[int], list[int], list[int])] {
    fds: list[int] = [];
    masks: list[int] = [];

    for fd in rlist {
        _check_fd(fd);
        found: bool = False;
        k: int = 0;
        while k < len(fds) {
            if fds[k] == fd {
                masks[k] = masks[k] | (_POLLIN | _POLLERR);
                found = True;
                break;
            }
            k += 1;
        }
        if not found {
            fds.append(fd);
            masks.append(_POLLIN | _POLLERR);
        }
    }
    for fd in wlist {
        _check_fd(fd);
        found: bool = False;
        k: int = 0;
        while k < len(fds) {
            if fds[k] == fd {
                masks[k] = masks[k] | (_POLLOUT | _POLLERR);
                found = True;
                break;
            }
            k += 1;
        }
        if not found {
            fds.append(fd);
            masks.append(_POLLOUT | _POLLERR);
        }
    }

    n: int = len(fds);
    buf: bytes = b"\x00" * ((n * 8) + 1);
    k: int = 0;
    while k < n {
        _add_entry(buf, k, fds[k], masks[k]);
        k += 1;
    }

    tmo: int = -1;
    if timeout >= 0.0 {
        tmo = int(timeout * 1000.0);
    }
    rc: int = poll(buf, n, tmo);
    if rc < 0 {
        raise ValueError("poll failed");
    }
    out_r: list[int] = [];
    out_w: list[int] = [];
    out_x: list[int] = [];
    k = 0;
    while k < n {
        rev: int = _revents_at(buf, k);
        if rev != 0 {
            fd: int = _fd_at(buf, k);
            if (rev & (_POLLIN | _POLLERR | _POLLHUP)) != 0 {
                out_r.append(fd);
            }
            if (rev & (_POLLOUT | _POLLERR | _POLLHUP)) != 0 {
                out_w.append(fd);
            }
        }
        k += 1;
    }
    return (out_r, out_w, out_x);
}
