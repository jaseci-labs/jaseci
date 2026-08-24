# Native @dataclass pins (jac-py/jacpython/dataclassmodule.jac).
#
# The facade consumes PEP 649 annotations (__annotate_func__(1) stored by the
# class body), merges inherited __dataclass_fields__ base-first, and attaches
# synthesized __init__/__repr__/__eq__ (+ ordering dunders under order=True)
# to the guest class. Frozen enforcement rides the type-level __setattr__
# protocol with host-exact FrozenInstanceError text. Every rule below was
# probed side-by-side against CPython 3.14 before pinning.
#
# Idiom: snippets run on ceval through host_compile_marshal -> unmarshal ->
# exec_code with the native shim module registered first, so `from dataclasses
# import ...` resolves proxy-free. Error pins assert on the returned error
# object's type_name/message rather than catching in-process.

import from objects { PyObj, PyStr, PyInt, PyError, PyException, is_error }
import from ceval { to_host }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }
import from dataclassmodule { register_dataclasses_module }

def _fresh_ns -> dict[str, PyObj] {
    return {"__name__": PyStr(t="str", val="__main__")};
}

def vm_exec_in(ns: dict[str, PyObj], src: str) {
    register_dataclasses_module();
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<dataclasses>", "exec")), [], ns
    );
    assert not is_error(outcome);
}

# Run a decorated-class snippet and return the namespace for value checks.
def dc_exec(body: str) -> dict[str, PyObj] {
    ns = _fresh_ns();
    vm_exec_in(ns, "from dataclasses import dataclass\n" + body);
    return ns;
}

# Eval/exec `src` and return the raw outcome so a test can pin the raised
# exception itself.
def vm_try(src: str) -> PyObj {
    register_dataclasses_module();
    return exec_code(
        unmarshal(host_compile_marshal(src, "<dataclasses>", "exec")),
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

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

def vm_int(ns: dict[str, PyObj], name: str) -> int {
    v = to_host(ns[name]);
    return v as int;
}

def vm_bool(ns: dict[str, PyObj], name: str) -> bool {
    v = to_host(ns[name]);
    return v as bool;
}

# ---------------- construction, defaults, repr ----------------

test "dataclass: init fills fields positionally and by keyword" {
    ns = dc_exec(
        "@dataclass\n"
        "class A:\n"
        "    x: int\n"
        "    y: str\n"
        "a = A(1, y='b')\n"
        "rx = a.x\n"
        "ry = a.y\n"
    );
    assert vm_int(ns, "rx") == 1;
    assert vm_str(ns, "ry") == "b";
}

test "dataclass: declared defaults apply when omitted" {
    ns = dc_exec(
        "@dataclass\n"
        "class A:\n"
        "    x: int\n"
        "    y: str = 'a'\n"
        "ry = A(1).y\n"
        "rz = A(1, 'z').y\n"
    );
    assert vm_str(ns, "ry") == "a";
    assert vm_str(ns, "rz") == "z";
}

test "dataclass: repr form is exact" {
    ns = dc_exec(
        "@dataclass\n"
        "class A:\n"
        "    x: int\n"
        "    y: str = 'a'\n"
        "out = repr(A(1))\n"
    );
    assert vm_str(ns, "out") == "A(x=1, y='a')";
}

test "dataclass: default_factory gives each instance a fresh value" {
    ns = dc_exec(
        "from dataclasses import field\n"
        "@dataclass\n"
        "class D:\n"
        "    xs: list = field(default_factory=list)\n"
        "d1 = D()\n"
        "d2 = D()\n"
        "d1.xs.append(1)\n"
        "same = d1.xs is d2.xs\n"
        "out = repr(d2)\n"
    );
    assert vm_bool(ns, "same") == False;
    assert vm_str(ns, "out") == "D(xs=[])";
}

test "dataclass: repr=False hides a field from repr but not from the instance" {
    ns = dc_exec(
        "from dataclasses import field\n"
        "from dataclasses import field\n"
        "@dataclass\n"
        "class D:\n"
        "    xs: list = field(default_factory=list)\n"
        "    hidden: int = field(default=5, repr=False)\n"
        "d = D()\n"
        "out = repr(d)\n"
        "rh = d.hidden\n"
    );
    assert vm_str(ns, "out") == "D(xs=[])";
    assert vm_int(ns, "rh") == 5;
}

test "dataclass: decorator works bare and with empty parens" {
    ns = dc_exec(
        "@dataclass()\n"
        "class B:\n"
        "    v: int = 0\n"
        "out = repr(B())\n"
    );
    assert vm_str(ns, "out") == "B(v=0)";
}

# ---------------- equality and hashing ----------------

test "dataclass: eq compares field tuples" {
    ns = dc_exec(
        "@dataclass\n"
        "class P:\n"
        "    x: int\n"
        "    y: str = 'a'\n"
        "eq = P(1) == P(1)\n"
        "ne = P(1) == P(2, 'a')\n"
        "neg = P(1) != P(1)\n"
    );
    assert vm_bool(ns, "eq") == True;
    assert vm_bool(ns, "ne") == False;
    assert vm_bool(ns, "neg") == False;
}

test "dataclass: eq against other classes falls back to False" {
    ns = dc_exec(
        "@dataclass\n"
        "class P:\n"
        "    x: int\n"
        "@dataclass\n"
        "class Q:\n"
        "    x: int\n"
        "cross = P(1) == Q(1)\n"
        "scalar = P(1) == 1\n"
    );
    assert vm_bool(ns, "cross") == False;
    assert vm_bool(ns, "scalar") == False;
}

test "dataclass: eq=False leaves identity equality and identity hashing" {
    ns = dc_exec(
        "@dataclass(eq=False)\n"
        "class IE:\n"
        "    x: int = 0\n"
        "i1 = IE()\n"
        "i2 = IE()\n"
        "same_obj = i1 is i1\n"
        "diff_obj = i1 == i2\n"
        "h = hash(i1)\n"
        "h_ok = isinstance(h, int)\n"
    );
    assert vm_bool(ns, "same_obj") == True;
    assert vm_bool(ns, "diff_obj") == False;
    assert vm_bool(ns, "h_ok") == True;
}

test "dataclass: eq=True without frozen makes instances unhashable" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass\n"
        "class M:\n"
        "    x: int\n"
        "hash(M(1))\n"
    );
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "unhashable type: 'M'";
}

