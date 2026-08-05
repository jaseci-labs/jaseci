"""Child-position stability for JSX statement slots (issue #7859).

Each statement in a slot body owns a reserved index, so a child's position
is fixed by where it is written rather than by what ran before it.
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

"""Reserved length of an accumulator, from its `let` initializer."""
def reserved_slots(js_code: str, acc: str) -> int {
    found = re.search(r"let " + re.escape(acc) + r" = \[([^\]]*)\];", js_code);
    assert found , (f"no `let {acc} = [...]` initializer found in:\n" + js_code);
    inner = found.group(1).strip();
    return len(inner.split(",")) if inner else 0;
}

"""Indices assigned on an accumulator, in source order."""
def assigned_indices(js_code: str, acc: str) -> list[int] {
    return [int(m) for m in re.findall(re.escape(acc) + r"\[(\d+)\] = ", js_code)];
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

test "a conditional holds its position whether or not it is taken" {
    # Appending inside the `if` makes the child vanish from the array when the
    # branch is not taken, shifting every later sibling down one index.
    js_code = compile_fixture("single_if.jac");

    assert reserved_slots(js_code, "__jac_view_kids") == 1 , (
        "one slot statement reserves exactly one child position:\n" + js_code
    );
    assert assigned_indices(js_code, "__jac_view_kids") == [0] , (
        "the branch must write its reserved index:\n" + js_code
    );
    assert "__jac_view_kids.push(" not in js_code , (
        "a statically counted slot must not append; appending is what lets a "
        "position collapse:\n"
        + js_code
    );
}

test "sibling conditionals keep their own child positions" {
    # The reconciliation bug: with `a` false, B slid from index 1 to index 0,
    # React matched keyless children by index and remounted B, losing its state.
    js_code = compile_fixture("two_conditionals.jac");

    assert reserved_slots(js_code, "__jac_view_kids") == 2 , (
        "two slot statements reserve two fixed child positions:\n" + js_code
    );
    assert assigned_indices(js_code, "__jac_view_kids") == [0, 1] , (
        "each conditional owns a distinct index, so the second child cannot "
        "shift when the first condition is false:\n"
        + js_code
    );
}

test "if/else branches share one child position" {
    # Matching hand-written `{cond ? <a/> : <b/>}`, one statement is one
    # position, so React reuses the element across a toggle.
    js_code = compile_fixture("if_else.jac");

    assert reserved_slots(js_code, "__jac_view_kids") == 1 , (
        "both branches of one `if` are one statement:\n" + js_code
    );
    assert assigned_indices(js_code, "__jac_view_kids") == [0, 0] , (
        "both arms must write the same index so the element is reused across a "
        "toggle rather than remounted:\n"
        + js_code
    );
}

test "an if reserves a range sized by its widest branch" {
    # Arms of differing length share one range, and the statement after the
    # chain starts past it rather than overlapping.
    js_code = compile_fixture("if_else_uneven.jac");

    assert reserved_slots(js_code, "__jac_view_kids") == 3 , (
        "a two-statement arm plus a following sibling needs three slots:\n" + js_code
    );
    assert assigned_indices(js_code, "__jac_view_kids") == [0, 1, 0, 2] , (
        "the wide arm takes 0 and 1, the narrow arm restarts at 0, and the "
        "sibling follows at 2:\n"
        + js_code
    );
}

test "a loop contributes one child holding its own array" {
    # Loops are the genuinely dynamic construct: their child count is unknown
    # until runtime, so they keep an appending array where author keys apply.
    js_code = compile_fixture("loop_slot.jac");

    assert reserved_slots(js_code, "__jac_view_kids") == 1 , (
        "a loop occupies exactly one position in the enclosing slot:\n" + js_code
    );
    inner = re.findall(r"let (__jac_view_kids_\d+) = \[\];", js_code);
    assert len(inner) == 1 , ("the loop needs an accumulator of its own:\n" + js_code);
    assert f"{inner[0]}.push(" in js_code , (
        "loop iterations append, since their count is only known at run time:\n"
        + js_code
    );
    assert f"return {inner[0]};" in js_code , (
        "the loop accumulator stays a raw array so React still requires the "
        "author's per-item keys:\n"
        + js_code
    );
}

test "a loop does not shift the position of its slot siblings" {
    # A loop appending N items into the shared accumulator moved every later
    # sibling by N, and N changes on every data update.
    js_code = compile_fixture("mixed_if_loop.jac");

    assert reserved_slots(js_code, "__jac_view_kids") == 2 , (
        "the conditional and the loop are two statements and so occupy two "
        "fixed positions:\n"
        + js_code
    );
    assert assigned_indices(js_code, "__jac_view_kids") == [0, 1] , (
        "the loop's whole output lands in one index, leaving its siblings "
        "where they are:\n"
        + js_code
    );
}

test "control flow still reaches the loop it was written in" {
    # Lowering a branch to an expression would put its body in a closure, so a
    # `skip` would return from that closure instead of the loop.
    js_code = compile_fixture("skip_in_slot.jac");

    guarded = re.search(r'if \(\(t === "x"\)\) \{\s*return ', js_code);
    assert guarded is not None , (
        "`skip` must stay an early return inside the loop body:\n" + js_code
    );
    assert "? (() =>" not in js_code , (
        "no branch may be lifted into a conditional expression:\n" + js_code
    );
}

test "an elif chain keeps every arm on the same footing" {
    # `ElseIf` subclasses `IfStmt`. Any lowering that treats an arm as its own
    # chain root can put one arm out of step with the rest of the chain.
    blocked = compile_fixture("elif_chain_blocked.jac");
    clean = compile_fixture("elif_chain_clean.jac");

    for js_code in [blocked, clean] {
        assert re.search(r"\} else if \(", js_code) , (
            "every arm stays a statement, so the chain stays an `else if`:\n" + js_code
        );
        stranded = re.search(r"\} else \(", js_code);
        assert stranded is None , (
            "an `else` clause holding a bare expression discards the children "
            "it builds and renders nothing:\n"
            + js_code
        );
    }
    assert assigned_indices(clean, "__jac_view_kids") == [0, 0, 0] , (
        "all three arms of one chain share a single child position:\n" + clean
    );
}

test "a loop inside a loop stays one flat array" {
    # An inner loop opening its own accumulator groups the children into
    # unkeyed sub-arrays, which React pairs by position, so reordering the
    # outer list rebuilds every item even though each key is correct.
    js_code = compile_fixture("nested_loops.jac");

    inner = re.findall(r"let (__jac_view_kids_\d+) = \[\];", js_code);
    assert len(inner) == 1 , (
        "nested loops share the one accumulator they are already inside:\n" + js_code
    );
    appends = len(re.findall(re.escape(inner[0]) + r"\.push\(", js_code));
    assert appends == 1 , (
        "only the innermost element appends; an inner loop must not push a "
        "sub-array of its own:\n"
        + js_code
    );
    assert reserved_slots(js_code, "__jac_view_kids") == 2 , (
        "the whole nest still occupies one position, leaving the sibling its " "own:\n"
        + js_code
    );
    assert assigned_indices(js_code, "__jac_view_kids") == [0, 1] , (
        "the nest takes index 0 and the sibling index 1, so the sibling cannot "
        "shift when the rows grow:\n"
        + js_code
    );
}
