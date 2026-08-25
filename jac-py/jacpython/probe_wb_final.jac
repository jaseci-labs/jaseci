import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\n\ndef f1(x):\n    print('f1 sees:', type(x).__name__, len(list(x)))\n    (y,) = x\n    return y\n\nns['f1'] = f1\ncode1 = 'def f1(x):\\n    print(\"f1e sees:\", type(x).__name__, len(list(x)))\\n    (y,) = x\\n    return y'\nexec(code1, ns)\ntry:\n    r = ns['f1'](range(3))\n    print('T1:', r)\nexcept BaseException as e:\n    print('T1 FAIL:', type(e).__name__, e)\n\n# variant: identical shape but WITHOUT the prior native f1 definition\nns2 = {}\ncode2 = 'def f1(x):\\n    (y,) = x\\n    return y'\nexec(code2, ns2)\ntry:\n    r2 = ns2['f1'](range(3))\n    print('T2:', r2)\nexcept BaseException as e:\n    print('T2 FAIL:', type(e).__name__, e)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
