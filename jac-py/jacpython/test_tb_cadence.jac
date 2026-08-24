# Traceback-cadence fidelity regression pins (lane tb-cadence).
#
# Each fixture executes Python source on jacpython's ceval via host-compiled
# marshal and asserts the guest traceback chain byte-exactly against the
# CPython oracle. Pins the cleanup-RERAISE escape cadence: re-raises
# (RERAISE 0/1, bare RAISE_VARARGS) must add NO tb entry -- entries come only
# from error events (failing op / fresh raise), once per frame, so an
# exception escaping through a finally leaves exactly one entry for that
# frame at the original raise line.

import from objects { PyStr, PyError }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }


# Walk a PyTraceback chain into "name:lineno" entries.
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


# Exec `src` on ceval with fresh module globals; returns the escaped error's
# traceback cadence ("name:lineno" head-first, like e.__traceback__ walks).
def escaped_cadence(src: str) -> str {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<tb_cadence>", "exec")), [], ns
    );
    assert outcome.t == "error";
    return "|".join(tb_entries((outcome as PyError).exception.traceback));
}


test "cleanup-RERAISE escape: finally adds no extra tb entry" {
    got = escaped_cadence(
        "def inner():\n"
        "    try:\n"
        "        raise ValueError('a')\n"
        "    finally:\n"
        "        pass\n"
        "\n"
        "def middle():\n"
        "    return inner()\n"
        "\n"
        "middle()\n"
    );
    assert got == "<module>:10|middle:8|inner:3", f"cadence mismatch: {got}";
}

test "bare reraise in except: single entry per frame" {
    got = escaped_cadence(
        "def f():\n"
        "    try:\n"
        "        raise ValueError('b')\n"
        "    except ValueError:\n"
        "        raise\n"
        "\n"
        "f()\n"
    );
    assert got == "<module>:7|f:3", f"cadence mismatch: {got}";
}

# Exec `src` on ceval with fresh module globals; returns module globals.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<tb_cadence>", "exec")), [], ns
    );
    assert outcome.t != "error";
    return ns;
}


test "caught-in-frame raise: one entry at the raise line" {
    ns = vm_exec(
        "def f():\n"
        "    try:\n"
        "        raise ValueError('c')\n"
        "    except ValueError as e:\n"
        "        parts = []\n"
        "        t = e.__traceback__\n"
        "        while t:\n"
        "            parts.append(\n"
        "                t.tb_frame.f_code.co_name + ':' + str(t.tb_lineno)\n"
        "            )\n"
        "            t = t.tb_next\n"
        "        return '|'.join(parts)\n"
        "    return None\n"
        "r = f()\n"
    );
    assert str((ns["r"] as PyStr).val) == "f:3";
}

test "nested double-finally escape: one entry per frame" {
    got = escaped_cadence(
        "def deep():\n"
        "    try:\n"
        "        raise ValueError('d')\n"
        "    finally:\n"
        "        pass\n"
        "\n"
        "def mid():\n"
        "    try:\n"
        "        return deep()\n"
        "    finally:\n"
        "        pass\n"
        "\n"
        "mid()\n"
    );
    assert got == "<module>:13|mid:9|deep:3", f"cadence mismatch: {got}";
}

test "finally raising a new error: single entry at the new raise line" {
    got = escaped_cadence(
        "def f():\n"
        "    try:\n"
        "        raise ValueError('e')\n"
        "    finally:\n"
        "        raise KeyError('f')\n"
        "\n"
        "f()\n"
    );
    assert got == "<module>:7|f:5", f"cadence mismatch: {got}";
}
