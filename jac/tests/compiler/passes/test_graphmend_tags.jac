"""Pass-schedule tags and the schedule-time gate."""
import os;
import from tests.support { GRAPHMEND_FIXTURES as FIXTURES }
import from jaclang.compiler.driver.schedules { get_py_code_gen, validate_schedule }
import from jaclang.compiler.passes.graphmend.graph_break_detect_pass {
    GraphBreakDetectPass
}
import from jaclang.compiler.passes.graphmend.trap_lowering_pass { TrapLoweringPass }
import from jaclang.compiler.passes.graphmend.predicate_ctrl_flow_pass {
    PredicateCtrlFlowPass
}
import from jaclang.compiler.passes.graphmend.defer_side_effect_pass {
    DeferSideEffectPass
}

test "detect pass provides the graph-breaks tag" {
    assert GraphBreakDetectPass.PROVIDES == ('graph-breaks', );
}

test "transform passes require the graph-breaks tag" {
    for p in [TrapLoweringPass, PredicateCtrlFlowPass, DeferSideEffectPass] {
        assert 'graph-breaks' in p.REQUIRES;
    }
}

test "the transform ordering constraints are declared as tags" {
    assert 'lowered-guards' in TrapLoweringPass.PROVIDES;
    assert 'lowered-guards' in PredicateCtrlFlowPass.REQUIRES;
    assert 'predicated-branches' in PredicateCtrlFlowPass.PROVIDES;
    assert 'predicated-branches' in DeferSideEffectPass.REQUIRES;
}

test "the graphmend schedule order derives from tags, not goal position" {
    ordered: list[type] = [
        GraphBreakDetectPass,
        TrapLoweringPass,
        PredicateCtrlFlowPass,
        DeferSideEffectPass
    ];
    assert validate_schedule(ordered, origin='graphmend tag-derivation test')
        == ordered;
    scrambled: list[type] = [
        DeferSideEffectPass,
        PredicateCtrlFlowPass,
        TrapLoweringPass
    ];
    refused = False;
    try {
        validate_schedule(scrambled, origin='graphmend tag-derivation test');
    } except RuntimeError {
        refused = True;
    }
    assert refused , "an order that ignores the tags must be refused";
}

glob GM_PASSES: list[type] = [
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
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.program { JacProgram }
    seen: list = [];
    orig: any = JacCompiler.run_schedule;
    def _spy(
        self: any, mod: any, target_program: any, passes: any, cancel_token: any = None
    ) {
        seen.extend(passes);
        orig(self, mod, target_program, passes, cancel_token);
    }
    JacCompiler.run_schedule = _spy;
    try {
        JacProgram().compile(
            file_path=os.path.join(FIXTURES, name), options=CompileOptions(graphmend=gm)
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
