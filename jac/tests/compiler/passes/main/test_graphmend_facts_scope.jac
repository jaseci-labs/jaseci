"""Per-compilation GraphMend facts: compile isolation and node-keyed maps."""
import ast;
import os;
import jaclang.jac0core.unitree as uni;
import from tests.support { GRAPHMEND_FIXTURES as FIXTURES }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { JacCompiler }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.main.graphmend.graph_break_detect_pass {
    GraphBreakDetectPass
}

"""Compile a fixture with graphmend on, recording into the given facts carrier."""
def _compile_with_facts(facts: any, name: str) -> any {
    import from jaclang.jac0core.codeinfo { swap_graphmend_facts }
    prev = swap_graphmend_facts(facts);
    try {
        return JacProgram().compile(
            file_path=os.path.join(FIXTURES, name),
            options=CompileOptions(graphmend=True, type_check=False)
        );
    } finally {
        swap_graphmend_facts(prev);
    }
}

"""Unparse a compiled module's generated Python source."""
def _unparse(mod: any) -> str {
    pa = mod.gen.py_ast;
    return ast.unparse(pa[0] if isinstance(pa, list) else pa);
}

"""Find the single top-level ability named `f` in a compiled module."""
def _entry_ability(mod: any) -> uni.Ability {
    found: (uni.Ability | None) = None;
    for ab in mod.get_all_sub_nodes(uni.Ability) {
        if ab.sym_name == 'f' {
            found = ab;
        }
    }
    assert found is not None;
    return found;
}

test "an interleaved compile does not clobber the in-flight break table" {
    # Splits the codegen schedule after detection and runs a second graphmend
    # compile on the same program, the shape of concurrent language-server
    # compiles; the outer compile's guard must still lower.
    prog = JacProgram();
    orig = JacCompiler.run_schedule;
    state = {"interleaved": False};
    def _spy(
        self: any, mod: any, target_program: any, passes: any, cancel_token: any = None
    ) {
        is_entry = str(mod.loc.mod_path).endswith("val_guard.jac");
        if state["interleaved"]
            or (GraphBreakDetectPass not in passes)
            or not is_entry {
            orig(self, mod, target_program, passes, cancel_token);
            return;
        }
        state["interleaved"] = True;
        i = passes.index(GraphBreakDetectPass);
        orig(self, mod, target_program, passes[:i + 1], cancel_token);
        target_program.get_bytecode(os.path.join(FIXTURES, "side_effect.jac"));
        orig(self, mod, target_program, passes[i + 1:], cancel_token);
    }
    JacCompiler.run_schedule = _spy;
    try {
        mod = prog.compile(
            file_path=os.path.join(FIXTURES, "val_guard.jac"),
            options=CompileOptions(graphmend=True, type_check=False)
        );
    } finally {
        JacCompiler.run_schedule = orig;
    }
    assert state["interleaved"] , "the interleaved compile never ran";
    src = _unparse(mod);
    assert "__jac_tensor_eq_assert__" in src , (
        "the interleaved compile wiped the outer break table"
    );
}

test "an interleaved compile records its facts into its own carrier" {
    import from jaclang.jac0core.codeinfo { GraphMendFacts, swap_graphmend_facts }
    prog = JacProgram();
    orig = JacCompiler.run_schedule;
    state = {"interleaved": False};
    def _spy(
        self: any, mod: any, target_program: any, passes: any, cancel_token: any = None
    ) {
        is_entry = str(mod.loc.mod_path).endswith("val_guard.jac");
        if state["interleaved"]
            or (GraphBreakDetectPass not in passes)
            or not is_entry {
            orig(self, mod, target_program, passes, cancel_token);
            return;
        }
        state["interleaved"] = True;
        i = passes.index(GraphBreakDetectPass);
        orig(self, mod, target_program, passes[:i + 1], cancel_token);
        target_program.get_bytecode(os.path.join(FIXTURES, "side_effect.jac"));
        orig(self, mod, target_program, passes[i + 1:], cancel_token);
    }
    facts = GraphMendFacts();
    prev = swap_graphmend_facts(facts);
    JacCompiler.run_schedule = _spy;
    try {
        prog.compile(
            file_path=os.path.join(FIXTURES, "val_guard.jac"),
            options=CompileOptions(graphmend=True, type_check=False)
        );
    } finally {
        JacCompiler.run_schedule = orig;
        swap_graphmend_facts(prev);
    }
    assert state["interleaved"] , "the interleaved compile never ran";
    kinds = [k.value for k in facts.breaks.values()];
    assert "val_guard" in kinds;
    assert "side_effect" not in kinds , (
        "the interleaved compile leaked its facts into the outer carrier"
    );
}

test "boundary and helper maps key on the node objects themselves" {
    import from jaclang.jac0core.codeinfo { GraphMendFacts }
    facts = GraphMendFacts();
    mod = _compile_with_facts(facts, "val_guard.jac");
    assert facts.boundary , "the compile seeded no boundary entries";
    for (k, v) in facts.boundary.items() {
        assert isinstance(k, uni.Ability) , (
            "boundary entries are keyed by a recyclable address, not by node"
        );
        assert isinstance(v, uni.Ability);
    }
    assert facts.helpers , "the compile recorded no helper needs";
    for m in facts.helpers.keys() {
        assert isinstance(m, uni.Module) , (
            "helper entries are keyed by a recyclable address, not by node"
        );
    }
    seed = _entry_ability(mod);
    assert facts.boundary.get(seed) is seed , (
        "the compiled entry does not resolve to itself by node identity"
    );
}

test "a distinct node with an equal shape does not resolve in the boundary" {
    import from jaclang.jac0core.codeinfo { GraphMendFacts }
    facts_a = GraphMendFacts();
    _compile_with_facts(facts_a, "val_guard.jac");
    facts_b = GraphMendFacts();
    mod_b = _compile_with_facts(facts_b, "val_guard.jac");
    twin = _entry_ability(mod_b);
    assert facts_b.boundary.get(twin) is twin;
    assert facts_a.boundary.get(twin) is None , (
        "a boundary lookup resolved a node the compile never saw"
    );
}

test "a graphmend compile restores the installed facts on exit" {
    import from jaclang.jac0core.codeinfo { installed_graphmend_facts }
    before = installed_graphmend_facts();
    JacProgram().compile(
        file_path=os.path.join(FIXTURES, "val_guard.jac"),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    assert installed_graphmend_facts() is before , (
        "the compile left a facts carrier installed in the context"
    );
}
