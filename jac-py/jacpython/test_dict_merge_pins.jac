# DICT_UPDATE / DICT_MERGE VM pins (lane wp4/dict-merge).
#
# Surface under test: ceval arms OP_DICT_UPDATE ({**x} display unpack) and
# OP_DICT_MERGE (f(**x) keyword-call merge), port of ceval.c
# TARGET(DICT_UPDATE)/TARGET(DICT_MERGE) over _PyDict_MergeEx.
#
# Ground truth recorded from host python3.14.7:
#   - {**x} accepts any keys()+__getitem__ mapping; duplicate keys overwrite
#     (last wins); non-mapping -> TypeError "'<type>' object is not a mapping"
#   - f(**x): duplicate key against an already-bound keyword ->
#     TypeError "... got multiple values for keyword argument 'k'"
#   - both errors fire at the FIRST offending key in iteration order:
#     f(a=1, **{"a": 2, 1: "x"}) reports the dup, f(a=1, **{1: "x", "a": 2})
#     reports keywords-must-be-strings
#   - non-str key under f(**x) -> TypeError "keywords must be strings"
#
# Known delta (documented, accepted): host prefixes merge-arm messages with
# the caller qualname ("__main__.f() argument after ..."); the VM omits the
# prefix, consistent with the other fast-bind call-site errors. The pins
# therefore assert the suffix text, which is the part CPython derives from
# the failing operation rather than the caller.

import from objects {
    PyObj,
    PyCode,
    PyStr,
    PyInt,
    PyNoneType,
    PyError,
    PyDict,
    is_error,
    expect_str,
}
import from opcode_meta {
    OP_RESUME,
    OP_DICT_UPDATE,
    OP_DICT_MERGE,
    OP_RETURN_VALUE,
}
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }


def oracle_exec(source: str, filename: str = "<dictmerge>") -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

def product_exec(source: str, filename: str = "<dictmerge>") -> PyObj {
    return compile_source(source, filename, "exec", 0);
}

# Exec module-level source on ceval; returns the globals dict it ran against.
def run_src(source: str) -> dict[str, PyObj] {
    comp = product_exec(source);
    assert not is_error(comp), f"compile failed: {(comp as PyError).exception.message}";
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(comp as PyCode, [], ns);
    assert not is_error(outcome), f"exec failed: {(outcome as PyError).exception.message}";
    return ns;
}

# Exec source expected to raise at module level; returns the propagated error.
def run_src_err(source: str) -> tuple[str, str] {
    comp = product_exec(source);
    assert not is_error(comp), f"compile failed: {(comp as PyError).exception.message}";
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(comp as PyCode, [], ns);
    assert is_error(outcome), "expected module exec to propagate an exception";
    exc = (outcome as PyError).exception;
    return (exc.type_name, exc.message);
}

def code_stream(src: str) -> list[int] {
    comp = product_exec(src);
    assert not is_error(comp);
    return (comp as PyCode).co_code;
}

def has_op(words: list[int], op: int) -> bool {
    i = 0;
    while i + 1 < len(words) {
        if words[i] == op {
            return True;
        }
        i = i + 2;
    }
    return False;
}

def dict_val_str(d: PyDict, k: str) -> str {
    v = d.mp_subscript(PyStr(t="str", val=k));
    if isinstance(v, PyStr) {
        return (v as PyStr).val;
    }
    if isinstance(v, PyInt) {
        return str((v as PyInt).val);
    }
    return "<" + v.t + ">";
}


# ---------------- byte-exact oracle parity ----------------

test "nested display lowering matches oracle bytes (BUILD_MAP runs + DICT_UPDATE)" {
    src = (
        "a = {'x': 1}\n"
        "b = {'y': 2}\n"
        "c = {**a, 'k': 3, **b}\n"
    );
    act = product_exec(src);
    assert not is_error(act);
    exp = oracle_exec(src);
    assert act.co_code == (exp as PyCode).co_code;
    assert act.names == (exp as PyCode).names;
    # Both unpacks must lower to DICT_UPDATE -- the exact arm this lane pins.
    assert has_op(act.co_code, OP_DICT_UPDATE), "no DICT_UPDATE in lowered stream";
}

test "double-star call lowering matches oracle bytes (DICT_MERGE present)" {
    src = (
        "def f(**kw):\n"
        "    return kw\n"
        "r = f(p=1, **{'q': 2})\n"
    );
    act = product_exec(src);
    assert not is_error(act);
    exp = oracle_exec(src);
    assert act.co_code == (exp as PyCode).co_code;
    assert act.names == (exp as PyCode).names;
    assert has_op((act as PyCode).co_code, OP_DICT_MERGE), "no DICT_MERGE in lowered stream";
}


# ---------------- DICT_UPDATE semantics through the VM ----------------

test "DICT_UPDATE: nested merges keep order, later unpack overrides" {
    ns = run_src(
        "a = {'k1': 1, 'k2': 2}\n"
        "b = {'k2': 99, 'k3': 3}\n"
        "r = {**a, 'mid': 0, **b}\n"
    );
    r = ns["r"] as PyDict;
    ks = [expect_str(k) for k in r.dict_keys()];
    assert ks == ["k1", "k2", "mid", "k3"], f"key order drifted: {ks}";
    assert dict_val_str(r, "k1") == "1";
    assert dict_val_str(r, "k2") == "99";
    assert dict_val_str(r, "mid") == "0";
    assert dict_val_str(r, "k3") == "3";
}

