"""Parity gate for the sealed native parser and its jac materializer.

Runs the exact pipeline `seal_native_artifacts` ships (AOT compile of the
`compiler/native_materialize.jac` root with the demotion gate, abort-stub
scan, in-house link, dlopen canary), serves the artifact through the real
`sealed.native_artifact_for` seam, binds it with the real
`frontend._native_parse`, and asserts the materialized tree IS the bytecode
parser's tree: error counts, node counts, unparse fingerprints, field-level
values, and instance-dict key sets, plus a compile-and-exec smoke. Green
here is the condition for a payload serving parse trees natively, which is
the only tier a sealed build has.
"""

import json;
import os;
import pytest;
import tempfile;
import jaclang;
import from pathlib { Path }
import from tests.support { JAC_ROOT as REPO_ROOT }
import from jaclang.utils.precompile_bytecode { seal_native_artifacts }
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

"""Serves one locally built parser artifact through the
sealed.native_artifact_for seam; everything else defers to the real
resolver."""
obj _ServeLocalArtifact {
    has lib_path: str,
        layout_dict: dict,
        real: any;

    def __call__(fullname: str) -> any {
        if fullname == "jaclang.compiler.native_materialize" {
            return (self.lib_path, self.layout_dict, );
        }
        return self.real(fullname) if self.real is not None else None;
    }
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
        PKG_PATH,
        out_dir,
        modules=("jac0core/unitree.jac", "compiler/native_materialize.jac", )
    );
    assert artifacts , (
        "seal_native_artifacts refused the materializer root on this platform"
    );
    rec = artifacts["jaclang.compiler.native_materialize"];
    lib_path = str(out_dir / rec["lib"]);
    layout_dict = json.loads((out_dir / rec["layout"]).read_text(encoding="utf-8"));
    # Serve the local artifact through the real seam and bind via the real
    # frontend, so every parity test exercises the exact production path.
    import jaclang.jac0core.sealed as sealed;
    import jaclang.jac0core.parser.frontend as frontend;
    sealed.native_artifact_for = _ServeLocalArtifact(
        lib_path=lib_path, layout_dict=layout_dict, real=sealed.native_artifact_for
    );
    frontend._NATIVE_PARSE_MEMO.clear();
    bound = frontend._native_parse();
    assert bound is not None , "frontend refused the local artifact";
    result = (bound, out_dir, rec);
    _ARTIFACT_MEMO.append(result);
    return result;
}

def _bytecode_parse(src: str, path: str) -> tuple {
    (tokens, _c, _ld, _le) = bytecode_lexer.tokenize_full(src, path);
    pyp = Parser(tokens=tokens, file_path=path, source_code=src);
    return (pyp.parse(), pyp.error_count);
}

def _materialize(src: str, path: str) -> tuple {
    ((fn, mat_entry, pydec, _keep), _out, _rec) = _build_binding();
    import ctypes as _t_ct;
    r = fn(src, path);
    mat_h = mat_entry(r[0].addr);
    assert mat_h != 0 , f"{path}: jac materializer returned NULL";
    module = _t_ct.cast(mat_h, _t_ct.py_object).value;
    pydec(module);
    return (module, r[1], None);
}

def _assert_parity(src: str, path: str) {
    (native_mod, native_errs, _unused) = _materialize(src, path);
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
}

