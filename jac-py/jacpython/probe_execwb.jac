import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\nexec('x = 1', ns)\nprint('A:', ns.get('x') == 1)\n\ndef make():\n    code = 'def f(a):\\n    return a + 1'\n    exec(code, ns)\n\nmake()\nprint('B:', 'f' in ns)\nprint('B2:', ns['f'](41) == 42)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
