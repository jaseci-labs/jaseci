import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\ndef mk(n):\n    code = 'def f(x):\\n    ' + '(' + 'y,' * n + ') = x\\n    return y'\n    return code\nprint(repr(mk(5)))\ncode5 = mk(5)\nexec(code5, ns)\ntry:\n    print('R:', ns['f'](range(5)))\nexcept BaseException as e:\n    print('RF:', type(e).__name__, e)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
