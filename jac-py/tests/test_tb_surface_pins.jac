# Traceback / sys.exc_info surface oracle pins.
# Each snippet is plain Python run on the guest ceval via
# layer_p2_libtest.p2_libtest_run_snippet; every snippet was verified
# against host CPython 3.14.7 before pinning.
import from layer_p2_libtest { p2_libtest_run_snippet }

test "exc_info_inside_handler" {
    (ok, detail) = p2_libtest_run_snippet("import sys\ndef _t():\n    try:\n        raise ValueError('boom')\n    except ValueError:\n        t, v, tb = sys.exc_info()\n        assert t.__name__ == 'ValueError', ('name', t.__name__)\n        assert v.args == ('boom',), ('assertEqual', v.args)\n        assert tb is not None, 'tb non-null'\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "exc_info_cleared_after_handler" {
    (ok, detail) = p2_libtest_run_snippet("import sys\ndef _t():\n    try:\n        raise ValueError('boom')\n    except ValueError:\n        pass\n    t, v, tb = sys.exc_info()\n    assert t is None, ('assertIsNone', t)\n    assert v is None, ('assertIsNone', v)\n    assert tb is None, ('assertIsNone', tb)\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "nested_handlers_restore_outer" {
    (ok, detail) = p2_libtest_run_snippet("import sys\ndef _t():\n    try:\n        raise ValueError('outer')\n    except ValueError as e1:\n        try:\n            raise KeyError('inner')\n        except KeyError:\n            t2 = sys.exc_info()[0]\n            v2 = sys.exc_info()[1]\n            assert t2.__name__ == 'KeyError', ('name', t2.__name__)\n            assert v2.args == ('inner',), ('assertEqual', v2.args)\n        t1 = sys.exc_info()[0]\n        assert t1.__name__ == 'ValueError', ('name', t1.__name__)\n        assert sys.exc_info()[1] is e1, 'outer exc identity restored'\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "format_exc_type_msg_frames" {
    (ok, detail) = p2_libtest_run_snippet("import traceback\ndef _inner():\n    raise RuntimeError('kaput')\ndef _mid():\n    _inner()\ndef _t():\n    try:\n        _mid()\n    except RuntimeError:\n        s = traceback.format_exc()\n        assert 'RuntimeError' in s, repr(s)\n        assert 'kaput' in s, repr(s)\n        assert '_inner' in s, repr(s)\n        assert '_mid' in s, repr(s)\n        assert '_t' in s, repr(s)\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "format_exc_outside_handler_none" {
    (ok, detail) = p2_libtest_run_snippet("import traceback\ndef _t():\n    s = traceback.format_exc()\n    assert 'NoneType: None' in s, repr(s)\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "extract_tb_names_and_linenos" {
    (ok, detail) = p2_libtest_run_snippet("import sys\nimport traceback\ndef _lvl3():\n    x = 1\n    raise ValueError('deep')\ndef _lvl2():\n    _lvl3()\ndef _lvl1():\n    _lvl2()\ndef _t():\n    try:\n        _lvl1()\n    except ValueError:\n        tb = sys.exc_info()[2]\n        fs = traceback.extract_tb(tb)\n        assert [f.name for f in fs] == ['_t', '_lvl1', '_lvl2', '_lvl3'], [f.name for f in fs]\n        assert all(f.lineno > 0 for f in fs), [f.lineno for f in fs]\n        assert fs[3].lineno == _lvl3.__code__.co_firstlineno + 2, fs[3].lineno\n        assert fs[1].lineno == _lvl1.__code__.co_firstlineno + 1, fs[1].lineno\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "format_tb_structure_per_frame" {
    (ok, detail) = p2_libtest_run_snippet("import sys\nimport traceback\ndef _lvl3():\n    raise ValueError('deep')\ndef _lvl2():\n    _lvl3()\ndef _lvl1():\n    _lvl2()\ndef _t():\n    try:\n        _lvl1()\n    except ValueError:\n        tb = sys.exc_info()[2]\n        s = ''.join(traceback.format_tb(tb))\n        parts = traceback.format_tb(tb)\n        assert isinstance(parts, list) and len(parts) == 4, len(parts)\n        assert all(isinstance(p, str) and p.endswith('\\n') for p in parts), parts\n        assert s.count('  File ') == 4, repr(s)\n        assert ', line ' in s, repr(s)\n        for nm in ['in _t', 'in _lvl1', 'in _lvl2', 'in _lvl3']:\n            assert nm in s, (nm, repr(s))\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "walk_tb_frame_count" {
    (ok, detail) = p2_libtest_run_snippet("import sys\nimport traceback\ndef _lvl3():\n    raise ValueError('deep')\ndef _lvl2():\n    _lvl3()\ndef _lvl1():\n    _lvl2()\ndef _t():\n    try:\n        _lvl1()\n    except ValueError:\n        tb = sys.exc_info()[2]\n        frames = list(traceback.walk_tb(tb))\n        assert len(frames) == 4, len(frames)\n        assert len(list(traceback.walk_tb(None))) == 0, 'walk_tb(None) empty'\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "format_exception_cause_chain" {
    (ok, detail) = p2_libtest_run_snippet("import sys\nimport traceback\ndef _t():\n    try:\n        try:\n            raise OSError('root cause')\n        except OSError as e:\n            raise ValueError('wrapper') from e\n    except ValueError:\n        exc = sys.exc_info()[1]\n        out = ''.join(traceback.format_exception(exc))\n        assert 'OSError' in out and 'root cause' in out, repr(out)\n        assert 'ValueError' in out and 'wrapper' in out, repr(out)\n        assert 'direct cause' in out, repr(out)\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "bare_reraise_identity" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    seen = []\n    try:\n        try:\n            raise ValueError('orig')\n        except ValueError as e:\n            seen.append(e)\n            raise\n    except ValueError as e2:\n        assert e2 is seen[0], ('identity mismatch', e2, seen[0])\n        assert e2.args == ('orig',), e2.args\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "exc_info_top_level_initially_none" {
    (ok, detail) = p2_libtest_run_snippet("import sys\ndef _helper():\n    return sys.exc_info()\ndef _t():\n    t, v, tb = _helper()\n    assert t is None and v is None and tb is None, (t, v, tb)\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "exc_info_visible_in_helper_call" {
    (ok, detail) = p2_libtest_run_snippet("import sys\ndef _probe():\n    return sys.exc_info()\ndef _t():\n    try:\n        raise TypeError('tt')\n    except TypeError:\n        t, v, tb = _probe()\n        assert t.__name__ == 'TypeError', ('name', t.__name__)\n        assert v.args == ('tt',), v.args\n        assert tb is not None\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "format_exc_in_nested_handler_shows_inner" {
    (ok, detail) = p2_libtest_run_snippet("import traceback\nimport sys\ndef _t():\n    try:\n        raise ValueError('outer')\n    except ValueError as e_outer:\n        try:\n            raise KeyError('inner')\n        except KeyError:\n            s = traceback.format_exc()\n            assert 'KeyError' in s, repr(s)\n            assert \"'inner'\" in s, repr(s)\n            assert 'During handling of the above exception' in s, repr(s)\n            assert sys.exc_info()[1] is not e_outer\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "tb_next_chain_length" {
    (ok, detail) = p2_libtest_run_snippet("import sys\ndef _lvl3():\n    raise ValueError('deep')\ndef _lvl2():\n    _lvl3()\ndef _lvl1():\n    _lvl2()\ndef _t():\n    try:\n        _lvl1()\n    except ValueError:\n        tb = sys.exc_info()[2]\n        n = 0\n        cur = tb\n        while cur is not None:\n            n += 1\n            cur = cur.tb_next\n        assert n == 4, n\n        assert tb.tb_frame.f_code.co_name == '_t', tb.tb_frame.f_code.co_name\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "raise_from_sets_cause_attrs" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    try:\n        try:\n            raise OSError('root')\n        except OSError as e:\n            raise ValueError('wrap') from e\n    except ValueError as w:\n        assert isinstance(w.__cause__, OSError), w.__cause__\n        assert w.__cause__.args == ('root',), w.__cause__.args\n        assert w.__suppress_context__ is True, w.__suppress_context__\n        assert isinstance(w.__context__, OSError), w.__context__\n        assert w.__context__.args == ('root',), w.__context__.args\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "implicit_context_when_raised_in_handler" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    try:\n        try:\n            raise OSError('first')\n        except OSError:\n            raise ValueError('second')\n    except ValueError as v:\n        c = v.__context__\n        assert isinstance(c, OSError), c\n        assert v.__cause__ is None, v.__cause__\n        assert v.__context__.args == ('first',), v.__context__.args\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "bare_reraise_nested_restores_outer" {
    (ok, detail) = p2_libtest_run_snippet("import sys\ndef _t():\n    outer_exc = None\n    try:\n        raise RuntimeError('R')\n    except RuntimeError as r:\n        outer_exc = r\n        try:\n            try:\n                raise KeyError('K')\n            except KeyError:\n                raise\n        except KeyError as k2:\n            assert k2.args == ('K',), k2.args\n        assert sys.exc_info()[1] is outer_exc, 'outer restored'\n    assert sys.exc_info()[0] is None, 'cleared at end'\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "format_exception_inside_handler_matches_format_exc" {
    (ok, detail) = p2_libtest_run_snippet("import sys\nimport traceback\ndef _t():\n    try:\n        raise ZeroDivisionError('zd')\n    except ZeroDivisionError:\n        exc = sys.exc_info()[1]\n        one = ''.join(traceback.format_exception(exc))\n        two = traceback.format_exc()\n        assert one == two, (repr(one), repr(two))\n        assert 'ZeroDivisionError: zd' in one, repr(one)\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "extract_tb_last_lineno_points_at_raise" {
    (ok, detail) = p2_libtest_run_snippet("import sys\nimport traceback\ndef _raise_site():\n    raise ValueError('at-line')  # marker line\ndef _t():\n    try:\n        _raise_site()\n    except ValueError:\n        tb = sys.exc_info()[2]\n        fs = traceback.extract_tb(tb)\n        expected = _raise_site.__code__.co_firstlineno + 1\n        assert fs[-1].lineno == expected, (fs[-1].lineno, expected)\n        assert [f.name for f in fs] == ['_t', '_raise_site'], [f.name for f in fs]\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}
