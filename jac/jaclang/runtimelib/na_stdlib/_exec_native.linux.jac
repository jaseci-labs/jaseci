"""Process-image floor (Linux): the running executable's own path via
`/proc/self/exe`. `_exec_native.darwin.jac` is the macOS twin."""

import from c { def readlink(path: str, buf: bytes, bufsiz: int) -> int; }

"""This executable's own path, or "" if unresolvable."""
def:pub executable_path -> str {
    buf = b"\x00" * 4096;
    n = readlink("/proc/self/exe", buf, 4095);
    if n <= 0 {
        return "";
    }
    return buf[0:n].decode();
}