test "the materializer root seals and binds through the frontend" {
    ((fn, mat_entry, _pydec, keep), _out, rec) = _build_binding();
    assert fn is not None;
    assert mat_entry is not None;
    assert len(keep) > 300;
    assert rec.get("lib_sha256");
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

test "the full compiler pipeline runs over materialized native trees" {
    # _build_binding patches sealed.native_artifact_for and primes the
    # frontend memo, so plain frontend.parse and JacProgram.compile run the
    # exact production path over the locally built artifact.
    _build_binding();
    import jaclang.jac0core.parser.frontend as frontend;
    import from jaclang.jac0core.program { JacProgram }
    (module, had_error) = frontend.parse(_canary_src(), "__pipeline_canary__.jac");
    assert not had_error;
    assert isinstance(module, uni.Module);
    with tempfile.TemporaryDirectory(prefix="jac_mat_pipe_") as td {
        target = Path(td) / "hello.jac";
        target.write_text("with entry { print('materialized'); }", encoding="utf-8");
        prog = JacProgram();
        mod = prog.compile(str(target));
        assert mod is not None;
        assert len(prog.errors_had) == 0 , str(prog.errors_had[:3]);
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

"""Field-level tree equality: unparse fingerprints see kid text but not
field VALUES (an erased `body` slot decoding to None, a wrong enum member,
a missing name_spec wiring are all unparse-invisible while being fatal to
codegen). This walker compares every scalar, enum, list length, dict key
set, and class name across both trees."""
def _assert_field_parity(a: any, b: any, path: str = "mod") {
    import enum as _py_enum;
    stack = [(a, b, path, )];
    seen: set = set();
    diffs: list = [];
    while stack {
        (x, y, p) = stack.pop();
        if id(x) in seen {
            continue;
        }
        seen.add(id(x));
        if type(x).__name__ != type(y).__name__ {
            diffs.append(f"{p}: class {type(x).__name__} vs {type(y).__name__}");
            continue;
        }
        dx = x?.__dict__;
        dy = y?.__dict__;
        if dx is None {
            continue;
        }
        kx = set(dx.keys());
        ky = set(dy.keys());
        if kx != ky {
            missing = {
                k
                for k in (ky - kx)
                if not hasattr(type(x), k)
            };
            extra = kx - ky;
            if missing or extra {
                diffs.append(f"{p}: keys +{sorted(extra)} -{sorted(missing)}");
            }
        }
        for k in kx & ky {
            vx = dx[k];
            vy = dy[k];
            if isinstance(vx, (int, str, bool, float))
                or vx is None
                or isinstance(vx, _py_enum.Enum) {
                if vx != vy or type(vx).__name__ != type(vy).__name__ {
                    diffs.append(f"{p}.{k}: {repr(vx)[:60]} vs {repr(vy)[:60]}");
                }
            } elif isinstance(vx, list) {
                if not isinstance(vy, list) or len(vx) != len(vy) {
                    diffs.append(
                        f"{p}.{k} [{type(x).__name__}]: list "
                        f"{len(vx)}x{[type(i).__name__ for i in vx][:6]} vs "
                        f"{len(vy) if isinstance(vy, list) else vy}"
                        f"{[type(i).__name__ for i in vy][:6]
                            if isinstance(vy, list)
                            else ''}"
                    );
                }
            } elif isinstance(vx, dict) {
                if not isinstance(vy, dict)
                    or set(map(str, vx.keys())) != set(map(str, vy.keys())) {
                    diffs.append(f"{p}.{k}: dict keys diverged");
                }
            } elif type(vx).__name__ != type(vy).__name__ {
                diffs.append(
                    f"{p}.{k}: type {type(vx).__name__} vs {type(vy).__name__}"
                );
            }
        }
        if hasattr(x, "kid") {
            for (i, (cx, cy)) in enumerate(zip(x.kid, y.kid)) {
                stack.append((cx, cy, f"{p}.kid[{i}]", ));
            }
        }
    }
    assert not diffs , chr(10).join(diffs[:12]);
}

def _assert_full_parity(src: str, path: str) {
    _assert_parity(src, path);
    (native_mod, _e1, _m) = _materialize(src, path);
    (py_mod, _e2) = _bytecode_parse(src, path);
    import from jaclang.jac0core.native_marshal { materialize_fixups }
    materialize_fixups(native_mod);
    _assert_field_parity(native_mod, py_mod);
    for (nx, ny) in zip(native_mod._in_mod_nodes, py_mod._in_mod_nodes) {
        _assert_field_parity(nx, ny, type(nx).__name__);
    }
}

test "field-level parity: archetypes, enums, walkers, edge ops" {
    nl = chr(10);
    src = nl.join(
        [
            "enum Hue { RED = 1, GREEN = 2 }",
            "node Spot { has label: str = ''; }",
            "edge Road { has miles: int = 0; }",
            "obj P { has x: int = 8, y: (str | None) = None; def m -> int; }",
            "impl P.m -> int { return self.x; }",
            "walker Tour {",
            "    can step with Spot entry;",
            "}",
            "impl Tour.step with Spot entry {",
            "    visit [-->];",
            "}",
            "def pick(h: Hue) -> int {",
            "    return 1 if h == Hue.GREEN else 0;",
            "}",
            "with entry { print(P(x=3).m(), pick(Hue.GREEN)); }",

        ]
    );
    _assert_full_parity(src, "__field_parity__.jac");
}

test "field-level parity holds on a compiler source module" {
    mod_src = PKG_PATH / "jac0core" / "srcloc.jac";
    _assert_full_parity(mod_src.read_text(encoding="utf-8"), str(mod_src));
}

test "materialized trees compile to RUNNABLE bytecode (obj __init__)" {
    # The payload smoke that caught #8109's body-slot gap: an obj compiled
    # through a materialized tree must construct with its has-var __init__.
    _build_binding();
    import from jaclang.jac0core.program { JacProgram }
    import types as _pytypes;
    import sys as _pysys;
    with tempfile.TemporaryDirectory(prefix="jac_mat_exec_") as td {
        target = Path(td) / "objinit.jac";
        nl = chr(10);
        target.write_text(
            "obj P { has x: int = 8; }"
                + nl
                + "def probe -> int { return P(x=3).x + P().x; }"
                + nl,
            encoding="utf-8"
        );
        prog = JacProgram();
        prog.compile(str(target));
        assert len(prog.errors_had) == 0 , str(prog.errors_had[:3]);
        code = prog.get_bytecode(str(target));
        assert code is not None;
        m = _pytypes.ModuleType("objinit_probe");
        m.__file__ = str(target);
        _pysys.modules["objinit_probe"] = m;
        try {
            exec(code, m.__dict__);
            assert m.probe() == 11 , f"probe() gave {m.probe()}";
        } finally {
            _pysys.modules.pop("objinit_probe", None);
        }
    }
}
