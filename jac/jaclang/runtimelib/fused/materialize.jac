"""Runtime materialization for the jac single binary.

Everything between "the process started" and "CPython is about to be
dlopened": find the trailer at the end of this executable, resolve the cache
dir, and on first run verify + zstd-decompress + untar the payload into
`<cache>/rt/<hash16>-<pathhash>/` (per-pid temp dir + atomic rename, `.ok`
marker guarding against partial extracts). Subsequent runs short-circuit on
the marker. The payload is TWO concatenated zstd frames whose decoded
concatenation is one tar stream; `compression.zstd.ZstdFile` + `tarfile`
(the bundled native stdlib) read it exactly as CPython would.

Shared by the `jac` launcher stub and the desktop host (both through
`_fused.embed`); the on-disk format itself lives in `_fused.trailer`.
"""

import hashlib;
import os;
import shutil;
import tarfile;
import time;
import from compression.zstd { ZstdFile }
import from io { BytesIO }
import from .trailer {
    MAGIC,
    OVERLAY_MAGIC,
    TRAILER_LEN,
    Trailer,
    parse_trailer,
    region_start,
    rt_key,
    rt_key_pathhash
}
import from ._libc { read_at, getuid, listdir }
import from .report { die, say }

"""An appended `.jab` app overlay: `[off, off+length)` is the raw `.jab`."""
obj Overlay {
    has off: int = 0,
        length: int = 0;
}

"""The trailer terminating the file region `[0, end)`, under `magic`."""
def trailer_at(path: str, end: int, magic: bytes) -> Trailer | None {
    if end < TRAILER_LEN {
        return None;
    }
    return parse_trailer(read_at(path, end - TRAILER_LEN, TRAILER_LEN), magic);
}

"""If the binary ends in an overlay trailer, the appended `.jab`'s span."""
def:pub peek_overlay(exe_path: str, total: int) -> Overlay | None {
    t = trailer_at(exe_path, total, OVERLAY_MAGIC);
    if t is None {
        return None;
    }
    off = region_start(total, t.payload_len);
    if off < 0 {
        die("corrupt app overlay (length exceeds the binary)");
        return None;
    }
    return Overlay(off=off, length=t.payload_len);
}

"""Report a trailing `.jab` overlay on `exe_path`, or None for a plain jac."""
def:pub overlay_for_path(exe_path: str) -> Overlay | None {
    total = os.path.getsize(exe_path);
    if total < TRAILER_LEN {
        return None;
    }
    return peek_overlay(exe_path, total);
}

"""True if `path` is a directory we can create files in."""
def dir_writable(path: str) -> bool {
    os.makedirs(path, exist_ok=True);
    if not os.path.isdir(path) {
        return False;
    }
    probe = path + "/.jac-write-probe";
    with open(probe, "wb") as f {
        f.write(b"");
    }
    if not os.path.isfile(probe) {
        return False;
    }
    os.remove(probe);
    return True;
}

"""The global cache cache_dir, mirroring jaclang's cache_paths: `$XDG_CACHE_HOME`
-> `$HOME/.cache`, then `/jac`; a per-uid temp dir when that is unwritable."""
def:pub cache_root -> str {
    base: str = os.environ.get("XDG_CACHE_HOME", "");
    if base == "" {
        home: str = os.environ.get("HOME", "");
        if home != "" {
            base = home + "/.cache";
        }
    }
    if base != "" {
        preferred: str = base + "/jac";
        if dir_writable(preferred) {
            return preferred;
        }
    }
    tmp: str = os.environ.get("TMPDIR", "");
    if tmp == "" {
        tmp = "/tmp";
    }
    fallback: str = f"{tmp}/jac-cache-{getuid()}";
    if not dir_writable(fallback) {
        die("no writable cache directory (set XDG_CACHE_HOME or TMPDIR)");
        return "";
    }
    return fallback;
}

"""Resolve (and on first run, extract) the runtime tree for this binary;
returns `<cache>/rt/<hash16>-<pathhash>`."""
def:pub materialize(exe_path: str) -> str {
    total = os.path.getsize(exe_path);
    if total < TRAILER_LEN {
        die("binary too small to carry a runtime payload");
        return "";
    }
    ovl = peek_overlay(exe_path, total);
    if ovl is not None {
        total = ovl.off;
    }
    trailer = trailer_at(exe_path, total, MAGIC);
    if trailer is None {
        die("no runtime payload trailer (this is not a bundled jac binary)");
        return "";
    }
    cache_dir = cache_root();
    key = rt_key(trailer.hash16(), exe_path);
    rt = f"{cache_dir}/rt/{key}";
    if os.path.isfile(rt + "/.ok") {
        return rt;
    }

    t0 = time.monotonic();
    say("first run, performing one-time setup...");
    say(f"  runtime cache: {rt}");
    say(f"  reading embedded payload ({trailer.payload_len // 1048576} MiB)...");
    poff = region_start(total, trailer.payload_len);
    if poff < 0 {
        die("corrupt payload trailer (length exceeds the binary)");
        return "";
    }
    zbuf = read_at(exe_path, poff, trailer.payload_len);
    if len(zbuf) != trailer.payload_len {
        die("short read of the embedded payload");
        return "";
    }
    say("  verifying payload (sha256)...");
    if hashlib.sha256(zbuf).hexdigest() != trailer.hash_hex {
        die("payload integrity check failed (truncated or tampered binary)");
        return "";
    }
    extract_payload(zbuf, rt);
    gc_stale(cache_dir, key);
    secs = time.monotonic() - t0;
    say(f"one-time setup complete ({secs:.1f}s).");
    return rt;
}

"""zstd-decompress + untar `zbuf` into `<rt>` via a per-pid temp dir and an
atomic rename. The `.ok` marker is stamped inside the temp dir before the
rename, so it can never appear on an incomplete tree."""
def:pub extract_payload(zbuf: bytes, rt: str) {
    tmp = f"{rt}.tmp.{os.getpid()}";
    if os.path.isdir(tmp) {
        shutil.rmtree(tmp);
    }
    os.makedirs(tmp, exist_ok=True);
    say("  extracting runtime...");
    tf = tarfile.open(fileobj=ZstdFile(BytesIO(zbuf)), mode="r|");
    tf.extractall(tmp);
    tf.close();
    with open(tmp + "/.ok", "wb") as f {
        f.write(b"");
    }
    os.makedirs(os.path.dirname(rt), exist_ok=True);
    os.rename(tmp, rt);
    if not os.path.isfile(rt + "/.ok") {
        if os.path.isdir(tmp) {
            shutil.rmtree(tmp);
        }
        die("could not publish the extracted runtime");
    }
}

"""Best-effort GC of THIS binary's own older-version trees: a sibling
`rt/<key>` is reclaimed only when its `<pathhash>` matches ours and its name
differs from `keep_key`. Other binaries' trees are never touched."""
def:pub gc_stale(cache_dir: str, keep_key: str) {
    rtdir = cache_dir + "/rt";
    mine = rt_key_pathhash(keep_key);
    for name in listdir(rtdir) {
        if name == keep_key or ".tmp." in name {
            continue;
        }
        if rt_key_pathhash(name) != mine {
            continue;
        }
        full = f"{rtdir}/{name}";
        if not os.path.isdir(full) {
            continue;
        }
        say(f"  removing stale runtime {full}...");
        shutil.rmtree(full);
    }
}
