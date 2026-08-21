"""On-disk trailer codec for the jac single binary.

This is the ONE authoritative definition of the trailer wire format. It is
plain Jac with no I/O, so the same source binds on the native pathway (the
launcher stub materializing its payload, the desktop host booting the fused
runtime) and on the Python pathway (`jac build --as binary` appending an app
overlay, the payload tool packing a release, the desktop builder grafting the
runtime onto a host).

Binary shape:

    jac = [ launcher stub ][ runtime.tar.zst payload ][ trailer ]
    trailer = magic(8) | payload_len(u64 LE, 8) | sha256_hex(64)   (80 bytes, at EOF)

A `jac build --as binary` app binary appends its sealed `.jab` after that with
its own trailer under a distinct magic, so one 8-byte read tells the two apart:

    app = [ base jac (verbatim) ][ app.jab ][ overlay trailer ]
    overlay trailer = "JABOVL01" | jab_len(u64 LE) | sha256_hex(64)

The runtime cache key folds the payload digest together with a digest of the
binary's own path (`rt_key`), so co-located checkouts with byte-identical
payloads never share one materialized tree (#7012) while `gc_stale` can still
tell this binary's older versions apart from other binaries' trees.
"""

glob MAGIC: bytes = b"JACBIN01";
glob OVERLAY_MAGIC: bytes = b"JABOVL01";
glob MAGIC_LEN: int = 8;
glob HASH_LEN: int = 64;
glob TRAILER_LEN: int = 80;
glob RT_KEY_LEN: int = 33;

"""A decoded trailer: the byte length of the region it terminates and the
lowercase sha256 hex of that region."""
obj Trailer {
    has payload_len: int = 0,
        hash_hex: str = "";

    """The first 16 hex chars of the digest: the payload version."""
    def hash16 -> str {
        return self.hash_hex[0:16];
    }
}

"""Encode an 80-byte trailer. `sha256_hex` must be 64 lowercase hex chars."""
def:pub build_trailer(magic: bytes, payload_len: int, sha256_hex: str) -> bytes {
    return magic + payload_len.to_bytes(8, "little") + sha256_hex.encode();
}

"""Decode an 80-byte trailer, requiring `magic` (MAGIC or OVERLAY_MAGIC).
Returns None for a short blob or a magic mismatch."""
def:pub parse_trailer(raw: bytes, magic: bytes) -> Trailer | None {
    if len(raw) != TRAILER_LEN or raw[0:MAGIC_LEN] != magic {
        return None;
    }
    return Trailer(
        payload_len=int.from_bytes(raw[MAGIC_LEN:MAGIC_LEN + 8], "little"),
        hash_hex=raw[MAGIC_LEN + 8:TRAILER_LEN].decode()
    );
}

"""Where the region a trailer terminates starts, given the offset just past
the trailer (`end`): `end - 80 - payload_len`, or -1 when that underflows
(a corrupt length)."""
def:pub region_start(end: int, payload_len: int) -> int {
    start = end - TRAILER_LEN - payload_len;
    return start if start >= 0 else -1;
}

"""Cache-dir name for a materialized runtime: `<hash16>-<pathhash>` where
`pathhash` is the first 16 hex chars of sha256(exe_path)."""
def:pub rt_key(hash16: str, exe_path: str) -> str {
    import hashlib;
    path_hex = hashlib.sha256(exe_path.encode()).hexdigest();
    return hash16 + "-" + path_hex[0:16];
}

"""The `<pathhash>` half of an `rt_key`, or "" if `name` is not a key."""
def:pub rt_key_pathhash(name: str) -> str {
    if len(name) != RT_KEY_LEN or name[16] != "-" {
        return "";
    }
    return name[17:RT_KEY_LEN];
}
