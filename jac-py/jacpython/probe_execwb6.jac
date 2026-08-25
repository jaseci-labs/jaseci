import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\ndef mk(n):\n    code = 'def f(x):\\n    ' + '(' + 'y,' * n + ') = x\\n    return y'\n    exec(code, ns)\n    return ns['f']\n\nfor n in (5, 50, 200, 250, 255, 256, 257, 300, 400):\n    f = mk(n)\n    try:\n        r = f(range(n))\n        print(n, 'OK', r == n - 1)\n    except BaseException as e:\n        print(n, 'FAIL', type(e).__name__, e)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
