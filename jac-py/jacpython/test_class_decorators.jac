# Class-decorator regression pins (parser action + codegen + scoping).
#
# `pa_class_def_decorators` used to return the statement unchanged, so
# `@deco class C:` compiled as an undecorated class -- silent-wrong output.
# The fix attaches decorator_list in the parser (mirroring
# _PyPegen_class_def_decorators), lowers decorators exactly like CPython 3.14
# codegen_class/codegen_apply_decorators (decorator loads in the ENCLOSING
# scope before LOAD_BUILD_CLASS, reversed CALL 0 chain after the build call,
# each CALL row carrying that decorator's span), and scopes the class body at
# the first decorator's line (co_firstlineno, RESUME/boilerplate rows,
# __firstlineno__). Function-def decorators were already lowered correctly;
# parity pins here guard that too.

import from layer9_product_exec { assert_matches_oracle }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<class_decorators>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

# ---------------- byte-parity battery vs the host oracle ----------------

test "class decorators: single decorator, plain body" {
    assert_matches_oracle(
        "def deco(c):\n"
        "    c.tag = 1\n"
        "    return c\n"
        "\n"
        "@deco\n"
        "class C:\n"
        "    pass\n"
    );
}

test "class decorators: stacked @a @b applies a(b(C))" {
    assert_matches_oracle(
        "def a(c):\n"
        "    return c\n"
        "\n"
        "def b(c):\n"
        "    return c\n"
        "\n"
        "@a\n"
        "@b\n"
        "class S:\n"
        "    pass\n"
    );
}

test "class decorators: factory with arguments" {
    assert_matches_oracle(
        "def fact(x):\n"
        "    def d(c):\n"
        "        c.x = x\n"
        "        return c\n"
        "    return d\n"
        "\n"
        "@fact(7)\n"
        "class A:\n"
        "    pass\n"
    );
}

test "class decorators: dotted attribute decorator expression" {
    assert_matches_oracle(
        "import mod\n"
        "\n"
        "@mod.deco\n"
        "class D:\n"
        "    pass\n"
    );
}

test "class decorators: empty body, bases, kwargs metaclass" {
    assert_matches_oracle("@deco\nclass C: pass\n");
    assert_matches_oracle(
        "def deco(c):\n"
        "    return c\n"
        "\n"
        "@deco\n"
        "class B(dict):\n"
        "    pass\n"
    );
    assert_matches_oracle(
        "def deco(c):\n"
        "    return c\n"
        "\n"
        "@deco\n"
        "class M(metaclass=type):\n"
        "    pass\n"
    );
}

test "class decorators: nested class inside function scope" {
    # Decorators evaluate in the enclosing scope; the store goes to a fast
    # local and the class body may close over enclosing cells.
    assert_matches_oracle(
        "def deco(c):\n"
        "    return c\n"
        "\n"
        "def outer():\n"
        "    @deco\n"
        "    class Inner:\n"
        "        pass\n"
        "    return Inner\n"
        "\n"
        "R = outer()\n"
    );
}

test "function decorators stay byte-exact (single, stacked, argful)" {
    assert_matches_oracle(
        "def deco(f):\n"
        "    return f\n"
        "\n"
        "@deco\n"
        "def f():\n"
        "    pass\n"
    );
    assert_matches_oracle(
        "def a(f):\n"
        "    return f\n"
        "\n"
        "def b(f):\n"
        "    return f\n"
        "\n"
        "@a\n"
        "@b\n"
        "def g():\n"
        "    pass\n"
    );
    assert_matches_oracle(
        "def fact(n):\n"
        "    def d(f):\n"
        "        return f\n"
        "    return d\n"
        "\n"
        "@fact(1)\n"
        "def h():\n"
        "    pass\n"
    );
}

# ---------------- runtime checks through ceval ----------------

test "class decorator side effect lands on the class" {
    ns = vm_exec(
        "def deco(c):\n"
        "    c.tag = 1\n"
        "    return c\n"
        "\n"
        "@deco\n"
        "class C:\n"
        "    pass\n"
        "\n"
        "out = C.tag\n"
    );
    assert vm_str(ns, "out") == "1";
}

test "stacked decorators run bottom-up around the raw class" {
    ns = vm_exec(
        "log = []\n"
        "\n"
        "def a(c):\n"
        "    log.append('a:' + c.__name__)\n"
        "    return c\n"
        "\n"
        "def b(c):\n"
        "    log.append('b:' + c.__name__)\n"
        "    return c\n"
        "\n"
        "@a\n"
        "@b\n"
        "class S:\n"
        "    pass\n"
        "\n"
        "out = '|'.join(log)\n"
    );
    # b wraps the raw class first; a wraps b's result.
    assert vm_str(ns, "out") == "b:S|a:S";
}

test "argful factory decorator binds its argument" {
    ns = vm_exec(
        "def fact(x):\n"
        "    def d(c):\n"
        "        c.x = x\n"
        "        return c\n"
        "    return d\n"
        "\n"
        "@fact(9)\n"
        "class A:\n"
        "    pass\n"
        "\n"
        "out = A.x\n"
    );
    assert vm_str(ns, "out") == "9";
}

test "name binds to the decorator's return value, not the raw class" {
    ns = vm_exec(
        "class Replacement:\n"
        "    pass\n"
        "\n"
        "def steal(c):\n"
        "    return Replacement\n"
        "\n"
        "@steal\n"
        "class C:\n"
        "    pass\n"
        "\n"
        "same = C is Replacement\n"
        "nm = C.__name__\n"
    );
    assert to_host(ns["same"]) == True;
    assert vm_str(ns, "nm") == "Replacement";
}

test "raising decorator propagates and leaves the name unbound" {
    ns = vm_exec(
        "def boom(c):\n"
        "    raise ValueError('nope')\n"
        "\n"
        "try:\n"
        "    @boom\n"
        "    class C:\n"
        "        pass\n"
        "except ValueError as e:\n"
        "    msg = str(e)\n"
        "\n"
        "try:\n"
        "    C\n"
        "    bound = True\n"
        "except NameError:\n"
        "    bound = False\n"
    );
    assert vm_str(ns, "msg") == "nope";
    assert to_host(ns["bound"]) == False;
}
