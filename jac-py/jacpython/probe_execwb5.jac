import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "ns = {}\n\n# v1: small direct\ndef _mk(code):\n    exec(code, ns)\n\nv1_code = 'def f1(x):\\n    (a,b,c) = x\\n    return c'\n_mk(v1_code)\nprint('V1:', ns['f1']([1,2,3]))\n\n# v2: f-string built code, small\ntarget2 = '(a,b,c)'\nv2_code = f'def f2(x):\\n    {target2} = x\\n    return c'\n_mk(v2_code)\nprint('V2:', ns['f2']([1,2,3]))\n\n# v3: 400-target via string mult, direct write (no f-string)\ntarget3 = '(' + 'y,' * 400 + ')'\nv3_code = 'def f3(x):\\n    ' + target3 + ' = x\\n    return y'\n_mk(v3_code)\nprint('V3:', ns['f3'](range(400)))\n\n# v4: f-string version of v3\nv4_code = f'def f4(x):\\n    {target3} = x\\n    return y'\n_mk(v4_code)\nprint('V4:', ns['f4'](range(400)))\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
