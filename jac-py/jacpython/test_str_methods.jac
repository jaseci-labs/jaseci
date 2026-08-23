# Native PyStr method-surface pins (host-exactness against CPython 3.14).
#
# Before this surface, every 'x'.method() lookup crossed the substrate boundary
# via _is_host_backed -> host_getattr. Now PyStr resolves a native PyStrMethod
# (ceval.jac) whose dispatch validates arguments byte-exactly and delegates the
# core algorithm to the underlying host string intrinsic. Layer-1 replay runs
# each assert argument on BOTH engines and diffs cross-engine, so every line
# doubles as an exactness oracle -- including the 3.14 lazy encode-error-handler
# semantics pinned in "strmeth: encode handler validation is lazy".
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

def _sm_probe(name: str, src: str) -> ReplayResult {
    return layer1_replay_source(src);
}

def _sm_expect_pass(result: ReplayResult, name: str) {
    assert result.failed == 0, name + " failed: " + str(result.failures);
    assert result.errored == 0, name + " errored: " + str(result.errors);
}

test "strmeth: case transforms incl. title apostrophe rule" {
    result = _sm_probe(
        "case",
        "class TestCase(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('aBc'.upper(), 'ABC')\n"
        "        self.assertEqual('aBc'.lower(), 'abc')\n"
        "        self.assertEqual('hello WORLD'.capitalize(), 'Hello world')\n"
        "        self.assertEqual('HELLO'.casefold(), 'hello')\n"
        "        self.assertEqual('aBc DeF'.swapcase(), 'AbC dEf')\n"
        "        self.assertEqual(\"they're bill's friends\".title(), \"They'Re Bill'S Friends\")\n"
        "        self.assertEqual('2b or not 2b'.title(), '2B Or Not 2B')\n"
        "        self.assertEqual('\\u00df'.casefold(), 'ss')\n"
        "        self.assertEqual('\\u00df'.upper(), 'SS')\n",
    );
    _sm_expect_pass(result, "case");
    assert result.passed == 1;
}

test "strmeth: istitle/islower/isupper subtleties" {
    result = _sm_probe(
        "pred_case",
        "class TestPredCase(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual(\"They'Re\".istitle(), True)\n"
        "        self.assertEqual('Hello World'.istitle(), True)\n"
        "        self.assertEqual('123'.istitle(), False)\n"
        "        self.assertEqual('ab1'.islower(), True)\n"
        "        self.assertEqual('AB1'.isupper(), True)\n"
        "        self.assertEqual('123'.islower(), False)\n"
        "        self.assertEqual('123'.isupper(), False)\n"
        "        self.assertEqual('\\u00e9'.islower(), True)\n"
        "        self.assertEqual('\\u0130'.lower() == 'i', False)\n",
    );
    _sm_expect_pass(result, "pred_case");
    assert result.passed == 1;
}

test "strmeth: strip family arg forms" {
    result = _sm_probe(
        "strip",
        "class TestStrip(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('  x  '.strip(), 'x')\n"
        "        self.assertEqual('xxaxx'.strip('x'), 'a')\n"
        "        self.assertEqual('www.example.com'.strip('cmowz.'), 'example')\n"
        "        self.assertEqual('  x '.lstrip(), 'x ')\n"
        "        self.assertEqual('xyXyx'.lstrip('xy'), 'Xyx')\n"
        "        self.assertEqual('  x '.rstrip(), '  x')\n"
        "        self.assertEqual('1,2,3'.rstrip(',3'), '1,2')\n"
        "        self.assertEqual('xx'.strip('x'), '')\n",
    );
    _sm_expect_pass(result, "strip");
    assert result.passed == 1;
}

test "strmeth: partition/rpartition shapes and empty-separator ValueError" {
    result = _sm_probe(
        "partition",
        "class TestPartition(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('a:b:c'.partition(':'), ('a', ':', 'b:c'))\n"
        "        self.assertEqual('abc'.partition(':'), ('abc', '', ''))\n"
        "        with self.assertRaises(ValueError):\n"
        "            'abc'.partition('')\n"
        "        self.assertEqual('a:b:c'.rpartition(':'), ('a:b', ':', 'c'))\n"
        "        self.assertEqual('abc'.rpartition(':'), ('', '', 'abc'))\n",
    );
    _sm_expect_pass(result, "partition");
    assert result.passed == 1;
}

