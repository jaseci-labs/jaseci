"""Construction-time schedule validation against declared pass dependencies.

Every pass schedule is validated from the passes' declared REQUIRES/PROVIDES at
construction time (#7871 workstream H): a schedule that omits a declared
dependency fails fast with the pass and the missing analysis named, never
mid-compile on user code.

Since #8398 there is one canonical compile pipeline instead of option-shaped
fragments, so validation is the whole story: every REQUIRES is satisfied by an
earlier pass in the single list, and nothing is derived or dropped at runtime.
The analysis stage is unconditional, so a pass whose declared inputs are
missing is a construction error rather than a silently omitted analysis.

Dependency tags are the relation-edge class names the analyses materialize
(CfgSucc/CfgTrue/CfgFalse from CFG build, TypeOf from type checking, SymOf
from symbol-table build), not the old free-form 'cfg'/'inference' labels.
"""

import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.schedules {
    get_analysis_sched,
    get_compile_sched,
    providers_of,
    validate_schedule
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
import from jaclang.compiler.passes.ownership_check_pass { OwnershipCheckPass }
import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }


test "schedule omitting a declared dependency fails fast at construction" {
    err = '';
    try {
        validate_schedule([OwnershipCheckPass], origin='test schedule');
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'CfgSucc'" in err;
    assert 'scheduling error' in err;
}

test "validation names the first missing analysis with CfgSucc preprovided" {
    err = '';
    try {
        validate_schedule(
            [OwnershipCheckPass], preprovided={'CfgSucc'}, origin='test schedule'
        );
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'TypeOf'" in err;
}

test "validation accepts a schedule whose dependencies are preprovided" {
    sched = validate_schedule(
        [OwnershipCheckPass], preprovided={'CfgSucc', 'TypeOf'}, origin='test schedule'
    );
    assert sched == [OwnershipCheckPass];
}

test "validation accepts a schedule whose dependencies run earlier in it" {
    sched = validate_schedule(
        [CFGBuildPass, TypeCheckPass, OwnershipCheckPass], origin='test schedule'
    );
    assert len(sched) == 3;
}

test "the analysis stage always carries type checking and the checkers" {
    sched = get_analysis_sched();
    assert TypeCheckPass in sched;
    assert StaticAnalysisPass in sched;
    assert OwnershipCheckPass in sched;
    assert sched.index(TypeCheckPass) < sched.index(OwnershipCheckPass);
}

test "the canonical compile pipeline validates end to end" {
    sched = get_compile_sched();
    assert CFGBuildPass in sched;
    assert TypeCheckPass in sched;
    assert OwnershipCheckPass in sched;
    assert sched.index(CFGBuildPass) < sched.index(TypeCheckPass);
    validate_schedule(sched, origin='compile schedule');
}

test "every declared requirement is satisfied within the one pipeline" {
    sched = get_compile_sched();
    provided: set[str] = set();
    for p in sched {
        for tag in (getattr(p, 'REQUIRES', ()) or ()) {
            assert tag in provided , f"{p.__name__} requires '{tag}' with no earlier provider";
        }
        for tag in (getattr(p, 'PROVIDES', ()) or ()) {
            provided.add(tag);
        }
    }
}

test "providers_of reports the tags a schedule segment supplies" {
    assert 'CfgSucc' in providers_of([CFGBuildPass]);
    assert 'TypeOf' in providers_of([TypeCheckPass]);
    assert providers_of([]) == set();
}

test "run_schedule rejects an incoherent schedule before running any pass" {
    prog = JacProgram();
    stub = uni.Module.make_stub(inject_name='sched_stub');
    err = '';
    try {
        prog.run_schedule(stub, [OwnershipCheckPass]);
    } except RuntimeError as e {
        err = str(e);
    }
    assert 'OwnershipCheckPass' in err;
    assert "'CfgSucc'" in err;
    assert 'scheduling error' in err;
}
