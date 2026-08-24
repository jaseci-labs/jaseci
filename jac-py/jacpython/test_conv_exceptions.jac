# Differential replay pins converted from CPython's exception test suites
# (reference/cpython/Lib/test/test_raise.py + test_exceptions.py).
#
# Idiom: layer1 statement-shaped replay -- each method's setup runs in BOTH
# host CPython and jacpython, then every assert argument / raises-check body is
# evaluated against both namespaces and diffed. Behavioral assertions only;
# scaffolding (unittest plumbing, KeyboardInterrupt/SystemExit machinery,
# compiler-static cases) is excluded by design.
#
# Covered here: raise/reraise forms (incl. bare raise with no active
# exception), except matching incl. tuples/subclasses/non-matches,
# else/finally interplay, chaining (__context__/__cause__/__suppress_context__,
# raise-from / raise-from-None), traceback attributes reachable at runtime,
# and the PEP 479 StopIteration-in-generator -> RuntimeError conversions.
#
# Not pinned (owned elsewhere): exc-hierarchy class additions, tb RENDERING
# (note: type(tb).__name__ currently reports 'NoneType' for a native
# PyTraceback -- py_type_of has no traceback-tag branch; tb-rendering lane),
# generator-region internals beyond PEP 479.

import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

# ---------------- tests ----------------
test "conv exceptions: raise reraise forms replay against the host" {
    # test_raise.py: bare `raise` re-raises intact through nested handlers;
    # a bare `raise` with no active handler is RuntimeError (PyErr_GetReraised).
    src = "class TestRaiseForms(unittest.TestCase):\n"
    "    def test_reraise_preserves_value(self):\n"
    "        got = ''\n"
    "        try:\n"
    "            try:\n"
    "                raise ValueError('inner')\n"
    "            except ValueError:\n"
    "                raise\n"
    "        except ValueError as e:\n"
    "            got = str(e)\n"
    "        self.assertEqual(got, 'inner')\n"
    "    def test_nested_reraise_chain(self):\n"
    "        seen = []\n"
    "        try:\n"
    "            try:\n"
    "                try:\n"
    "                    raise IndexError('deep')\n"
    "                except IndexError:\n"
    "                    raise\n"
    "            except IndexError as e:\n"
    "                seen.append(str(e))\n"
    "                raise\n"
    "        except IndexError as e2:\n"
    "            seen.append('outer:' + str(e2))\n"
    "        self.assertEqual(seen, ['deep', 'outer:deep'])\n"
    "    def test_bare_raise_without_active_exception(self):\n"
    "        name = ''\n"
    "        try:\n"
    "            raise\n"
    "        except RuntimeError as e:\n"
    "            name = type(e).__name__\n"
    "        self.assertEqual(name, 'RuntimeError')\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "conv exceptions: except tuple subclass and non-match routing" {
    # test_raise.py/test_exceptions.py matching semantics: instances match via
    # the handler tuple; a non-matching type falls through to later handlers
    # exactly as CPython's exception normal form does.
    src = "class TestExceptMatch(unittest.TestCase):\n"
    "    def test_tuple_subclass_nonmatch(self):\n"
    "        hits = []\n"
    "        for exc in [ValueError('a'), KeyError('k'), TypeError('t')]:\n"
    "            try:\n"
    "                raise exc\n"
    "            except (ValueError, KeyError) as e:\n"
    "                hits.append(type(e).__name__)\n"
    "            except TypeError as e2:\n"
    "                hits.append(type(e2).__name__)\n"
    "        self.assertEqual(hits, ['ValueError', 'KeyError', 'TypeError'])\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "conv exceptions: else finally interplay replays against the host" {
    # else runs only on fall-through; finally runs during propagation and after
    # handling; str(KeyError('k')) is repr'd (CPython KeyError_str).
    src = "class TestElseFinally(unittest.TestCase):\n"
    "    def test_else_then_raise_finally_order(self):\n"
    "        order = []\n"
    "        msg = ''\n"
    "        try:\n"
    "            try:\n"
    "                pass\n"
    "            except ValueError:\n"
    "                order.append('except')\n"
    "            else:\n"
    "                order.append('else')\n"
    "            raise KeyError('late')\n"
    "        except KeyError as e:\n"
    "            msg = str(e)\n"
    "        finally:\n"
    "            order.append('finally')\n"
    "        self.assertEqual(order, ['else', 'finally'])\n"
    "        self.assertEqual(msg, \"'late'\")\n"
    "    def test_finally_runs_during_propagation(self):\n"
    "        order = []\n"
    "        msg = ''\n"
    "        try:\n"
    "            try:\n"
    "                raise ValueError('v')\n"
    "            finally:\n"
    "                order.append('finally')\n"
    "        except ValueError as e:\n"
    "            msg = str(e)\n"
    "        order.append('after')\n"
    "        self.assertEqual(order, ['finally', 'after'])\n"
    "        self.assertEqual(msg, 'v')\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "conv exceptions: chaining cause context suppress_context" {
    # __cause__/__context__/__suppress_context__ per PyErr_SetCause/SetObject:
    # `from X` sets cause+suppress; `from None` suppresses with empty cause;
    # implicit contexts record silently; a fresh raise replaces the context.
    src = "class TestChaining(unittest.TestCase):\n"
    "    def test_explicit_cause(self):\n"
    "        cause_name = ''\n"
    "        supp = None\n"
    "        try:\n"
    "            try:\n"
    "                raise TypeError('bad')\n"
    "            except TypeError as e1:\n"
    "                raise ValueError('outer') from e1\n"
    "        except ValueError as e2:\n"
    "            cause_name = type(e2.__cause__).__name__\n"
    "            supp = e2.__suppress_context__\n"
    "        self.assertEqual(cause_name, 'TypeError')\n"
    "        self.assertIs(supp, True)\n"
    "    def test_raise_from_none(self):\n"
    "        supp = None\n"
    "        has_cause = None\n"
    "        try:\n"
    "            try:\n"
    "                raise ValueError('a')\n"
    "            except ValueError:\n"
    "                raise TypeError('b') from None\n"
    "        except TypeError as e:\n"
    "            has_cause = e.__cause__ is not None\n"
    "            supp = e.__suppress_context__\n"
    "        self.assertIs(has_cause, False)\n"
    "        self.assertIs(supp, True)\n"
    "    def test_implicit_context(self):\n"
    "        ctx = ''\n"
    "        supp = None\n"
    "        try:\n"
    "            try:\n"
    "                1 / 0\n"
    "            except ZeroDivisionError:\n"
    "                raise ValueError('wrap')\n"
    "        except ValueError as e:\n"
    "            ctx = type(e.__context__).__name__\n"
    "            supp = e.__suppress_context__\n"
    "        self.assertEqual(ctx, 'ZeroDivisionError')\n"
    "        self.assertIs(supp, False)\n"
    "    def test_new_raise_records_context(self):\n"
    "        ctx = ''\n"
    "        try:\n"
    "            try:\n"
    "                raise ValueError('first')\n"
    "            except ValueError:\n"
    "                raise KeyError('second')\n"
    "        except KeyError as e:\n"
    "            ctx = str(e.__context__)\n"
    "        self.assertEqual(ctx, 'first')\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "conv exceptions: runtime traceback attributes replay against the host" {
    # e.__traceback__ heads at the catching frame: tb_next is None (single
    # frame), tb_lineno/tb_lasti are ints, tb_frame is present.
    src = "class TestTbAttrs(unittest.TestCase):\n"
    "    def test_traceback_attributes(self):\n"
    "        tb = None\n"
    "        try:\n"
    "            raise ValueError('tb')\n"
    "        except ValueError as e:\n"
    "            tb = e.__traceback__\n"
    "        self.assertIs(tb.tb_next, None)\n"
    "        self.assertTrue(isinstance(tb.tb_lineno, int))\n"
    "        self.assertTrue(isinstance(tb.tb_lasti, int))\n"
    "        self.assertTrue(tb.tb_frame is not None)\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "conv exceptions: PEP 479 StopIteration in generators becomes RuntimeError" {
    # test_pep479: StopIteration escaping a generator frame converts to
    # RuntimeError -- both a direct raise and one surfacing through next().
    src = "class TestPEP479(unittest.TestCase):\n"
    "    def test_stop_iteration_raised_in_generator(self):\n"
    "        def g():\n"
    "            raise StopIteration\n"
    "            yield 1\n"
    "        name = ''\n"
    "        try:\n"
    "            list(g())\n"
    "        except RuntimeError as e:\n"
    "            name = type(e).__name__\n"
    "        self.assertEqual(name, 'RuntimeError')\n"
    "    def test_stop_iteration_from_next_in_generator(self):\n"
    "        def g(items):\n"
    "            for x in items:\n"
    "                yield next(x)\n"
    "        name = ''\n"
    "        try:\n"
    "            list(g([iter([])]))\n"
    "        except RuntimeError as e:\n"
    "            name = type(e).__name__\n"
    "        self.assertEqual(name, 'RuntimeError')\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}
