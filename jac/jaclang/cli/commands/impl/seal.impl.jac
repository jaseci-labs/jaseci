import os;
import json;
import from pathlib { Path }
import from jaclang.cli.console { console }

impl seal(
    filename: str = "",
    compiler: bool = False,
    output: str = "",
    ir: bool = False,
    debug: bool = False
) -> int {
    if compiler and filename {
        console.error("seal: give a module OR --compiler, not both.");
        return 1;
    }
    if not compiler and not filename {
        console.error("seal: give a .jac module to seal, or --compiler.");
        return 1;
    }
    if debug {
        os.environ["JAC_NA_DEBUG"] = "1";
    }
    out = Path(output or "jac-seal").resolve();
    out.mkdir(parents=True, exist_ok=True);
    ir_out = str(out / "unit.ll") if ir else None;

    import from jaclang.dist.precompile_bytecode { SealProgress }
    say = SealProgress();

    if compiler {
        import jaclang;
        import from jaclang.dist.precompile_bytecode { seal_native_artifacts }
        pkg = Path(str(jaclang.__file__)).parent;
        console.print_header("jac seal -- the served compiler surface");
        say.facts([("source", str(pkg)), ("output", str(out))]);
        record = seal_native_artifacts(pkg, out, ir_out=ir_out, progress=say);
        if record is None {
            console.error("seal: refused; the gate's diagnostics are above.");
            return 1;
        }
        record_path = out / "native-record.json";
        record_path.write_text(
            json.dumps(record, indent=1, sort_keys=True) + "\n", encoding="utf-8"
        );
        artifact = record.get("artifact") or {};
        modules = record.get("modules") or [];
        lib_path = out / str(artifact.get("lib") or "");
        console.success(f"Sealed {len(modules)} served module(s) in {say.elapsed()}");
        say.facts(
            [
                ("artifact", f"{lib_path}"),
                ("layout", f"{out / str(artifact.get('layout') or '')}"),
                ("triple", str(artifact.get("triple") or "")),
                ("record", f"{record_path}")
            ]
                + ([("ir", str(ir_out))] if ir_out else [])
        );
        console.print_list(modules, style="muted", symbol="·");
        return 0;
    }

    src = Path(filename).resolve();
    if not src.is_file() {
        console.error(f"seal: no such file: {src}");
        return 1;
    }
    import from jaclang.dist.precompile_bytecode { seal_one_root }
    console.print_header(f"jac seal -- {src.name}");
    say.facts([("source", str(src)), ("output", str(out))]);
    artifact_entry = seal_one_root(
        src.parent, out, src.name, ir_out=ir_out, progress=say
    );
    if artifact_entry is None {
        console.error(
            "seal: refused; the gate's diagnostics are above. Every demotion "
            "must be fixed (or knowingly waived) before this unit can seal -- "
            "run with --debug for the reason behind each one."
        );
        return 1;
    }
    console.success(f"Sealed {src.name} in {say.elapsed()}");
    say.facts(
        [
            ("artifact", f"{out / str(artifact_entry['lib'])}"),
            ("layout", f"{out / str(artifact_entry['layout'])}"),
            ("triple", str(artifact_entry["triple"]))
        ]
            + ([("ir", str(ir_out))] if ir_out else [])
    );
    return 0;
}
