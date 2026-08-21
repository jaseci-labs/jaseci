"""Dynamic-loader floor (macOS): `dlopen`/`dlsym`/`dlerror` from libSystem.
`_dl_native.linux.jac` is the Linux twin; the resolver picks the variant for
the compile target."""

import from c {
    def dlopen(filename: str, flags: i32) -> int;
    def dlsym(handle: int, symbol: str) -> int;
    def dlerror() -> int;
    def strdup(s: int) -> str;
}

glob RTLD_NOW: int = 2;
glob RTLD_GLOBAL: int = 8;
glob SHLIB_EXT: str = ".dylib";

"""Human-readable reason for the last dlopen/dlsym failure."""
def:pub dl_error -> str {
    p = dlerror();
    if p == 0 {
        return "unknown dl error";
    }
    return strdup(p);
}
