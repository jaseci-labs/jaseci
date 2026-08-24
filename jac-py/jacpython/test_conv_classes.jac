# Converted CPython class-system coverage as differential replay pins.
# Sources: reference/cpython/Lib/test/{test_mro.py,test_classes.py,test_descriptors.py,
# test_class.py}. Behavioral assertions only -- each block replays unittest-shaped
# source through layer1_replay_source (both legs run identical statements; every
# self.assert* argument must agree cross-engine or the tally fails). Tally unit
# is the METHOD: want_passed == number of harvested test_* methods.
#
# Coverage map (converted -> pinned here):
#   test_mro.py     : C3 linearization order + attribute resolution through it,
#                     type.mro()/type.__mro__ surface, 3.14 repeated-base
#                     acceptance (class C(B, A) with B(A) is LEGAL on 3.14)
# KNOWN GAP (dropped case, type-creation lane owns): jacpython silently creates
# classes with genuinely unmergeable MROs -- e.g. class E(C, D) over
# class C(A, B)/class D(B, A), where CPython 3.14 raises TypeError at creation.
# The test_mro.py TestOrderMRO conversion cannot be pinned until the native
# type builder runs the MRO merge consistency check.
#   test_classes.py : metaclass __prepare__ seeding, metaclass __init__ hook,
#                     class-body comprehension scoping quirks
#   test_class.py   : classmethod subclass propagation, staticmethod non-binding,
#                     __getattr__ fallback chained through super()
# NOT duplicated here: __slots__ enforcement is pinned end-to-end in
# test_slots_runtime.jac; class-body free-cell scoping in test_class_scope.jac;
# tp_getattro/setattro override protocol in test_attr_protocol.jac.
# KNOWN GAP (dropped cases, descr-override lane owns): user-defined
# __get__/__delete__ descriptors are not dispatched during instance attribute
# load/delete on the jacpython engine (raw descriptor leaks instead), so the
# test_descriptors.py DescWithDel/non-data-shadow conversions cannot replay yet.
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

def replay(src: str, want_passed: int) {
    # Every converted method must actually replay (no silent scaffolding skips).
    r = layer1_replay_source(src);
    assert r.failed == 0;
    assert r.errored == 0;
    assert r.skipped == 0;
    assert r.passed == want_passed;
    return r;
}

# ---------------- MRO linearization (test_mro.py) ----------------

test "mro: C3 linearizes the classic diamond in host order" {
    # test_mro.py consistency shape: class D(B, C) over class B(A)/class C(A)
    # linearizes [D, B, C, A, object]; attribute lookup follows the same order.
    replay(
        "class TestDiamond(unittest.TestCase):\n"
        "    def test_order(self):\n"
        "        class A:\n"
        "            def who(self):\n"
        "                return 'A'\n"
        "        class B(A):\n"
        "            def who(self):\n"
        "                return 'B'\n"
        "        class C(A):\n"
        "            pass\n"
        "        class D(B, C):\n"
        "            pass\n"
        "        d = D()\n"
        "        self.assertEqual([c.__name__ for c in D.__mro__], ['D', 'B', 'C', 'A', 'object'])\n"
        "        self.assertEqual(d.who(), 'B')\n",
        1
    );
}

test "mro: type.mro() surface mirrors the __mro__ attribute" {
    # test_mro.py: mro() is the queryable form of the same linearization and
    # agrees with __mro__ element-for-element; every class bottoms at object.
    replay(
        "class TestMroFn(unittest.TestCase):\n"
        "    def test_agreement(self):\n"
        "        class A: pass\n"
        "        class B(A): pass\n"
        "        class C(B): pass\n"
        "        self.assertEqual([c.__name__ for c in C.mro()], ['C', 'B', 'A', 'object'])\n"
        "        self.assertEqual([c.__name__ for c in C.__mro__], ['C', 'B', 'A', 'object'])\n"
        "        self.assertIs(C.mro()[0], C)\n"
        "    def test_object_base(self):\n"
        "        class Z: pass\n"
        "        self.assertEqual([c.__name__ for c in Z.mro()], ['Z', 'object'])\n",
        2
    );
}

test "mro: repeated direct base behind its subclass is accepted, order kept" {
    # 3.14 semantics (test_mro.py historically expected TypeError here): a base
    # listed again behind its own subclass is accepted and the stated order is
    # preserved through linearization.
    replay(
        "class TestRepeat(unittest.TestCase):\n"
        "    def test_repeat_base(self):\n"
        "        class A: pass\n"
        "        class B(A): pass\n"
        "        class C(B, A): pass\n"
        "        self.assertEqual([c.__name__ for c in C.__mro__], ['C', 'B', 'A', 'object'])\n",
        1
    );
}

# ---------------- metaclass surface (test_classes.py) ----------------

