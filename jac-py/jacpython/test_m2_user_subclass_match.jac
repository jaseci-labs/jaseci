# Lane-m2 pins: user exception subclass transitive matching in
# ceval.exception_matches.
#
# CPython 3.14.7 oracle provenance: PyErr_GivenExceptionMatches /
# PyType_IsSubtype walk the full MRO of the raised instance's type, so a user
# class inheriting a builtin exception satisfies `except` targets for every
# ancestor, not just exact-name hits. Anchor cases mirror Lib/test's
# exception-hierarchy related tests (test_exceptions.py inheritance/matching
# blocks).
#
# Pins (guest source driven through product_exec + exec_code):
#   1. class MyErr(KeyError); raise MyErr('x'); except LookupError -> caught
#      (host oracle: caught; this was BROKEN before the fix -- the user-MRO
#      walk compared base names exactly, so KeyError != LookupError missed,
#      while builtin KeyError matched via the name-level EXC_PARENT chain).
#   2. Mid(LookupError), Leaf(Mid) vs except LookupError -> caught (control;
#      two-level guest chain, worked before via direct klass.name hit).
#   3. MyErr vs except Exception -> caught (control; broad target).
#   4. Unrelated(ValueError) vs except KeyError -> NOT caught, propagates
#      (negative control; pinned via the propagated "Unrelated: x" outcome).
#      NOTE: the planned nested-try shape (outer handler catches ValueError)
#      exposes a PRE-EXISTING VM bug on tip b8e3c4586 -- an exception raised
#      in an inner try whose handler does not match escapes ALL outer
#      handlers instead of propagating outward (reproduces with builtin
#      raise ValueError alone, unrelated to this fix). Reported separately;
#      pinned flat here so this lane stays green.

import from layer9_product_exec { product_exec }
import from pyc_first { exec_code, to_host }
import from objects { PyObj, PyStr, PyCode, PyError, is_error }


def _run_native(src: str) -> str {
    # Native front end -> PyCode -> VM; str of module global `r`, or
    # "TypeName: message" when the VM raised.
    co = product_exec(src);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    out = exec_code(co as PyCode, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    if "r" in ns {
        return str(to_host(ns["r"]));
    }
    return "";
}


# ---------------- tests ----------------

test "m2: user KeyError subclass matches except LookupError" {
    # Host oracle (CPython 3.14.7): caught.
    assert _run_native(
        "class MyErr(KeyError):\n"
        "    pass\n"
        "r = 'missed'\n"
        "try:\n"
        "    raise MyErr('x')\n"
        "except LookupError:\n"
        "    r = 'caught'\n"
    ) == "caught";
}

test "m2: two-level guest chain matches grandparent target" {
    # Host oracle: caught (control -- direct klass.name hit worked pre-fix).
    assert _run_native(
        "class Mid(LookupError):\n"
        "    pass\n"
        "class Leaf(Mid):\n"
        "    pass\n"
        "r = 'missed'\n"
        "try:\n"
        "    raise Leaf('x')\n"
        "except LookupError:\n"
        "    r = 'caught'\n"
    ) == "caught";
}

test "m2: user subclass matches broad Exception target" {
    # Host oracle: caught (control).
    assert _run_native(
        "class MyErr(KeyError):\n"
        "    pass\n"
        "r = 'missed'\n"
        "try:\n"
        "    raise MyErr('x')\n"
        "except Exception:\n"
        "    r = 'caught'\n"
    ) == "caught";
}

test "m2: unrelated family still escapes" {
    # Host oracle: ValueError-family instance is not caught by except
    # KeyError; it propagates out of the module as an Unrelated error.
    # (Prefix match on the type name: PyException.message is not populated
    # for user exceptions through this path on tip -- pre-existing.)
    got = _run_native(
        "class Unrelated(ValueError):\n"
        "    pass\n"
        "try:\n"
        "    raise Unrelated('x')\n"
        "except KeyError:\n"
        "    r = 'wrongly caught'\n"
    );
    assert got.startswith("Unrelated");
}
