import io;
import json;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle {
    BUNDLE_MANIFEST_NAME,
    _bundle_manifest_bytes,
    assert_entry_module_ships,
    assert_manifest_name_free,
    bundle_source_files,
    pack_jab,
    resolve_service_members,
    source_filter_for
}


glob _JAC_BIN: Path = Path(__file__).parents[4] / "zig-out" / "bin" / "jac",
     _ROUTED_TOML: str = (
         "[project]\nname = \"mini\"\n\n[scale.microservices.routes]\n"
         "svc = \"/svc\"\n"
     ),
     _PING: str = "def:pub ping -> str { return \"pong\"; }\n";


def _app(toml: str, files: dict[str, str], jacignore: (str | None) = None) -> Path {
    d = Path(tempfile.mkdtemp(prefix="jac-manifest-"));
    (d / "jac.toml").write_text(toml);
    for (rel, text) in files.items() {
        p = d / rel;
        p.parent.mkdir(parents=True, exist_ok=True);
        p.write_text(text);
    }
    if jacignore is not None {
        (d / ".jacignore").write_text(jacignore);
    }
    return d;
}


def _members(base: Path) -> list[str] {
    return sorted([p.relative_to(base).as_posix() for p in bundle_source_files(base)]);
}


def _resolve(base: Path) -> dict[str, str] {
    return resolve_service_members(base, _members(base), source_filter_for(base));
}


test "a declared service resolves to its root module by default" {
    base = _app(_ROUTED_TOML, {"svc.jac": _PING, "main.jac": _PING});
    assert _resolve(base) == {"svc": "svc.jac", "main": "main.jac"};
}


test "a root module wins over nested same-named modules" {
    base = _app(
        _ROUTED_TOML, {"svc.jac": _PING, "lib/svc.jac": _PING, "main.jac": _PING}
    );
    assert _resolve(base) == {"svc": "svc.jac", "main": "main.jac"};
}


test "a single nested module resolves deterministically" {
    base = _app(_ROUTED_TOML, {"src/svc.jac": _PING, "main.jac": _PING});
    assert _resolve(base) == {"svc": "src/svc.jac", "main": "main.jac"};
}


test "an explicit file key is honored and validated" {
    toml = (
        _ROUTED_TOML
        + "\n[scale.microservices.services.svc]\nfile = \"src/entry.jac\"\n"
    );
    base = _app(toml, {"src/entry.jac": _PING, "svc.jac": _PING, "main.jac": _PING});
    assert _resolve(base) == {"svc": "src/entry.jac", "main": "main.jac"};
}


test "the implicit main service follows the configured entry point" {
    # Mirrors ensure_main_service: routed fleets also deploy a 'main' pod for
    # the entry module, resolved by basename like the rest of the toolchain.
    toml = (
        "[project]\nname = \"mini\"\nentry-point = \"src/app.jac\"\n\n"
        "[scale.microservices.routes]\nsvc = \"/svc\"\n"
    );
    base = _app(toml, {"svc.jac": _PING, "src/app.jac": _PING});
    assert _resolve(base) == {"svc": "svc.jac", "main": "src/app.jac"};
}


test "a route covering the root suppresses the implicit main service" {
    toml = (
        "[project]\nname = \"mini\"\n\n[scale.microservices.routes]\n" "svc = \"/\"\n"
    );
    base = _app(toml, {"svc.jac": _PING});
    assert _resolve(base) == {"svc": "svc.jac"};
}


test "a missing implicit main module fails the pack" {
    base = _app(_ROUTED_TOML, {"svc.jac": _PING});
    caught = "";
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "'main'" in caught , caught;
    assert "main.jac" in caught , caught;
}


test "an explicit file that does not exist fails the pack" {
    toml = _ROUTED_TOML + "\n[scale.microservices.services.svc]\nfile = \"gone.jac\"\n";
    base = _app(toml, {"svc.jac": _PING});
    caught = "";
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "gone.jac" in caught , caught;
    assert "no such file" in caught , caught;
}


test "ambiguous service modules fail the pack naming every candidate" {
    base = _app(_ROUTED_TOML, {"a/svc.jac": _PING, "b/svc.jac": _PING});
    caught = "";
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "a/svc.jac" in caught , caught;
    assert "b/svc.jac" in caught , caught;
    assert "[scale.microservices.services.svc] file" in caught , caught;
}


test "parking a declared service module fails the pack, not the fleet" {
    # The WI-2 half of the #8097 entry-module guard: a .jacignore'd service
    # module used to pack fine and crash-loop its pods in-cluster.
    base = _app(_ROUTED_TOML, {"svc.jac": _PING}, jacignore="svc.jac\n");
    caught = "";
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "svc.jac" in caught , caught;
    assert ".jacignore" in caught , caught;
}


test "a missing declared service module fails the pack" {
    base = _app(_ROUTED_TOML, {"other.jac": _PING});
    caught = "";
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "svc.jac" in caught , caught;
    assert "no such module" in caught , caught;
}


test "a project top-level manifest.json is refused as reserved" {
    base = _app(_ROUTED_TOML, {"svc.jac": _PING, "manifest.json": "{}\n"});
    caught = "";
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "reserves" in caught , caught;
    # Parking the file resolves the collision: nothing ships under that name.
    parked = _app(
        _ROUTED_TOML,
        {"svc.jac": _PING, "manifest.json": "{}\n"},
        jacignore="manifest.json\n"
    );
    assert_manifest_name_free(parked, source_filter_for(parked));
}


test "the entry-module guard covers baseline exclusions, not just .jacignore" {
    toml = "[project]\nname = \"mini\"\nentry-point = \"dist/main.jac\"\n";
    base = _app(toml, {"dist/main.jac": _PING});
    caught = "";
    try {
        assert_entry_module_ships(base, source_filter_for(base));
    } except ValueError as e {
        caught = str(e);
    }
    assert "entry module" in caught , caught;
    assert "dist" in caught , caught;
}


test "manifest bytes are deterministic and move with membership" {
    base = _app(_ROUTED_TOML, {"svc.jac": _PING, "main.jac": _PING});
    members: set[str] = set(_members(base));
    services = _resolve(base);
    first = _bundle_manifest_bytes(base, members, services);
    assert first == _bundle_manifest_bytes(base, members, services);
    grown: set[str] = set(members);
    grown.add("extra.jac");
    assert first != _bundle_manifest_bytes(base, grown, services);
    manifest = json.loads(first.decode("utf-8"));
    assert manifest["format"] == 1;
    assert manifest["services"] == {"svc": "svc.jac", "main": "main.jac"};
    assert manifest["members"] == sorted(members);
}


test "a sealed .jab carries the manifest naming exactly what ships" {
    if not _JAC_BIN.is_file() {
        return;
    }
    base = _app(_ROUTED_TOML, {"svc.jac": _PING, "main.jac": _PING});
    raw = pack_jab(str(base), _JAC_BIN.read_bytes());
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
        data = tar.extractfile(BUNDLE_MANIFEST_NAME).read();
    }
    manifest = json.loads(data.decode("utf-8"));
    assert manifest["services"] == {"svc": "svc.jac", "main": "main.jac"};
    shipped_sources = sorted(
        [
            n
            for n in names
            if (
                not n.startswith("_precompiled/")
                and not n.startswith("_vendor/")
                and n != BUNDLE_MANIFEST_NAME
            )
        ]
    );
    assert manifest["members"] == shipped_sources , (
        manifest["members"],
        shipped_sources
    );
}
