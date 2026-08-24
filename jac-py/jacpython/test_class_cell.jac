# __class__ cell / zero-arg super() end-to-end pins (native compiler + ceval).
#
# Exercises the full product path (compile_source -> exec_code) for the
# CPython 3.14 class-closure protocol:
#   - symtable: a `super` load in a function-like scope marks __class__ as a
#     use; drop_class_free turns it into the class body's implicit cellvar.
#   - codegen: implicit MAKE_CELL prologue, LOAD_GLOBAL super / LOAD_DEREF
#     __class__ / LOAD_FAST self / LOAD_SUPER_ATTR sequence, and the epilogue
#     returning __classcell__ to py_build_class.
#   - runtime: py_build_class seeds the returned cell so zero-arg super()
#     resolves the defining class; bare super() in a class BODY raises
#     RuntimeError("super(): no arguments") like host CPython.
import from objects { PyObj, PyCode, PyError, is_error }
import from product_compile { compile_source }
import from pyc_first { exec_code, to_host }


def run_src(src: str) -> str {
    # Native compile + VM execute; repr of module global `r`, or
    # "Type: message" when the VM raised (mirrors test_class_scope._run).
    co = compile_source(src, "<classcell>", "exec", 0);
    if is_error(co) {
        e = co as PyError;
        return "CompileError: " + str(e.exception.message);
    }
    ns: dict[str, PyObj] = {};
    outcome = exec_code(co as PyCode, [], ns);
    if is_error(outcome) {
        e2 = outcome as PyError;
        return str(e2.exception.type_name) + ": " + str(e2.exception.message);
    }
    if "r" in ns {
        return repr(to_host(ns["r"]));
    }
    return "";
}

test "class cell: zero-arg super() single inheritance" {
    assert run_src(
        "class A:\n"
        + "    def who(self):\n"
        + "        return 'A'\n"
        + "class B(A):\n"
        + "    def who(self):\n"
        + "        return 'B+' + super().who()\n"
        + "r = B().who()\n"
    ) == "'B+A'";
}

test "class cell: zero-arg super() multi-level chain" {
    assert run_src(
        "class A:\n"
        + "    def who(self):\n"
        + "        return 'A'\n"
        + "class B(A):\n"
        + "    def who(self):\n"
        + "        return 'B+' + super().who()\n"
        + "class C(B):\n"
        + "    def who(self):\n"
        + "        return 'C+' + super().who()\n"
        + "r = C().who()\n"
    ) == "'C+B+A'";
}

test "class cell: two-arg super(Cls, self) still works" {
    assert run_src(
        "class A:\n"
        + "    def who(self):\n"
        + "        return 'A'\n"
        + "class H(A):\n"
        + "    def who(self):\n"
        + "        return 'H+' + super(H, self).who()\n"
        + "r = H().who()\n"
    ) == "'H+A'";
}

test "class cell: bare super() in class body raises like CPython" {
    # Host: RuntimeError("super(): no arguments"); no __class__ cell exists.
    assert run_src(
        "r = ''\n"
        + "try:\n"
        + "    class D:\n"
        + "        x = super()\n"
        + "except RuntimeError as e:\n"
        + "    r = 'RuntimeError: ' + str(e)\n"
    ) == "'RuntimeError: super(): no arguments'";
}

test "class cell: direct __class__ deref inside a method" {
    assert run_src(
        "class G:\n"
        + "    def m(self):\n"
        + "        return __class__.__name__\n"
        + "r = G().m()\n"
    ) == "'G'";
}

test "class cell: __classcell__ never leaks into the class namespace" {
    # type.__new__ pops __classcell__; the attribute must not exist on the class.
    assert run_src(
        "r = ''\n"
        + "class A:\n"
        + "    def m(self):\n"
        + "        return 1\n"
        + "try:\n"
        + "    A.__classcell__\n"
        + "except AttributeError:\n"
        + "    r = 'AttributeError'\n"
    ) == "'AttributeError'";
}
