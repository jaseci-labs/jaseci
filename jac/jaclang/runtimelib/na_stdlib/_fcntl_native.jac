"""FFI floor for the `fcntl` surface (Mechanism F over libc).

The clib decls live here (not in the surface module) because the
Python-shaped surface functions are themselves named `fcntl` / `ioctl`
-- a clib extern binds under its C symbol name, which would collide.
"""
import from c { def fcntl(fd: i32, cmd: i32, arg: i64) -> i32;  }
import from c { def ioctl(fd: i32, req: u64, arg: bytes) -> i32;  }


def:pub do_fcntl(fd: int, cmd: int, arg: int) -> int {
    return fcntl(fd, cmd, arg);
}


def:pub do_ioctl(fd: int, request: int, arg: bytes) -> int {
    return ioctl(fd, request, arg);
}
