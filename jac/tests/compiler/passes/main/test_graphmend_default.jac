"""GraphMend default-on (auto) behavior.

GraphMend is on by default in auto mode: with nothing passed and no jac.toml
keys, compiling any module engages GraphMend exactly when the module imports
torch, while torch-free modules stay byte-identical to an explicit
graphmend-off compile. The tri-state default is `auto` at every layer that
decides it (CompileOptions, JacProgram, the jac.toml run section), explicit
`off` still wins, and the CLI carries no `--graphmend` enable flag: jac.toml
`run.graphmend` is the only mode control, while `--graphmend-scope` and
`--graphmend-disable` remain flags and a scope alone still activates
GraphMend. GraphMend-active compiles participate in the bytecode cache with
the GraphMend configuration folded into the cache key, so a same-config
recompile hits and any configuration flip misses instead of serving the
wrong variant."""
import ast;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from tests.support { GRAPHMEND_FIXTURES as FIXTURES }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.jir { get_module_cache_path }
import from jaclang.project.config { JacConfig }
import jaclang.project.config as config_mod;

glob TORCH_MAIN = "import torch;\n\n"
         + "@torch.compile()\n"
         + "def f(x: any, mask: torch.Tensor) -> any {\n"
         + "    x = torch.relu(x);\n"
         + "    if not mask.all() {\n"
         + "        raise ValueError(\"mask must be all true\");\n"
         + "    }\n"
         + "    return torch.sin(x) * 2.0;\n"
         + "}\n",
     PLAIN_HELPER = "def triple(x: int) -> int {\n"
         + "    if x > 0 {\n"
         + "        print(\"positive\");\n"
         + "        return x * 3;\n"
         + "    }\n"
         + "    return x;\n"
         + "}\n";

"""Compile a fixture and return its unparsed Python source and bytecode."""
def _compile(path: str, opts: CompileOptions) -> tuple[str, any] {
    prog = JacProgram();
    mod = prog.compile(file_path=path, options=opts);
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return (ast.unparse(mod_ast), mod.gen.py_bytecode);
}

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

"""Create a temp project with a jac.toml, a torch entry, and a plain helper."""
def _mk_gm_project(tmp: str) -> tuple[str, str] {
    with open(os.path.join(tmp, "jac.toml"), "w") as fh {
        fh.write(
            "[project]\nname = \"gmdefault\"\nversion = \"0.1.0\"\n"
                + "entry-point = \"main.jac\"\n"
        );
    }
    main_path = os.path.join(tmp, "main.jac");
    with open(main_path, "w") as fh {
        fh.write(TORCH_MAIN);
    }
    helper_path = os.path.join(tmp, "helper.jac");
    with open(helper_path, "w") as fh {
        fh.write(PLAIN_HELPER);
    }
    return (main_path, helper_path);
}

test "graphmend defaults to auto at every layer that decides it" {
    assert CompileOptions().graphmend == "auto";
    assert JacProgram().graphmend_enabled == "auto";
    assert JacConfig.from_toml_str("[project]\nname = \"p\"\n").run.graphmend == "auto";
    assert JacConfig.from_toml_str("[run]\nmain = true\n").run.graphmend == "auto";
    assert JacConfig.from_toml_str("[run]\ngraphmend = \"off\"\n").run.graphmend
        == "off";
}

test "default compile options transform a torch module like explicit on" {
    target = os.path.join(FIXTURES, "val_guard_all.jac");
    (src_default, _bc) = _compile(target, CompileOptions(type_check=False));
    (src_on, _bc2) = _compile(target, CompileOptions(graphmend=True, type_check=False));
    assert src_default == src_on;
    assert "torch._assert_async(" in src_default;
    assert "raise ValueError" not in src_default;
}

test "default compile options leave a torch-free module identical to off" {
    target = os.path.join(FIXTURES, "no_torch_plain.jac");
    (src_default, bc_default) = _compile(target, CompileOptions(type_check=False));
    (src_off, bc_off) = _compile(
        target, CompileOptions(graphmend=False, type_check=False)
    );
    assert src_default == src_off;
    assert bc_default == bc_off;
}

