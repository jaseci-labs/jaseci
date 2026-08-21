"""Portable libc floor for the fused runtime: positional file reads (the
POSIX fd API, which the native runtime's own stdio helpers never declare),
directory listing for the cache GC, and the pointer-string plumbing the PEP
741 string lists need. Everything here exists under the same names on Linux
and macOS; the OS-specific pieces (the dynamic loader, the executable's own
path) are the bundled `_dl_native` / `_exec_native` floors."""

import from c {
    def pread(fd: i32, buf: bytes, n: int, off: int) -> int;
    def close(fd: i32) -> i32;
    def getuid() -> i32;
    def opendir(path: str) -> int;
    def readdir(dirp: int) -> int;
    def closedir(dirp: int) -> i32;
    def malloc(size: int) -> int;
    def free(ptr: int) -> None;
    def strcpy(dst: int, src: str) -> int;
    def strdup(s: int) -> str;
    def memcpy(dst: bytes, src: int, n: int) -> int;
    def memmove(dst: int, src: bytes, n: int) -> int;
}
import from _dirent_native { dirent_name }
import from _fd_native { open_readonly }

"""Read `n` bytes of `path` starting at `off` (short on EOF; b"" on error)."""
def:pub read_at(path: str, off: int, n: int) -> bytes {
    fd = open_readonly(path);
    if fd < 0 {
        return b"";
    }
    buf = b"\x00" * n;
    got = pread(fd, buf, n, off);
    close(fd);
    if got < 0 {
        return b"";
    }
    return buf[0:got];
}

"""Entry names of a directory (no `.`/`..`), or [] if it cannot be opened."""
def:pub listdir(path: str) -> list[str] {
    names: list[str] = [];
    dirp = opendir(path);
    if dirp == 0 {
        return names;
    }
    ent = readdir(dirp);
    while ent != 0 {
        name = dirent_name(ent);
        if name != "." and name != ".." {
            names.append(name);
        }
        ent = readdir(dirp);
    }
    closedir(dirp);
    return names;
}

"""Read a C string out of a pointer."""
def:pub c_string(ptr: int) -> str {
    return strdup(ptr);
}

"""Copy a Jac string into malloc'd memory and return its address. The caller
owns the allocation (`free`)."""
def:pub c_alloc_string(s: str) -> int {
    p = malloc(len(s.encode()) + 1);
    strcpy(p, s);
    return p;
}

"""Copy `n` bytes out of raw memory at `ptr`."""
def:pub peek(ptr: int, n: int) -> bytes {
    buf = b"\x00" * n;
    memcpy(buf, ptr, n);
    return buf;
}

"""Copy `data` into raw memory at `ptr`."""
def:pub poke(ptr: int, data: bytes) {
    memmove(ptr, data, len(data));
}
