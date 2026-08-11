"""Tests for comptime metaprogramming: parse, EXPAND, both expanders."""

import from jaclang.jac0core.parser.frontend { parse, parse_diags }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0 { ct_expand_source }

glob CT_SRC: str = """
glob NAMES: list[str] = ["alpha", "beta"];

comptime for K in NAMES {
    glob ${ct.name("CNT_" + K.upper())}: int = ${len(K)};
}

obj Arena {
    comptime for K in NAMES {
        def mk_${K}(
            comptime for p in ["a", "b"] {
                ${ct.name(p)}: int = 0,
            }
            kid: int = 9
        ) -> int {
            comptime if len(K) > 4 {
                return a + b + kid + ${len(K)};
            } else {
                return a - b - kid - ${len(K)};
            }
        }
    }
}

with entry {
    x = comptime { 6 * 7 };
    y = CNT_ALPHA + CNT_BETA;
}
""";


test "comptime constructs parse clean" {
    (bad, pdiags, ldiags) = parse_diags(CT_SRC, "ct_test.jac");
    assert not bad , f"parse errors: {[d.message for d in pdiags]}";
}


test "expansion produces ct-free module with derived declarations" {
    import from jaclang.jac0core.unitree {
        Ability,
        CtBlock,
        CtFor,
        CtIf,
        CtName,
        CtSplice,
        GlobalVars
    }
    (mod, err) = parse(CT_SRC, "ct_test.jac");
    assert not err , "expansion reported errors";
    leftovers = [
        nd
        for nd in mod._in_mod_nodes
        if isinstance(nd, (CtBlock, CtFor, CtIf, CtName, CtSplice))
    ];
    assert not leftovers , f"{len(leftovers)} ct nodes survived expansion";
    names = [
        nd.name_ref.value
        for nd in mod._in_mod_nodes
        if isinstance(nd, Ability) and nd.name_ref is not None
    ];
    assert "mk_alpha" in names and "mk_beta" in names , names;
}


test "formatter path keeps templates unexpanded" {
    import from jaclang.jac0core.unitree { CtFor }
    prog = JacProgram.jac_str_formatter(CT_SRC, "ct_test.jac");
    main_mod = prog.mod.main_mod;
    kept = [
        nd
        for nd in main_mod._in_mod_nodes
        if isinstance(nd, CtFor)
    ];
    assert kept , "formatter tree should retain comptime templates";
    out = main_mod.unparse(requires_format=True);
    assert "comptime for K in NAMES" in out , out[:200];
    assert "${" in out , "splices should survive the formatter tree";
}


test "expansion errors surface as diagnostics with locations" {
    src = "comptime for X in undefined_name {\n    glob Y: int = 1;\n}\n";
    prog = JacProgram();
    (mod, err) = parse(src, "ct_err.jac", prog=prog);
    assert err , "expected expansion failure";
    assert prog.errors_had , "expected an E0108 diagnostic";
    assert "comptime" in prog.errors_had[0].msg;
}


test "comptime if selects by target context" {
    src = (
        "comptime if target.has(\"server\") {\n    glob W: int = 1;\n}\n"
        "comptime if target.has(\"nonexistent\") {\n    glob BAD: int = 2;\n}\n"
    );
    import from jaclang.jac0core.unitree { GlobalVars }
    (mod, err) = parse(src, "ct_tgt.jac");
    assert not err;
    globs = [
        nd
        for nd in mod._in_mod_nodes
        if isinstance(nd, GlobalVars)
    ];
    assert len(globs) == 1 , f"expected only the server branch, got {len(globs)}";
}


test "reflect deps are visible to cache invalidation" {
    import os;
    import jaclang;
    import from jaclang.jac0 { ct_reflect_source_deps }
    arena_path = os.path.join(
        os.path.dirname(jaclang.__file__), "jac0core", "arena.jac"
    );
    deps = ct_reflect_source_deps(open(arena_path, encoding="utf-8").read());
    names = {os.path.basename(d) for d in deps};
    assert "unitree.jac" in names and "constant.jac" in names , names;
    assert ct_reflect_source_deps("with entry { print(1); }") == [];
}


test "jac0 bootstrap expander agrees on the same dialect" {
    out = ct_expand_source(CT_SRC, "ct_test.jac");
    assert "comptime" not in out , "bootstrap expansion left comptime text";
    assert "${" not in out;
    assert "glob CNT_ALPHA: int = 5;" in out.replace("  ", " ") , out[:400];
    assert "def mk_alpha(" in out;
    assert "def mk_beta(" in out;
}


test "arena derivation self-hosts through the full compiler" {
    import os;
    import jaclang;
    import from jaclang.jac0core.arena { KIND_CT_FOR, SPECS, SyntaxArena }
    import from jaclang.jac0core.arena_materialize { decode_spec }
    arena_path = os.path.join(
        os.path.dirname(jaclang.__file__), "jac0core", "arena.jac"
    );
    src = open(arena_path, encoding="utf-8").read();
    prog = JacProgram();
    (mod, err) = parse(src, arena_path, prog=prog);
    assert not err , [a.msg for a in prog.errors_had[:2]];
    a = SyntaxArena();
    got = a.mk_ct_for(target=1, iter=2, body=[3], kid=[1, 2, 3]);
    assert a.kind_of(got) == KIND_CT_FOR;
    assert decode_spec(SPECS[KIND_CT_FOR])[0] == "CtFor";
}
