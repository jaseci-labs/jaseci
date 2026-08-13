import io;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle {
    _stage_app,
    add_source_members,
    bundle_source_files,
    content_address,
    nested_sanitized_tomls,
    open_det_tar,
    pack_jab,
    sanitized_jac_toml
}


glob _JAC_BIN: Path = Path(__file__).parents[4] / "zig-out" / "bin" / "jac",
     _PARKED: str = "# parked for the deploy\ndocsite/\nevaluation/\n";


def _app(jacignore: (str | None)) -> Path {
    # The issue-8044 shape: two standalone trees a project parks with
    # .jacignore. docsite/ is a nested project that no longer compiles
    # (pre-0.35 `cl {}` markers); evaluation/ is loose source the seal would
    # compile, so shipping it crash-loops the fleet.
    d = Path(tempfile.mkdtemp(prefix="jac-jacignore-"));
    (d / "jac.toml").write_text("[project]\nname = \"mini\"\n");
    (d / "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    (d / "docsite").mkdir();
    (d / "docsite" / "jac.toml").write_text("[project]\nname = \"docs\"\n");
    (d / "docsite" / "main.jac").write_text(
        "cl {\n    def page -> str { return \"x\"; }\n}\n"
    );
    (d / "evaluation").mkdir();
    (d / "evaluation" / "broken.jac").write_text("this is not valid jac\n");
    if jacignore is not None {
        (d / ".jacignore").write_text(jacignore);
    }
    return d;
}


def _rels(base: Path) -> list[str] {
    return sorted([p.relative_to(base).as_posix() for p in bundle_source_files(base)]);
}


def _source_digest(base: Path) -> str {
    # The re-ship decision is the content address of the .jab, and every
    # source member in it comes from add_source_members.
    buf = io.BytesIO();
    (tar, gz) = open_det_tar(buf);
    try {
        with tar {
            add_source_members(tar, base);
        }
    } finally {
        gz.close();
    }
    return content_address(buf.getvalue());
}


test "the seal stage drops the trees .jacignore parks" {
    base = _app(_PARKED);
    stage = _stage_app(base, sanitized_jac_toml(base)) / "app";
    staged = sorted([p.relative_to(stage).as_posix() for p in stage.rglob("*")]);
    assert "svc.jac" in staged , staged;
    assert not (stage / "docsite").exists() , staged;
    assert not (stage / "evaluation").exists() , staged;
}


test "a nested jac.toml inside a parked tree never reaches the bundle" {
    nested = nested_sanitized_tomls(_app(_PARKED));
    assert nested == {} , nested;
    # Without the parking, the same nested project still ships.
    assert list(nested_sanitized_tomls(_app(None)).keys()) == ["docsite/jac.toml"];
}


test "the bundle source set honors .jacignore and ships the file itself" {
    rels = _rels(_app(_PARKED));
    assert "svc.jac" in rels , rels;
    assert ".jacignore" in rels , rels;
    assert not any([r.startswith("docsite/") for r in rels]) , rels;
    assert not any([r.startswith("evaluation/") for r in rels]) , rels;
    unparked = _rels(_app(None));
    assert "docsite/main.jac" in unparked , unparked;
    assert "evaluation/broken.jac" in unparked , unparked;
}


test "editing .jacignore alone moves the content-addressed bundle digest" {
    parked = _source_digest(_app(_PARKED));
    assert parked == _source_digest(_app(_PARKED));
    assert parked != _source_digest(_app(None));
    assert parked != _source_digest(_app("docsite/\n"));
    # Same exclusions, different bytes: .jacignore ships verbatim, so the
    # digest still moves and the deploy re-ships instead of hitting the
    # content-addressed skip.
    assert parked != _source_digest(_app("docsite/\nevaluation/\n"));
}


test "parking the entry module fails the pack, not the fleet" {
    # The one failure mode honoring .jacignore introduces: a project that
    # parks its own entry point would ship a bundle with nothing to boot.
    base = _app("main.jac\n");
    (base / "main.jac").write_text("with entry { print(\"hi\"); }\n");
    caught = "";
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "entry module" in caught , caught;
    assert ".jacignore" in caught , caught;
    # An entry module the bundle ships is not flagged.
    ok = _app(_PARKED);
    (ok / "main.jac").write_text("with entry { print(\"hi\"); }\n");
    assert "main.jac" in _rels(ok);
}


test "a sealed .jab carries no tree that .jacignore parks" {
    # Unfixed, this seal dies on evaluation/broken.jac, which is the crash the
    # in-pod boot compile hits.
    if not _JAC_BIN.is_file() {
        return;
    }
    raw = pack_jab(str(_app(_PARKED)), _JAC_BIN.read_bytes());
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
    }
    assert "svc.jac" in names , names;
    assert ".jacignore" in names , names;
    assert not any([n.startswith("docsite/") for n in names]) , names;
    assert not any([n.startswith("evaluation/") for n in names]) , names;
}
