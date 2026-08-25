"""The seal's single-record reuse decision, proven on its pure logic.

The index lets an unchanged closure reuse the fused artifact outright, so
its gate has to be exact: any drifted input -- compiler digest, waiver
table, a source's content key, the recorded artifact bytes -- refuses
reuse with a named reason, and only a record proven whole is served. These
tests drive `seal_reuse_decision` and its key helpers directly with
fabricated records and real temp files; no native compile is involved, so
the whole file runs in seconds.
"""

import hashlib;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.dist.precompile_bytecode {
    NATIVE_SEAL_FUSED_ROOT,
    read_seal_index,
    seal_artifact_key,
    seal_reuse_decision,
    seal_source_keys,
    seal_waiver_digest,
    write_seal_index
}

glob TRIPLE: str = "x86_64-test-triple";

"""A fabricated-but-internally-consistent record over real files."""
def _fixture -> tuple {
    base = Path(tempfile.mkdtemp(prefix="jac_seal_reuse_"));
    pkg = base / "pkg";
    (pkg / "native" / TRIPLE).mkdir(parents=True);
    src = pkg / "mod.jac";
    src.write_text("with entry { print(1); }\n", encoding="utf-8");
    pdir = pkg;
    lib = pkg / "native" / TRIPLE / "libjac_compiler.so";
    lib.write_bytes(b"\x7fELF-not-really");
    layout = pkg / "native" / TRIPLE / "compiler.layout.json";
    layout.write_text("{}", encoding="utf-8");
    keys = seal_source_keys(pkg, ["mod.jac"]);
    assert keys is not None;
    record = {
        "lib": "native/" + TRIPLE + "/libjac_compiler.so",
        "layout": "native/" + TRIPLE + "/compiler.layout.json",
        "triple": TRIPLE,
        "lib_sha256": hashlib.sha256(lib.read_bytes()).hexdigest(),
        "layout_sha256": hashlib.sha256(layout.read_bytes()).hexdigest(),
        "key": seal_artifact_key(NATIVE_SEAL_FUSED_ROOT, TRIPLE, keys),
        "compiler": "test-compiler-digest",
        "waivers": seal_waiver_digest(NATIVE_SEAL_FUSED_ROOT),
        "sources": keys,
        "modules": ["pkg.mod"]
    };
    return (base, pkg, pdir, src, lib, record, );
}

def _decide(pkg: Path, pdir: Path, record: dict) -> str {
    return seal_reuse_decision(
        record,
        pdir,
        NATIVE_SEAL_FUSED_ROOT,
        TRIPLE,
        "test-compiler-digest",
        seal_waiver_digest(NATIVE_SEAL_FUSED_ROOT),
        seal_source_keys(pkg, sorted(record.get("sources") or {}))
    );
}

test "an unchanged record over intact files reuses" {
    (base, pkg, pdir, _src, _lib, record) = _fixture();
    try {
        assert _decide(pkg, pdir, record) == "" , _decide(pkg, pdir, record);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "every drifted input refuses reuse with a named reason" {
    (base, pkg, pdir, src, lib, record) = _fixture();
    try {
        assert "compiler"
            in seal_reuse_decision(
                record,
                pdir,
                NATIVE_SEAL_FUSED_ROOT,
                TRIPLE,
                "OTHER-compiler",
                seal_waiver_digest(NATIVE_SEAL_FUSED_ROOT),
                seal_source_keys(pkg, sorted(record["sources"]))
            );
        assert "waiver"
            in seal_reuse_decision(
                record,
                pdir,
                NATIVE_SEAL_FUSED_ROOT,
                TRIPLE,
                "test-compiler-digest",
                "not-the-recorded-waiver-digest",
                seal_source_keys(pkg, sorted(record["sources"]))
            );
        assert "built for"
            in seal_reuse_decision(
                record,
                pdir,
                NATIVE_SEAL_FUSED_ROOT,
                "other-triple",
                "test-compiler-digest",
                seal_waiver_digest(NATIVE_SEAL_FUSED_ROOT),
                seal_source_keys(pkg, sorted(record["sources"]))
            );
        src.write_text("with entry { print(2); }\n", encoding="utf-8");
        assert "changed" in _decide(pkg, pdir, record);
        src.write_text("with entry { print(1); }\n", encoding="utf-8");
        lib.write_bytes(b"corrupted");
        assert "sha256" in _decide(pkg, pdir, record);
        lib.unlink();
        assert "missing" in _decide(pkg, pdir, record);
        src.unlink();
        assert "gone or unreadable" in _decide(pkg, pdir, record);
        assert "no artifact"
            in seal_reuse_decision(
                None,
                pdir,
                NATIVE_SEAL_FUSED_ROOT,
                TRIPLE,
                "test-compiler-digest",
                seal_waiver_digest(NATIVE_SEAL_FUSED_ROOT),
                None
            );
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "the index round-trips one record and rejects foreign shapes" {
    (base, pkg, pdir, _src, _lib, record) = _fixture();
    try {
        write_seal_index(pdir, TRIPLE, {NATIVE_SEAL_FUSED_ROOT: record});
        back = read_seal_index(pdir, TRIPLE);
        assert back.get(NATIVE_SEAL_FUSED_ROOT) == record;
        assert read_seal_index(pdir, "some-other-triple") == {};
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
