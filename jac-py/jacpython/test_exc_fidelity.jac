# Exception-subsystem fidelity regression pins (items 29/F3, 32/37, 39, 73).
#
# Each fixture executes Python source on jacpython's ceval via host-compiled
# marshal and asserts CPython-oracle outcomes: implicit __context__ chaining,
# chained-raise args fidelity, BaseException attribute reassignment, user-
# exception-subclass args/str surface, post-catch control flow, traceback
# objects, and exception-attribute write enforcement.

import from objects { PyObj, PyStr, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<exc_fidelity>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    # to_host yields real host values (bool/list/tuple/str); str() normalizes
    # them all to the same text CPython would print.
    return str(to_host(ns[name]));
}

test "implicit __context__ chains raise-inside-except (builtin types)" {
    ns = vm_exec(
        "try:\n"
        "    try:\n"
        "        raise ValueError('inner')\n"
        "    except ValueError:\n"
        "        raise TypeError('outer')\n"
        "except TypeError as e:\n"
        "    ctx = e.__context__\n"
        "    rctx = repr(ctx)\n"
    );
    assert vm_str(ns, "rctx") == "ValueError('inner')";
    assert vm_str(ns, "ctx") == "inner";
}

test "implicit __context__ chains through user exception subclasses" {
    ns = vm_exec(
        "class MyErr(Exception):\n"
        "    pass\n"
        "try:\n"
        "    try:\n"
        "        raise MyErr('inner')\n"
        "    except MyErr:\n"
        "        raise TypeError('outer')\n"
        "except TypeError as e:\n"
        "    ctx = e.__context__\n"
        "    rctx = repr(ctx)\n"
    );
    assert vm_str(ns, "rctx") == "MyErr('inner')";
}

test "chained-raise __cause__ keeps full args (host-proxied builtin)" {
    # OSError is not a natively-mirrored exception type: raising it crosses the
    # host boundary, which used to collapse args to a single message string.
    ns = vm_exec(
        "try:\n"
        "    try:\n"
        "        raise OSError('o')\n"
        "    except OSError as inner:\n"
        "        raise TypeError('t') from inner\n"
        "except TypeError as e:\n"
        "    cause = e.__cause__\n"
        "    rcause = repr(cause)\n"
    );
    assert vm_str(ns, "rcause") == "OSError('o')";
}

test "chained-raise context keeps multi-arg tuples" {
    ns = vm_exec(
        "try:\n"
        "    try:\n"
        "        raise OSError('oo', 2)\n"
        "    except OSError:\n"
        "        raise TypeError('t')\n"
        "except TypeError as e:\n"
        "    ctx = e.__context__\n"
        "    rctx = repr(ctx)\n"
    );
    assert vm_str(ns, "rctx") == "OSError('oo', 2)";
}

test "BaseException attribute reassignment lands" {
    ns = vm_exec("e = ValueError('x')\ne.args = ('y',)\nsaved = e.args\n");
    assert vm_str(ns, "saved") == "('y',)";
}

test "user exception subclass records constructor args at new time" {
    # A custom __init__ that never calls super().__init__ still leaves
    # e.args == constructor args (CPython BaseException_new semantics).
    ns = vm_exec(
        "class MyErr(Exception):\n"
        "    def __init__(self, a=None, b=None):\n"
        "        pass\n"
        "e = MyErr(1, 2)\n"
        "a = e.args\n"
        "s = str(e)\n"
        "r = repr(e)\n"
    );
    assert vm_str(ns, "a") == "(1, 2)";
    assert vm_str(ns, "s") == "(1, 2)";
    assert vm_str(ns, "r") == "MyErr(1, 2)";
}

test "user exception subclass str/repr survive a raise round-trip" {
    # The inherited BaseException slots must hold both pre-raise (unraised
    # PyUserObj) and post-raise (wrapped view) -- the raise path used to be
    # the only wiring for the str/repr machinery.
    ns = vm_exec(
        "class MyErr(Exception):\n"
        "    def __init__(self, a=None, b=None):\n"
        "        pass\n"
        "pre_s = str(MyErr(1, 2))\n"
        "try:\n"
        "    raise MyErr(3, 4)\n"
        "except MyErr as e:\n"
        "    post_s = str(e)\n"
        "    post_r = repr(e)\n"
    );
    assert vm_str(ns, "pre_s") == "(1, 2)";
    assert vm_str(ns, "post_s") == "(3, 4)";
    assert vm_str(ns, "post_r") == "MyErr(3, 4)";
}

test "user KeyError subclass inherits the repr-of-payload str form" {
    ns = vm_exec(
        "class MyKeyErr(KeyError):\n"
        "    pass\n"
        "e = MyKeyErr('k')\n"
        "pre_s = str(e)\n"
        "pre_r = repr(e)\n"
        "try:\n"
        "    raise MyKeyErr('j')\n"
        "except KeyError as exc:\n"
        "    post_s = str(exc)\n"
    );
    assert vm_str(ns, "pre_s") == "'k'";
    assert vm_str(ns, "pre_r") == "MyKeyErr('k')";
    assert vm_str(ns, "post_s") == "'j'";
}

test "user exception subclass explicit __str__ override wins over base slot" {
    ns = vm_exec(
        "class MyErr(Exception):\n"
        "    def __str__(self):\n"
        "        return 'custom'\n"
        "e = MyErr(1, 2)\n"
        "pre_s = str(e)\n"
        "r = repr(e)\n"
        "try:\n"
        "    raise MyErr(5, 6)\n"
        "except MyErr as exc:\n"
        "    post_s = str(exc)\n"
    );
    assert vm_str(ns, "pre_s") == "custom";
    assert vm_str(ns, "r") == "MyErr(1, 2)";
    assert vm_str(ns, "post_s") == "custom";
}

