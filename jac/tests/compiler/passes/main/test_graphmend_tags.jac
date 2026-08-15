"""GraphMend pass scheduling tags.

GraphBreakDetectPass provides the graph-breaks analysis that the three
transform passes consume, and the codegen schedule that inserts the four
passes stays valid under validate_schedule with the tags declared."""
import from jaclang.jac0core.compiler { get_py_code_gen, validate_schedule }
import from jaclang.compiler.passes.main.graphmend.graph_break_detect_pass {
    GraphBreakDetectPass
}
import from jaclang.compiler.passes.main.graphmend.trap_lowering_pass {
    TrapLoweringPass
}
import from jaclang.compiler.passes.main.graphmend.predicate_ctrl_flow_pass {
    PredicateCtrlFlowPass
}
import from jaclang.compiler.passes.main.graphmend.defer_side_effect_pass {
    DeferSideEffectPass
}

test "detect pass provides the graph-breaks tag" {
    assert GraphBreakDetectPass.PROVIDES == ('graph-breaks', );
}

test "transform passes require the graph-breaks tag" {
    for p in [TrapLoweringPass, PredicateCtrlFlowPass, DeferSideEffectPass] {
        assert p.REQUIRES == ('graph-breaks', );
    }
}

test "codegen schedule orders detect before the transforms and validates" {
    sched = get_py_code_gen(native=False);
    validate_schedule(sched, origin='graphmend tag test');
    assert sched.index(GraphBreakDetectPass) < sched.index(TrapLoweringPass);
    assert sched.index(TrapLoweringPass) < sched.index(PredicateCtrlFlowPass);
    assert sched.index(PredicateCtrlFlowPass) < sched.index(DeferSideEffectPass);
}
