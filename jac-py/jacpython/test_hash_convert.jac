# Hash-inheritance + int()/float()-conversion regression pins.
#
# BUG 1 (hash): tp_hashkey checked "__eq__ without __hash__" only against the
# instance's own class MRO presence, never resolving which definition WINS.
# CPython's actual rule (Objects/typeobject.c): inherit_slots (~8372) copies
# tp_richcompare/tp_hash together from the first MRO base while neither is
# overridden locally; type_ready_set_hash (~8773) injects tp_dict["__hash__"] =
# None into any class body defining __eq__ without __hash__, and that injected
# None SHADOWS every ancestor's explicit __hash__ during MRO lookup
# (update_one_slot ~11655). So a base's __hash__ does NOT rescue a subclass
# whose body defines __eq__; only a __hash__ in the same-or-nearer body does.
#
# BUG 2 (convert): py_convert_int swallowed errors from user __int__ and fell
# back to __index__. PyNumber_Long/PyNumber_Float (Objects/abstract.c) treat an
# existing nb_int/nb_float as FINAL -- exceptions and the non-number TypeError
# propagate verbatim; nb_index runs only when the number slot is absent
# entirely, where an inherited builtin number slot (int/bool/float base)
# counts as present and preempts even a user-defined __index__.
#
# All pins are captured byte-exact from the host oracle (CPython 3.14).

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<hash_convert>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

