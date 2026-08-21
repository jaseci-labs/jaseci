"""Python-tier surgery on fused single binaries.

The trailer wire format is owned by `_fused.trailer` (bundled native stdlib),
the same source the native launcher parses at boot; this module is the
build-side writer over it: `jac build --as binary` appends an app overlay onto
a copy of the running jac, the desktop builder grafts the running jac's
runtime suffix onto an `na` host binary, and both first ask whether the
running interpreter IS a fused binary at all.
"""

import hashlib;
import os;
import sys;
import from pathlib { Path }
import from jaclang.runtimelib.fused.trailer {
    MAGIC,
    OVERLAY_MAGIC,
    TRAILER_LEN,
    Trailer,
    build_trailer,
    parse_trailer,
    region_start
}

"""The byte length of the base fused binary inside `data`: the whole blob for
a plain jac, or everything before an appended `.jab` overlay. -1 when `data`
does not end in a payload trailer at all (a source / pip jac)."""
def fused_base_length(data: bytes) -> int {
    total = len(data);
    if total < TRAILER_LEN {
        return -1;
    }
    ovl = parse_trailer(data[total - TRAILER_LEN:], OVERLAY_MAGIC);
    if ovl is not None {
        total = region_start(total, ovl.payload_len);
        if total < TRAILER_LEN {
            return -1;
        }
    }
    if parse_trailer(data[total - TRAILER_LEN:], MAGIC) is None {
        return -1;
    }
    return total;
}

"""True if `path` (default: the running interpreter) carries a fused runtime."""
def has_runtime(path: str = "") -> bool {
    exe = Path(path or os.path.realpath(sys.executable));
    if not exe.is_file() {
        return False;
    }
    return fused_base_length(exe.read_bytes()) >= 0;
}

"""Write `[ base ][ jab ][ overlay trailer ]` to `out_path`, producing a
self-contained app binary. `base_path` must be a plain fused jac (its EOF is a
payload trailer, never already an overlay). The base is copied verbatim -- no
CPython unpack/repack -- so the artifact is reproducible whenever the inputs
are. Returns False when the base is not a fused binary."""
def append_overlay(base_path: str, jab_path: str, out_path: str) -> bool {
    base = Path(base_path).read_bytes();
    if len(base) < TRAILER_LEN or parse_trailer(base[-TRAILER_LEN:], MAGIC) is None {
        return False;
    }
    jab = Path(jab_path).read_bytes();
    out = Path(out_path);
    out.write_bytes(
        base
            + jab
            + build_trailer(OVERLAY_MAGIC, len(jab), hashlib.sha256(jab).hexdigest())
    );
    out.chmod(0o755);
    return True;
}

"""Append the fused binary `self_path`'s `[ payload ][ trailer ]` runtime
suffix onto `host_path` in place, fusing the bundled CPython + jaclang runtime
into a foreign host binary (the `na` desktop host). The host is appended to,
never truncated: an interrupted write leaves an invalid trailer on a
regenerable intermediate, not a zeroed host. Returns False when `self_path`
is not a fused binary."""
def graft_runtime(self_path: str, host_path: str) -> bool {
    data = Path(self_path).read_bytes();
    base_total = fused_base_length(data);
    if base_total < 0 {
        return False;
    }
    t = parse_trailer(data[base_total - TRAILER_LEN:base_total], MAGIC);
    start = region_start(base_total, t.payload_len);
    if start < 0 {
        return False;
    }
    with open(host_path, "ab") as f {
        f.write(data[start:base_total]);
    }
    return True;
}
