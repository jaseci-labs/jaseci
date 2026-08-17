"""Tests for comptime metaprogramming: parse, EXPAND, both expanders."""

import from jaclang.jac0core.parser.frontend { parse, parse_diags }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.tool.unparse_pass { unparse_module }
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
    out = unparse_module(main_mod, requires_format=True);
    assert "comptime for K in NAMES" in out , out[:200];
    assert "${" in out , "splices should survive the formatter tree";
}


test "expansion errors surface as diagnostics with locations" {
    src = "comptime for X in undefined_name {\n    glob Y: int = 1;\n}\n";
    prog = JacProgram();
    (mod, err) = parse(src, "ct_err.jac", prog=prog);
    assert err , "expected expansion failure";
    assert prog.errors_had , "expected an E0109 diagnostic";
    assert "comptime" in prog.errors_had[0].msg;
    codes = {
        str(e.code.code)
        for e in prog.errors_had
        if e.code is not None
    };
    assert "E0109" in codes , (
        "a comptime expansion failure has to carry its own code. It read "
        f"{sorted(codes)}: E0108 here means the duplicate definition is back, "
        "and the escape-sequence diagnostic is shadowing this one again."
    );
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
    import from jaclang.jac0 { ct_reflect_source_deps }
    src = (
        "comptime def _m -> any {\n"
        "    return reflect.module(\"jaclang.jac0core.unitree\");\n"
        "}\n"
        "comptime def _c -> any {\n"
        "    return reflect.module(\"jaclang.jac0core.constant\");\n"
        "}\n"
    );
    deps = ct_reflect_source_deps(src);
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


test "semantic reflection over unitree drives expansion" {
    import from jaclang.jac0core.unitree { Ability }
    src = (
        "comptime def _schema -> list {\n"
        "    mod = reflect.module(\"jaclang.jac0core.unitree\");\n"
        "    out = [];\n"
        "    for nm in sorted(mod.subtypes_of(\"MatchPattern\")) {\n"
        "        out.append(ct.snake(nm));\n"
        "    }\n"
        "    return out;\n"
        "}\n"
        "comptime for K in _schema() {\n"
        "    def probe_${K} -> str {\n"
        "        return \"${K}\";\n"
        "    }\n"
        "}\n"
    );
    prog = JacProgram();
    (mod, err) = parse(src, "ct_reflect_unitree.jac", prog=prog);
    assert not err , [a.msg for a in prog.errors_had[:2]];
    names = [
        nd.name_ref.value
        for nd in mod._in_mod_nodes
        if isinstance(nd, Ability) and nd.name_ref is not None
    ];
    assert "probe_match_or" in names and "probe_match_value" in names , names;
}

glob ENUM_CT_SRC: str = """
glob HUES: list[str] = ["RED", "GREEN"];

enum Hue: int {
    comptime for N in HUES {
        ${ct.name(N)} = ${len(N)},
    }
}

with entry {
    x = Hue.RED;
}
""";


test "comptime for inside an enum body parses clean" {
    (bad, pdiags, ldiags) = parse_diags(ENUM_CT_SRC, "enum_ct.jac");
    assert not bad , f"parse errors: {[d.message for d in pdiags]}";
}


test "enum-body comptime expands to plain members" {
    import from jaclang.jac0core.unitree { Assignment, CtFor, Enum }
    (mod, err) = parse(ENUM_CT_SRC, "enum_ct.jac");
    assert not err , "expansion reported errors";
    leftovers = [
        nd
        for nd in mod._in_mod_nodes
        if isinstance(nd, CtFor)
    ];
    assert not leftovers , "ct nodes survived enum expansion";
    enums = [
        nd
        for nd in mod._in_mod_nodes
        if isinstance(nd, Enum)
    ];
    assert len(enums) == 1;
    member_names = [
        asgn.target[0].value
        for asgn in enums[0].body
        if isinstance(asgn, Assignment)
    ];
    assert member_names == ["RED", "GREEN"] , member_names;
}


test "jac0 bootstrap expands enum-body comptime" {
    import from jaclang.jac0 { ct_expand_source }
    expanded = ct_expand_source(ENUM_CT_SRC, "enum_ct.jac");
    assert "RED = 3" in expanded , expanded;
    assert "GREEN = 5" in expanded , expanded;
    assert "comptime" not in expanded , expanded;
}


test "comptime-only defs are stripped from the expanded module" {
    import from jaclang.jac0core.unitree { Ability }
    src = (
        "comptime def gen_names -> list {\n"
        "    return [\"one\", \"two\"];\n"
        "}\n"
        "comptime for K in gen_names() {\n"
        "    glob ${ct.name(\"N_\" + K.upper())}: str = \"${K}\";\n"
        "}\n"
    );
    (mod, err) = parse(src, "ct_strip.jac");
    assert not err;
    survivors = [
        nd
        for nd in mod._in_mod_nodes
        if isinstance(nd, Ability)
    ];
    assert not survivors , "comptime-only def leaked into the expanded module";
}
