# Phase-1 except* VM plumbing pins (lane p1exc).
#
# Surface under test: CALL_INTRINSIC_2 oparg 1 = INTRINSIC_PREP_RERAISE_STAR
# -- the tail recombine of a lowered try/except* block, port of
# _PyExc_PrepReraiseStar (Objects/exceptions.c). CHECK_EG_MATCH is owned by
# another lane; the VM-exec pins here drive the intrinsic directly through
# hand-built code objects so they stay valid regardless of when that arm
# lands.
#
# Ground truth recorded from host python3.14:
#   - _PyExc_PrepReraiseStar naked paths (Objects/exceptions.c ~1618):
#     excs == [] -> None; naked orig -> excs[0] verbatim (so an all-None
#     list yields None -> normal path, and the unmatched `rest` flows back
#     for reraise).
#   - ExceptionGroup("g", []) ->
#     ValueError: second argument (exceptions) must be a non-empty sequence
#   - bound multi-handler except* lowering is byte-exact vs the host
#     compiler (band-11 oracle parity), including CALL_INTRINSIC_2 oparg 1
#     at the rr_match tail.

import from objects {
    PyObj,
    PyCode,
    PyStr,
    PyNoneType,
    PyException,
    PyError,
    is_error,
}
import from opcode_meta {
    OP_RESUME,
    OP_LOAD_CONST,
    OP_BUILD_LIST,
    OP_LIST_APPEND,
    OP_CALL_INTRINSIC_2,
    OP_STORE_NAME,
    OP_RETURN_VALUE,
}
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }


def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

def product_exec(source: str, filename: str = "<p1exc>") -> PyObj {
    return compile_source(source, filename, "exec", 0);
}

def nested_code_named(co: PyCode, want: str) -> PyCode {
    ci = 0;
    while ci < len(co.consts) {
        c = co.consts[ci];
        if isinstance(c, PyCode) and (c as PyCode).name == want {
            return c as PyCode;
        }
        ci = ci + 1;
    }
    assert False, f"nested code '{want}' not found";
    return co;
}

# Exec a hand-built code object on ceval; returns the module-globals dict it
# ran against (STORE_NAME results land there).
def run_code(co: PyCode) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome), f"exec failed: {(outcome as PyError).exception.message}";
    return ns;
}

def make_code(consts: list[PyObj], names: list[str], words: list[int]) -> PyCode {
    return PyCode(
        t="code",
        argcount=0,
        posonlyargcount=0,
        kwonlyargcount=0,
        stacksize=4,
        flags=64,
        co_code=words,
        consts=consts,
        names=names,
        varnames=[],
        cellvars=[],
        freevars=[],
        filename="<p1exc>",
        name="<module>",
        qualname="<module>",
        firstlineno=1,
        linetable=[],
        exceptiontable=[],
    );
}

def value_error(msg: str) -> PyObj {
    return PyException(t="exception", type_name="ValueError", message=msg) as PyObj;
}


# ---------------- byte-exact oracle parity (compile-only golden) ----------------

test "except* bound multi-handler lowering matches oracle bytes" {
    src = (
        "def f():\n"
        "    try:\n"
        "        raise ValueError('v')\n"
        "    except* TypeError as e:\n"
        "        print('t', e)\n"
        "    except* ValueError as e:\n"
        "        print('v', e)\n"
    );
    act = product_exec(src);
    assert not is_error(act);
    exp = oracle_exec(src);
    act_f = nested_code_named(act as PyCode, "f");
    exp_f = nested_code_named(exp as PyCode, "f");
    assert act_f.co_code == exp_f.co_code;
    assert act_f.linetable == exp_f.linetable;
    assert act_f.names == exp_f.names;
    assert act_f.exceptiontable == exp_f.exceptiontable;
    assert act_f.stacksize == exp_f.stacksize;
    # The stream must carry the PREP_RERAISE_STAR intrinsic (op 54, oparg 1)
    # -- the exact opcode this lane wires into the VM.
    found = False;
    i = 0;
    while i + 1 < len(exp_f.co_code) {
        if exp_f.co_code[i] == 54 and exp_f.co_code[i + 1] == 1 {
            found = True;
        }
        i = i + 2;
    }
    assert found, "no CALL_INTRINSIC_2 oparg 1 in lowered stream";
}