test "run graphmend in jac toml is the mode control without a cli flag" {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import jaclang.cli.commands.execution as execution;
    prog = Jac.get_program();
    prev_enabled = prog.graphmend_enabled;
    prev_scope = prog.graphmend_scope;
    prev_disable = prog.graphmend_disable;
    old_config = config_mod._config;
    try {
        config_mod._config = JacConfig.from_toml_str("[run]\nmain = true\n");
        execution._apply_graphmend("", "");
        assert Jac.get_program().graphmend_enabled == "auto";
        config_mod._config = JacConfig.from_toml_str("[run]\ngraphmend = \"off\"\n");
        execution._apply_graphmend("", "");
        assert Jac.get_program().graphmend_enabled is False;
        config_mod._config = JacConfig.from_toml_str("[run]\ngraphmend = \"on\"\n");
        execution._apply_graphmend("", " trap ");
        assert Jac.get_program().graphmend_enabled is True;
        assert Jac.get_program().graphmend_disable == ["trap"];
    } finally {
        config_mod._config = old_config;
        cur = Jac.get_program();
        cur.graphmend_enabled = prev_enabled;
        cur.graphmend_scope = prev_scope;
        cur.graphmend_disable = prev_disable;
    }
}

test "a scope alone still activates graphmend and installs the loader hook" {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import jaclang.cli.commands.execution as execution;
    prog = Jac.get_program();
    prev_enabled = prog.graphmend_enabled;
    prev_scope = prog.graphmend_scope;
    prev_disable = prog.graphmend_disable;
    old_config = config_mod._config;
    try {
        config_mod._config = JacConfig.from_toml_str("[run]\nmain = true\n");
        execution._apply_graphmend("mypkg", "");
        assert Jac.get_program().graphmend_enabled is True;
        assert Jac.get_program().graphmend_scope == ["mypkg"];
        import from importlib.machinery { SourceFileLoader }
        assert getattr(SourceFileLoader, "_jac_graphmend_hooked", False);
    } finally {
        config_mod._config = old_config;
        cur = Jac.get_program();
        cur.graphmend_enabled = prev_enabled;
        cur.graphmend_scope = prev_scope;
        cur.graphmend_disable = prev_disable;
    }
}

test "a graphmend compile is cached and a same-config recompile hits" {
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, helper_path) = _mk_gm_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            code_a = prog_a.get_bytecode(main_path);
            assert code_a is not None;
            assert prog_a.mod.hub , "first compile should not be a cache hit";
            assert _mentions_symbol(code_a, "_assert_async");
            assert get_module_cache_path(main_path).exists() , (
                "a graphmend-active compile must write the bytecode cache"
            );
            prog_b = JacProgram();
            code_b = prog_b.get_bytecode(main_path);
            assert code_b is not None;
            assert not prog_b.mod.hub , (
                "a same-config recompile must hit the cache, not recompile"
            );
            assert _mentions_symbol(code_b, "_assert_async");
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "flipping the graphmend configuration misses the cached variant" {
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, helper_path) = _mk_gm_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            code_a = prog_a.get_bytecode(main_path);
            assert code_a is not None and _mentions_symbol(code_a, "_assert_async");
            prog_off = JacProgram();
            prog_off.graphmend_enabled = False;
            code_off = prog_off.get_bytecode(main_path);
            assert prog_off.mod.hub , (
                "an off run must not reuse the graphmend-on artifact"
            );
            assert not _mentions_symbol(code_off, "_assert_async");
            prog_auto = JacProgram();
            code_auto = prog_auto.get_bytecode(main_path);
            assert prog_auto.mod.hub , (
                "an auto run must not reuse the graphmend-off artifact"
            );
            assert _mentions_symbol(code_auto, "_assert_async");
            prog_dis = JacProgram();
            prog_dis.graphmend_disable = ["trap"];
            code_dis = prog_dis.get_bytecode(main_path);
            assert prog_dis.mod.hub , (
                "a disable-list flip must invalidate the cached variant"
            );
            assert not _mentions_symbol(code_dis, "_assert_async");
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "auto shares the cache artifact with off for a torch-free module" {
    old_config = config_mod._config;
    try {
        with TemporaryDirectory() as tmpdir {
            tmpdir = os.path.realpath(tmpdir);
            (main_path, helper_path) = _mk_gm_project(tmpdir);
            config_mod._config = JacConfig.load(Path(tmpdir) / "jac.toml");
            prog_a = JacProgram();
            code_a = prog_a.get_bytecode(helper_path);
            assert code_a is not None;
            assert prog_a.mod.hub;
            prog_off = JacProgram();
            prog_off.graphmend_enabled = False;
            code_off = prog_off.get_bytecode(helper_path);
            assert code_off is not None;
            assert not prog_off.mod.hub , (
                "auto resolving to off must share the explicit-off artifact"
            );
        }
    } finally {
        config_mod._config = old_config;
    }
}

test "the run manifest drops the graphmend flag but keeps scope and disable" {
    import from jaclang.cli.manifest { get_command_meta }
    meta = get_command_meta("run");
    assert meta is not None;
    by_name = {a.name: a for a in meta.args};
    assert "graphmend" not in by_name;
    assert by_name["graphmend_scope"].config_key == "run.graphmend_scope";
    assert by_name["graphmend_disable"].config_key == "run.graphmend_disable";
}
