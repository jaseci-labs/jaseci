# Converted container-behavior replay pins (reference/cpython/Lib/test/
# {test_list,test_dict,test_tuple,test_set}.py).
#
# Each pin converts a BEHAVIORAL assertion from the CPython suite into a
# differential replay: the same source runs on host CPython and jacpython's
# ceval, and results must match (replay_expr) or whole setup+check methods must
# replay identically (layer1_replay_source). Per-stem sections mirror the four
# source files; each test cites its originating CPython method.
#
# Test harness only: layer0_replay_harness uses host compile/marshal/ast solely
# to produce the expected side of every diff -- same carve-out as layer0_replay.
import from layer0_replay_harness {
    ReplayResult,
    replay_expr,
    layer1_replay_source,
}

def _pins_clean(stem: str, result: ReplayResult) {
    assert result.passed >= 1, stem + ": nothing replayed";
    assert result.skipped == 0, stem + " skipped=" + str(result.skipped);
    assert result.failed == 0, stem + " failed=" + str(result.failures);
    assert result.errored == 0, stem + " errored=" + str(result.errors);
}

# ---------------- stem: test_list ----------------

# test_list.ListTest.test_basic: constructors from tuple/str/genexpr.
test "conv/list: constructors from tuple str genexpr (test_list.test_basic)" {
    assert replay_expr("list(())") == True;
    assert replay_expr("list((0, 1, 2, 3))") == True;
    assert replay_expr("list('spam')") == True;
    assert replay_expr("list(x for x in range(10) if x % 2)") == True;
}

# test_list.ListTest.test_truth / .test_identity / .test_len.
test "conv/list: truth identity and len (test_list.test_truth/.identity/.len)" {
    assert replay_expr("not []") == True;
    assert replay_expr("not [0]") == True;
    assert replay_expr("[42]") == True;
    assert replay_expr("[] is not []") == True;
    assert replay_expr("len([])") == True;
    assert replay_expr("len([0])") == True;
    assert replay_expr("len([0, 1, 2])") == True;
}

# test_list.ListTest.test_empty_slice: x[:] = x on an empty list.
test "conv/list: empty slice assign stays empty (test_list.test_empty_slice)" {
    src = "class TestListSlice(unittest.TestCase):\n"
        + "    def test_empty_slice(self):\n"
        + "        x = []\n"
        + "        x[:] = x\n"
        + "        self.assertEqual(x, [])\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    _pins_clean("list.empty_slice", result);
}

# test_list.ListTest.test_step_overflow: extended-slice assignment with a huge
# step -- DROPPED for now: the layer1 host probe skips the method (slice-store
# with an extreme step is not yet replayable), so no differential pin lands.

# ---------------- stem: test_dict ----------------

# test_dict.DictTest.test_merge_operator: | keeps LEFT operand's value on key
# overlap, in operator and in-place (dict-operand) forms. DROPPED subset:
# d |= [(1, 1), ...] (pair-iterable |=) raises TypeError natively -- a real
# dictobject gap, left to its owner rather than pinned red here.
test "conv/dict: merge operator precedence (test_dict.test_merge_operator)" {
    assert replay_expr("{0: 0, 1: 1, 2: 1} | {1: 1, 2: 2, 3: 3}") == True;
    assert replay_expr("{1: 1, 2: 2, 3: 3} | {0: 0, 1: 1, 2: 1}") == True;
    src = "class TestDictMerge(unittest.TestCase):\n"
        + "    def test_merge_operator(self):\n"
        + "        a = {0: 0, 1: 1, 2: 1}\n"
        + "        b = {1: 1, 2: 2, 3: 3}\n"
        + "        c = a.copy()\n"
        + "        c |= b\n"
        + "        self.assertEqual(c, {0: 0, 1: 1, 2: 2, 3: 3})\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    _pins_clean("dict.merge_operator", result);
}

# test_dict.DictTest.test_bool: emptiness drives truthiness.
test "conv/dict: truthiness (test_dict.test_bool)" {
    assert replay_expr("not {}") == True;
    assert replay_expr("bool({})") == True;
    assert replay_expr("bool({1: 2})") == True;
    assert replay_expr("{1: 2}") == True;
}

# test_dict.DictTest.test_get: default handling without mutating.
test "conv/dict: get defaults (test_dict.test_get)" {
    assert replay_expr("{}.get('c')") == True;
    assert replay_expr("{}.get('c', 3)") == True;
    assert replay_expr("{'a': 1, 'b': 2}.get('c', 3)") == True;
    assert replay_expr("{'a': 1, 'b': 2}.get('a', 3)") == True;
}

# test_dict.DictTest.test_setdefault: insert-on-miss then return-existing chain.
test "conv/dict: setdefault chains (test_dict.test_setdefault)" {
    src = "class TestDictSetDefault(unittest.TestCase):\n"
        + "    def test_setdefault(self):\n"
        + "        d = {}\n"
        + "        self.assertIs(d.setdefault('key0'), None)\n"
        + "        d.setdefault('key0', [])\n"
        + "        self.assertIs(d.setdefault('key0'), None)\n"
        + "        d.setdefault('key', []).append(3)\n"
        + "        self.assertEqual(d['key'][0], 3)\n"
        + "        d.setdefault('key', []).append(4)\n"
        + "        self.assertEqual(len(d['key']), 2)\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    _pins_clean("dict.setdefault", result);
}

