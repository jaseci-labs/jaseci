import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\ndef mk(n):\n    code = 'def f(x):\\n    ' + '(' + 'y,' * n + ') = x\\n    return y'\n    exec(code, ns)\n    return ns['f']\n\nallok = True\nfor n in (5, 50, 200, 255, 256, 257, 300, 400):\n    f = mk(n)\n    try:\n        r = f(range(n))\n        okr = r == n - 1\n        allok = allok and okr\n        if not okr:\n            print(n, 'WRONGVAL', r)\n    except BaseException as e:\n        allok = False\n        print(n, 'FAIL', type(e).__name__, e)\nprint('ALL:', allok)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