test "strmeth: split/rsplit maxsplit and empties" {
    result = _sm_probe(
        "split",
        "class TestSplit(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('a,b,,c'.split(','), ['a', 'b', '', 'c'])\n"
        "        self.assertEqual(',a,'.split(','), ['', 'a', ''])\n"
        "        self.assertEqual(''.split(','), [''])\n"
        "        self.assertEqual('a,b,c'.split(',', 1), ['a', 'b,c'])\n"
        "        self.assertEqual('a,b,c'.split(',', 0), ['a,b,c'])\n"
        "        with self.assertRaises(ValueError):\n"
        "            'abc'.split('')\n"
        "        self.assertEqual(' a b  c '.split(), ['a', 'b', 'c'])\n"
        "        self.assertEqual(' a b  c '.split(None, 1), ['a', 'b  c '])\n"
        "        self.assertEqual(''.split(), [])\n"
        "        self.assertEqual('a,b,c'.rsplit(',', 1), ['a,b', 'c'])\n"
        "        self.assertEqual(' a b c '.rsplit(None, 1), [' a b', 'c'])\n"
        "        self.assertEqual('a,,b'.rsplit(','), ['a', '', 'b'])\n",
    );
    _sm_expect_pass(result, "split");
    assert result.passed == 1;
}

test "strmeth: splitlines universal boundaries incl. \\x85 \\u2028 \\u2029" {
    result = _sm_probe(
        "splitlines",
        "class TestSplitLines(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('a\\nb\\n'.splitlines(), ['a', 'b'])\n"
        "        self.assertEqual('a\\rb\\r\\nc\\vd\\fe\\x1cf\\x1dg\\x85h\\u2028i\\u2029j'.splitlines(), ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'])\n"
        "        self.assertEqual('a\\nb\\n'.splitlines(True), ['a\\n', 'b\\n'])\n"
        "        self.assertEqual(''.splitlines(), [])\n"
        "        self.assertEqual('\\n'.splitlines(), [''])\n",
    );
    _sm_expect_pass(result, "splitlines");
    assert result.passed == 1;
}

test "strmeth: center/ljust/rjust/zfill sign handling" {
    result = _sm_probe(
        "pad",
        "class TestPad(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('hi'.center(6), '  hi  ')\n"
        "        self.assertEqual('hi'.center(7, '-'), '--hi---')\n"
        "        self.assertEqual('hi'.ljust(5, '.'), 'hi...')\n"
        "        self.assertEqual('-42'.zfill(6), '-000042')\n"
        "        self.assertEqual('+42'.zfill(6), '+000042')\n"
        "        self.assertEqual('-abc'.zfill(6), '-00abc')\n"
        "        self.assertEqual('42'.zfill(1), '42')\n"
        "        with self.assertRaises(TypeError):\n"
        "            'hi'.center(7, '--')\n",
    );
    _sm_expect_pass(result, "pad");
    assert result.passed == 1;
}

test "strmeth: find family conventions" {
    result = _sm_probe(
        "find",
        "class TestFind(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('banana'.find('na'), 2)\n"
        "        self.assertEqual('banana'.find('na', 3), 4)\n"
        "        self.assertEqual('banana'.rfind('na'), 4)\n"
        "        self.assertEqual('banana'.index('na'), 2)\n"
        "        self.assertEqual('aaa'.find('a', -100, 2), 0)\n"
        "        self.assertEqual('aaa'.find('a', 10), -1)\n"
        "        with self.assertRaises(ValueError):\n"
        "            'banana'.index('zz')\n"
        "        with self.assertRaises(ValueError):\n"
        "            'banana'.rindex('zz')\n",
    );
    _sm_expect_pass(result, "find");
    assert result.passed == 1;
}

test "strmeth: count non-overlap and replace limits" {
    result = _sm_probe(
        "count_replace",
        "class TestCount(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('aaaa'.count('aa'), 2)\n"
        "        self.assertEqual(''.count('x'), 0)\n"
        "        self.assertEqual(''.count(''), 1)\n"
        "        self.assertEqual('abc'.count(''), 4)\n"
        "        self.assertEqual('aaaa'.replace('aa', 'b'), 'bb')\n"
        "        self.assertEqual('aaaa'.replace('aa', 'b', 1), 'baa')\n"
        "        self.assertEqual('abc'.replace('', '-'), '-a-b-c-')\n"
        "        self.assertEqual('abc'.replace('x', 'y'), 'abc')\n",
    );
    _sm_expect_pass(result, "count_replace");
    assert result.passed == 1;
}

