"""In-CI parity gate for the sealed AOT native parser and its materializer.

Runs the exact pipeline `seal_native_artifacts` ships (AOT compile with the
demotion gate, abort-stub scan, in-house link, dlopen canary, jacmat build,
recipe bake) on this platform, binds `parse_program` and the jacmat
materializer the way `frontend._native_parse` does, and asserts the
materialized native tree is the bytecode parser's tree: error counts, node
counts, unparse fingerprints, and instance-dict key sets. Green here is the
condition for a payload serving parse trees natively, which since the
JAC_NATIVE_PARSE_TREES retirement is the only tier a sealed build has.
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
    load_materializer,
    materialize_recipes,
    wrap_native_function
}
import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
import from jaclang.jac0core.parser.parser { Parser }
import jaclang.jac0core.parser.parser as na_parser;
import jaclang.jac0core.parser.lexer as bytecode_lexer;
import jaclang.jac0core.srcloc as uni_srcloc;
import jaclang.jac0core.unitree as uni;

glob PKG_PATH = Path(jaclang.__file__).parent,
     _ARTIFACT_MEMO: list = [];

glob _CANARY_LINES: tuple = (
         "import os;",
         "glob G: int = 42, H: str = 'control-flow harness (Branch 4)';",
         "enum E { A = 1, B = 2 }",
         "obj Canary {",
         "    has a: int = 0, b: (str | None) = None, c: list[int] = [];",
         "    def m(p: int = 3) -> int;",
         "}",
         "impl Canary.m(p: int = 3) -> int {",
         "    if p > 1 and p < 10 or not p {",
         "        for i in range(p) {",
         "            self.a += i * 2 - 1;",
         "        }",
         "    } elif p == 0 {",
         "        while self.a {",
         "            self.a -= 1;",
         "        }",
         "    } else {",
         "        try {",
         "            self.b = f'v={p} w={self.a}';",
         "        } except Exception as e {",
         "            raise;",
         "        }",
         "    }",
         "    return self.a if self.a else -1;",
         "}",
         "test \"canary t\" { assert Canary(a=5).m(2) >= -1; }",
         "with entry { print({'k': [1, 2.5, True, None]}); }",

     );

def _canary_src -> str {
    nl = chr(10);
    return nl.join(list(_CANARY_LINES));
}

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
    # Classes resolve across the sealed closure's modules, the way
    # `frontend._native_parse` binds them: accessor-bearing helpers
    # (`CodeLocInfo`) live only in their defining modules.
    pc: dict = {};
    for sn in layout.structs {
        for _sc_ns in (ns, uni.__dict__, uni_srcloc.__dict__) {
            if _sc_ns.get(sn) is not None {
                pc[sn] = _sc_ns[sn];
                break;
            }
        }
    }
    fn = wrap_native_function(
        eng, layout.functions["parse_program"], cc, em, pc, layout=layout
    );
    assert fn is not None , "parser binding failed";
    if "materializer" not in rec {
        pytest.skip(
            "seal built no jacmat materializer on this host (needs CPython "
            "headers + a C compiler; set JAC_PY_INCLUDE / JAC_CC). The seal "
            "messages above carry the reason."
        );
    }
    matmod = load_materializer(str(out_dir / rec["materializer"]));
    recipes = materialize_recipes(layout_dict, (ns, uni.__dict__, uni_srcloc.__dict__));
    assert recipes is not None , "layout carries no baked materialize recipes";
    matmod.install(recipes);
    result = (fn, matmod, eng, out_dir, rec);
    _ARTIFACT_MEMO.append(result);
    return result;
}

def _bytecode_parse(src: str, path: str) -> tuple {
    (tokens, _c, _ld, _le) = bytecode_lexer.tokenize_full(src, path);
    pyp = Parser(tokens=tokens, file_path=path, source_code=src);
    return (pyp.parse(), pyp.error_count);
}

def _materialize(src: str, path: str) -> tuple {
    (fn, matmod, _eng, _out, _rec) = _build_binding();
    r = fn(src, path);
    return (matmod.materialize(r[0].addr), r[1], matmod);
}

def _assert_parity(src: str, path: str) {
    (native_mod, native_errs, matmod) = _materialize(src, path);
    (py_mod, py_errs) = _bytecode_parse(src, path);
    assert native_errs == py_errs , (
        f"{path}: native reported {native_errs} errors, bytecode {py_errs}"
    );
    assert isinstance(native_mod, uni.Module) , (
        f"{path}: materializer returned {type(native_mod).__name__}"
    );
    assert len(native_mod._in_mod_nodes) == len(py_mod._in_mod_nodes) , (
        f"{path}: node count diverged "
        f"({len(native_mod._in_mod_nodes)} != {len(py_mod._in_mod_nodes)})"
    );
    native_up = unparse_node(native_mod);
    py_up = unparse_node(py_mod);
    assert native_up == py_up , f"{path}: unparse diverged";
    stats = matmod.stats();
    for key in ("unknown_stamp", "unmapped_cls", "bad_list", "bad_ptr", "bad_dict") {
        assert stats[key] == 0 , f"{path}: materializer anomaly {key}={stats[key]}";
    }
}

test "sealed parser passes the demotion gate and builds its materializer" {
    (fn, matmod, _eng, _out, rec) = _build_binding();
    assert fn is not None;
    assert matmod is not None;
    assert rec.get("materializer_sha256");
}

test "materialized native tree matches bytecode on the canary corpus" {
    _assert_parity(_canary_src(), "__parity_canary__.jac");
}

test "materialized native tree matches bytecode on fam.jac" {
    fam = os.path.join(REPO_ROOT, "tests", "compiler", "fixtures", "fam.jac");
    _assert_parity(Path(fam).read_text(encoding="utf-8"), fam);
}

test "materialized native tree matches bytecode on a compiler source module" {
    mod_src = PKG_PATH / "jac0core" / "srcloc.jac";
    _assert_parity(mod_src.read_text(encoding="utf-8"), str(mod_src));
}

test "elif and else arms build their postinit chain (#8090)" {
    src = (
        "with entry { if 1 > 0 { x = 2; } elif 2 > 1 { x = 3; } " + "else { x = 4; } }"
    );
    _assert_parity(src, "__parity_elseif__.jac");
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

test "union-erased slots materialize their runtime arm (ImplDef.spec)" {
    # `ImplDef.spec` is declared as a list in the native layout, but an impl
    # with a signature stores a `FuncSignature` there. The materializer must
    # follow the rc stamp, never the declared type (the same rule covers
    # `LambdaExpr.body` holding a list).
    src = "obj A { def m(p: int) -> int; }" + " impl A.m(p: int) -> int { return p; }";
    (native_mod, _errs, _mat) = _materialize(src, "__parity_union_arm__.jac");
    (py_mod, _perrs) = _bytecode_parse(src, "__parity_union_arm__.jac");
    n_impls = [
        n
        for n in native_mod._in_mod_nodes
        if type(n).__name__ == "ImplDef"
    ];
    p_impls = [
        n
        for n in py_mod._in_mod_nodes
        if type(n).__name__ == "ImplDef"
    ];
    assert n_impls and p_impls;
    assert type(n_impls[0].spec).__name__ == type(p_impls[0].spec).__name__;
    assert type(n_impls[0].spec).__name__ == "FuncSignature";
}

test "materialized instances carry exactly the bytecode parser's dict keys" {
    # The seal-time field mask exists so passes that probe with hasattr or
    # iterate __dict__ see the same instance shape either way.
    (native_mod, _errs, _mat) = _materialize(_canary_src(), "__parity_keys__.jac");
    (py_mod, _perrs) = _bytecode_parse(_canary_src(), "__parity_keys__.jac");
    for (n_node, p_node) in zip(native_mod._in_mod_nodes, py_mod._in_mod_nodes) {
        assert type(n_node).__name__ == type(p_node).__name__;
        n_keys = set(n_node.__dict__.keys());
        p_keys = set(p_node.__dict__.keys());
        # `static has` counters (Test.TEST_COUNT) have no per-instance native
        # slot; attribute access still resolves through the class, so a
        # class-attribute key may live only there on the materialized side.
        missing = {
            k
            for k in (p_keys - n_keys)
            if not hasattr(type(n_node), k)
        };
        extra = n_keys - p_keys;
        assert not missing and not extra , (
            f"{type(n_node).__name__}: key drift +{sorted(extra)} "
            f"-{sorted(missing)}"
        );
    }
}

"""Serves one locally built parser artifact through the
sealed.native_artifact_for seam; everything else defers to the real
resolver."""
obj _ServeLocalArtifact {
    has lib_path: str,
        layout_dict: dict,
        mat_path: str,
        real: any;

    def __call__(fullname: str) -> any {
        if fullname == "jaclang.jac0core.parser.parser" {
            return (self.lib_path, self.layout_dict, self.mat_path, );
        }
        return self.real(fullname) if self.real is not None else None;
    }
}

test "the full compiler pipeline runs over materialized native trees" {
    # The end-to-end contract of the clean break: with the artifact served
    # through sealed.native_artifact_for, frontend.parse returns materialized
    # native trees and JacProgram.compile works unchanged on them.
    (fn, matmod, _eng, out_dir, rec) = _build_binding();
    import jaclang.jac0core.sealed as sealed;
    import jaclang.jac0core.parser.frontend as frontend;
    import from jaclang.jac0core.program { JacProgram }
    lib_path = str(out_dir / rec["lib"]);
    layout_dict = json.loads((out_dir / rec["layout"]).read_text(encoding="utf-8"));
    mat_path = str(out_dir / rec["materializer"]);
    real_naf = sealed.native_artifact_for;
    saved_memo = list(frontend._NATIVE_PARSE_MEMO);
    sealed.native_artifact_for = _ServeLocalArtifact(
        lib_path=lib_path, layout_dict=layout_dict, mat_path=mat_path, real=real_naf
    );
    frontend._NATIVE_PARSE_MEMO.clear();
    try {
        (module, had_error) = frontend.parse(_canary_src(), "__pipeline_canary__.jac");
        assert not had_error;
        assert isinstance(module, uni.Module);
        with tempfile.TemporaryDirectory(prefix="jac_mat_pipe_") as td {
            target = Path(td) / "hello.jac";
            target.write_text(
                "with entry { print('materialized'); }", encoding="utf-8"
            );
            prog = JacProgram();
            mod = prog.compile(str(target));
            assert mod is not None;
            assert len(prog.errors_had) == 0 , str(prog.errors_had[:3]);
        }
    } finally {
        sealed.native_artifact_for = real_naf;
        frontend._NATIVE_PARSE_MEMO.clear();
        for m in saved_memo {
            frontend._NATIVE_PARSE_MEMO.append(m);
        }
    }
}

test "materializer parity holds across the jac0core source corpus" {
    # Bounded standing corpus sweep: every jac0core source this checkout
    # ships. Fixture-wide equivalence ran once on the integration branch
    # (1410 files, zero divergence); this keeps a representative slice green
    # in CI without that cost.
    corpus = sorted((PKG_PATH / "jac0core").glob("*.jac"));
    assert len(corpus) > 10;
    for src_file in corpus {
        _assert_parity(src_file.read_text(encoding="utf-8"), str(src_file));
    }
}
