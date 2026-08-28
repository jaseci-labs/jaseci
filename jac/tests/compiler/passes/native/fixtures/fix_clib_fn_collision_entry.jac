"""Entry module for clib/Jac function name-collision fix test.

Imports only the wrapper from the FFI floor but defines a public `ioctl`
with the same LLVM symbol name the libc decl would use if re-walked.
"""

import from fix_clib_fn_collision_lib { do_ioctl }


def:pub ioctl(fd: int, request: int, arg: bytes) -> bytes {
    rc: int = do_ioctl(fd, request, arg);
    if rc < 0 {
        raise ValueError("ioctl failed");
    }
    return arg;
}

with entry {}