test "strmeth: startswith/endswith tuples and ranges" {
    result = _sm_probe(
        "affix",
        "class TestAffix(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('hello'.startswith(('x', 'he')), True)\n"
        "        self.assertEqual('hello'.startswith(('x', 'y')), False)\n"
        "        self.assertEqual('hello'.endswith(('x', 'lo')), True)\n"
        "        self.assertEqual('hello'.startswith('e', 1), True)\n"
        "        self.assertEqual('hello'.endswith('ell', 0, 4), True)\n"
        "        with self.assertRaises(TypeError):\n"
        "            'hello'.startswith(42)\n"
        "        with self.assertRaises(TypeError):\n"
        "            'hello'.startswith((1, 2))\n",
    );
    _sm_expect_pass(result, "affix");
    assert result.passed == 1;
}

test "strmeth: isX family incl. digit/decimal/numeric split" {
    result = _sm_probe(
        "ispred",
        "class TestIsPred(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('ab\\u00e7'.isalpha(), True)\n"
        "        self.assertEqual(''.isalpha(), False)\n"
        "        self.assertEqual('ab12'.isalnum(), True)\n"
        "        self.assertEqual('abc123'.isascii(), True)\n"
        "        self.assertEqual('\\u00b2'.isdigit(), True)\n"
        "        self.assertEqual('\\u00b2'.isdecimal(), False)\n"
        "        self.assertEqual('\\u00b2'.isnumeric(), True)\n"
        "        self.assertEqual('\\u56db'.isdigit(), False)\n"
        "        self.assertEqual('\\u56db'.isnumeric(), True)\n"
        "        self.assertEqual('\\u00bd'.isnumeric(), True)\n"
        "        self.assertEqual('\\u2163'.isnumeric(), True)\n"
        "        self.assertEqual('\\u0664'.isdecimal(), True)\n"
        "        self.assertEqual(' \\t\\n\\u2028'.isspace(), True)\n"
        "        self.assertEqual('abc'.isidentifier(), True)\n"
        "        self.assertEqual('printable!'.isprintable(), True)\n"
        "        self.assertEqual('\\n'.isprintable(), False)\n",
    );
    _sm_expect_pass(result, "ispred");
    assert result.passed == 1;
}

test "strmeth: join sequences and the item-type TypeError" {
    result = _sm_probe(
        "join",
        "class TestJoin(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual(','.join(['a', 'b']), 'a,b')\n"
        "        self.assertEqual('-'.join(()), '')\n"
        "        self.assertEqual(','.join(('x', 'y')), 'x,y')\n"
        "        self.assertEqual(','.join({'k': 1}), 'k')\n"
        "        self.assertEqual('-'.join('ab'), 'a-b')\n"
        "        with self.assertRaises(TypeError):\n"
        "            ','.join([1, 2])\n"
        "        with self.assertRaises(TypeError):\n"
        "            ','.join(1)\n",
    );
    _sm_expect_pass(result, "join");
    assert result.passed == 1;
}

test "strmeth: translate and maketrans dict/tuple/3-arg forms" {
    result = _sm_probe(
        "translate",
        "class TestTranslate(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('abc'.translate({97: 'X'}), 'Xbc')\n"
        "        self.assertEqual('abc'.translate(str.maketrans('a', 'X')), 'Xbc')\n"
        "        self.assertEqual(str.maketrans('a', 'X'), {97: 88})\n"
        "        self.assertEqual('abc'.translate(str.maketrans({'a': 'X', 'b': None})), 'Xc')\n"
        "        self.assertEqual(str.maketrans('ab', 'XY', 'c'), {97: 88, 98: 89, 99: None})\n"
        "        self.assertEqual('abc'.translate({}), 'abc')\n"
        "        with self.assertRaises(TypeError):\n"
        "            'abc'.translate({97: b'x'})\n"
        "        with self.assertRaises(ValueError):\n"
        "            'abc'.translate({97: -1})\n"
        "        with self.assertRaises(ValueError):\n"
        "            str.maketrans('ab', 'x')\n",
    );
    _sm_expect_pass(result, "translate");
    assert result.passed == 1;
}