# ---------------- intrinsic semantics through the VM ----------------

test "PREP_RERAISE_STAR: all handlers matched (all-None list) -> None" {
    co = make_code(
        [value_error("v"), PyNoneType(t="none")],
        ["r"],
        [
            OP_RESUME, 0,
            OP_LOAD_CONST, 0,
            OP_BUILD_LIST, 0,
            OP_LOAD_CONST, 1,
            OP_LIST_APPEND, 1,
            OP_CALL_INTRINSIC_2, 1,
            OP_STORE_NAME, 0,
            OP_RETURN_VALUE, 0,
        ],
    );
    ns = run_code(co);
    r = ns["r"];
    assert not is_error(r);
    assert isinstance(r, PyNoneType), f"expected None, got {r.t}";
}

test "PREP_RERAISE_STAR: unmatched rest propagates verbatim" {
    orig = value_error("v");
    co = make_code(
        [orig, PyNoneType(t="none")],
        ["r"],
        [
            OP_RESUME, 0,
            OP_LOAD_CONST, 0,
            OP_BUILD_LIST, 0,
            OP_LOAD_CONST, 0,
            OP_LIST_APPEND, 1,
            OP_CALL_INTRINSIC_2, 1,
            OP_STORE_NAME, 0,
            OP_RETURN_VALUE, 0,
        ],
    );
    ns = run_code(co);
    r = ns["r"];
    assert not is_error(r);
    # Identity: the naked path returns excs[0] itself, no re-wrap.
    assert r is orig, "naked PrepReraiseStar must return excs[0] by identity";
}

test "PREP_RERAISE_STAR: empty excs list -> None" {
    co = make_code(
        [value_error("v")],
        ["r"],
        [
            OP_RESUME, 0,
            OP_LOAD_CONST, 0,
            OP_BUILD_LIST, 0,
            OP_CALL_INTRINSIC_2, 1,
            OP_STORE_NAME, 0,
            OP_RETURN_VALUE, 0,
        ],
    );
    ns = run_code(co);
    r = ns["r"];
    assert not is_error(r);
    assert isinstance(r, PyNoneType), f"expected None, got {r.t}";
}

test "PREP_RERAISE_STAR: malformed operand -> SystemError" {
    co = make_code(
        [value_error("v")],
        [],
        [
            OP_RESUME, 0,
            OP_LOAD_CONST, 0,
            OP_LOAD_CONST, 0,
            OP_CALL_INTRINSIC_2, 1,
            OP_RETURN_VALUE, 0,
        ],
    );
    outcome = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
    assert is_error(outcome);
    err = (outcome as PyError).exception;
    assert err.type_name == "SystemError", f"got {err.type_name}";
    assert "PREP_RERAISE_STAR" in err.message;
}


# ---------------- ctor boundary parity vs host ----------------

def vm_exec_capture(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<p1exc>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

test "ExceptionGroup ctor ValueError text matches host" {
    # Host ground truth: ValueError: second argument (exceptions) must be a
    # non-empty sequence. The builtin name resolves through the host bridge;
    # if the raised type were anything else, the handler would not match and
    # the exec would fail instead of capturing the message.
    ns = vm_exec_capture(
        "msg = ''\n"
        "try:\n"
        "    ExceptionGroup('g', [])\n"
        "except ValueError as e:\n"
        "    msg = str(e)\n"
    );
    got = (ns["msg"] as PyStr).val;
    assert got == "second argument (exceptions) must be a non-empty sequence", (
        f"got: {got}"
    );
}
