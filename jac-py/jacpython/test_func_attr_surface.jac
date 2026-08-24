# Function attribute-surface pins: __kwdefaults__ / __defaults__ / __dict__.
# CPython binds these attributes to the call machinery: __kwdefaults__ is
# None without keyword-only defaults, otherwise ONE live dict whose mutations
# reach later calls; explicit assignments override the MAKE_FUNCTION tables;
# f.__dict__ is the live attribute map (functools.wraps WRAPPER_UPDATES
# depends on update() persisting) with the fixed surface names absent.
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

# ---------------- __kwdefaults__ ----------------
test "func surface: __kwdefaults__ read/mutate/rebind" {
    src = "class TestKwDefaults(unittest.TestCase):\n"
    "    def test_present(self):\n"
    "        def f(*, a=1): return a\n"
    "        self.assertEqual(f.__kwdefaults__, {'a': 1})\n"
    "    def test_absent_is_none(self):\n"
    "        def f(): pass\n"
    "        self.assertIsNone(f.__kwdefaults__)\n"
    "    def test_mutation_reaches_call(self):\n"
    "        def f(*, a=1): return a\n"
    "        f.__kwdefaults__['a'] = 5\n"
    "        self.assertEqual(f(), 5)\n"
    "    def test_identity_stable(self):\n"
    "        def f(*, a=1): pass\n"
    "        self.assertTrue(f.__kwdefaults__ is f.__kwdefaults__)\n"
    "    def test_kwonly_without_default_excluded(self):\n"
    "        def h(x, *, b=2): pass\n"
    "        self.assertEqual(h.__kwdefaults__, {'b': 2})\n"
    "        self.assertIsNone(h.__defaults__)\n";
    result = layer1_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "func surface: __kwdefaults__ assignment overrides call defaults" {
    src = "class TestKwDefaultsAssign(unittest.TestCase):\n"
    "    def test_rebind_dict(self):\n"
    "        def f(*, a=1): return a\n"
    "        f.__kwdefaults__ = {'a': 7}\n"
    "        self.assertEqual(f(), 7)\n"
    "    def test_rebind_none_then_call_fails(self):\n"
    "        def f(*, a=1): return a\n"
    "        f.__kwdefaults__ = None\n"
    "        with self.assertRaises(TypeError):\n"
    "            f()\n"
    "    def test_positional_defaults_untouched(self):\n"
    "        def k(a=1): return a\n"
    "        self.assertEqual(k.__defaults__, (1,))\n"
    "        k.__defaults__ = (9,)\n"
    "        self.assertEqual(k(), 9)\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- __dict__ ----------------
test "func surface: __dict__ is live and excludes fixed names" {
    src = "class TestFuncDict(unittest.TestCase):\n"
    "    def test_update_persists(self):\n"
    "        def f(): pass\n"
    "        f.__dict__.update({'marker': 1})\n"
    "        self.assertEqual(f.marker, 1)\n"
    "    def test_attr_reflects_into_dict(self):\n"
    "        def f(): pass\n"
    "        f.custom = 3\n"
    "        self.assertEqual(f.__dict__['custom'], 3)\n"
    "    def test_fixed_names_absent(self):\n"
    "        def f(): pass\n"
    "        f.custom = 1\n"
    "        d = f.__dict__\n"
    "        self.assertIsNone(d.get('__name__'))\n"
    "        self.assertIsNone(d.get('__doc__'))\n"
    "        self.assertEqual(sorted(f.__dict__.keys()), ['custom'])\n"
    "    def test_pop_removes_attribute(self):\n"
    "        def f(): pass\n"
    "        f.temporary = 2\n"
    "        del f.__dict__['temporary']\n"
    "        self.assertFalse(hasattr(f, 'temporary'))\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}