test "dataclass: frozen+eq generates tuple-of-fields hash" {
    ns = dc_exec(
        "from dataclasses import dataclass\n"
        "@dataclass(frozen=True)\n"
        "class FH:\n"
        "    x: int\n"
        "    y: str\n"
        "ok = hash(FH(1, 'a')) == hash((1, 'a'))\n"
    );
    assert vm_bool(ns, "ok") == True;
}

test "dataclass: unsafe_hash hashes mutable dataclasses" {
    ns = dc_exec(
        "@dataclass(unsafe_hash=True)\n"
        "class UH:\n"
        "    x: int\n"
        "u = UH(2)\n"
        "h_ok = isinstance(hash(u), int)\n"
    );
    assert vm_bool(ns, "h_ok") == True;
}

# ---------------- ordering ----------------

test "dataclass: order=True generates all four ordering dunders" {
    ns = dc_exec(
        "@dataclass(order=True)\n"
        "class O:\n"
        "    a: int\n"
        "    b: str\n"
        "lt = O(1, 'a') < O(2, 'a')\n"
        "le_eq = O(1, 'a') <= O(1, 'a')\n"
        "gt = O(2, 'a') > O(1, 'a')\n"
        "ge_eq = O(1, 'a') >= O(1, 'a')\n"
        "second_field_decides = O(1, 'a') < O(1, 'b')\n"
    );
    assert vm_bool(ns, "lt") == True;
    assert vm_bool(ns, "le_eq") == True;
    assert vm_bool(ns, "gt") == True;
    assert vm_bool(ns, "ge_eq") == True;
    assert vm_bool(ns, "second_field_decides") == True;
}

test "dataclass: order without eq is a ValueError" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass(order=True, eq=False)\n"
        "class Bad:\n"
        "    p: int\n"
    );
    assert err_type(outcome) == "ValueError";
    assert err_msg(outcome) == "eq must be true if order is true";
}

# ---------------- validation errors ----------------

test "dataclass: non-default-after-default names both arguments exactly" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass\n"
        "class B:\n"
        "    a: int = 1\n"
        "    b: int\n"
    );
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "non-default argument 'b' follows default argument 'a'";
}

