"""GraphMend per-transform configuration tests.

Each transform (trap: guard lowering, where: branch predication, defer:
side-effect deferral) is independently disableable through the single
comma-list disable option, threaded the same way as the other GraphMend
flags: CLI `--graphmend-disable` -> JacProgram.graphmend_disable ->
CompileOptions.graphmend_disable -> per-pass gating. jac.toml reaches the
CLI through the generic Arg.config_key bridge, so precedence is: explicit
CLI flag > jac.toml > built-in default."""
import ast;
import os;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "graphmend"
     );

"""Compile a checked-in fixture under graphmend with a disable list and
return its generated Python source."""
def _pysrc(name: str, disable: list) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(
            graphmend=True, graphmend_disable=disable, type_check=False
        )
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

test "disabling trap leaves guards unlowered while where and defer still fire" {
    src = _pysrc("val_guard_all.jac", ["trap"]);
    assert "raise ValueError" in src;
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "torch.where(" in _pysrc("where_return.jac", ["trap"]);
    assert "__jac_se_emit__(print, " in _pysrc("side_effect.jac", ["trap"]);
}

test "disabling where leaves branches intact while trap and defer still fire" {
    src = _pysrc("where_return.jac", ["where"]);
    assert "torch.where(" not in src;
    assert "if " in src;
    assert "torch._assert_async(" in _pysrc("val_guard_all.jac", ["where"]);
    assert "__jac_se_emit__(print, " in _pysrc("side_effect.jac", ["where"]);
}

test "disabling defer leaves side effects eager while trap and where still fire" {
    src = _pysrc("side_effect.jac", ["defer"]);
    assert "__jac_se_emit__" not in src;
    assert "__jac_se_guard__" not in src;
    assert "print(x)" in src;
    assert "torch._assert_async(" in _pysrc("val_guard_all.jac", ["defer"]);
    assert "torch.where(" in _pysrc("where_return.jac", ["defer"]);
}

test "an empty disable list keeps every transform active" {
    assert "torch._assert_async(" in _pysrc("val_guard_all.jac", []);
    assert "torch.where(" in _pysrc("where_return.jac", []);
    assert "__jac_se_emit__(print, " in _pysrc("side_effect.jac", []);
}

test "the run command bridges the graphmend flags that remain to jac.toml" {
    import from jaclang.cli.manifest { get_command_meta }
    meta = get_command_meta("run");
    assert meta is not None;
    by_name = {a.name: a for a in meta.args};
    assert "graphmend" not in by_name;
    assert by_name["graphmend_scope"].config_key == "run.graphmend_scope";
    gd = by_name.get("graphmend_disable");
    assert gd is not None;
    assert gd.config_key == "run.graphmend_disable";
}

test "the run section of jac.toml carries the graphmend keys" {
    import from jaclang.project.config { JacConfig }
    cfg = JacConfig.from_toml_str(
        "[run]\ngraphmend = true\ngraphmend_scope = \"pkg.a\"\n"
            + "graphmend_disable = \"trap\"\n"
    );
    assert cfg.run.graphmend;
    assert cfg.run.graphmend_scope == "pkg.a";
    assert cfg.run.graphmend_disable == "trap";
}

test "explicit cli flags beat jac.toml which beats built-in defaults" {
    import from jaclang.cli.dispatch { _apply_config_defaults }
    import from jaclang.cli.manifest { get_command_meta }
    import from jaclang.project.config { JacConfig }
    meta = get_command_meta("run");
    cfg = JacConfig.from_toml_str("[run]\ngraphmend_disable = \"trap\"\n");
    at_defaults = {"graphmend_disable": ""};
    _apply_config_defaults(cfg, meta, at_defaults);
    assert at_defaults["graphmend_disable"] == "trap";
    explicit = {"graphmend_disable": "where"};
    _apply_config_defaults(cfg, meta, explicit);
    assert explicit["graphmend_disable"] == "where";
    silent = {"graphmend_disable": ""};
    _apply_config_defaults(
        JacConfig.from_toml_str("[run]\nmain = true\n"), meta, silent
    );
    assert silent["graphmend_disable"] == "";
}

test "the cli disable flag reaches the program state" {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import jaclang.cli.commands.execution as execution;
    import from jaclang.project.config { JacConfig }
    import jaclang.project.config as config_mod;
    prog = Jac.get_program();
    prev_enabled = prog.graphmend_enabled;
    prev_scope = prog.graphmend_scope;
    prev_disable = prog.graphmend_disable;
    old_config = config_mod._config;
    try {
        config_mod._config = JacConfig.from_toml_str("[run]\ngraphmend = \"on\"\n");
        execution._apply_graphmend("", " trap , defer ");
        assert Jac.get_program().graphmend_disable == ["trap", "defer"];
        assert Jac.get_program().graphmend_enabled;
    } finally {
        config_mod._config = old_config;
        cur = Jac.get_program();
        cur.graphmend_enabled = prev_enabled;
        cur.graphmend_scope = prev_scope;
        cur.graphmend_disable = prev_disable;
    }
}
