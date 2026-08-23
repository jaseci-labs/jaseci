# Class-scope free-name load regression battery (LOAD_FROM_DICT_OR_DEREF family).
# Pins the ceval opcode arms against host CPython 3.14 semantics:
#   - LOAD_FROM_DICT_OR_DEREF (90): pop the LOAD_LOCALS mapping, look up the
#     localsplus name, fall back to dereferencing the slot's cell, raise the
#     exact unbound-free-variable NameError when both miss
#     (CPython generated_cases.c.h TARGET(LOAD_FROM_DICT_OR_DEREF)).
#   - LOAD_FROM_DICT_OR_GLOBALS (91): mapping first, then globals/builtins,
#     then NAME_ERROR_MSG (host compiler never emits it today; our native
#     compiler does for PEP 649 __annotate__ bodies, so the arm must stay green).
# Also pins cell boundness living on the shared PyCell (filled flag), which is
# what lets an enclosing function's None binding read through a class body.
import from layer0_replay_harness {
    ReplayResult,
    layer0_replay_source,
}
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, PyError, is_error }
import marshal;
import types as pytypes;


def _run(src: str) -> str {
    # Compile with the host front end, execute on the jacpython VM, return repr
    # of module global `r` or "Type: message" when the VM raised.
    co = unmarshal(marshal.dumps(compile(src, "<classscope>", "exec")) as list[int]);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(co, [], ns);
    if is_error(outcome) {
        e = outcome as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    if "r" in ns {
        return repr(to_host(ns["r"]));
    }
    return "";
}

def _run_globals_opcode(hit_mode: bool) -> str {
    # Hand-assemble LOAD_LOCALS; LOAD_FROM_DICT_OR_GLOBALS 'g'; RETURN_VALUE --
    # the host 3.14 compiler never emits opcode 91, so exercise the arm through
    # a marshaled types.CodeType built here.
    co_host = pytypes.CodeType(
        0,
        0,
        0,
        0,
        3,
        64,
        bytes([22, 0, 91, 0, 35, 0]),
        (),
        ("g",),
        (),
        "<classscope>",
        "<classscope>",
        "<classscope>",
        1,
        b"",
        b"",
        (),
        ()
    );
    co = unmarshal(marshal.dumps(co_host) as list[int]);

    def seed_and_run() -> str {
        ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
        gco = unmarshal(marshal.dumps(compile("g = 42", "<c>", "exec")) as list[int]);
        outcome0 = exec_code(gco, [], ns);
        if is_error(outcome0) {
            return "seed-failed";
        }
        outcome = exec_code(co, [], ns);
        if is_error(outcome) {
            e = outcome as PyError;
            return str(e.exception.type_name) + ": " + str(e.exception.message);
        }
        return repr(to_host(outcome));
    }

    if not hit_mode {
        empty_ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
        miss_out = exec_code(co, [], empty_ns);
        if is_error(miss_out) {
            e2 = miss_out as PyError;
            return str(e2.exception.type_name) + ": " + str(e2.exception.message);
        }
        return "";
    }
    return seed_and_run();
}

glob UNBOUND_FREE_MSG: str = "NameError: cannot access free variable 'z' where it is not associated with a value in enclosing scope";

# ---------------- tests ----------------

test "class scope: direct class-body read of an enclosing function cell" {
    # The shape that raised SystemError: unsupported opcode 90 before the
    # LOAD_FROM_DICT_OR_DEREF arm landed. Host returns 2.
    assert _run(
        "def mk():\n"
        "    z = 1\n"
        "    class C:\n"
        "        w = z + 1\n"
        "    return C.w\n"
        "r = mk()\n"
    ) == "2";
}

test "class scope: same-named class attribute shadows the cell" {
    # Dict-hit path: the class namespace wins over the deref fallback.
    assert _run(
        "def mk():\n"
        "    z = 1\n"
        "    class C:\n"
        "        z = 10\n"
        "        w = z + 1\n"
        "    return C.w\n"
        "r = mk()\n"
    ) == "11";
}

test "class scope: method-shaped free reads stay green" {
    assert _run(
        "def mk():\n"
        "    z = 3\n"
        "    class C:\n"
        "        def m(self):\n"
        "            return z * 2\n"
        "    return C().m()\n"
        "r = mk()\n"
    ) == "6";
}

test "class scope: nested classes read enclosing function cells" {
    # Class scopes are not lexically visible to each other (Inner sees neither
    # Outer's b nor its own nesting), but both see the function frame's cells.
    assert _run(
        "def mk():\n"
        "    a = 5\n"
        "    class Outer:\n"
        "        class Inner:\n"
        "            c = a * 10\n"
        "    return Outer.Inner.c\n"
        "r = mk()\n"
    ) == "50";
}

test "class scope: nested-class name resolution matches host exactly" {
    # b lives in Outer's class namespace only; Inner reading b is a NameError
    # on the host too (class scopes are invisible to nested class scopes).
    assert _run(
        "def mk():\n"
        "    a = 2\n"
        "    class Outer:\n"
        "        b = a + 1\n"
        "        class Inner:\n"
        "            c = b * 10\n"
        "    return Outer\n"
        "try:\n"
        "    r = mk()\n"
        "except Exception as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
        "r = r\n"
    ) == "\"" + "NameError: name 'b' is not defined" + "\"";
}

test "class scope: unbound free cell raises the host-exact message" {
    # Cell exists but was never assigned (conditional bind skipped). Byte-exact
    # UNBOUNDFREE_ERROR_MSG per _PyEval_FormatExcUnbound (Python/ceval.c).
    assert _run(
        "def mk(flag):\n"
        "    if flag:\n"
        "        z = 1\n"
        "    def f():\n"
        "        return z\n"
        "    class C:\n"
        "        w = z\n"
        "    return C.w\n"
        "try:\n"
        "    r = mk(False)\n"
        "except Exception as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
        "r = r\n"
    ) == "\"" + UNBOUND_FREE_MSG + "\"";
}

test "plain deref: unbound free cell raises instead of yielding None" {
    assert _run(
        "def mk(flag):\n"
        "    if flag:\n"
        "        z = 1\n"
        "    def f():\n"
        "        return z\n"
        "    return f()\n"
        "try:\n"
        "    r = mk(False)\n"
        "except Exception as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
        "r = r\n"
    ) == "\"" + UNBOUND_FREE_MSG + "\"";
}

test "cell boundness: a None binding reads as None through the shared cell" {
    # Guards the filled flag on PyCell: emptiness lives on the cell object
    # (CPython's cell NULL), so an enclosing z=None binding must NOT look
    # unbound inside the class body or a captured function.
    assert _run(
        "def mk():\n"
        "    z = None\n"
        "    def f():\n"
        "        return z\n"
        "    class C:\n"
        "        w = z is None\n"
        "    return C.w\n"
        "r = mk()\n"
    ) == "True";
    assert _run(
        "def mk():\n"
        "    def f():\n"
        "        return z\n"
        "    z = None\n"
        "    return f()\n"
        "r = mk()\n"
    ) == "None";
}

test "LOAD_FROM_DICT_OR_GLOBALS: dict hit, globals fallback, exact NameError" {
    assert _run_globals_opcode(True) == "42";
    assert _run_globals_opcode(False) == "NameError: name 'g' is not defined";
}
