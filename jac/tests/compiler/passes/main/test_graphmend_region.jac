"""GraphMend compiled-region invariant.

GraphMend analysis and transformation are restricted to the compiled region:
the torch.compile entry points (decorated functions and classes, call-site
wraps, and in scoped mode the forward seeds) plus their transitive callees. A
function never reachable from any entry must stay byte-identical no matter
which transformable patterns it contains, and a torch-importing module with no
torch.compile usage at all must compile byte-identical to a graphmend-off run
under auto and explicit on alike."""
import ast;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from tests.support {
    GRAPHMEND_FIXTURES as FIXTURES,
    graphmend_break_kinds as _break_kinds,
    graphmend_pysrc as _pysrc
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.project.config { JacConfig }
import jaclang.project.config as config_mod;

"""Unparse one named function out of generated Python source."""
def _fn_src(src: str, name: str) -> str {
    tree = ast.parse(src);
    for nd in ast.walk(tree) {
        if isinstance(nd, ast.FunctionDef) and (nd.name == name) {
            return ast.unparse(nd);
        }
    }
    return "";
}

"""Compile a fixture with default (auto) options and return its Python source."""
def _auto_pysrc(name: str) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name), options=CompileOptions(type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

"""Compile a fixture in an existing program and return its Python source."""
def _pysrc_in(prog: JacProgram, name: str) -> str {
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

test "an unreachable sibling keeps every transformable pattern untouched" {
    src_on = _pysrc("region_unreachable_sibling.jac", True);
    src_off = _pysrc("region_unreachable_sibling.jac", False);
    # The entry chain is transformed as usual.
    assert "torch._assert_async(mask.all()" in _fn_src(src_on, "entry");
    assert "__jac_se_emit__" in _fn_src(src_on, "entry");
    # The sibling holds a lowerable guard, a data-dependent branch, and a
    # print, yet none of them may move: it is byte-identical to graphmend-off.
    assert _fn_src(src_on, "orphan") == _fn_src(src_off, "orphan");
    assert _fn_src(src_on, "orphan_leaf") == _fn_src(src_off, "orphan_leaf");
    assert "raise ValueError('orphan mask must be all true')" in src_on;
    assert "print('ORPHAN-EFFECT', y)" in src_on;
    assert "torch.where" not in src_on;
}

test "detection tags nothing outside the compiled region" {
    kinds = sorted(_break_kinds("region_unreachable_sibling.jac"));
    assert kinds == ["side_effect", "val_guard"];
}

test "a torch module without torch compile compiles byte identical" {
    src_on = _pysrc("region_no_compile.jac", True);
    src_off = _pysrc("region_no_compile.jac", False);
    src_auto = _auto_pysrc("region_no_compile.jac");
    assert src_on == src_off;
    assert src_auto == src_off;
    assert _break_kinds("region_no_compile.jac") == [];
}

test "a decorated entry chain is transformed at depth" {
    src = _pysrc("region_chain.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "deep");
    assert "print('DEEP-EFFECT'" not in src;
}

test "a cross module helper is transformed when its entry is in the hub" {
    prog = JacProgram();
    _pysrc_in(prog, "region_xmod_entry.jac");
    src = _pysrc_in(prog, "region_xmod_helper.jac");
    assert "__jac_se_emit__" in _fn_src(src, "far_helper");
    assert "print('FAR-ORPHAN', x)" in _fn_src(src, "far_orphan");
}

test "a wrapped entry function is transformed through the wrap" {
    src = _pysrc("region_wrap_fn.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "wrapped");
}

test "a wrap entry callee is transformed at depth" {
    src = _pysrc("region_wrap_fn.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "wrap_helper");
    assert _break_kinds("region_wrap_fn.jac") == ["side_effect", "side_effect"];
}

test "a wrapped class compiles forward only" {
    # torch.compile(Model()) compiles forward; sibling methods stay eager. The
    # region is forward plus its call edges, never the whole class.
    src_on = _pysrc("region_wrap_cls.jac", True);
    src_off = _pysrc("region_wrap_cls.jac", False);
    assert "__jac_se_emit__" in _fn_src(src_on, "cls_helper");
    assert _fn_src(src_on, "side_step") == _fn_src(src_off, "side_step");
    assert "print('SIDE-STEP', x)" in src_on;
}

test "scoped forward reaches a method through the self call and no further" {
    prog = JacProgram();
    prog.graphmend_scoped_compile = True;
    src = _pysrc_in(prog, "region_self_method.jac");
    assert "__jac_se_emit__" in _fn_src(src, "step");
    assert "print('UNUSED-EFFECT', x)" in _fn_src(src, "unused");
    assert "__jac_se_emit__" not in _fn_src(src, "unused");
}

glob CACHE_ENTRY_SRC = "import torch;\n"
         + "import from usedmod { used_helper }\n\n"
         + "@torch.compile()\n"
         + "def f(x: any, mask: torch.Tensor) -> any {\n"
         + "    x = torch.relu(used_helper(x));\n"
         + "    if not mask.all() {\n"
         + "        raise ValueError(\"mask must be all true\");\n"
         + "    }\n"
         + "    return torch.sin(x) * 2.0;\n"
         + "}\n",
     CACHE_USED_SRC = "import torch;\n\n"
         + "def used_helper(x: any) -> any {\n"
         + "    print(\"USED\", x);\n"
         + "    return torch.relu(x);\n"
         + "}\n",
     CACHE_CONF_SRC = "import torch;\n\n"
         + "def conf_guard(x: any, mask: torch.Tensor) -> any {\n"
         + "    if not mask.all() {\n"
         + "        raise ValueError(\"conf mask must be all true\");\n"
         + "    }\n"
         + "    return torch.sin(x);\n"
         + "}\n\n"
         + "def conf_noisy(x: any) -> any {\n"
         + "    print(\"CONF\", x);\n"
         + "    return x;\n"
         + "}\n";

"""True when the code object (or any nested one) references the symbol."""
def _mentions_symbol(code: any, symbol: str) -> bool {
    if symbol in code.co_names {
        return True;
    }
    for const in code.co_consts {
        if hasattr(const, "co_names") and _mentions_symbol(const, symbol) {
            return True;
        }
    }
    return False;
}

"""Lay out a temp project shaped like the transformers import tree: one entry
module, one helper the entry reaches, one torch-importing module nothing
reaches."""
def _mk_region_project(tmp: str) -> tuple[str, str, str] {
    with open(os.path.join(tmp, "jac.toml"), "w") as fh {
        fh.write(
            "[project]\nname = \"gmregion\"\nversion = \"0.1.0\"\n"
                + "entry-point = \"main.jac\"\n"
        );
    }
    main_path = os.path.join(tmp, "main.jac");
    with open(main_path, "w") as fh {
        fh.write(CACHE_ENTRY_SRC);
    }
    used_path = os.path.join(tmp, "usedmod.jac");
    with open(used_path, "w") as fh {
        fh.write(CACHE_USED_SRC);
    }
    conf_path = os.path.join(tmp, "confmod.jac");
    with open(conf_path, "w") as fh {
        fh.write(CACHE_CONF_SRC);
    }
    return (main_path, used_path, conf_path);
}

test "an entry-less torch module shares its cache artifact with off" {
    # The phi4 shape: every module imports torch, so auto engages GraphMend on
    # all of them, but only the entry chain has a compiled region. The
    # entry-less module compiles byte-identical to off, so after one engaged
    # compile stamps the artifact, auto and off runs share the same cache slot
    # in both directions.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, used_path, conf_path) = _mk_region_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            code_main = prog_a.get_bytecode(main_path);
            code_conf = prog_a.get_bytecode(conf_path);
            assert code_main is not None and code_conf is not None;
            assert prog_a.mod.hub;
            assert _mentions_symbol(code_main, "_assert_async");
            assert not _mentions_symbol(code_conf, "__jac_se_emit__");
            prog_b = JacProgram();
            code_b = prog_b.get_bytecode(conf_path);
            assert code_b is not None;
            assert not prog_b.mod.hub , (
                "a second auto run must hit the stamped shared artifact"
            );
            prog_off = JacProgram();
            prog_off.graphmend_enabled = False;
            code_off = prog_off.get_bytecode(conf_path);
            assert code_off is not None;
            assert not prog_off.mod.hub , (
                "an off run must share the entry-less module's artifact"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "a reached helper module keeps its own gm cache variant" {
    # The helper the entry reaches IS transformed, so its artifact must stay
    # variant-keyed: an off run may not reuse it and recompiles untransformed.
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, used_path, conf_path) = _mk_region_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            code_main = prog_a.get_bytecode(main_path);
            code_used = prog_a.get_bytecode(used_path);
            assert code_main is not None and code_used is not None;
            assert _mentions_symbol(code_used, "__jac_se_emit__") , (
                "the reached helper must be transformed in realistic order"
            );
            prog_off = JacProgram();
            prog_off.graphmend_enabled = False;
            code_off = prog_off.get_bytecode(used_path);
            assert code_off is not None;
            assert prog_off.mod.hub , (
                "an off run must not reuse the transformed helper artifact"
            );
            assert not _mentions_symbol(code_off, "__jac_se_emit__");
        }
    } finally {
        config_mod._config = old_config;
    }
}
