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

    if compiler {
        import jaclang;
        import from jaclang.dist.precompile_bytecode { seal_native_artifacts }
        pkg = Path(str(jaclang.__file__)).parent;
        console.print(f"Sealing the served compiler surface from {pkg}");
        record = seal_native_artifacts(pkg, out, ir_out=ir_out);
        if record is None {
            console.error("seal: refused; the gate's diagnostics are above.");
            return 1;
        }
        record_path = out / "native-record.json";
        record_path.write_text(
            json.dumps(record, indent=1, sort_keys=True) + "\n", encoding="utf-8"
        );
        artifact = record.get("artifact") or {};
        console.print(
            f"Sealed {len(record.get('modules') or [])} served module(s) -> "
            f"{out / str(artifact.get('lib') or '')}"
        );
        console.print(f"Record: {record_path}");
        if ir_out {
            console.print(f"IR: {ir_out}");
        }
        return 0;
    }

    src = Path(filename).resolve();
    if not src.is_file() {
        console.error(f"seal: no such file: {src}");
        return 1;
    }
    import from jaclang.dist.precompile_bytecode { seal_one_root }
    artifact_entry = seal_one_root(src.parent, out, src.name, ir_out=ir_out);
    if artifact_entry is None {
        console.error(
            "seal: refused; the gate's diagnostics are above. Every demotion "
            "must be fixed (or knowingly waived) before this unit can seal -- "
            "run with --debug for the reason behind each one."
        );
        return 1;
    }
    console.print(f"Sealed -> {out / str(artifact_entry['lib'])}");
    console.print(f"Layout -> {out / str(artifact_entry['layout'])}");
    if ir_out {
        console.print(f"IR: {ir_out}");
    }
    return 0;
}