test "DICT_UPDATE: non-mapping rejected with CPython text" {
    res = run_src_err("x = {**5}\n");
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    assert msg == "'int' object is not a mapping", f"got: {msg}";
}

test "DICT_UPDATE: None rejected as NoneType" {
    res = run_src_err("x = {**None}\n");
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    assert msg == "'NoneType' object is not a mapping", f"got: {msg}";
}

test "DICT_UPDATE: merge error routes through try/except handler" {
    ns = run_src(
        "flag = 0\n"
        "try:\n"
        "    x = {**5}\n"
        "except TypeError:\n"
        "    flag = 1\n"
    );
    fv = ns["flag"];
    assert isinstance(fv, PyInt) and ((fv as PyInt).val == 1), "handler never ran";
}


# ---------------- DICT_MERGE semantics through the VM ----------------

test "DICT_MERGE: basic kwcall collects plain + unpacked keywords" {
    ns = run_src(
        "def f(**kw):\n"
        "    return kw\n"
        "r = f(p=1, **{'q': 2})\n"
    );
    r = ns["r"] as PyDict;
    ks = [expect_str(k) for k in r.dict_keys()];
    assert ks == ["p", "q"], f"keys: {ks}";
    assert dict_val_str(r, "p") == "1";
    assert dict_val_str(r, "q") == "2";
}

test "DICT_MERGE: non-mapping rejected with CPython suffix text" {
    res = run_src_err(
        "def f(**kw):\n"
        "    return kw\n"
        "f(**5)\n"
    );
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    # Host prefixes the caller qualname; VM omits it (documented delta).
    assert msg.endswith("argument after ** must be a mapping, not int"), f"got: {msg}";
}

test "DICT_MERGE: non-str key -> keywords must be strings" {
    res = run_src_err(
        "def f(**kw):\n"
        "    return kw\n"
        "f(**{1: 'a'})\n"
    );
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    assert msg == "keywords must be strings", f"got: {msg}";
}

test "DICT_MERGE: duplicate bound keyword -> got multiple values" {
    res = run_src_err(
        "def f(**kw):\n"
        "    return kw\n"
        "f(a=1, **{'a': 2})\n"
    );
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    assert msg.endswith("got multiple values for keyword argument 'a'"), f"got: {msg}";
}

test "DICT_MERGE: first offending key wins -- dup before bad key" {
    res = run_src_err(
        "def f(a=None, **kw):\n"
        "    return kw\n"
        "f(a=1, **{'a': 2, 1: 'x'})\n"
    );
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    assert msg.endswith("got multiple values for keyword argument 'a'"), f"got: {msg}";
}

test "DICT_MERGE: first offending key wins -- bad key before dup" {
    res = run_src_err(
        "def f(a=None, **kw):\n"
        "    return kw\n"
        "f(a=1, **{1: 'x', 'a': 2})\n"
    );
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    assert msg == "keywords must be strings", f"got: {msg}";
}


# ---------------- user-defined mapping protocol ----------------

test "user mapping (keys + __getitem__) unpacks in both arms" {
    ns = run_src(
        "class M:\n"
        "    def keys(self):\n"
        "        return ['u', 'v']\n"
        "    def __getitem__(self, k):\n"
        "        return {'u': 7, 'v': 8}[k]\n"
        "m = M()\n"
        "d = {**m, 'w': 9}\n"
        "def g(**kw):\n"
        "    return kw\n"
        "r = g(z=0, **m)\n"
    );
    d = ns["d"] as PyDict;
    assert dict_val_str(d, "u") == "7";
    assert dict_val_str(d, "v") == "8";
    assert dict_val_str(d, "w") == "9";
    r = ns["r"] as PyDict;
    # No overlap between the literal keyword and the mapping keys: both flow
    # into **kw without conflict.
    assert dict_val_str(r, "z") == "0";
    assert dict_val_str(r, "u") == "7";
    assert dict_val_str(r, "v") == "8";
}

test "user mapping duplicate against bound keyword still errors" {
    res = run_src_err(
        "class M:\n"
        "    def keys(self):\n"
        "        return ['u']\n"
        "    def __getitem__(self, k):\n"
        "        return 7\n"
        "def g(**kw):\n"
        "    return kw\n"
        "g(u=0, **M())\n"
    );
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    assert msg.endswith("got multiple values for keyword argument 'u'"), f"got: {msg}";
}

test "user mapping missing __getitem__ is not a mapping" {
    res = run_src_err(
        "class OnlyKeys:\n"
        "    def keys(self):\n"
        "        return ['u']\n"
        "x = {**OnlyKeys()}\n"
    );
    tn = res[0];
    msg = res[1];
    assert tn == "TypeError", f"got {tn}";
    assert msg == "'OnlyKeys' object is not a mapping", f"got: {msg}";
}


# ---------------- regression guard ----------------

# Overcorrection guard: the validation must not reject valid sources. An
# empty dict unpack stays a no-op (not an error) in both arms.
test "regression: valid empty merges stay silent no-ops" {
    ns = run_src(
        "a = {'x': 1}\n"
        "d = {**{}, **a}\n"
        "def f(**kw):\n"
        "    return kw\n"
        "r = f(**{})\n"
    );
    d = ns["d"] as PyDict;
    ks = [expect_str(k) for k in d.dict_keys()];
    assert ks == ["x"], f"keys: {ks}";
    r = ns["r"] as PyDict;
    assert len(r.dict_keys()) == 0, "f(**{}) should collect nothing";
}
