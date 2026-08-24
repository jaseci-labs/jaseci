# Type-object inherited dunder surface: CPython serves `Cls.__repr__` (and every
# other object slot) on guest-defined classes through the metaclass channel --
# type(Cls).__mro__ reaches object, whose type dict carries the slot wrappers.
# Regression guard for pprint's import-time `_dispatch[OrderedDict.__repr__]`
# family of lookups, which died with AttributeError before the tp_getattro
# fallback existed. Runs each behavior as a snippet so assertions carry the
# guest-observed value in the failure message.
import from layer_p2_libtest { p2_libtest_run_snippet }


test "plain class inherits object.__repr__ slot wrapper" {
    (ok, detail) = p2_libtest_run_snippet("class C: pass\nr = repr(C.__repr__)\nprint(r)");
    assert ok , "RUN<" + detail + ">";
    assert detail == "<slot wrapper '__repr__' of 'object' objects>" , "GOT<" + detail + ">";
}

test "native-base class inherits its base's wrapper" {
    (ok, detail) = p2_libtest_run_snippet("class D(dict): pass\nprint(repr(D.__repr__))");
    assert ok , "RUN<" + detail + ">";
    assert detail == "<slot wrapper '__repr__' of 'dict' objects>" , "GOT<" + detail + ">";
}

test "wrapper identity follows host object across lookups" {
    (ok, detail) = p2_libtest_run_snippet("class C: pass\na = C.__repr__\nb = C.__repr__\nprint(a is b, a == b)");
    assert ok , "RUN<" + detail + ">";
    # CPython: the same underlying slot wrapper object every lookup -> `is` True.
    assert detail == "True True" , "GOT<" + detail + ">";
}

test "explicitly defined dunder still wins over inherited wrapper" {
    (ok, detail) = p2_libtest_run_snippet("class D:\n    def __repr__(self):\n        return 'D!'\nr = repr(D.__repr__)\nprint(r.startswith('<function D.__repr__ at 0x'), repr(D()))");
    assert ok , "RUN<" + detail + ">";
    assert detail == "True D!" , "GOT<" + detail + ">";
}
