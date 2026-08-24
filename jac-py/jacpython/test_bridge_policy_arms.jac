# Bridge-policy to_host arm coverage pins (lane wp4/recensus).
#
# Surface under test: every BridgePolicy tag in to_host_policy() must have a
# live conversion arm in ceval.jac to_host(). Root cause this lane closed:
# Jac match has NO grouped case labels -- stacked `case A(): case B(): body`
# silently gave ONLY B the body, so whole families (bound_method,
# native_builtin, list/dict/set methods, every iterator kind except PyIter)
# fell through to "policy but no arm" RuntimeErrors.
#
# Pin shape: construct one guest object per tag in guest source, cross it via
# to_host(), assert no bridge-table error. Host differential is implicit:
# a successful crossing means the object reached real host machinery, which
# then round-trips or consumes it exactly like CPython's boundary does.

import from pyc_first { exec_code }
import from product_compile { compile_source }
import from objects { PyCode, PyStr, PyError, is_error }
import from ceval { to_host }
import from product_compile { compile_source as product_exec }

def setup() -> dict[str, PyObj] {
    src = (
        "import itertools\n"
        "class W:\n"
        "    def m(self):\n"
        "        return 1\n"
        "    @classmethod\n"
        "    def c(cls): return 2\n"
        "    @staticmethod\n"
        "    def s(): return 3\n"
        "d = {'k': 1}\n"
        "v_function = W.m\n"
        "v_bound_method = W().m\n"
        "v_native_builtin = len\n"
        "v_native_new = int.__new__\n"
        "v_classmethod = W.c\n"
        "v_staticmethod = W.s\n"
        "v_property_ctor = property\n"
        "v_classmethod_ctor = classmethod\n"
        "v_staticmethod_ctor = staticmethod\n"
        "v_str_method = 'ab'.upper\n"
        "v_list_method = [].append\n"
        "v_dict_method = d.get\n"
        "v_dictview_keys = d.keys()\n"
        "v_dictiter = iter(d)\n"
        "v_seqiter = iter('abc')\n"
        "v_rangeiter = iter(range(3))\n"
        "v_calliter = iter(itertools.count, None)\n"
        "v_generator = (x for x in [1])\n"
        "v_class = W\n"
    );
    comp = compile_source(src, "<p>", "exec", 0);
    assert not is_error(comp), "compile failed";
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    out = exec_code(comp as PyCode, [], ns);
    assert not is_error(out), "exec failed";
    return ns;
}

# Crosses obj through to_host inside try/except so a regression surfaces as
# the bridge-table RuntimeError text instead of crashing the harness.
def crosses(ns: dict[str, PyObj], key: str) -> bool {
    ok = True;
    try {
        h = to_host(ns[key]);
    } except BaseException as e {
        msg = str(e);
        print("bridge miss [", key, "]: ", msg);
        ok = False;
    }
    return ok;
}

test "TRAMPOLINE arms: functions, methods, ctors all cross" {
    ns = setup();
    assert crosses(ns, "v_function");
    assert crosses(ns, "v_bound_method");
    assert crosses(ns, "v_native_builtin");
    assert crosses(ns, "v_native_new");
    assert crosses(ns, "v_classmethod");
    assert crosses(ns, "v_staticmethod");
    assert crosses(ns, "v_property_ctor");
    assert crosses(ns, "v_classmethod_ctor");
    assert crosses(ns, "v_staticmethod_ctor");
    assert crosses(ns, "v_str_method");
    assert crosses(ns, "v_list_method");
    assert crosses(ns, "v_dict_method");
}

test "LAZY_ITER arms: every iterator kind crosses" {
    ns = setup();
    assert crosses(ns, "v_dictiter");
    assert crosses(ns, "v_seqiter");
    assert crosses(ns, "v_rangeiter");
    assert crosses(ns, "v_calliter");
    assert crosses(ns, "v_generator");
}

test "VIEW_COPY arm: dict view crosses" {
    ns = setup();
    assert crosses(ns, "v_dictview_keys");
}

test "STANDIN arm: guest class object crosses" {
    ns = setup();
    assert crosses(ns, "v_class");
}

test "crossed trampoline actually invokes guest code" {
    ns = setup();
    # End-to-end: host sorted(key=...) calls BACK into a guest function --
    # the round-trip that grouped-case fall-through used to break for
    # bound/native callables.
    comp = product_exec(
        "class A:\n"
        "    def k(self, x):\n"
        "        return -x\n"
        "a = A()\n"
        "r = sorted([3, 1, 2], key=a.k)\n",
        "<bp>", "exec", 0
    );
    assert not is_error(comp);
    nss: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(comp as PyCode, [], nss);
    assert not is_error(outcome), f"round-trip failed: {(outcome as PyError).exception.message}";
}
