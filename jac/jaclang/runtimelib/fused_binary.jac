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

def has_runtime(path: str = "") -> bool {
    exe = Path(path or os.path.realpath(sys.executable));
    if not exe.is_file() {
        return False;
    }
    return fused_base_length(exe.read_bytes()) >= 0;
}

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