test "caught user exception exposes args and class name" {
    ns = vm_exec(
        "class MyErr(Exception):\n"
        "    pass\n"
        "try:\n"
        "    raise MyErr('m')\n"
        "except MyErr as e:\n"
        "    sargs = str(e.args)\n"
        "    cname = e.__class__.__name__\n"
    );
    assert vm_str(ns, "sargs") == "('m',)";
    assert vm_str(ns, "cname") == "MyErr";
}

test "return value survives catching a user exception subclass" {
    ns = vm_exec(
        "class SubCls(Exception):\n"
        "    pass\n"
        "def f():\n"
        "    try:\n"
        "        raise SubCls('boom')\n"
        "    except SubCls:\n"
        "        pass\n"
        "    return 42\n"
        "fret = f()\n"
    );
    assert vm_str(ns, "fret") == "42";
}

test "__traceback__ is a real chain headed at the catching frame" {
    ns = vm_exec(
        "def g():\n"
        "    raise ValueError('x')\n"
        "def f():\n"
        "    g()\n"
        "try:\n"
        "    f()\n"
        "except ValueError as e:\n"
        "    tb = e.__traceback__\n"
        "    fname = tb.tb_frame.f_code.co_filename\n"
        "names = []\n"
        "t = tb\n"
        "while t is not None:\n"
        "    names.append((t.tb_frame.f_code.co_name, t.tb_lineno))\n"
        "    t = t.tb_next\n"
    );
    assert vm_str(ns, "names") == "[('<module>', 6), ('f', 4), ('g', 2)]";
    assert vm_str(ns, "fname") == "<exc_fidelity>";
}

test "same-frame catch yields a single traceback entry at the raise line" {
    ns = vm_exec(
        "try:\n"
        "    raise RuntimeError('r')\n"
        "except RuntimeError as e:\n"
        "    tb2 = e.__traceback__\n"
        "info = (tb2.tb_lineno, tb2.tb_next is None)\n"
    );
    assert vm_str(ns, "info") == "(2, True)";
}

test "exception-attribute writes enforce CPython types" {
    ns = vm_exec(
        "msgs = []\n"
        "for attr in ('__cause__', '__context__', '__traceback__', "
        "'__suppress_context__'):\n"
        "    try:\n"
        "        setattr(ValueError('v'), attr, 5)\n"
        "        msgs.append('ok')\n"
        "    except TypeError as te:\n"
        "        msgs.append(str(te))\n"
    );
    assert vm_str(ns, "msgs") == (
        "['exception cause must be None or derive from BaseException', "
        "'exception context must be None or derive from BaseException', "
        "'__traceback__ must be a traceback or None', "
        "'attribute value type must be bool']"
    );
}

test "setting __cause__ implies __suppress_context__" {
    ns = vm_exec(
        "y = ValueError('a')\n"
        "z = KeyError('b')\n"
        "y.__cause__ = z\n"
        "sup = y.__suppress_context__\n"
    );
    assert vm_str(ns, "sup") == "True";
}

test "user exception subclass super().__init__ stores args" {
    # Exception is not a boxed-layout native base, so super resolution serves
    # BaseException's own slots directly over the live instance: super().
    # __init__(a, b) replaces args exactly like CPython BaseException_init.
    ns = vm_exec(
        "class MyErr(Exception):\n"
        "    def __init__(self, a=None, b=None):\n"
        "        super().__init__(a, b)\n"
        "e = MyErr(1, 2)\n"
        "a1 = e.args\n"
        "s1 = str(e)\n"
        "r1 = repr(e)\n"
        "try:\n"
        "    raise MyErr(7, 8)\n"
        "except MyErr as e2:\n"
        "    a2 = e2.args\n"
        "    s2 = str(e2)\n"
    );
    assert vm_str(ns, "a1") == "(1, 2)";
    assert vm_str(ns, "s1") == "(1, 2)";
    assert vm_str(ns, "r1") == "MyErr(1, 2)";
    assert vm_str(ns, "a2") == "(7, 8)";
    assert vm_str(ns, "s2") == "(7, 8)";
}

test "chain attribute __class__ synthesis (cause/context/traceback/None)" {
    # object.__class__ NEVER raises AttributeError in CPython: every value
    # served by the exception attribute surface must resolve it -- set chain
    # entries to their concrete type, unset ones (None) to NoneType, and
    # tracebacks to 'traceback'. Unset e.__cause__/e.__context__ used to
    # raise through PyNoneType's missing tp_getattro arm.
    ns = vm_exec(
        "names = []\n"
        "try:\n"
        "    try:\n"
        "        raise ValueError('inner')\n"
        "    except ValueError:\n"
        "        raise TypeError('outer')\n"
        "except TypeError as e:\n"
        "    names.append(e.__context__.__class__.__name__)\n"
        "    names.append(e.__cause__.__class__.__name__)\n"
        "    names.append(e.__traceback__.__class__.__name__)\n"
        "    names.append(e.args.__class__.__name__)\n"
        "    names.append(e.__suppress_context__.__class__.__name__)\n"
        "    names.append(None.__class__.__name__)\n"
    );
    assert vm_str(ns, "names") == (
        "['ValueError', 'NoneType', 'traceback', 'tuple', 'bool', 'NoneType']"
    );
}
