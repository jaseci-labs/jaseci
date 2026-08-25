import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\ntests = [\n    ('T1', 'def f(x):\\n    (y,) = x\\n    return y'),\n    ('T2', 'def f(x):\\n    (y,y,y) = x\\n    return y'),\n    ('T3', 'def f(x):\\n    (y,y,y,) = x\\n    return y'),\n    ('T4', 'def f(x):\\n    (a,b,c,) = x\\n    return c'),\n]\nfor tag, code in tests:\n    try:\n        exec(code, ns)\n        r = ns['f'](range(3))\n        print(tag, 'OK', r)\n    except BaseException as e:\n        print(tag, 'FAIL', type(e).__name__, e)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
