import from product_compile { compile_source }
import from pyc_first { exec_code }
import from objects { PyObj, PyStr, PyCode, PyError, is_error }
import builtins;

def _run(src: str) -> str {
    co = compile_source(src, "<min4>", "exec", 0);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    out = exec_code(co as PyCode, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    v = ns.get("r");
    if isinstance(v, PyStr) {
        return (v as PyStr).val;
    }
    return "ok";
}

glob V = {};

test "m4" {
    f = builtins.open("/var/tmp/min4.txt", "w");
    builtins.print("Q1 bound-handler-while:", _run(
        "w = []\n"
        "try:\n"
        "    raise ValueError('d')\n"
        "except ValueError as e:\n"
        "    n = 0\n"
        "    while n < 2:\n"
        "        w.append(n)\n"
        "        n = n + 1\n"
        "r = 'len' + str(len(w))\n"), file=f);
    builtins.print("Q2 unbound-handler-while:", _run(
        "w = []\n"
        "try:\n"
        "    raise ValueError('d')\n"
        "except ValueError:\n"
        "    n = 0\n"
        "    while n < 2:\n"
        "        w.append(n)\n"
        "        n = n + 1\n"
        "r = 'len' + str(len(w))\n"), file=f);
    builtins.print("Q3 while-in-try-body:", _run(
        "w = []\n"
        "try:\n"
        "    n = 0\n"
        "    while n < 2:\n"
        "        w.append(n)\n"
        "        n = n + 1\n"
        "except ValueError:\n"
        "    pass\n"
        "r = 'len' + str(len(w))\n"), file=f);
    f.close();
    assert false;
}
test "q1 bound" {
    f = builtins.open("/var/tmp/min4_q1.txt", "w");
    builtins.print("R:", _run(
        "w = []\n"
        "try:\n"
        "    raise ValueError('d')\n"
        "except ValueError as e:\n"
        "    n = 0\n"
        "    while n < 2:\n"
        "        w.append(n)\n"
        "        n = n + 1\n"
        "r = 'len' + str(len(w))\n"), file=f);
    f.close();
    assert false;
}

test "q2 unbound" {
    f2 = builtins.open("/var/tmp/min4_q2.txt", "w");
    builtins.print("R:", _run(
        "w = []\n"
        "try:\n"
        "    raise ValueError('d')\n"
        "except ValueError:\n"
        "    n = 0\n"
        "    while n < 2:\n"
        "        w.append(n)\n"
        "        n = n + 1\n"
        "r = 'len' + str(len(w))\n"), file=f2);
    f2.close();
    assert false;
}

test "q3 trybody" {
    f3 = builtins.open("/var/tmp/min4_q3.txt", "w");
    builtins.print("R:", _run(
        "w = []\n"
        "try:\n"
        "    n = 0\n"
        "    while n < 2:\n"
        "        w.append(n)\n"
        "        n = n + 1\n"
        "except ValueError:\n"
        "    pass\n"
        "r = 'len' + str(len(w))\n"), file=f3);
    f3.close();
    assert false;
}