test "dataclass: mutable default is rejected with use-factory hint" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass\n"
        "class MD:\n"
        "    xs: list = [1]\n"
    );
    assert err_type(outcome) == "ValueError";
    assert err_msg(outcome)
        == "mutable default <class 'list'> for field xs is not allowed: use default_factory";
}

test "dataclass: field() rejects default together with default_factory" {
    outcome = vm_try(
        "from dataclasses import dataclass, field\n"
        "@dataclass\n"
        "class F:\n"
        "    x: int = field(default=1, default_factory=int)\n"
    );
    assert err_type(outcome) == "ValueError";
    assert err_msg(outcome) == "cannot specify both default and default_factory";
}

# ---------------- keyword-only fields ----------------

test "dataclass: kw_only=True forces every field onto keywords" {
    # TODO(vm): currently fails because the ceval call binder does not reject
    # positional args past a bare `*` in guest-compiled signatures (pre-existing
    # on origin/jac-python: `def f(a, *, b=1)` accepts f(3)). The synthesized
    # __init__ source itself is correct -- see dc_build_init's star marker.
    ns = dc_exec(
        "from dataclasses import field\n"
        "@dataclass(kw_only=True)\n"
        "class K:\n"
        "    a: int\n"
        "    b: str = 'q'\n"
        "k = K(a=3)\n"
        "rb = k.b\n"
        "kw_rejected = False\n"
        "try:\n"
        "    K(3)\n"
        "except TypeError:\n"
        "    kw_rejected = True\n"
    );
    assert vm_str(ns, "rb") == "q";
    assert vm_bool(ns, "kw_rejected") == True;
}

test "dataclass: per-field kw_only splits the signature after '*'" {
    ns = dc_exec(
        "from dataclasses import field\n"
        "@dataclass\n"
        "class KM:\n"
        "    a: int\n"
        "    b: int = 0\n"
        "    c: int = field(default=2, kw_only=True)\n"
        "k = KM(1)\n"
        "rc = k.c\n"
        "positional_c_rejected = False\n"
        "try:\n"
        "    KM(1, 5, 6)\n"
        "except TypeError:\n"
        "    positional_c_rejected = True\n"
    );
    assert vm_int(ns, "rc") == 2;
    assert vm_bool(ns, "positional_c_rejected") == True;
}

# ---------------- __post_init__ hook ----------------

test "dataclass: __post_init__ runs after field assignment" {
    ns = dc_exec(
        "@dataclass\n"
        "class P:\n"
        "    a: int = 0\n"
        "    seen: int = -1\n"
        "    def __post_init__(self):\n"
        "        self.seen = self.a * 2\n"
        "p = P(5)\n"
        "rv = p.seen\n"
    );
    assert vm_int(ns, "rv") == 10;
}

test "dataclass: __post_init__ can reject bad input via raise" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass\n"
        "class P:\n"
        "    a: int\n"
        "    def __post_init__(self):\n"
        "        if self.a < 0:\n"
        "            raise ValueError('negative')\n"
        "P(-1)\n"
    );
    assert err_type(outcome) == "ValueError";
    assert err_msg(outcome) == "negative";
}

test "dataclass: inherited __post_init__ resolves through the MRO once" {
    ns = dc_exec(
        "from dataclasses import dataclass\n"
        "calls = []\n"
        "@dataclass\n"
        "class Base:\n"
        "    a: int = 0\n"
        "    def __post_init__(self):\n"
        "        calls.append('base')\n"
        "@dataclass\n"
        "class Sub(Base):\n"
        "    b: int = 0\n"
        "s = Sub(a=1, b=2)\n"
        "ncalls = len(calls)\n"
    );
    assert vm_int(ns, "ncalls") == 1;
}

# ---------------- ClassVar vs fields ----------------

test "dataclass: ClassVar annotations stay class attributes, not fields" {
    ns = dc_exec(
        "from dataclasses import dataclass, fields\n"
        "from typing import ClassVar\n"
        "@dataclass\n"
        "class CV:\n"
        "    a: int\n"
        "    reg: ClassVar[int] = 9\n"
        "names = [f.name for f in fields(CV)]\n"
        "rv = CV.reg\n"
    );
    assert vm_str(ns, "names") == "['a']";
    assert vm_int(ns, "rv") == 9;
}

