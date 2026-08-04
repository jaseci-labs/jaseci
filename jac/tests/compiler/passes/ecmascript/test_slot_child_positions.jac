"""Child-position stability for JSX statement slots (issue #7859).

Every statement in a slot body must contribute exactly one child, so that
child positions are structurally fixed and React can reconcile by position.
"""

import os;
import re;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.program { JacProgram }

glob SLOT_POS = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "ecmascript",
         "fixtures",
         "slot_positions"
     );

"""Compile a fixture to JavaScript and assert no errors were emitted."""
def compile_fixture(filename: str) -> str {
    path = os.path.join(SLOT_POS, filename);
    prog = JacProgram();
    ir = prog.compile(file_path=path, no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {filename}: " + str([str(e) for e in prog.errors_had])
    );
    return es_to_js(EsastGenPass(ir_in=ir, prog=prog).ir_out.gen.es_ast);
}

"""Count `<acc>.push(` occurrences for one accumulator name."""
def push_count(js_code: str, acc: str) -> int {
    return len(re.findall(re.escape(acc) + r"\.push\(", js_code));
}

test "slot fragment children are positional, not a nested array" {
    # `__jacJsx(null, {}, [acc])` hands React a single child whose value is an
    # array, which is the one shape React key-validates. Pass `acc` directly.
    js_code = compile_fixture("single_if.jac");

    assert "__jacJsx(null, {}, [__jac_view_kids])" not in js_code , (
        "the slot accumulator must not be nested inside another array; React "
        "treats that single array-valued child as a keyless list:\n"
        + js_code
    );
    assert "__jacJsx(null, {}, __jac_view_kids)" in js_code , (
        "the accumulator's contents should be the fragment's positional " "children:\n"
        + js_code
    );
}

test "a conditional contributes exactly one child whether or not it is taken" {
    # A statement-level `if` around the push makes the child disappear from the
    # array when false, shifting every later sibling down one index.
    js_code = compile_fixture("single_if.jac");

    assert push_count(js_code, "__jac_view_kids") == 1 , (
        "one slot statement should mean exactly one accumulator entry:\n" + js_code
    );
    guarded = re.search(r"if \([^)]*\) \{\s*__jac_view_kids\.push\(", js_code);
    assert guarded is None , (
        "the push must be unconditional; a guarded push collapses child "
        "positions when the branch is not taken:\n"
        + js_code
    );
}

test "sibling conditionals keep their own child positions" {
    # The reconciliation bug: with `a` false, B slides from index 1 to index 0,
    # React matches keyless children by index and remounts B, losing its state.
    js_code = compile_fixture("two_conditionals.jac");

    assert push_count(js_code, "__jac_view_kids") == 2 , (
        "two slot statements should reserve two fixed child positions:\n" + js_code
    );
    guarded = re.search(r"if \([^)]*\) \{\s*__jac_view_kids\.push\(", js_code);
    assert guarded is None , (
        "neither push may be guarded, or the second child shifts position when "
        "the first condition is false:\n"
        + js_code
    );
}

test "if/else branches share one child position" {
    # Matching hand-written `{cond ? <a/> : <b/>}`, one statement is one
    # position, so React reuses the element across a toggle.
    js_code = compile_fixture("if_else.jac");

    assert push_count(js_code, "__jac_view_kids") == 1 , (
        "both branches of one `if` are one statement and must share a single "
        "child position:\n"
        + js_code
    );
}

test "a loop contributes one child holding its own array" {
    # Loops are the genuinely dynamic construct: their child count is unknown
    # until runtime, so they get a nested array where author keys are required.
    js_code = compile_fixture("loop_slot.jac");

    assert push_count(js_code, "__jac_view_kids") == 1 , (
        "a loop occupies exactly one position in the enclosing slot:\n" + js_code
    );
    inner = re.findall(r"let (__jac_view_kids_\d+) = \[\];", js_code);
    assert len(inner) == 1 , ("the loop needs an accumulator of its own:\n" + js_code);
    assert push_count(js_code, inner[0]) == 1 , (
        "loop iterations should accumulate into the loop's own array:\n" + js_code
    );
    assert f"return {inner[0]};" in js_code , (
        "the loop accumulator stays a raw array so React still requires the "
        "author's per-item keys:\n"
        + js_code
    );
}

test "a loop does not shift the position of its slot siblings" {
    # A loop pushing N items directly into the shared accumulator moves every
    # later sibling by N, and N changes on every data update.
    js_code = compile_fixture("mixed_if_loop.jac");

    assert push_count(js_code, "__jac_view_kids") == 2 , (
        "the conditional and the loop are two statements and so occupy two "
        "fixed positions:\n"
        + js_code
    );
    inner = re.findall(r"let (__jac_view_kids_\d+) = \[\];", js_code);
    assert len(inner) == 1 , (
        "the loop needs its own accumulator rather than sharing the slot's:\n" + js_code
    );
}

test "control flow in a branch keeps the statement lowering" {
    # Wrapping a branch in a conditional expression would trap `skip` inside a
    # closure, making it a no-op and letting the rest of the body still run.
    js_code = compile_fixture("skip_in_slot.jac");

    guarded = re.search(r'if \(\(t === "x"\)\) \{\s*return ', js_code);
    assert guarded is not None , (
        "a branch containing `skip` must stay a real `if` statement so the "
        "early return still leaves the enclosing loop:\n"
        + js_code
    );
    assert "? (() =>" not in js_code , (
        "the branch must not be lifted into a conditional expression:\n" + js_code
    );
}
