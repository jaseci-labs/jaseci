"""W6009: closures built in a loop body over a loop-body local (#8168).

A per-item handler created inside a `for` slot closes over a local first
assigned in the loop body. Jac scoping is python-like, so that local binds one
symbol in the enclosing component and every handler observes the last
iteration's value -- silently, since labels and other eagerly read positions
are evaluated during the loop and stay correct.

The scoping is intended, so the fix is a diagnostic. These tests pin that it
fires exactly on the shapes that share a binding, stays silent on every shape
that already has a per-iteration one (including the annotation the help text
recommends), and reaches `jac check`, which compiles with codegen disabled.
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "loop_capture"
     );

"""Compile a fixture the way `jac check` does: type check, no codegen."""
def check_fixture(name: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(
        os.path.join(FIXTURES, name),
        options=CompileOptions(no_cgen=True, type_check=True)
    );
    return prog;
}

def warnings_with_code(prog: JacProgram, code: str) -> list {
    return [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == code
    ];
}

test "loop-body local captured by an escaping closure warns W6009" {
    prog = check_fixture("loop_capture_client.jac");
    msgs = [str(w) for w in warnings_with_code(prog, "W6009")];

    assert any("bareId" in m for m in msgs) , (
        "a handler built in a `for` slot over a bare loop-body local shares "
        f"one component binding and must be reported; got: {msgs}"
    );
}

test "hoisted for-to counter captured in the loop body warns W6009" {
    prog = check_fixture("loop_capture_client.jac");
    msgs = [str(w) for w in warnings_with_code(prog, "W6009")];

    assert any("'i'" in m for m in msgs) , (
        "the `for x = a to ... by ...` counter is declared once outside the "
        f"loop, so closures built in the body all read its last value; got: {msgs}"
    );
}

test "W6009 stays silent on every per-iteration binding" {
    prog = check_fixture("loop_capture_client.jac");
    msgs = [str(w) for w in warnings_with_code(prog, "W6009")];

    for (name, why) in [
        ("annId", "a typed declaration in a loop body is a per-iteration local"),
        ("t", "an `in`-loop target binds fresh on every iteration"),
        ("facId", "a value bound through a function parameter is per call"),
        ("mapId", "a lambda-body local is per-invocation since #8130"),

    ] {
        assert not any((("'" + name + "'") in m) for m in msgs) , (
            f"W6009 must not fire on '{name}': {why}. Got: {msgs}"
        );
    }
}

test "W6009 reports each shared binding once" {
    prog = check_fixture("loop_capture_client.jac");
    warns = warnings_with_code(prog, "W6009");

    assert len(warns) == 2 , (
        "one report per name that shares a binding, not one per capturing "
        f"closure or per reference; got: {[str(w) for w in warns]}"
    );
}

test "W6009 does not fire on server code" {
    prog = check_fixture("loop_capture_server.jac");
    warns = warnings_with_code(prog, "W6009");

    assert warns == [] , (
        "Python's late-binding closure is documented behaviour and the "
        "emitted code matches it, so server code must stay silent; got: "
        f"{[str(w) for w in warns]}"
    );
}