# ---------------- inheritance chains ----------------

test "dataclass: inherited fields precede derived fields" {
    ns = dc_exec(
        "from dataclasses import fields\n"
        "@dataclass\n"
        "class Base:\n"
        "    a: int = 0\n"
        "@dataclass\n"
        "class Child(Base):\n"
        "    b: str = 'x'\n"
        "names = [f.name for f in fields(Child)]\n"
        "out = repr(Child())\n"
    );
    assert vm_str(ns, "names") == "['a', 'b']";
    assert vm_str(ns, "out") == "Child(a=0, b='x')";
}

test "dataclass: three-level chain keeps declaration order and defaults" {
    ns = dc_exec(
        "@dataclass\n"
        "class G1:\n"
        "    a: int = 1\n"
        "@dataclass\n"
        "class G2(G1):\n"
        "    b: int = 2\n"
        "@dataclass\n"
        "class G3(G2):\n"
        "    c: int = 3\n"
        "out = repr(G3())\n"
        "ra = G3().a\n"
    );
    assert vm_str(ns, "out") == "G3(a=1, b=2, c=3)";
    assert vm_int(ns, "ra") == 1;
}

test "dataclass: redeclaring an inherited field refreshes its default in place" {
    ns = dc_exec(
        "from dataclasses import fields\n"
        "@dataclass\n"
        "class Base:\n"
        "    a: int = 0\n"
        "    b: int = 5\n"
        "@dataclass\n"
        "class Child(Base):\n"
        "    a: int = 7\n"
        "out = repr(Child())\n"
        "names = [f.name for f in fields(Child)]\n"
    );
    assert vm_str(ns, "out") == "Child(a=7, b=5)";
    assert vm_str(ns, "names") == "['a', 'b']";
}

test "dataclass: derived required field after defaulted base field is an error" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass\n"
        "class Base:\n"
        "    a: int = 0\n"
        "@dataclass\n"
        "class Child(Base):\n"
        "    b: int\n"
    );
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "non-default argument 'b' follows default argument 'a'";
}

# ---------------- frozen protocol ----------------

test "dataclass: frozen assignment raises byte-exact FrozenInstanceError" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass(frozen=True)\n"
        "class F:\n"
        "    x: int\n"
        "F(1).x = 2\n"
    );
    assert err_type(outcome) == "FrozenInstanceError";
    assert err_msg(outcome) == "cannot assign to field 'x'";
}

test "dataclass: frozen new-attribute writes name the attempted attribute" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass(frozen=True)\n"
        "class F:\n"
        "    x: int\n"
        "F(1).z = 2\n"
    );
    assert err_type(outcome) == "FrozenInstanceError";
    assert err_msg(outcome) == "cannot assign to field 'z'";
}

test "dataclass: frozen deletion raises cannot-delete" {
    outcome = vm_try(
        "from dataclasses import dataclass\n"
        "@dataclass(frozen=True)\n"
        "class F:\n"
        "    x: int\n"
        "del F(1).x\n"
    );
    assert err_type(outcome) == "FrozenInstanceError";
    assert err_msg(outcome) == "cannot delete field 'x'";
}

test "dataclass: FrozenInstanceError catches as itself and as AttributeError" {
    ns = dc_exec(
        "import dataclasses\n"
        "@dataclass(frozen=True)\n"
        "class F:\n"
        "    x: int\n"
        "caught_exact = False\n"
        "caught_attr = False\n"
        "caught_value = False\n"
        "try:\n"
        "    F(1).x = 2\n"
        "except dataclasses.FrozenInstanceError:\n"
        "    caught_exact = True\n"
        "try:\n"
        "    F(1).x = 2\n"
        "except AttributeError:\n"
        "    caught_attr = True\n"
        "try:\n"
        "    F(1).x = 2\n"
        "except ValueError:\n"
        "    caught_value = True\n"
        "except Exception:\n"
        "    pass\n"
    );
    assert vm_bool(ns, "caught_exact") == True;
    assert vm_bool(ns, "caught_attr") == True;
    # Host python3 oracle: FrozenInstanceError subclasses AttributeError, NOT
    # ValueError -- the original stranded commit pinned the ValueError catch,
    # which real CPython does not satisfy.
    assert vm_bool(ns, "caught_value") == False;
}

