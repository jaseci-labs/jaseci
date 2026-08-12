"""Unpacking an `Any` element binds `Any`, not `Unknown`.

PEP 484 treats a bare `tuple` as `tuple[Any, ...]` and a bare `list` as
`list[Any]`, so iterating one yields `Any` -- and unpacking `Any` binds
`Any` to every target. Jac agreed on the first half but not the second:
`_extract_tuple_element_type` returned None for anything that was not a
`ClassType`, `Any` included, so each destructured target fell through to
`Unknown`. Because `Unknown` is not assignable, every *use* of such a
target then errored.

    glob BARE: tuple = (("a", int),);
    for (nm, ty) in BARE {          # nm and ty were both Unknown
        out += nm + takes_type(ty); # E1055 on nm, E1053 on ty
    }

The tell was that the non-destructured form had always been fine --
`for ty in BARE { takes_type(ty) }` binds `Any` and checks clean. Only the
unpacking step dropped it, which is why this surfaced the moment a constant
table in `placement.jac` grew from a tuple of classes to a tuple of
(name, class) pairs.

Known remaining gap, deliberately not covered here: unpacking a value whose
*declared* annotation is `any` (`pair: any; (nm, ty) = pair;`) still raises
E1020 and binds Unknown. That travels a different path -- the E1020 guard in
`type_checker_pass` already skips `types.AnyType`, so an explicit `any`
annotation evidently is not that type -- and it is its own fix.

Refs #8039
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(TESTS_DIR, "compiler", "fixtures");

"""Type-check a fixture and return its errors."""
def check_errors(fixture: str) -> list {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)),
        options=CompileOptions(type_check=True, no_cgen=True)
    );
    return [str(e) for e in (prog.errors_had or [])];
}

test "unpacking elements of a bare tuple or list type-checks clean" {
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
