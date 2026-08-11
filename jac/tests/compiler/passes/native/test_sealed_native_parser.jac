"""In-CI parity gate for the sealed AOT native parser.

Runs the exact pipeline `seal_native_artifacts` ships (AOT compile with the
demotion gate, abort-stub scan, in-house link, dlopen canary) on this
platform, binds `parse_program` + `arena_strtab_blob` the way
`frontend._native_parse` does, and asserts the native arena materializes to
the same tree as the bytecode arena on a corpus. Green here is the condition
for sealing the parser outside darwin.
"""

import json;
import os;
import pytest;
import tempfile;
import jaclang;
import from pathlib { Path }
import from tests.support { JAC_ROOT as REPO_ROOT }
import from jaclang.utils.precompile_bytecode { seal_native_artifacts }
import from jaclang.jac0core.native_dylib { DylibEngine, layout_from_dict }
import from jaclang.jac0core.native_marshal {
    build_ctypes_classes,
    build_enum_maps,
    wrap_native_function
}
import from jaclang.jac0core.arena { SyntaxArena }
import from jaclang.jac0core.arena_materialize { materialize_module }
import from jaclang.jac0core.unitree { Source }
import from jaclang.jac0core.parser.frontend { _arena_from_native, _canary_src }
import from jaclang.jac0core.parser.parser { Parser }
import jaclang.jac0core.parser.parser as na_parser;
import jaclang.jac0core.parser.lexer as bytecode_lexer;

glob PKG_PATH = Path(jaclang.__file__).parent,
     _ARTIFACT_MEMO: list = [];

def _build_binding -> tuple {
    if "/.cache/jac/rt/"
        in str(Path(jaclang.__file__).resolve()).replace(os.sep, "/") {
        pytest.skip(
            "sealed-payload runtime: the parser seal is gated in source "
            "environments (dev lanes, macOS, build time), not from inside "
            "an installed payload"
        );
    }
    if _ARTIFACT_MEMO {
        return _ARTIFACT_MEMO[0];
    }
    out_dir = Path(tempfile.mkdtemp(prefix="jac_sealed_parser_"));
    artifacts = seal_native_artifacts(
        PKG_PATH, out_dir, modules=("jac0core/parser/parser.jac", )
    );
    assert artifacts , (
        "seal_native_artifacts refused the parser artifact on this platform"
    );
    rec = artifacts["jaclang.jac0core.parser.parser"];
    lib_path = str(out_dir / rec["lib"]);
    layout_dict = json.loads((out_dir / rec["layout"]).read_text(encoding="utf-8"));
    eng = DylibEngine(lib_path);
    eng.initialize();
    layout = layout_from_dict(layout_dict);
    ns = na_parser.__dict__;
    cc = build_ctypes_classes(layout);
    em = build_enum_maps(layout, ns);
    pc: dict = {};
    for sn in layout.structs {
        if ns.get(sn) is not None {
            pc[sn] = ns[sn];
        }
    }
    fn = wrap_native_function(
        eng, layout.functions["parse_program"], cc, em, pc, layout=layout
    );
    blob_fn = wrap_native_function(
        eng, layout.functions["arena_strtab_blob"], cc, em, pc, layout=layout
    );
    assert fn is not None and blob_fn is not None , "parser binding failed";
    result = (fn, blob_fn, eng, out_dir);
    _ARTIFACT_MEMO.append(result);
    return result;
}

def _assert_parity(src: str, path: str, use_blob: bool = False) {
    (fn, real_blob_fn, _eng, _keep) = _build_binding();
    blob_fn = real_blob_fn if use_blob else None;
    r = fn(src, path);
    native_mod = materialize_module(
        _arena_from_native(r[0], blob_fn), Source(src, mod_path=path)
    );
    (tokens, _c, _ld, _le) = bytecode_lexer.tokenize_full(src, path);
    pyp = Parser(tokens=tokens, file_path=path, source_code=src);
    pyp.parse();
    py_mod = materialize_module(pyp.b, Source(src, mod_path=path));
    assert r[1] == pyp.error_count , (
        f"{path}: native reported {r[1]} errors, bytecode {pyp.error_count}"
    );
    assert len(native_mod._in_mod_nodes) == len(py_mod._in_mod_nodes) , (
        f"{path}: node count diverged "
        f"({len(native_mod._in_mod_nodes)} != {len(py_mod._in_mod_nodes)})"
    );
    native_up = native_mod.unparse(requires_format=False);
    py_up = py_mod.unparse(requires_format=False);
    assert native_up == py_up , f"{path}: unparse diverged";
}

test "sealed parser passes the demotion gate and canary on this platform" {
    (fn, blob_fn, _eng, _keep) = _build_binding();
    assert fn is not None and blob_fn is not None;
}

test "sealed parser matches bytecode parser on the canary corpus" {
    _assert_parity(_canary_src(), "__parity_canary__.jac");
}

test "sealed parser matches bytecode parser on fam.jac" {
    fam = os.path.join(REPO_ROOT, "tests", "compiler", "fixtures", "fam.jac");
    _assert_parity(Path(fam).read_text(encoding="utf-8"), fam);
}

test "sealed parser matches bytecode parser on a compiler source module" {
    arena_src = PKG_PATH / "jac0core" / "arena.jac";
    _assert_parity(arena_src.read_text(encoding="utf-8"), str(arena_src));
}

test "ascii strtab still splits through the blob export" {
    _assert_parity(_canary_src(), "__parity_blob__.jac", use_blob=True);
}

test "jsx slot bodies with repeated brace-statement backtracks stay congruent" {
    src = (
        "def:pub C(a: int) -> JsxElement { "
        + "return <ul>{for x in [a] { {1, 2}; {a: 1}; }}</ul>; }"
    );
    _assert_parity(src, "__parity_jsx_backtrack__.jac");
}

test "non-ascii sources reach full parity through the direct decode" {
    nl = chr(10);
    src = nl.join(
        [
            "glob MSG: str = '✅ done';",
            "def greet(who: str) -> str {",
            "    return f'hey {who} ✅';",
            "}",
            "with entry { print(greet('éé')); }",

        ]
    );
    _assert_parity(src, "__parity_nonascii__.jac");
}