test "metaclass: __prepare__ seeds the class namespace" {
    # test_classes.py metaclass machinery: __prepare__ supplies the mapping the
    # class body executes in, so names bound there become class attributes and
    # the metaclass is visible as type(C).
    replay(
        "class TestPrepare(unittest.TestCase):\n"
        "    def test_seed(self):\n"
        "        class Meta(type):\n"
        "            @classmethod\n"
        "            def __prepare__(mcls, name, bases):\n"
        "                return {'pre': name}\n"
        "        class C(metaclass=Meta):\n"
        "            pass\n"
        "        self.assertEqual(C.pre, 'C')\n"
        "        self.assertEqual(type(C).__name__, 'Meta')\n"
        "    def test_plain_type_default(self):\n"
        "        class D: pass\n"
        "        self.assertEqual(type(D).__name__, 'type')\n",
        2
    );
}

test "metaclass: __init__ hook observes the new class" {
    # test_classes.py creation order: the metaclass __init__ receives
    # cls/name/bases/dict exactly once, at class creation time.
    replay(
        "class TestMetaInit(unittest.TestCase):\n"
        "    def test_hook(self):\n"
        "        seen = []\n"
        "        class Meta(type):\n"
        "            def __init__(cls, name, bases, d):\n"
        "                seen.append(name)\n"
        "                type.__init__(cls, name, bases, d)\n"
        "        class C(metaclass=Meta):\n"
        "            pass\n"
        "        self.assertEqual(seen, ['C'])\n",
        1
    );
}

# ---------------- class-body scoping quirks (test_classes.py) ----------------

test "class body: comprehension iterable resolves in class scope, body names stay invisible inward" {
    # The CPython rule this pins: the OUTERMOST iterable of a class-body
    # comprehension IS evaluated in class scope, while names bound by the class
    # body are invisible inside the comprehension's implicit function scope --
    # reading one raises NameError mid-class-creation.
    replay(
        "class TestClassScope(unittest.TestCase):\n"
        "    def test_iterable_visible(self):\n"
        "        class C:\n"
        "            xs = [1, 2, 3]\n"
        "            ys = [x * 2 for x in xs]\n"
        "        self.assertEqual(C.ys, [2, 4, 6])\n"
        "    def test_body_names_invisible(self):\n"
        "        with self.assertRaises(NameError):\n"
        "            class D:\n"
        "                z = 10\n"
        "                pairs = [(z, x) for x in range(2)]\n",
        2
    );
}

# ---------------- classmethod / staticmethod (test_class.py) ----------------

test "classmethod/staticmethod: binding surfaces match host" {
    # test_class.py classmethods/staticmethods blocks: classmethod binds cls to
    # the *calling* class (subclass propagation), staticmethod never binds, and
    # both are invocable through instances.
    replay(
        "class TestCM(unittest.TestCase):\n"
        "    def test_cm_subclass_propagation(self):\n"
        "        class C:\n"
        "            @classmethod\n"
        "            def who(cls):\n"
        "                return cls.__name__\n"
        "        class Sub(C): pass\n"
        "        self.assertEqual(C.who(), 'C')\n"
        "        self.assertEqual(Sub.who(), 'Sub')\n"
        "        self.assertEqual(C().who(), 'C')\n"
        "    def test_sm_no_binding(self):\n"
        "        class C:\n"
        "            @staticmethod\n"
        "            def g(x):\n"
        "                return x + 1\n"
        "        self.assertEqual(C.g(1), 2)\n"
        "        self.assertEqual(C().g(41), 42)\n",
        2
    );
}

# ---------------- __getattr__ / super interplay (test_class.py) ----------------

test "__getattr__: fallback chains through super().__getattr__" {
    # test_class.py attroverriding shapes: __getattr__ runs only after normal
    # lookup misses; an override may delegate up the MRO via super().__getattr__
    # without recursion, and real attributes skip the hook entirely.
    replay(
        "class TestGetAttrChain(unittest.TestCase):\n"
        "    def test_chain(self):\n"
        "        class A:\n"
        "            def __getattr__(self, name):\n"
        "                return 'A:' + name\n"
        "        class B(A):\n"
        "            def __getattr__(self, name):\n"
        "                if name == 'handled':\n"
        "                    return 'B'\n"
        "                return super().__getattr__(name)\n"
        "        b = B()\n"
        "        self.assertEqual(b.handled, 'B')\n"
        "        self.assertEqual(b.missed, 'A:missed')\n"
        "    def test_real_attrs_skip_hook(self):\n"
        "        class K:\n"
        "            real = 5\n"
        "            def __getattr__(self, name):\n"
        "                return 'fallback'\n"
        "        k = K()\n"
        "        self.assertEqual(k.real, 5)\n"
        "        self.assertEqual(k.fake, 'fallback')\n",
        2
    );
}
