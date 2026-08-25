import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    snip = "def _t():\n    target = '(' + 'y,' * 400 + ')'\n    code = f'def unpack_400(x):\\n            {target} = x\\n            return y\\n        '\n    ns = {}\n    exec(code, ns)\n    unpack_400 = ns['unpack_400']\n    for _ in range(30):\n        y = unpack_400(range(400))\n        assert y == 399, ('assertEqual', y, 399)\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n";
    co = unmarshal(host_compile_marshal(snip));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