test "strmeth: removeprefix/removesuffix" {
    result = _sm_probe(
        "affix2",
        "class TestRmAffix(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('TestHook'.removeprefix('Test'), 'Hook')\n"
        "        self.assertEqual('BaseTestCase'.removesuffix('Case'), 'BaseTest')\n"
        "        self.assertEqual('abc'.removeprefix('x'), 'abc')\n"
        "        self.assertEqual('abc'.removesuffix('abc'), '')\n"
        "        self.assertEqual('abc'.removeprefix(''), 'abc')\n",
    );
    _sm_expect_pass(result, "affix2");
    assert result.passed == 1;
}

test "strmeth: expandtabs" {
    result = _sm_probe(
        "tabs",
        "class TestTabs(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('01\\t012\\t0123'.expandtabs(), '01      012     0123')\n"
        "        self.assertEqual('a\\tb'.expandtabs(4), 'a   b')\n"
        "        self.assertEqual('a\\tb'.expandtabs(0), 'ab')\n",
    );
    _sm_expect_pass(result, "tabs");
    assert result.passed == 1;
}

test "strmeth: encode utf-8/latin-1 round-trips and error policies" {
    result = _sm_probe(
        "encode",
        "class TestEncode(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('h\\u00e9llo'.encode('utf-8'), b'h\\xc3\\xa9llo')\n"
        "        self.assertEqual('ab'.encode('ascii'), b'ab')\n"
        "        self.assertEqual('h\\u00e9llo'.encode('latin-1'), b'h\\xe9llo')\n"
        "        self.assertEqual('h\\u00e9llo'.encode('utf-8', 'ignore'), b'h llo' if False else b'hllo')\n"
        "        self.assertEqual('h\\u00e9llo'.encode('ascii', 'replace'), b'h?llo')\n"
        "        self.assertEqual('h\\u00e9llo'.encode('ascii', 'backslashreplace'), b'h\\\\xe9llo')\n"
        "        self.assertEqual('h\\u00e9llo'.encode('ascii', 'xmlcharrefreplace'), b'h&#233;llo')\n",
    );
    _sm_expect_pass(result, "encode");
    assert result.passed == 1;
}

test "strmeth: encode failures raise host-exact types; handler validation lazy" {
    result = _sm_probe(
        "encode_errors",
        "class TestEncodeErrors(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        with self.assertRaises(UnicodeEncodeError):\n"
        "            'h\\u00e9llo'.encode('ascii')\n"
        "        with self.assertRaises(UnicodeEncodeError):\n"
        "            '\\ud800'.encode('utf-8')\n"
        "        with self.assertRaises(LookupError):\n"
        "            'ab'.encode('nope')\n"
        "        with self.assertRaises(LookupError):\n"
        "            'h\\u00e9llo'.encode('ascii', 'nope')\n"
        "        self.assertEqual('ab'.encode('utf-8', 'nope'), b'ab')\n",
    );
    _sm_expect_pass(result, "encode_errors");
    assert result.passed == 1;
}

test "strmeth: unicode oracle -- combining marks, CJK width chars" {
    result = _sm_probe(
        "unicode",
        "class TestUnicode(unittest.TestCase):\n"
        "    def test_x(self):\n"
        "        self.assertEqual('caf\\u00e9'.upper(), 'CAF\\u00c9')\n"
        "        self.assertEqual('\\u65e5\\u672c\\u8a9e'.isalpha(), True)\n"
        "        self.assertEqual('\\u65e5\\u672c\\u8a9e123'.isalnum(), True)\n"
        "        self.assertEqual(len('\\u00e9'), 1)\n"
        "        self.assertEqual('\\ufb01'.casefold(), 'fi')\n"
        "        self.assertEqual('\\uff21\\uff22'.lower(), '\\uff41\\uff42')\n"
        "        self.assertEqual('e\\u0301' == '\\u00e9', False)\n"
        "        self.assertEqual('\\u0130'.casefold(), 'i\\u0307')\n",
    );
    _sm_expect_pass(result, "unicode");
    assert result.passed == 1;
}