# ---------------- module-level API ----------------

test "dataclass: fields() works on class and instance; exposes metadata" {
    ns = dc_exec(
        "from dataclasses import fields, is_dataclass\n"
        "@dataclass\n"
        "class D:\n"
        "    x: int\n"
        "    y: str = 'a'\n"
        "cls_names = [f.name for f in fields(D)]\n"
        "inst_names = [f.name for f in fields(D(1))]\n"
        "dy_default = fields(D)[1].default\n"
        "is_dc_cls = is_dataclass(D)\n"
        "is_dc_inst = is_dataclass(D(1))\n"
        "is_dc_int = is_dataclass(3)\n"
    );
    assert vm_str(ns, "cls_names") == "['x', 'y']";
    assert vm_str(ns, "inst_names") == "['x', 'y']";
    assert vm_str(ns, "dy_default") == "a";
    assert vm_bool(ns, "is_dc_cls") == True;
    assert vm_bool(ns, "is_dc_inst") == True;
    assert vm_bool(ns, "is_dc_int") == False;
}

test "dataclass: asdict recurses into nested dataclasses and containers" {
    ns = dc_exec(
        "from dataclasses import asdict\n"
        "@dataclass\n"
        "class Inner:\n"
        "    v: int\n"
        "@dataclass\n"
        "class Outer:\n"
        "    i: Inner\n"
        "    tags: list\n"
        "o = Outer(Inner(1), [Inner(2)])\n"
        "d = asdict(o)\n"
        "out = str(d)\n"
    );
    assert vm_str(ns, "out") == "{'i': {'v': 1}, 'tags': [{'v': 2}]}";
}

test "dataclass: astuple recurses like asdict" {
    ns = dc_exec(
        "from dataclasses import astuple\n"
        "@dataclass\n"
        "class Inner:\n"
        "    v: int\n"
        "@dataclass\n"
        "class Outer:\n"
        "    i: Inner\n"
        "    tag: str = 't'\n"
        "t = astuple(Outer(Inner(1)))\n"
        "out = str(t)\n"
    );
    assert vm_str(ns, "out") == "((1,), 't')";
}

test "dataclass: replace builds a changed copy without touching the original" {
    ns = dc_exec(
        "from dataclasses import replace\n"
        "@dataclass\n"
        "class Outer:\n"
        "    i: int\n"
        "    tag: str = 't'\n"
        "o = Outer(1)\n"
        "p = replace(o, tag='u')\n"
        "ro = repr(o)\n"
        "rp = repr(p)\n"
    );
    assert vm_str(ns, "ro") == "Outer(i=1, tag='t')";
    assert vm_str(ns, "rp") == "Outer(i=1, tag='u')";
}

test "dataclass: replace on a frozen instance constructs a new object" {
    ns = dc_exec(
        "from dataclasses import replace\n"
        "@dataclass(frozen=True)\n"
        "class F:\n"
        "    x: int\n"
        "f2 = replace(F(1), x=2)\n"
        "rx = f2.x\n"
    );
    assert vm_int(ns, "rx") == 2;
}

test "dataclass: replace rejects init=False fields" {
    outcome = vm_try(
        "from dataclasses import dataclass, field, replace\n"
        "@dataclass\n"
        "class N:\n"
        "    a: int\n"
        "    c: int = field(default=2, init=False)\n"
        "replace(N(1), c=9)\n"
    );
    assert err_type(outcome) == "ValueError";
    assert err_msg(outcome)
        == "field c is declared with init=False, it cannot be specified with replace()";
}

test "dataclass: init=False fields are set at construction, absent from init" {
    ns = dc_exec(
        "from dataclasses import field\n"
        "@dataclass\n"
        "class N:\n"
        "    a: int\n"
        "    c: int = field(default=2, init=False)\n"
        "out = repr(N(1))\n"
        "init_rejected = False\n"
        "try:\n"
        "    N(1, 2)\n"
        "except TypeError:\n"
        "    init_rejected = True\n"
    );
    assert vm_str(ns, "out") == "N(a=1, c=2)";
    assert vm_bool(ns, "init_rejected") == True;
}
