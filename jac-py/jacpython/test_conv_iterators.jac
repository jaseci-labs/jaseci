# Converted iterator/generator replay pins (CPython Lib/test corpus lift).
#
# Differential conversions from reference/cpython/Lib/test/{test_iter,
# test_generators,test_zip,test_enumerate,test_map,test_filter}.py: each jac
# test embeds a self-contained unittest-method subset and replays it through
# layer1_replay_source -- setup runs on BOTH engines, every self.assert*
# argument is evaluated cross-engine and diffed. Async-generator internals are
# excluded (owned by the async-gen lane).

import from layer0_replay_harness {
    layer1_replay_source
}

# ---------------- iter/next protocol (test_iter) ----------------

test "conv iterators: iter/next exhaustion and sentinel default" {
    src = "class TestIterNext(unittest.TestCase):\n"
    "    def test_iter_next_list(self):\n"
    "        it = iter([1, 2])\n"
    "        self.assertEqual(next(it), 1)\n"
    "        self.assertEqual(next(it), 2)\n"
    "        with self.assertRaises(StopIteration):\n"
    "            next(it)\n"
    "        self.assertEqual(next(it, 'sentinel'), 'sentinel')\n"
    "    def test_iter_str_tuple(self):\n"
    "        self.assertEqual(''.join(iter('ab')), 'ab')\n"
    "        self.assertEqual(list(iter((4, 5))), [4, 5])\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "conv iterators: custom __iter__/__next__ class protocol" {
    src = "class TestCustomIter(unittest.TestCase):\n"
    "    def test_countdown(self):\n"
    "        class Countdown:\n"
    "            def __init__(self):\n"
    "                self.n = 2\n"
    "            def __iter__(self):\n"
    "                return self\n"
    "            def __next__(self):\n"
    "                if self.n <= 0:\n"
    "                    raise StopIteration\n"
    "                self.n -= 1\n"
    "                return self.n\n"
    "        self.assertEqual(list(Countdown()), [1, 0])\n"
    "        c = Countdown()\n"
    "        self.assertEqual(next(c), 1)\n"
    "        self.assertEqual(next(c, 'done'), 0)\n"
    "        self.assertEqual(next(c, 'done'), 'done')\n"
    "    def test_callable_sentinel(self):\n"
    "        vals = [3, 2, 1]\n"
    "        def pop():\n"
    "            if vals:\n"
    "                return vals.pop()\n"
    "            raise StopIteration\n"
    "        self.assertEqual(list(iter(pop, None)), [1, 2, 3])\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- zip incl. strict= forms (test_zip) ----------------

test "conv iterators: zip shortest and transpose" {
    src = "class TestZipShortest(unittest.TestCase):\n"
    "    def test_shortest_wins(self):\n"
    "        self.assertEqual(list(zip([1, 2, 3], 'ab')), [(1, 'a'), (2, 'b')])\n"
    "        self.assertEqual(list(zip([])), [])\n"
    "    def test_transpose(self):\n"
    "        pairs = [(1, 'a'), (2, 'b')]\n"
    "        self.assertEqual(list(zip(*pairs)), [(1, 2), ('a', 'b')])\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# NOTE (conversion gap, not pinned here): zip(it1, it2, strict=True) with
# UNEQUAL lengths must raise ValueError; jacpython currently raises TypeError
# because keyword args are not forwarded to the host-builtin zip binding
# (bridge-table territory, owned by another lane). Only the equal-length
# strict form is pinned until that lands.
test "conv iterators: zip strict= equal lengths passes" {
    src = "class TestZipStrict(unittest.TestCase):\n"
    "    def test_strict_equal_lengths(self):\n"
    "        self.assertEqual(list(zip([1, 2], [3, 4], strict=True)),\n"
    "                         [(1, 3), (2, 4)])\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- enumerate start (test_enumerate) ----------------

test "conv iterators: enumerate basic and start forms" {
    src = "class TestEnumerateConv(unittest.TestCase):\n"
    "    def test_basic(self):\n"
    "        self.assertEqual(list(enumerate('ab')), [(0, 'a'), (1, 'b')])\n"
    "        self.assertEqual(list(enumerate([])), [])\n"
    "    def test_start(self):\n"
    "        self.assertEqual(list(enumerate(['x'], start=5)), [(5, 'x')])\n"
    "        self.assertEqual(list(enumerate(['x', 'y'], 7)),\n"
    "                         [(7, 'x'), (8, 'y')])\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- map/filter laziness via side-effect lists ----------------

test "conv iterators: map is lazy and stops at shortest input" {
    src = "class TestMapLazy(unittest.TestCase):\n"
    "    def test_laziness_side_effects(self):\n"
    "        calls = []\n"
    "        def track(x):\n"
    "            calls.append(x)\n"
    "            return x * 2\n"
    "        m = map(track, [1, 2, 3])\n"
    "        self.assertEqual(calls, [])\n"
    "        self.assertEqual(next(m), 2)\n"
    "        self.assertEqual(calls, [1])\n"
    "        self.assertEqual(list(m), [4, 6])\n"
    "        self.assertEqual(calls, [1, 2, 3])\n"
    "    def test_multi_input_shortest(self):\n"
    "        add = lambda a, b: a + b\n"
    "        self.assertEqual(list(map(add, [1, 2, 3], [10, 20])), [11, 22])\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "conv iterators: filter is lazy and None-predicate keeps truthy" {
    src = "class TestFilterLazy(unittest.TestCase):\n"
    "    def test_laziness_side_effects(self):\n"
    "        seen = []\n"
    "        def keep(x):\n"
    "            seen.append(x)\n"
    "            return x % 2 == 0\n"
    "        f = filter(keep, [1, 2, 3, 4])\n"
    "        self.assertEqual(seen, [])\n"
    "        self.assertEqual(next(f), 2)\n"
    "        self.assertEqual(seen, [1, 2])\n"
    "        self.assertEqual(list(f), [4])\n"
    "        self.assertEqual(seen, [1, 2, 3, 4])\n"
    "    def test_none_predicate(self):\n"
    "        self.assertEqual(list(filter(None, [0, 1, '', 'a', [], [2]])),\n"
    "                         [1, 'a', [2]])\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- generator send/throw/close sync paths (test_generators) --

test "conv generators: send drives coroutine-style accumulation" {
    src = "class TestGenSend(unittest.TestCase):\n"
    "    def test_echo(self):\n"
    "        def echo():\n"
    "            while True:\n"
    "                v = yield 'ready'\n"
    "                if v == 'stop':\n"
    "                    return\n"
    "                yield 'got:' + str(v)\n"
    "        g = echo()\n"
    "        self.assertEqual(g.send(None), 'ready')\n"
    "        self.assertEqual(g.send(5), 'got:5')\n"
    "        self.assertEqual(g.send(None), 'ready')\n"
    "        with self.assertRaises(StopIteration):\n"
    "            g.send('stop')\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "conv generators: throw caught yields fallback, uncaught propagates" {
    src = "class TestGenThrow(unittest.TestCase):\n"
    "    def test_throw_caught(self):\n"
    "        def resilient():\n"
    "            try:\n"
    "                yield 1\n"
    "            except ValueError as e:\n"
    "                yield str(e)\n"
    "            yield 'end'\n"
    "        g = resilient()\n"
    "        self.assertEqual(next(g), 1)\n"
    "        self.assertEqual(g.throw(ValueError('boom')), 'boom')\n"
    "        self.assertEqual(next(g), 'end')\n"
    "    def test_throw_uncaught(self):\n"
    "        def g():\n"
    "            yield 1\n"
    "            yield 2\n"
    "        gg = g()\n"
    "        self.assertEqual(next(gg), 1)\n"
    "        with self.assertRaises(KeyError):\n"
    "            gg.throw(KeyError('k'))\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# The pre-close yield is bound to `first` in setup because the harness
# evaluates every check argument against one linear namespace after the whole
# setup runs -- a raw next(g) check would evaluate after g.close().
test "conv generators: close runs finally once and exhausts the frame" {
    src = "class TestGenClose(unittest.TestCase):\n"
    "    def test_close_finally(self):\n"
    "        log = []\n"
    "        def fin():\n"
    "            try:\n"
    "                yield 1\n"
    "            finally:\n"
    "                log.append('closed')\n"
    "        g = fin()\n"
    "        first = next(g)\n"
    "        g.close()\n"
    "        fresh = fin()\n"
    "        fresh.close()\n"
    "        self.assertEqual(first, 1)\n"
    "        self.assertEqual(log, ['closed'])\n"
    "        with self.assertRaises(StopIteration):\n"
    "            next(g)\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- yield from delegation observable behavior ----------------

test "conv generators: yield from captures return and delegates send" {
    src = "class TestYieldFromConv(unittest.TestCase):\n"
    "    def test_return_capture(self):\n"
    "        def inner():\n"
    "            yield 1\n"
    "            return 'ret'\n"
    "        def outer():\n"
    "            r = yield from inner()\n"
    "            yield 'captured:' + r\n"
    "        self.assertEqual(list(outer()), [1, 'captured:ret'])\n"
    "    def test_send_delegates(self):\n"
    "        def inner():\n"
    "            v = yield 'q'\n"
    "            yield 'ans:' + str(v)\n"
    "        def outer():\n"
    "            yield from inner()\n"
    "        o = outer()\n"
    "        self.assertEqual(next(o), 'q')\n"
    "        self.assertEqual(o.send(42), 'ans:42')\n"
    "    def test_nested_delegation(self):\n"
    "        def leaf():\n"
    "            yield 'l'\n"
    "        def mid():\n"
    "            yield from leaf()\n"
    "            yield 'm'\n"
    "        def top():\n"
    "            yield from mid()\n"
    "        self.assertEqual(list(top()), ['l', 'm'])\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- comprehension scoping ----------------

test "conv comprehension: loop var scoped, walrus leaks to enclosing fn" {
    src = "class TestCompScope(unittest.TestCase):\n"
    "    def test_comp_var_no_leak(self):\n"
    "        def f():\n"
    "            y = 'keep'\n"
    "            [y for y in range(3)]\n"
    "            return y\n"
    "        self.assertEqual(f(), 'keep')\n"
    "    def test_walrus_leaks_to_enclosing_fn(self):\n"
    "        def f():\n"
    "            [n := i for i in range(5)]\n"
    "            return n\n"
    "        self.assertEqual(f(), 4)\n"
    "    def test_outermost_iter_in_enclosing_scope(self):\n"
    "        rng = range(3)\n"
    "        def f():\n"
    "            return [i for i in rng]\n"
    "        self.assertEqual(f(), [0, 1, 2])\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}
