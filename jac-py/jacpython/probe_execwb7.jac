import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\n\n# w1: exec INSIDE function, distinct names\ndef w1():\n    c1 = 'def f(x):\\n    (a,b,c) = x\\n    return c'\n    exec(c1, ns)\nw1()\ntry:\n    print('W1:', ns['f']([1,2,3]))\nexcept BaseException as e:\n    print('W1 FAIL:', type(e).__name__, e)\n\n# w2: exec INSIDE function, duplicate names\ndef w2():\n    c2 = 'def g(x):\\n    (y,y,y) = x\\n    return y'\n    exec(c2, ns)\nw2()\ntry:\n    print('W2:', ns['g']([1,2,3]))\nexcept BaseException as e:\n    print('W2 FAIL:', type(e).__name__, e)\n\n# w3: exec at MODULE level, duplicate names\nexec('def h(x):\\n    (y,y,y) = x\\n    return y', ns)\ntry:\n    print('W3:', ns['h']([1,2,3]))\nexcept BaseException as e:\n    print('W3 FAIL:', type(e).__name__, e)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
