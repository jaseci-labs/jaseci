# Generator/coroutine semantics regression pins (audit items 2, 3, 5, 6, 7, 8).
#
# Each fixture executes Python source on jacpython's ceval via host-compiled
# marshal and asserts CPython-oracle outcomes (probed against python3.14):
#   2. gen.throw() converts a caught-and-return generator into
#      StopIteration(return_value); full throw(a[, b[, c]]) argument forms.
#   3. Resuming a finished coroutine raises RuntimeError
#      "cannot reuse already awaited coroutine" (send/throw/re-await).
#   5. await rejects plain generators unless marked CO_ITERABLE_COROUTINE by
#      types.coroutine (native fast path).
#   6. send()/close() arity + keyword rejection with exact CPython messages.
#   7. Exception state survives a yield inside an except block: bare raise
#      re-raises the handled exception, immune to intervening handler noise.
#   8. gi_yieldfrom / __name__ / __qualname__ getters and string-checked
#      setters on generator objects.
import from objects { PyObj, PyStr, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<probe>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

test "item2: throw caught then return" {
    ns = vm_exec(
        "def g():\n"
        "    try:\n"
        "        yield 1\n"
        "    except ValueError:\n"
        "        return 'ret'\n"
        "it = g()\n"
        "next(it)\n"
        "try:\n"
        "    it.throw(ValueError())\n"
        "except StopIteration as e:\n"
        "    r = 'SI:' + repr(e.value)\n"
        "except Exception as e:\n"
        "    r = type(e).__name__\n"
    );
    assert "r" in ns;
    assert vm_str(ns, "r") == "SI:'ret'", vm_str(ns, "r");
}

test "item2b: throw forms" {
    ns = vm_exec(
        "def g():\n"
        "    try:\n"
        "        yield 1\n"
        "    except ValueError as e:\n"
        "        yield str(e)\n"
        "outs = []\n"
        "a = g(); next(a)\n"
        "try:\n"
        "    a.throw()\n"
        "except TypeError as e:\n"
        "    outs.append(str(e))\n"
        "b = g(); next(b)\n"
        "try:\n"
        "    v = b.throw(ValueError('m'))\n"
        "    outs.append('returned ' + repr(v))\n"
        "    try:\n"
        "        next(b)\n"
        "        outs.append('no SI')\n"
        "    except StopIteration:\n"
        "        outs.append('SI after')\n"
        "except Exception as e:\n"
        "    outs.append(type(e).__name__ + ': ' + str(e))\n"
        "c = g(); next(c)\n"
        "try:\n"
        "    v = c.throw(ValueError, 'msg')\n"
        "    outs.append('returned ' + repr(v))\n"
        "except Exception as e:\n"
        "    outs.append(type(e).__name__ + ': ' + str(e))\n"
        "d = g()\n"
        "try:\n"
        "    d.throw(5)\n"
        "except TypeError as e:\n"
        "    outs.append(str(e))\n"
        "e2 = g(); next(e2)\n"
        "try:\n"
        "    e2.throw(ValueError(), 'sep')\n"
        "except TypeError as e:\n"
        "    outs.append(str(e))\n"
        "r = '; '.join(outs)\n"
    );
    expect = (
        "throw expected at least 1 argument, got 0; "
        "returned 'm'; SI after; "
        "returned 'msg'; "
        "exceptions must be classes or instances deriving from BaseException, not int; "
        "instance exception may not have a separate value"
    );
    assert vm_str(ns, "r") == expect, vm_str(ns, "r");
}

test "item3: coroutine reuse" {
    ns = vm_exec(
        "async def c():\n"
        "    return 42\n"
        "co = c()\n"
        "try:\n"
        "    co.send(None)\n"
        "except StopIteration:\n"
        "    pass\n"
        "try:\n"
        "    co.send(None)\n"
        "    r = 'NO ERROR'\n"
        "except RuntimeError as e:\n"
        "    r = 'RE:' + str(e)\n"
        "co2 = c()\n"
        "try:\n"
        "    co2.send(None)\n"
        "except StopIteration:\n"
        "    pass\n"
        "co2.close()\n"
        "try:\n"
        "    co2.throw(ValueError())\n"
        "    r2 = 'NO ERROR'\n"
        "except RuntimeError as e:\n"
        "    r2 = 'RE:' + str(e)\n"
        "async def wait_on(x):\n"
        "    try:\n"
        "        await x\n"
        "    except RuntimeError as e:\n"
        "        return 'await RE:' + str(e)\n"
        "co3 = c()\n"
        "w = wait_on(co3)\n"
        "try:\n"
        "    w.send(None)\n"
        "except StopIteration:\n"
        "    pass\n"
        "try:\n"
        "    w.send(None)\n"
        "    r3 = 'NO ERROR'\n"
        "except RuntimeError as e:\n"
        "    r3 = 'outer RE:' + str(e)\n"
    );
    assert vm_str(ns, "r") == "RE:cannot reuse already awaited coroutine", vm_str(ns, "r");
    assert vm_str(ns, "r2") == "RE:cannot reuse already awaited coroutine", vm_str(ns, "r2");
    assert vm_str(ns, "r3") == "outer RE:cannot reuse already awaited coroutine", vm_str(ns, "r3");
}

test "item5: await plain generator rejected; marked one accepted" {
    ns = vm_exec(
        "import types\n"
        "async def main():\n"
        "    def g():\n"
        "        yield 1\n"
        "    got = []\n"
        "    try:\n"
        "        await g()\n"
        "        got.append('NO ERROR')\n"
        "    except TypeError as e:\n"
        "        got.append('TE:' + str(e))\n"
        "    @types.coroutine\n"
        "    def ic():\n"
        "        got.append(str((yield 7)))\n"
        "    outer_got = await ic()\n"
        "    got.append('sent=' + repr(outer_got))\n"
        "    return '; '.join(got)\n"
        "co = main()\n"
        "step1 = co.send(None)\n"
        "try:\n"
        "    co.send(99)\n"
        "except StopIteration as e:\n"
        "    r = str(step1) + '|' + e.value\n"
    );
    assert vm_str(ns, "r") == "7|TE:'generator' object can't be awaited; 99; sent=None", vm_str(ns, "r");
}

test "item6: send/close arity + kwargs" {
    ns = vm_exec(
        "def g():\n"
        "    yield 1\n"
        "outs = []\n"
        "a = g(); next(a)\n"
        "try:\n"
        "    a.send()\n"
        "except TypeError as e:\n"
        "    outs.append(str(e))\n"
        "b = g(); next(b)\n"
        "try:\n"
        "    b.send(1, 2)\n"
        "except TypeError as e:\n"
        "    outs.append(str(e))\n"
        "c = g(); next(c)\n"
        "try:\n"
        "    c.close(1)\n"
        "except TypeError as e:\n"
        "    outs.append(str(e))\n"
        "d = g(); next(d)\n"
        "try:\n"
        "    d.send(1, v=2)\n"
        "except TypeError as e:\n"
        "    outs.append(str(e))\n"
        "e2 = g(); next(e2)\n"
        "e2.close(1) if False else None\n"
        "try:\n"
        "    e2.close(x=1)\n"
        "except TypeError as e:\n"
        "    outs.append(str(e))\n"
        "r = '; '.join(outs)\n"
    );
    expect = (
        "generator.send() takes exactly one argument (0 given); "
        "generator.send() takes exactly one argument (2 given); "
        "generator.close() takes no arguments (1 given); "
        "generator.send() takes no keyword arguments; "
        "generator.close() takes no keyword arguments"
    );
    assert vm_str(ns, "r") == expect, vm_str(ns, "r");
}

test "item7: bare raise across yield w/ noise exc" {
    ns = vm_exec(
        "def g():\n"
        "    try:\n"
        "        yield 1\n"
        "    except KeyError:\n"
        "        yield 2\n"
        "        raise\n"
        "it = g()\n"
        "next(it)\n"
        "v = it.throw(KeyError())\n"
        "try:\n"
        "    raise ValueError('noise')\n"
        "except ValueError:\n"
        "    pass\n"
        "try:\n"
        "    next(it)\n"
        "    r = 'no error'\n"
        "except KeyError:\n"
        "    r = 'KeyError re-raised'\n"
        "except BaseException as e:\n"
        "    r = 'WRONG: ' + type(e).__name__ + ' ' + str(e)\n"
    );
    assert vm_str(ns, "v") == "2", vm_str(ns, "v");
    assert vm_str(ns, "r") == "KeyError re-raised", vm_str(ns, "r");
}

test "item8: gi_yieldfrom + names + setters" {
    ns = vm_exec(
        "def inner():\n"
        "    yield 1\n"
        "def outer():\n"
        "    yield from inner()\n"
        "o = outer()\n"
        "next(o)\n"
        "yf = o.gi_yieldfrom.__name__ if o.gi_yieldfrom is not None else 'None'\n"
        "o2 = outer()\n"
        "yf0 = o2.gi_yieldfrom.__name__ if o2.gi_yieldfrom is not None else 'None'\n"
        "nm = o.__name__\n"
        "qn = o.__qualname__\n"
        "o.__name__ = 'renamed'\n"
        "nm2 = o.__name__\n"
        "o.__qualname__ = 'ns.outer'\n"
        "qn2 = o.__qualname__\n"
        "errs = []\n"
        "try:\n"
        "    o.__qualname__ = 5\n"
        "except TypeError as e:\n"
        "    errs.append(str(e))\n"
        "try:\n"
        "    o.no_such_attr\n"
        "except AttributeError:\n"
        "    errs.append('AttributeError')\n"
        "errstr = '; '.join(errs)\n"
    );
    got = vm_str(ns, "yf") + "|" + vm_str(ns, "yf0") + "|" + vm_str(ns, "nm")
        + "|" + vm_str(ns, "qn") + "|" + vm_str(ns, "nm2") + "|" + vm_str(ns, "qn2")
        + "|" + vm_str(ns, "errstr");
    expect = "inner|None|outer|outer|renamed|ns.outer|"
        "__qualname__ must be set to a string object; AttributeError";
    assert got == expect, got;
}
