"""The `jac seal` command: the seal's gate behind one front door.

Drives the command handler directly over the same tiny fixtures the seal
machinery suite uses: a clean module seals into the given output directory
(artifact, layout, and with --ir the unit's LLVM text), and a module with
an un-lowerable method is refused with exit 1 and nothing left on disk.
The heavy compiler form (`--compiler`) shares its whole body with the
build's own seal and is exercised there, not here.
"""

import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.cli.commands.seal { seal }

glob FIXTURES = Path(TESTS_DIR) / "compiler" / "backends" / "native" / "fixtures";

test "a clean module seals through the command, with artifacts where asked" {
    out = tempfile.mkdtemp(prefix="jac_seal_cmd_");
    try {
        rc = seal(filename=str(FIXTURES / "seal_clean.jac"), output=out, ir=True);
        assert rc == 0 , "the command refused a module the seal accepts";
        libs = list(Path(out).rglob("libjac_seal_clean.*"));
        assert libs , f"no sealed library under {out}";
        layouts = list(Path(out).rglob("seal_clean.layout.json"));
        assert layouts , f"no layout under {out}";
        assert (Path(out) / "unit.ll").is_file() , "--ir wrote no LLVM text";
        assert "define" in (Path(out) / "unit.ll").read_text(encoding="utf-8") , (
            "the IR dump does not look like LLVM text"
        );
    } finally {
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "an un-lowerable module is refused with exit 1 and a clean tree" {
    out = tempfile.mkdtemp(prefix="jac_seal_cmd_bad_");
    try {
        rc = seal(filename=str(FIXTURES / "seal_demoted_method.jac"), output=out);
        assert rc == 1 , "the command accepted a module whose method demotes";
        assert not list(Path(out).rglob("*.so")) , (
            "a refused seal left a shared library in the output tree"
        );
    } finally {
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "argument validation refuses ambiguous and empty invocations" {
    assert seal() == 1;
    assert seal(filename="x.jac", compiler=True) == 1;
    assert seal(filename="/nonexistent/nope.jac") == 1;
}
