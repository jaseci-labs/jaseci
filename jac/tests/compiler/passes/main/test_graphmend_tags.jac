"""GraphMend pass scheduling tags and the schedule-time gate.

GraphBreakDetectPass provides the graph-breaks tag the three transform passes
require, and the four passes are scheduled only when GraphMend is live for the
module: an off compile never instantiates them, and the `before_pass` prune is
only the second line of defense."""
import os;
import from tests.support { GRAPHMEND_FIXTURES as FIXTURES }
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

glob GM_PASSES = [
         GraphBreakDetectPass,
         TrapLoweringPass,
         PredicateCtrlFlowPass,
         DeferSideEffectPass
     ];

test "codegen schedule orders detect before the transforms and validates" {
    sched = get_py_code_gen(native=False);
    validate_schedule(sched, origin='graphmend tag test');
    assert sched.index(GraphBreakDetectPass) < sched.index(TrapLoweringPass);
    assert sched.index(TrapLoweringPass) < sched.index(PredicateCtrlFlowPass);
    assert sched.index(PredicateCtrlFlowPass) < sched.index(DeferSideEffectPass);
}

test "an off codegen schedule leaves the four passes out entirely" {
    sched = get_py_code_gen(native=False, graphmend=False);
    validate_schedule(sched, origin='graphmend off schedule');
    for p in GM_PASSES {
        assert p not in sched , f"{p.__name__} must not be scheduled when off";
    }
}

"""Compile a fixture under the given graphmend setting and collect every pass
the compiler actually resolved into a schedule."""
def _scheduled_passes(name: str, gm: bool) -> list {
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.program { JacProgram }
    seen: list = [];
    orig = JacCompiler.run_schedule;
    def _spy(
        self: any, mod: any, target_program: any, passes: any, cancel_token: any = None
    ) {
        seen.extend(passes);
        orig(self, mod, target_program, passes, cancel_token);
    }
    JacCompiler.run_schedule = _spy;
    try {
        JacProgram().compile(
            file_path=os.path.join(FIXTURES, name),
            options=CompileOptions(graphmend=gm, type_check=False)
        );
    } finally {
        JacCompiler.run_schedule = orig;
    }
    return seen;
}

test "an off compile never instantiates the graphmend passes" {
    off = _scheduled_passes("val_guard_all.jac", False);
    for p in GM_PASSES {
        assert p not in off , f"{p.__name__} was scheduled on an off compile";
    }
    on = _scheduled_passes("val_guard_all.jac", True);
    for p in GM_PASSES {
        assert p in on , f"{p.__name__} must run when graphmend is live";
    }
}
