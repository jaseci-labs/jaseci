# str/repr/format slot-dispatch regression pins (ledger items 53/60).
#
# Native dispatch of __str__/__repr__/__format__ for user instances BEFORE any
# to_host bridging: a plain user object marshals as None, so the host bridge
# answered str(obj) == 'None', repr(obj) == 'None', and format(obj, spec)
# raised on a lost value. Harness lives in layer0_replay_harness.jac; importing
# it here must NOT pull in layer0_replay's tests.
#
# Layer-1 replay runs each method body on BOTH engines and diffs assert
# arguments cross-engine, so address-bearing default reprs are pinned through
# engine-invariant structural facts (addresses legitimately differ per engine),
# never by value.
import from layer0_replay_harness {
    ReplayResult,
    layer0_replay_source,
    layer1_replay_source,
}

def _strfmt_probe(name: str, src: str) -> ReplayResult {
    return layer1_replay_source(src);
}

def _strfmt_expect_pass(result: ReplayResult, name: str) {
    assert result.failed == 0, name + " failed: " + str(result.failures);
    assert result.errored == 0, name + " errored: " + str(result.errors);
}

test "strfmt: scalar %s/%r formatting still replays against the host" {
    src = "class TestScalars(unittest.TestCase):\n"
    "    def test_pct(self):\n"
    "        self.assertEqual('%d' % 42, '42')\n"
    "        self.assertEqual('%05d' % 42, '00042')\n"
    "        self.assertEqual('%x' % 255, 'ff')\n"
    "        self.assertEqual('%s=%d' % ('x', 5), 'x=5')\n"
    "        self.assertEqual('%r' % 'hi', chr(39) + 'hi' + chr(39))\n";
    result = layer0_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 0;
    assert result.failed == 0;
}

test "strfmt: class with only __repr__ serves both repr() and str()" {
    result = _strfmt_probe(
        "only_repr",
        "class TestOnlyRepr(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class R:\n"
        "            def __repr__(self):\n"
        "                return 'R!'\n"
        "        r = R()\n"
        "        self.assertEqual(repr(r), 'R!')\n"
        "        self.assertEqual(str(r), 'R!')\n"
        "        self.assertEqual(f'{r}', 'R!')\n"
        "        self.assertEqual(f'{r!r}', 'R!')\n",
    );
    _strfmt_expect_pass(result, "only_repr");
    assert result.passed == 1;
}

test "strfmt: class with only __str__; repr falls back to the default form" {
    result = _strfmt_probe(
        "only_str",
        "class TestOnlyStr(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class S:\n"
        "            def __str__(self):\n"
        "                return 'S!'\n"
        "        s = S()\n"
        "        self.assertEqual(str(s), 'S!')\n"
        "        self.assertEqual('S!' not in repr(s), True)\n",
    );
    _strfmt_expect_pass(result, "only_str");
    assert result.passed == 1;
}

test "strfmt: both dunders -- str() and repr() stay independent" {
    result = _strfmt_probe(
        "both_dunders",
        "class TestBoth(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class B:\n"
        "            def __repr__(self):\n"
        "                return 'REP'\n"
        "            def __str__(self):\n"
        "                return 'STR'\n"
        "        b = B()\n"
        "        self.assertEqual(str(b), 'STR')\n"
        "        self.assertEqual(repr(b), 'REP')\n",
    );
    _strfmt_expect_pass(result, "both_dunders");
    assert result.passed == 1;
}

test "strfmt: raising inside __repr__/__str__ propagates verbatim" {
    result = _strfmt_probe(
        "raise_in_dunder",
        "class TestRaise(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class X:\n"
        "            def __repr__(self):\n"
        "                raise ValueError('boom')\n"
        "        with self.assertRaises(ValueError):\n"
        "            repr(X())\n",
    );
    _strfmt_expect_pass(result, "raise_in_dunder");
    assert result.passed == 1;
}

test "strfmt: non-string returns raise host-exact TypeErrors" {
    result = _strfmt_probe(
        "bad_return_types",
        "class TestBadReturn(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class W:\n"
        "            def __str__(self):\n"
        "                return 42\n"
        "        with self.assertRaises(TypeError):\n"
        "            str(W())\n"
        "    def test_y(self):\n"
        "        class V:\n"
        "            def __repr__(self):\n"
        "                return 42\n"
        "        with self.assertRaises(TypeError):\n"
        "            repr(V())\n",
    );
    _strfmt_expect_pass(result, "bad_return_types");
    assert result.passed == 2;
}

test "strfmt: default object form is '<C object at 0x..>' shaped, lowercase hex" {
    # Addresses differ per engine, so pin the engine-invariant structure:
    # identity collapse of str() onto repr(), four space-separated fields, an
    # 'object at 0x' marker whose digits are lowercase hex, and the class name.
    result = _strfmt_probe(
        "default_shape",
        "class TestDefaultShape(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class P:\n"
        "            pass\n"
        "        p = P()\n"
        "        a = repr(p)\n"
        "        ok = (str(p) == a\n"
        "              and a.startswith('<') and a.endswith('>')\n"
        "              and ' object at 0x' in a and len(a.split(' ')) == 4\n"
        "              and 'P object' in a\n"
        "              and a.split('0x')[1][:-1] == a.split('0x')[1][:-1].lower()\n"
        "              and len(a.split('0x')[1][:-1]) > 0)\n"
        "        self.assertEqual(ok, True)\n",
    );
    _strfmt_expect_pass(result, "default_shape");
    assert result.passed == 1;
}

