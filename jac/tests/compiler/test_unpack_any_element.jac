"""Unpacking an `Any` element binds `Any`, not `Unknown`.

Iterating a generic left unparameterized yields `Any`, and unpacking `Any`
should bind `Any` to every target. Jac agreed on the first half but not the
second: `_extract_tuple_element_type` returned None for anything that was
not a `ClassType`, `Any` included, so each destructured target fell through
to `Unknown`, and every *use* of such a target then errored (E1053/E1055).

The fixture uses a bare `set`, not the bare `tuple`/`list` it was written
with: those are E1036 since #8080 and their elements are now `Unknown` by
design. `set` still erases to `Any`, so it reaches the same code path.

Known remaining gap, deliberately not covered here: unpacking a value whose
*declared* annotation is `any` (`pair: any; (nm, ty) = pair;`) still raises
E1020 and binds Unknown. That travels a different path -- the E1020 guard in
`type_checker_pass` already skips `types.AnyType`, so an explicit `any`
annotation evidently is not that type -- and it is its own fix. #8080 makes
that gap easier to hit, since `list[any]` is now the spelling a bare `list`
migrates to.

Refs #8039
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(TESTS_DIR, "compiler", "fixtures");

"""Type-check a fixture and return its errors."""
def check_errors(fixture: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)),
        options=CompileOptions(type_check=True, no_cgen=True)
    );
    return [str(e) for e in (prog.errors_had or [])];
}

test "unpacking elements of an Any-erased container type-checks clean" {
    errs = check_errors("unpack_any_element.jac");
    assert not errs , f"expected no type errors, got {errs}";
}

test "a destructured Any target is usable where its type is constrained" {
    errs = check_errors("unpack_any_element.jac");
    # `takes_type(ty)` constrains a destructured target to `type`, and
    # `nm + ...` constrains the other to `str`. Both were E1053/E1055 before.
    joined = " ".join(errs);
    assert "E1053" not in joined , f"Unknown leaked into a parameter: {errs}";
    assert "E1055" not in joined , f"Unknown leaked into an operator: {errs}";
}