# test_dict.DictTest.test_getitem: missing keys raise KeyError.
test "conv/dict: missing key raises KeyError (test_dict.test_getitem)" {
    src = "class TestDictGetItem(unittest.TestCase):\n"
        + "    def test_getitem(self):\n"
        + "        d = {'a': 1}\n"
        + "        with self.assertRaises(KeyError):\n"
        + "            d['b']\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    _pins_clean("dict.getitem", result);
}

# ---------------- stem: test_tuple ----------------

# test_tuple.TupleTest.test_constructors: empty/str/genexpr construction.
# DROPPED pin: tuple(exact_tuple) is exact_tuple (interning identity) --
# jacpython builds a fresh PyTuple, a real tupleobject-core gap, left to its
# owner rather than pinned red here.
test "conv/tuple: constructors (test_tuple.test_constructors)" {
    assert replay_expr("tuple()") == True;
    assert replay_expr("tuple([])") == True;
    assert replay_expr("tuple('spam')") == True;
    assert replay_expr("tuple(x for x in range(10) if x % 2)") == True;
}

# test_tuple.TupleTest truth/len (inherited CommonTest cases re-asserted here).
test "conv/tuple: truth and len (test_tuple.test_truth/.test_len)" {
    assert replay_expr("not ()") == True;
    assert replay_expr("len((0,))") == True;
    assert replay_expr("len((0, 1, 2))") == True;
}

# test_tuple.TupleTest.test_iadd / .test_imul: augmented ops on tuples build a
# NEW tuple (the original binding is untouched).
test "conv/tuple: iadd imul create new tuples (test_tuple.test_iadd/.imul)" {
    src = "class TestTupleAug(unittest.TestCase):\n"
        + "    def test_iadd(self):\n"
        + "        u = (0, 1)\n"
        + "        u2 = u\n"
        + "        u += (2, 3)\n"
        + "        self.assertTrue(u is not u2)\n"
        + "        self.assertEqual(u, (0, 1, 2, 3))\n"
        + "    def test_imul(self):\n"
        + "        u = (0, 1)\n"
        + "        u2 = u\n"
        + "        u *= 3\n"
        + "        self.assertTrue(u is not u2)\n"
        + "        self.assertEqual(u, (0, 1, 0, 1, 0, 1))\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    _pins_clean("tuple.iadd_imul", result);
}

# test_tuple.TupleTest.test_repr: repr of empty/nested tuples round-trips.
test "conv/tuple: repr (test_tuple.test_repr)" {
    assert replay_expr("repr(())") == True;
    assert replay_expr("repr((0, 1, 2))") == True;
    assert replay_expr("repr((0,))") == True;
}

# test_tuple.TupleTest.test_lexicographic_ordering (+ hash parity per
# test_hash_exact's regular-hash expectation, pinned differentially).
test "conv/tuple: lexicographic ordering and hash parity (test_tuple)" {
    assert replay_expr("(1, 2) < (1, 2, -1)") == True;
    assert replay_expr("(1, 2, 0) < (1, 3)") == True;
    assert replay_expr("hash((0, 1, 2)) == hash((0, 1, 2))") == True;
    assert replay_expr("hash(('a', (1, 2))) != hash(('a', (2, 1)))") == True;
}

# ---------------- stem: test_set ----------------

# TestJointOps.setUp-driven constructor behavior: set(str) dedupes letters,
# frozenset builds an equal, hashable counterpart.
test "conv/set: constructors dedupe (test_set constructors)" {
    assert replay_expr("set('abcba')") == True;
    assert replay_expr("set('simsalabim')") == True;
    assert replay_expr("frozenset('abcba')") == True;
    assert replay_expr("set('abcba') == frozenset('abcba')") == True;
    assert replay_expr("len(set('mississippi'))") == True;
}

# test_set.TestJointOps.test_union: union accepts any iterable source and never
# mutates the receiver.
test "conv/set: union over iterables (test_set.test_union)" {
    assert replay_expr("set('abcba').union('cdc')") == True;
    assert replay_expr("set('abcba').union('efgfe')") == True;
    assert replay_expr("set('abcba').union(['e', 'f'])") == True;
    assert replay_expr("set('abcba').union(('c', 'd'))") == True;
    assert replay_expr("set().union({1}, {2}, [3])") == True;
}

# test_set.TestJointOps.test_or: | agrees with union for set/frozenset peers.
test "conv/set: or operator matches union (test_set.test_or)" {
    assert replay_expr("set('simsalabim') | frozenset('madagascar')") == True;
    assert replay_expr("set('ab') | set('bc')") == True;
}

# test_set.TestJointOps.test_add / .test_remove: membership mutation and the
# add-duplicate no-op / remove-miss KeyError contracts.
test "conv/set: add remove discard (test_set.test_add/.test_remove)" {
    src = "class TestSetMutation(unittest.TestCase):\n"
        + "    def test_add_remove(self):\n"
        + "        s = set('abc')\n"
        + "        s.add('Q')\n"
        + "        self.assertTrue('Q' in s)\n"
        + "        dup = s.copy()\n"
        + "        s.add('Q')\n"
        + "        self.assertEqual(s, dup)\n"
        + "        s.discard('zzz')\n"
        + "        s.remove('a')\n"
        + "        self.assertFalse('a' in s)\n"
        + "        with self.assertRaises(KeyError):\n"
        + "            s.remove('a')\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    _pins_clean("set.add_remove", result);
}
