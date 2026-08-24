# CLEANUP_THROW traceback-cadence pins (lane m9-cleanupthrow).
#
# Companion to test_tb_cadence.jac: an exception thrown into a yield-from
# that escapes via OP_CLEANUP_THROW is a re-dispatch, not a new error event.
# CPython routes it through exception_unwind without tb growth, so chains
# must carry exactly one entry per frame at the original raise site -- no
# extra entry attributed to the CLEANUP_THROW instruction.

import from objects { PyStr, PyError }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }


def tb_entries(tb: any) -> list[str] {
    out: list[str] = [];
    frame = tb;
    while frame is not None {
        code = (frame as PyTraceback).code;
        out.append(
            (code as PyCode).name + ":" + str((frame as PyTraceback).tb_lineno)
        );
        frame = (frame as PyTraceback).tb_next;
    }
    return out;
}


def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<tb_m9>", "exec")), [], ns
    );
    assert outcome.t != "error";
    return ns;
}


test "cleanup-throw escape into module handler: one entry per frame" {
    ns = vm_exec(
        "def inner():\n"
        "    try:\n"
        "        yield 1\n"
        "    finally:\n"
        "        pass\n"
        "\n"
        "def outer():\n"
        "    try:\n"
        "        yield from inner()\n"
        "    finally:\n"
        "        pass\n"
        "\n"
        "g = outer()\n"
        "next(g)\n"
        "try:\n"
        "    g.throw(ValueError('m9'))\n"
        "except ValueError as e:\n"
        "    parts = []\n"
        "    t = e.__traceback__\n"
        "    while t:\n"
        "        parts.append(t.tb_frame.f_code.co_name + ':' + str(t.tb_lineno))\n"
        "        t = t.tb_next\n"
        "        r = '|'.join(parts)\n"
    );
    got = str((ns["r"] as PyStr).val);
    assert got == "<module>:16|outer:9|inner:3", f"cadence mismatch: {got}";
}

test "cleanup-throw escape out of module: no extra CLEANUP_THROW entry" {
    got = "";
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(
            host_compile_marshal(
                "def inner():\n"
                "    try:\n"
                "        yield 1\n"
                "    finally:\n"
                "        pass\n"
                "\n"
                "def outer():\n"
                "    try:\n"
                "        yield from inner()\n"
                "    finally:\n"
                "        pass\n"
                "\n"
                "g = outer()\n"
                "next(g)\n"
                "g.throw(ValueError('m9'))\n",
                "<tb_m9>",
                "exec",
            )
        ),
        [],
        ns,
    );
    assert outcome.t == "error";
    got = "|".join(tb_entries((outcome as PyError).exception.traceback));
    assert (
        got == "<module>:15|outer:9|inner:3"
    ), f"cadence mismatch: {got}";
}

test "cleanup-throw caught by generator itself: handled, no leak" {
    ns = vm_exec(
        "def inner():\n"
        "    try:\n"
        "        yield 1\n"
        "    finally:\n"
        "        pass\n"
        "\n"
        "def catcher():\n"
        "    try:\n"
        "        yield from inner()\n"
        "    except ValueError:\n"
        "        yield 'caught'\n"
        "\n"
        "g = catcher()\n"
        "next(g)\n"
        "try:\n"
        "    r = g.throw(ValueError('m9b'))\n"
        "except ValueError:\n"
        "    r = 'LEAKED'\n"
    );
    got = str((ns["r"] as PyStr).val);
    assert got == "caught", f"expected caught, got: {got}";
}
