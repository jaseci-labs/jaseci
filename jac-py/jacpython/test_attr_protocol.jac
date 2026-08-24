# Attribute-protocol dispatch pins (tp_getattro/tp_setattro/tp_delattr).
# Type-level __getattribute__/__setattr__/__delattr__ overrides must BE the
# attribute protocol (CPython slot_tp_getattro / slot_tp_setattro), with the
# object.__*attr__ slot wrappers running the DEFAULT protocol as the recursion
# guard for delegation. Regression tests in the layer0_replay idiom: import
# layer0_replay_harness (NOT layer0_replay) for a clean ceval slate.
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

# ---------------- __getattribute__ ----------------
test "attr protocol: __getattribute__ override is the get protocol" {
    src = "class TestGetAttrOverride(unittest.TestCase):\n"
    "    def test_constant(self):\n"
    "        class Const:\n"
    "            def __getattribute__(self, name):\n"
    "                return 42\n"
    "        c = Const()\n"
    "        self.assertEqual(c.foo, 42)\n"
    "        self.assertEqual(c.__class__, 42)\n"
    "    def test_delegation_via_object(self):\n"
    "        class Wrap:\n"
    "            def __init__(self):\n"
    "                object.__setattr__(self, 'v', 3)\n"
    "            def __getattribute__(self, name):\n"
    "                return object.__getattribute__(self, name)\n"
    "        w = Wrap()\n"
    "        self.assertEqual(w.v, 3)\n"
    "    def test_raises_propagate(self):\n"
    "        class Raiser:\n"
    "            def __getattribute__(self, name):\n"
    "                raise RuntimeError('boom:' + name)\n"
    "        r = Raiser()\n"
    "        with self.assertRaises(RuntimeError):\n"
    "            r.x\n"
    "    def test_inherited_by_subclass(self):\n"
    "        class Base:\n"
    "            def __getattribute__(self, name):\n"
    "                return 'intercepted'\n"
    "        class Sub(Base):\n"
    "            pass\n"
    "        s = Sub()\n"
    "        self.assertEqual(s.anything, 'intercepted')\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- __setattr__ / __delattr__ ----------------
test "attr protocol: setattr/delattr intercept writes and deletes" {
    src = "class TestSetDelAttrOverride(unittest.TestCase):\n"
    "    def test_setattr_intercepts_then_delegates(self):\n"
    "        log = []\n"
    "        class Logger:\n"
    "            def __setattr__(self, name, value):\n"
    "                log.append(('set', name))\n"
    "                super().__setattr__(name, value)\n"
    "        l = Logger()\n"
    "        l.x = 5\n"
    "        self.assertEqual(log, [('set', 'x')])\n"
    "        self.assertEqual(l.x, 5)\n"
    "    def test_delattr_intercepts_then_delegates(self):\n"
    "        log = []\n"
    "        class Logger:\n"
    "            def __delattr__(self, name):\n"
    "                log.append(('del', name))\n"
    "                super().__delattr__(name)\n"
    "        l = Logger()\n"
    "        l.y = 7\n"
    "        del l.y\n"
    "        self.assertEqual(log, [('del', 'y')])\n"
    "        self.assertFalse(hasattr(l, 'y'))\n"
    "    def test_object_setattr_bypasses_override(self):\n"
    "        class Guarded:\n"
    "            def __init__(self):\n"
    "                object.__setattr__(self, 'd', {'a': 1})\n"
    "            def __setattr__(self, name, value):\n"
    "                raise AssertionError('must not run for d')\n"
    "        g = Guarded()\n"
    "        self.assertEqual(g.d['a'], 1)\n"
    "    def test_setattr_builtin_routes_through_protocol(self):\n"
    "        log = []\n"
    "        class Logger:\n"
    "            def __setattr__(self, name, value):\n"
    "                log.append(name)\n"
    "                super().__setattr__(name, value)\n"
    "        l = Logger()\n"
    "        setattr(l, 'k', 9)\n"
    "        got = getattr(l, 'k')\n"
    "        delattr(l, 'k')\n"
    "        gone = hasattr(l, 'k')\n"
    "        self.assertEqual(got, 9)\n"
    "        self.assertFalse(gone)\n"
    "        self.assertEqual(log, ['k'])\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- __getattr__ fallback interplay ----------------
test "attr protocol: __getattr__ fallback after AttributeError" {
    src = "class TestGetAttrFallback(unittest.TestCase):\n"
    "    def test_fallback_on_missing(self):\n"
    "        class Fallback:\n"
    "            def __getattr__(self, name):\n"
    "                return 'fb:' + name\n"
    "        f = Fallback()\n"
    "        f.real = 1\n"
    "        self.assertEqual(f.real, 1)\n"
    "        self.assertEqual(f.missing, 'fb:missing')\n"
    "    def test_fallback_after_getattribute_raise(self):\n"
    "        class Both:\n"
    "            def __getattribute__(self, name):\n"
    "                raise AttributeError('nope')\n"
    "            def __getattr__(self, name):\n"
    "                return 'fallback:' + name\n"
    "        b = Both()\n"
    "        self.assertEqual(b.k, 'fallback:k')\n"
    "    def test_no_fallback_without_getattr(self):\n"
    "        class Plain:\n"
    "            pass\n"
    "        p = Plain()\n"
    "        with self.assertRaises(AttributeError):\n"
    "            p.nothere\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- descriptor priority + plain-object regress -------------
test "attr protocol: data-descriptor priority and default protocol intact" {
    src = "class TestDescriptorPriority(unittest.TestCase):\n"
    "    def test_property_wins_over_class_dict(self):\n"
    "        class P:\n"
    "            @property\n"
    "            def v(self):\n"
    "                return 'prop'\n"
    "        p = P()\n"
    "        self.assertEqual(p.v, 'prop')\n"
    "        with self.assertRaises(AttributeError):\n"
    "            object.__setattr__(p, 'v', 1)\n"
    "    def test_instance_dict_shadows_plain_class_attr(self):\n"
    "        class S:\n"
    "            x = 1\n"
    "        s = S()\n"
    "        s.x = 2\n"
    "        self.assertEqual(s.x, 2)\n"
    "        self.assertEqual(S.x, 1)\n"
    "    def test_plain_object_roundtrip(self):\n"
    "        class Plain:\n"
    "            cls_attr = 3\n"
    "            def meth(self):\n"
    "                return 'm:' + str(self.f)\n"
    "        o = Plain()\n"
    "        o.f = 8\n"
    "        msg = o.meth()\n"
    "        del o.f\n"
    "        gone = hasattr(o, 'f')\n"
    "        self.assertEqual(o.cls_attr, 3)\n"
    "        self.assertEqual(msg, 'm:8')\n"
    "        self.assertFalse(gone)\n"
    "    def test_hasattr_exposes_slot_wrappers(self):\n"
    "        class Plain:\n"
    "            pass\n"
    "        c = Plain()\n"
    "        c.name = 'x'\n"
    "        self.assertTrue(hasattr(c, '__getattribute__'))\n"
    "        self.assertEqual(c.__getattribute__('name'), 'x')\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- live instance __dict__ ----------------
# CPython's instance __dict__ is ONE identity-stable dict per instance:
# reads, writes through a fetched reference, and attribute writes all observe
# each other. vars(obj) must answer that same live dict (not a host stand-in
# whose only key is the _jac_guest_ back-reference marker).
test "attr protocol: __dict__ is identity-stable and write-through" {
    src = "class TestLiveDict(unittest.TestCase):\n"
    "    def test_identity(self):\n"
    "        class C: pass\n"
    "        c = C()\n"
    "        self.assertTrue(c.__dict__ is c.__dict__)\n"
    "    def test_write_through(self):\n"
    "        class C: pass\n"
    "        c = C()\n"
    "        d = c.__dict__\n"
    "        d['y'] = 2\n"
    "        self.assertEqual(c.y, 2)\n"
    "    def test_reflect(self):\n"
    "        class C: pass\n"
    "        c = C()\n"
    "        d = c.__dict__\n"
    "        c.z = 3\n"
    "        self.assertEqual(d['z'], 3)\n"
    "    def test_pop_removes_attribute(self):\n"
    "        class C: pass\n"
    "        c = C()\n"
    "        c.a = 1\n"
    "        c.__dict__.pop('a')\n"
    "        self.assertFalse(hasattr(c, 'a'))\n"
    "    def test_vars_same_object(self):\n"
    "        import sys\n"
    "        class C: pass\n"
    "        c = C()\n"
    "        c.a = 1\n"
    "        self.assertEqual(sorted(vars(c).keys()), ['a'])\n"
    "        self.assertTrue(vars(c) is c.__dict__)\n";
    result = layer1_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "attr protocol: slotted __dict__ view excludes member storage" {
    src = "class TestSlotDictView(unittest.TestCase):\n"
    "    def test_slots_stay_out_of_view(self):\n"
    "        class C:\n"
    "            __slots__ = ('s', '__dict__')\n"
    "        c = C()\n"
    "        c.s = 1\n"
    "        c.other = 2\n"
    "        self.assertEqual(sorted(c.__dict__.keys()), ['other'])\n"
    "    def test_suppressed_dict_errors(self):\n"
    "        class D:\n"
    "            __slots__ = ('x',)\n"
    "        d = D()\n"
    "        with self.assertRaises(AttributeError):\n"
    "            d.__dict__\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- property attribute surface ----------------
# CPython exposes fget/fset/fdel (None when absent), __doc__ from the getter,
# and __isabstractmethod__ on every property object -- ABC walks and
# introspection tools read these unconditionally.
test "attr protocol: property object surface" {
    src = "class TestPropertySurface(unittest.TestCase):\n"
    "    def test_accessors_exposed(self):\n"
    "        class C:\n"
    "            @property\n"
    "            def p(self):\n"
    "                return 1\n"
    "        self.assertTrue(C.p.fget is not None)\n"
    "        self.assertIsNone(C.p.fset)\n"
    "        self.assertIsNone(C.p.fdel)\n"
    "    def test_setter_chain_sets_fset(self):\n"
    "        class C:\n"
    "            _x = 0\n"
    "            @property\n"
    "            def x(self):\n"
    "                return self._x\n"
    "            @x.setter\n"
    "            def x(self, v):\n"
    "                self._x = v\n"
    "        self.assertTrue(C.x.fset is not None)\n"
    "        c = C()\n"
    "        c.x = 7\n"
    "        self.assertEqual(c.x, 7)\n"
    "    def test_doc_from_getter(self):\n"
    "        class C:\n"
    "            @property\n"
    "            def p(self):\n"
    "                'doc here'\n"
    "                return 1\n"
    "        self.assertEqual(C.p.__doc__, 'doc here')\n"
    "    def test_isabstractmethod_default_false(self):\n"
    "        class C:\n"
    "            @property\n"
    "            def p(self):\n"
    "                return 1\n"
    "        self.assertFalse(C.p.__isabstractmethod__)\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}
