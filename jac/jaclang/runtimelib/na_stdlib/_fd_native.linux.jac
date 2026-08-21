"""File-descriptor floor (Linux): open a path read-only through `openat`,
which does not collide with the builtin `open`. `_fd_native.darwin.jac` is
the macOS twin (different `AT_FDCWD`)."""

import from c { def openat(dirfd: i32, path: str, flags: i32) -> i32; }

glob AT_FDCWD: int = -100;

"""A read-only descriptor for `path`, or -1."""
def:pub open_readonly(path: str) -> i32 {
    return openat(AT_FDCWD, path, 0);
}
