import from layer_p2_libtest { p2_libtest_run_snippet }

with entry {
    snip = "def _t():\n    target = '(' + 'y,' * 400 + ')'\n    code = f'def unpack_400(x):\\n            {target} = x\\n            return y\\n        '\n    ns = {}\n    exec(code, ns)\n    unpack_400 = ns['unpack_400']\n    for _ in range(30):\n        y = unpack_400(range(400))\n        assert y == 399, ('assertEqual', y, 399)\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n";
    (ok, detail) = p2_libtest_run_snippet(snip);
    print('PIN1:', ok, detail);
}
