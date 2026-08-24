# Pins for two exception-surface fixes, each probed side-by-side against
# CPython 3.14 before pinning:
#
# 1. Unset OSError members read as None (CPython oserror_init fills all four
#    members on every arity and OSError_getset defaults them to None), instead
#    of raising AttributeError.
# 2. _IncompleteInputError sits directly under SyntaxError in the builtin
#    hierarchy (CPython Lib/test/exception_hierarchy.txt).
#
# Guest-side asserts carry the actual value in the AssertionError message.

import from objects { PyObj, PyStr, PyError, PyException, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

def _fresh_ns -> dict[str, PyObj] {
    return {"__name__": PyStr(t="str", val="__main__")};
}

def vm_try(src: str) -> PyObj {
    return exec_code(
        unmarshal(host_compile_marshal(src, "<exc_smallfixes>", "exec")),
        [],
        _fresh_ns()
    );
}

def err_type(outcome: PyObj) -> str {
    assert isinstance(outcome, PyError);
    return ((outcome as PyError).exception as PyException).type_name;
}

def err_msg(outcome: PyObj) -> str {
    assert isinstance(outcome, PyError);
    return ((outcome as PyError).exception as PyException).message;
}

def vm_ok(src: str) {
    outcome = vm_try(src);
    assert not is_error(outcome), err_type(outcome) + ": " + err_msg(outcome);
}

# --- Fix 1: unset OSError members default to None -------------------------

test "oserror: plain-message form leaves all four members None" {
    vm_ok(
        "e = OSError('x')\n"
        "assert e.errno is None, e.errno\n"
        "assert e.strerror is None, e.strerror\n"
        "assert e.filename is None, e.filename\n"
        "assert e.filename2 is None, e.filename2\n"
        "assert e.args == ('x',)\n"
        "assert str(e) == 'x', str(e)\n"
    );
}

test "oserror: zero-arg form leaves all four members None" {
    vm_ok(
        "e = OSError()\n"
        "assert e.errno is None and e.strerror is None\n"
        "assert e.filename is None and e.filename2 is None\n"
        "assert e.args == ()\n"
    );
}

test "oserror: two-arg form defaults filename/filename2 to None" {
    vm_ok(
        "e = OSError(2, 'No such file')\n"
        "assert e.errno == 2\n"
        "assert e.strerror == 'No such file'\n"
        "assert e.filename is None, e.filename\n"
        "assert e.filename2 is None, e.filename2\n"
    );
}

test "oserror: unset-member reads on caught subclass raise nothing" {
    vm_ok(
        "try:\n"
        "    raise FileNotFoundError('missing.py')\n"
        "except OSError as e:\n"
        "    assert e.errno is None, e.errno\n"
        "    assert e.filename is None, e.filename\n"
    );
}

test "oserror: characters_written stays AttributeError until set" {
    outcome = vm_try("OSError('x').characters_written\n");
    assert isinstance(outcome, PyError);
    assert err_type(outcome) == "AttributeError", err_type(outcome);
}

# --- Fix 2: _IncompleteInputError under SyntaxError -----------------------

test "iie: resolves and subclasses SyntaxError" {
    vm_ok(
        "assert isinstance(_IncompleteInputError(1, 2, 3), SyntaxError)\n"
        "assert issubclass(_IncompleteInputError, SyntaxError)\n"
    );
}

test "iie: except-clause matching via SyntaxError" {
    vm_ok(
        "try:\n"
        "    raise _IncompleteInputError('unexpected EOF')\n"
        "except SyntaxError as e:\n"
        "    assert str(e) == 'unexpected EOF', str(e)\n"
    );
}
