import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\nexec('def f(x):\\n    (a,b,c) = x\\n    return c', ns)\nprint('A:', ns['f']([1,2,3]))\nexec('def g(x):\\n    return len(x)', ns)\nprint('B:', ns['g']([1,2,3]))\nexec('def h(n):\\n    return n + 1', ns)\nprint('C:', ns['h'](5))\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