# Run `src`, capturing `expr`'s value or its exception as "Type: message".
def outcome_str(src: str, expr: str) -> str {
    ns = vm_exec(
        src +
        "try:\n"
        "    r = " + expr + "\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    );
    v = to_host(ns["r"]);
    if isinstance(v, str) {
        return v;
    }
    return str(v);
}

# ---- BUG 1: __eq__/__hash__ slot resolution over the MRO --------------------

test "eq-only class is unhashable" {
    src =
        "class EqOnly:\n"
        "    def __eq__(self, o): return True\n";
    assert outcome_str(src, "hash(EqOnly())")
        == "TypeError: unhashable type: 'EqOnly'";
}

test "eq in subclass of plain base is unhashable" {
    src =
        "class Base0: pass\n"
        "class Sub0(Base0):\n"
        "    def __eq__(self, o): return True\n";
    assert outcome_str(src, "hash(Sub0())")
        == "TypeError: unhashable type: 'Sub0'";
}

test "ancestor __hash__ does not rescue a defining-__eq__ subclass" {
    src =
        "class Base2:\n"
        "    def __hash__(self): return 7\n"
        "class Sub2(Base2):\n"
        "    def __eq__(self, o): return True\n";
    # type_ready_set_hash injects __hash__ = None into Sub2, shadowing Base2's.
    assert outcome_str(src, "hash(Sub2())")
        == "TypeError: unhashable type: 'Sub2'";
    # The base itself stays hashable with its own hash.
    assert outcome_str(src, "hash(Base2())") != "TypeError: unhashable type: 'Base2'";
    # Residual: CPython also makes that injected None VISIBLE as
    # Sub2.__hash__ is None; this runtime computes hashability on demand
    # without mutating the class dict, so attribute visibility is not pinned.
}

test "grandparent hash does not survive an intervening eq" {
    src =
        "class G:\n"
        "    def __hash__(self): return 9\n"
        "class P(G): pass\n"
        "class S(P):\n"
        "    def __eq__(self, o): return True\n";
    assert outcome_str(src, "hash(S())") == "TypeError: unhashable type: 'S'";
}

test "own __hash__ overrides inherited eq-unhashability" {
    src =
        "class E5:\n"
        "    def __eq__(self, o): return True\n"
        "class H5(E5):\n"
        "    def __hash__(self): return 3\n";
    assert outcome_str(src, "hash(H5())") == "3";
}

test "unhashability inherits through neutral subclasses" {
    src =
        "class E6:\n"
        "    def __eq__(self, o): return True\n"
        "class N6(E6): pass\n";
    assert outcome_str(src, "hash(N6())")
        == "TypeError: unhashable type: 'N6'";
    assert outcome_str(src, "N6() == N6()") == "True";
}

test "explicit __hash__ = None blocks hashing" {
    src =
        "class X7:\n"
        "    def __hash__(self): return 4\n"
        "class Y7(X7):\n"
        "    __hash__ = None\n";
    assert outcome_str(src, "hash(Y7())")
        == "TypeError: unhashable type: 'Y7'";
}

test "eq+hash in one body hashes by value" {
    src =
        "class B8:\n"
        "    def __eq__(self, o): return True\n"
        "    def __hash__(self): return 11\n";
    assert outcome_str(src, "hash(B8())") == "11";
}

test "MRO order decides the mixed-inheritance pair copy" {
    # inherit_slots copies richcompare/hash from the FIRST MRO base.
    src =
        "class AE:\n"
        "    def __eq__(self, o): return True\n"
        "class BH:\n"
        "    def __hash__(self): return 7\n"
        "    def __eq__(self, o): return False\n"
        "class CAB(AE, BH): pass\n"
        "class CBA(BH, AE): pass\n";
    assert outcome_str(src, "hash(CAB())")
        == "TypeError: unhashable type: 'CAB'";
    assert outcome_str(src, "hash(CBA())") == "7";
}

test "builtin subclass eq rule matches host" {
    src =
        "class I9(int):\n"
        "    def __eq__(self, o): return True\n"
        "class I10(int):\n"
        "    def __eq__(self, o): return True\n"
        "    def __hash__(self): return 42\n";
    assert outcome_str(src, "hash(I9(3))")
        == "TypeError: unhashable type: 'I9'";
    assert outcome_str(src, "hash(I10(3))") == "42";
}

test "plain classes stay identity-hashable" {
    src =
        "class Plain: pass\n"
        "a = Plain()\n"
        "b = Plain()\n"
        "d = {a: 1}\n";
    assert outcome_str(src, "d[a]") == "1";
    assert outcome_str(src, "(a in d) and (b not in d)") == "True";
}

# ---- BUG 2: int()/float() conversion slot precedence ------------------------

test "raising __int__ propagates" {
    src =
        "class IntRaising:\n"
        "    def __int__(self): raise ValueError('boom')\n";
    assert outcome_str(src, "int(IntRaising())") == "ValueError: boom";
}

test "index-only class converts" {
    src =
        "class IndexOnly:\n"
        "    def __index__(self): return 5\n";
    assert outcome_str(src, "int(IndexOnly())") == "5";
    assert outcome_str(src, "float(IndexOnly())") == "5.0";
}

test "non-int __int__ result pins abstract.c message" {
    src =
        "class IntBad:\n"
        "    def __int__(self): return 'nope'\n";
    assert outcome_str(src, "int(IntBad())")
        == "TypeError: __int__ returned non-int (type str)";
}

test "defined __int__ beats __index__" {
    src =
        "class IntAndIndex:\n"
        "    def __int__(self): return 1\n"
        "    def __index__(self): return 99\n";
    assert outcome_str(src, "int(IntAndIndex())") == "1";
}

test "inherited builtin number slot preempts user __index__" {
    src =
        "class C7(int):\n"
        "    def __index__(self): return 99\n"
        "class F7(float):\n"
        "    def __index__(self): return 42\n";
    assert outcome_str(src, "int(C7(7))") == "7";
    assert outcome_str(src, "int(F7(1.5))") == "1";
    assert outcome_str(src, "float(F7(1.5))") == "1.5";
}

test "str subclass parses unless __index__ intervenes" {
    src =
        "class S2(str): pass\n"
        "class SI(str):\n"
        "    def __index__(self): return 42\n";
    assert outcome_str(src, "int(S2('123'))") == "123";
    assert outcome_str(src, "float(S2('1.5'))") == "1.5";
    assert outcome_str(src, "int(SI('x'))") == "42";
}

test "non-number base keeps user __index__" {
    src =
        "class L9(list):\n"
        "    def __index__(self): return 8\n";
    assert outcome_str(src, "int(L9([1]))") == "8";
}

test "raising __index__ propagates to int() and float()" {
    src =
        "class RI:\n"
        "    def __index__(self): raise KeyError('ki')\n";
    assert outcome_str(src, "int(RI())") == "KeyError: 'ki'";
    assert outcome_str(src, "float(RI())") == "KeyError: 'ki'";
}

test "raising inherited __int__ propagates through boxed base" {
    src =
        "class RaisingInt(int):\n"
        "    def __int__(self): raise ValueError('rb')\n";
    assert outcome_str(src, "int(RaisingInt(3))") == "ValueError: rb";
}

test "__int__ returning bool coerces" {
    src =
        "class BoolRet:\n"
        "    def __int__(self): return True\n";
    assert outcome_str(src, "int(BoolRet())") == "1";
}

test "float conversion fidelity" {
    src =
        "class FloatOk:\n"
        "    def __float__(self): return 2.0\n"
        "class FltRaising:\n"
        "    def __float__(self): raise KeyError('kf')\n"
        "class FltBad:\n"
        "    def __float__(self): return 'x'\n"
        "class NoSlots:\n"
        "    pass\n";
    assert outcome_str(src, "float(FloatOk())") == "2.0";
    assert outcome_str(src, "float(FltRaising())") == "KeyError: 'kf'";
    assert outcome_str(src, "float(FltBad())")
        == "TypeError: FltBad.__float__ returned non-float (type str)";
    assert outcome_str(src, "float(NoSlots())")
        == "TypeError: float() argument must be a string or a real number, not 'NoSlots'";
    assert outcome_str(src, "int(NoSlots())")
        == "TypeError: int() argument must be a string, a bytes-like object or a real number, not 'NoSlots'";
}
