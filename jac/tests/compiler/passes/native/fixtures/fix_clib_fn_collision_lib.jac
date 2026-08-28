"""FFI floor for clib/Jac function name-collision fix test.

The clib extern binds under the C symbol name.  A Python-shaped surface
module that also defines `ioctl` must not ICE with DuplicatedNameError when
the dep's clib decl is walked into the entry module's LLVM IR.
"""

import from c { def ioctl(fd: i32, req: u64, arg: bytes) -> i32;  }


def:pub do_ioctl(fd: int, request: int, arg: bytes) -> int {
    return ioctl(fd, request, arg);
}

with entry {}