test "strfmt: format specs pass through to user __format__" {
    result = _strfmt_probe(
        "spec_passthrough",
        "class TestSpec(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class F:\n"
        "            def __format__(self, spec):\n"
        "                return 'F<' + spec + '>'\n"
        "        f = F()\n"
        "        self.assertEqual(format(f, 'zz'), 'F<zz>')\n"
        "        self.assertEqual(format(f, ''), 'F<>')\n"
        "        self.assertEqual(f'{f:q}', 'F<q>')\n",
    );
    _strfmt_expect_pass(result, "spec_passthrough");
    assert result.passed == 1;
}

test "strfmt: empty spec delegates like str(); bad __format__ return raises" {
    result = _strfmt_probe(
        "empty_spec_and_bad_return",
        "class TestEmptySpec(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class S:\n"
        "            def __str__(self):\n"
        "                return 'EQ'\n"
        "        s = S()\n"
        "        self.assertEqual(format(s), 'EQ')\n"
        "        self.assertEqual(format(s, ''), 'EQ')\n"
        "    def test_y(self):\n"
        "        class F:\n"
        "            def __format__(self, spec):\n"
        "                return 7\n"
        "        with self.assertRaises(TypeError):\n"
        "            format(F(), 'x')\n",
    );
    _strfmt_expect_pass(result, "empty_spec_and_bad_return");
    assert result.passed == 2;
}

test "strfmt: plain instance with non-empty spec is CPython's TypeError" {
    result = _strfmt_probe(
        "plain_nonempty_spec",
        "class TestPlainSpec(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class P:\n"
        "            pass\n"
        "        with self.assertRaises(TypeError):\n"
        "            format(P(), '10')\n",
    );
    _strfmt_expect_pass(result, "plain_nonempty_spec");
    assert result.passed == 1;
}

test "strfmt: inheritance -- inherited dunders serve subclasses" {
    result = _strfmt_probe(
        "inheritance",
        "class TestInherit(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class Base:\n"
        "            def __str__(self):\n"
        "                return 'BS'\n"
        "        class Sub(Base):\n"
        "            pass\n"
        "        s = Sub()\n"
        "        self.assertEqual(str(s), 'BS')\n"
        "        self.assertEqual('BS' not in repr(s), True)\n"
        "    def test_y(self):\n"
        "        class RBase:\n"
        "            def __repr__(self):\n"
        "                return 'BR'\n"
        "        class RSub(RBase):\n"
        "            pass\n"
        "        r = RSub()\n"
        "        self.assertEqual(str(r), 'BR')\n"
        "        self.assertEqual(repr(r), 'BR')\n"
        "        class Ov(RBase):\n"
        "            def __repr__(self):\n"
        "                return 'OV'\n"
        "        self.assertEqual(repr(Ov()), 'OV')\n",
    );
    _strfmt_expect_pass(result, "inheritance");
    assert result.passed == 2;
}

test "strfmt: boxed builtin bases contribute their own str/repr slots" {
    result = _strfmt_probe(
        "boxed_bases",
        "class TestBoxed(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class SI(int):\n"
        "            pass\n"
        "        v = SI(7)\n"
        "        self.assertEqual(str(v), '7')\n"
        "        self.assertEqual(repr(v), '7')\n"
        "    def test_y(self):\n"
        "        class SS(str):\n"
        "            pass\n"
        "        w = SS('ab')\n"
        "        self.assertEqual(str(w), 'ab')\n"
        "        self.assertEqual(repr(w), chr(39) + 'ab' + chr(39))\n",
    );
    _strfmt_expect_pass(result, "boxed_bases");
    assert result.passed == 2;
}

test "strfmt: str %-format consults native __str__/__repr__ slots" {
    result = _strfmt_probe(
        "pct_user_slots",
        "class TestPctSlots(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        class R:\n"
        "            def __repr__(self):\n"
        "                return 'RV'\n"
        "        class S:\n"
        "            def __str__(self):\n"
        "                return 'SV'\n"
        "        r = R()\n"
        "        s = S()\n"
        "        self.assertEqual('%s|%r' % (s, r), 'SV|RV')\n"
        "        self.assertEqual('%s' % s, 'SV')\n"
        "        self.assertEqual('%(k)s' % {'k': s}, 'SV')\n"
        "    def test_y(self):\n"
        "        class X:\n"
        "            def __rmod__(self, other):\n"
        "                return 'RMOD'\n"
        "        with self.assertRaises(TypeError):\n"
        "            '%d' % X()\n",
    );
    _strfmt_expect_pass(result, "pct_user_slots");
    assert result.passed == 2;
}
