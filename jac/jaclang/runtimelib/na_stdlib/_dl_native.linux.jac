"""Dynamic-loader floor (Linux): `dlopen`/`dlsym`/`dlerror` bound from
`libdl.so.2` explicitly, so a binary also runs on glibc < 2.34 where they are
not yet part of libc. `_dl_native.darwin.jac` is the macOS twin; the resolver
picks the variant for the compile target."""

import from "libdl.so.2" {
    def dlopen(filename: str, flags: i32) -> int;
    def dlsym(handle: int, symbol: str) -> int;
    def dlerror() -> int;
}
import from c { def strdup(s: int) -> str; }

glob RTLD_NOW: int = 2;
glob RTLD_GLOBAL: int = 256;
glob SHLIB_EXT: str = ".so";

"""Human-readable reason for the last dlopen/dlsym failure."""
def:pub dl_error -> str {
    p = dlerror();
    if p == 0 {
        return "unknown dl error";
    }
    return strdup(p);
}
