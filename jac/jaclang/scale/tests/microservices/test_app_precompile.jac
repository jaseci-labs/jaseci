import io;
import os;
import tarfile;
import tempfile;
import from pathlib { Path }
import from unittest.mock { MagicMock, patch }
import jaclang.scale.injector.bundle as bundle_mod;
import from jaclang.scale.injector.bundle { pack_jab, _precompile_app }


glob _seal_call: dict[str, str] = {};


def _capture_seal(cmd: list[str], **kw: object) -> MagicMock {
    # cmd = [pod_jac, "run", <seal script>, <stage_root>, "--seal"]
    _seal_call["script_text"] = Path(cmd[2]).read_text(encoding="utf-8");
    _seal_call["script_arg"] = cmd[2];
    manifest = Path(cmd[3]) / "app" / "_precompiled" / "MANIFEST.json";
    manifest.parent.mkdir(parents=True, exist_ok=True);
    manifest.write_text("{}", encoding="utf-8");
    return MagicMock(returncode=0, stdout="", stderr="");
}


def _mini_app -> str {
    d = tempfile.mkdtemp(prefix="jac-app-");
    Path(d, "jac.toml").write_text("[project]\nname = \"mini\"\n");
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    return d;
}


def _names(raw: bytes) -> list[str] {
    # A .jab is a gzip tar, so r:gz opens it like any bundle.
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        return tar.getnames();
    }
}


test "pack_jab without a pod binary is a hard error (a .jab requires a seal)" {
    caught = False;
    try {
        pack_jab(_mini_app(), "", b"");
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "an unrunnable pod binary fails the seal instead of shipping unsealed" {
    caught = False;
    try {
        pack_jab(_mini_app(), "", b"not-an-elf");
    } except Exception {
        caught = True;
    }
    assert caught;
}


test "a real pod binary seals the app into a .jab (source + _precompiled + manifest)" {
    # The checkout's own binary stands in for the downloaded pod binary; the
    # mechanism (stage -> precompile_bytecode.jac --seal -> pack _precompiled/**)
    # is identical for release binaries.
    jac_bin = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";
    if not jac_bin.is_file() {
        return;
    }
    names = _names(pack_jab(_mini_app(), "", jac_bin.read_bytes()));
    assert "svc.jac" in names;
    # The sealed manifest sits at the tar root, which is what makes this a .jab.
    assert "_precompiled/MANIFEST.json" in names;
    pre = [
        n
        for n in names
        if n.startswith("_precompiled/")
    ];
    assert any([n.endswith("svc.jir") for n in pre]) , pre;
}


test "the seal runs the pod binary's own precompile, not the builder's script" {
    # A builder deploying a pinned version runs a different-version pod binary.
    # Handing it the builder's own precompile_bytecode.jac breaks across a
    # version gap (jaseci-labs/jac#7811); the seal must instead import precompile
    # from the running pod binary so it stays version-consistent.
    _seal_call.clear();
    base = Path(tempfile.mkdtemp(prefix="jac-app-"));
    (base / "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    with patch.object(bundle_mod.subprocess, "run", _capture_seal) {
        _precompile_app(base, b"fake-pod-binary");
    }
    assert (
        "import from jaclang.utils.precompile_bytecode { main }" in _seal_call[
            "script_text"
        ]
    );
    assert not _seal_call["script_arg"].endswith("precompile_bytecode.jac");
}
