"""P2 wave 19 facade parity: native deque + defaultdict vs host stdlib.

Staged ``jac-py/Modules/collectionsmodule.{c,jac}`` stay the c2jac corpus
pair (staging=lift); this file gates the product-path facade semantics in
jac-py/jacpython/_collectionsmodule.jac against the pinned host oracle.
Expected values and error messages were verified against the host stdlib
``_collections`` at authoring time.
"""

import _collections as host_coll;
import from _collectionsmodule {
    _p2_defaultdict,
    _p2_deque,
}


def _drain(it: any) -> list {
    out: list = [];
    while True {
        try {
            out.append(next(it));
        } except StopIteration {
            break;
        }
    }
    return out;
}


def _expect_pop_empty() {
    g = _p2_deque();
    raised = False;
    got_type = "";
    got = "";
    try {
        g.pop();
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    assert raised , "pop empty: expected an error";
    assert got_type == "IndexError" , got_type;
    assert got == "pop from an empty deque" , got;

    raised = False;
    try {
        g.popleft();
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    assert raised and got_type == "IndexError"
        and got == "pop from an empty deque" , (got_type, got);
}


def _expect_maxlen_negative() {
    raised = False;
    got_type = "";
    got = "";
    try {
        _p2_deque(maxlen=-1);
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    assert raised and got_type == "ValueError"
        and got == "maxlen must be non-negative" , (got_type, got);
}


def _expect_oob(label: str, mode: str) {
    d = _p2_deque([10, 20]);
    raised = False;
    got_type = "";
    got = "";
    try {
        if mode == "get" {
            _ = d[9];
        } elif mode == "set" {
            d[9] = 1;
        } else {
            d.__delitem__(-9);
        }
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    assert raised , label + ": expected an error";
    assert got_type == "IndexError" , (label, got_type);
    assert got == "deque index out of range" , (label, got);
}


def _expect_slice_reject(op: str) {
    d = _p2_deque([10, 20]);
    raised = False;
    got_type = "";
    got = "";
    try {
        if op == "get" {
            _ = d[::2];
        } elif op == "set" {
            d[::2] = [];
        } else {
            del d[::2];
        }
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    # Deques expose only sq_item/sq_ass_item; every slice raises the host's
    # sequence-index message (verified against host 3.14).
    assert raised and got_type == "TypeError"
        and got == "sequence index must be integer, not 'slice'" , (op, got_type, got);
}


def _expect_index_non_int() {
    d = _p2_deque([10, 20]);
    raised = False;
    got = "";
    try {
        _ = d["s"];
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised and got == "sequence index must be integer, not 'str'" , got;
}


def _expect_concat_error() {
    a = _p2_deque([1, 2]);
    raised = False;
    got = "";
    try {
        a.__add__([1]);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised
        and got == 'can only concatenate deque (not "list") to deque' , got;
}


def _expect_repeat_error() {
    a = _p2_deque([1, 2]);
    raised = False;
    got = "";
    try {
        a.__mul__(1.5);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised
        and got == "can't multiply sequence by non-int of type 'float'" , got;
}


def _expect_order_vs_list() {
    a = _p2_deque([1, 2]);
    raised = False;
    got = "";
    try {
        _ = a.__lt__([1]);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised
        and got == "'<' not supported between instances of 'collections.deque'"
                   " and 'list'" , got;
}


def _expect_iter_poisoned() {
    d = _p2_deque([1, 2, 3]);
    it = iter(d);
    _ = next(it);
    d.append(4);
    raised = False;
    got = "";
    try {
        next(it);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised and got == "deque mutated during iteration" , got;
    # Every subsequent next keeps raising (counter zeroed, state mismatch first).
    raised = False;
    try {
        next(it);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised and got == "deque mutated during iteration" , got;
}


def _expect_reviter_poisoned() {
    d = _p2_deque([1, 2, 3]);
    r = reversed(d);
    _ = next(r);
    d.rotate(1);
    raised = False;
    got = "";
    try {
        next(r);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised and got == "deque mutated during iteration" , got;
}


def _expect_factory_not_callable() {
    raised = False;
    got_type = "";
    got = "";
    try {
        _p2_defaultdict(5);
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    assert raised and got_type == "TypeError"
        and got == "first argument must be callable or None" , (got_type, got);
}


def _expect_none_factory_keyerror() {
    dd = _p2_defaultdict();
    raised = False;
    got_type = "";
    got = "";
    try {
        _ = dd[1];
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    assert raised and got_type == "KeyError" and got == "1" , (got_type, got);
}


def _expect_del_missing_key() {
    dd = _p2_defaultdict();
    raised = False;
    got_type = "";
    got = "";
    try {
        del dd["nope"];
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    assert raised and got_type == "KeyError" and got == "'nope'" , (got_type, got);
}


test "wave19 deque core: construction, maxlen trimming, pop/popleft" {
    assert repr(_p2_deque()) == "deque([])";
    assert repr(_p2_deque([1, 2, 3])) == "deque([1, 2, 3])";
    assert repr(_p2_deque("ab")) == "deque(['a', 'b'])";
    assert repr(_p2_deque(maxlen=3)) == "deque([], maxlen=3)";

    d = _p2_deque([1], maxlen=2);
    d.append(2);
    assert repr(d) == "deque([1, 2], maxlen=2)" , repr(d);
    d.append(3);
    assert repr(d) == "deque([2, 3], maxlen=2)" , repr(d);
    d.appendleft(9);
    assert repr(d) == "deque([9, 2], maxlen=2)" , repr(d);

    e = _p2_deque(maxlen=0);
    e.extend([1, 2, 3]);
    assert repr(e) == "deque([], maxlen=0)" , repr(e);

    f = _p2_deque([1, 2, 3]);
    assert f.pop() == 3;
    assert f.popleft() == 1;
    assert len(f) == 1;
    assert repr(f) == "deque([2])";

    h = _p2_deque([10, 20, 30]);
    assert h[True] == 20 and h[False] == 10 , "bool indexes like C longs";

    _expect_pop_empty();
    _expect_maxlen_negative();
}


test "wave19 deque surface: extend/index/count/remove/insert/rotate" {
    d = _p2_deque([1, 2, 99, 3, 4, 5]);
    d.insert(2, 100);
    assert repr(d) == "deque([1, 2, 100, 99, 3, 4, 5])" , repr(d);
    d.insert(-1, 77);
    assert repr(d) == "deque([1, 2, 100, 99, 3, 4, 77, 5])" , repr(d);

    e = _p2_deque("abc");
    e.extendleft("xy");
    assert repr(e) == "deque(['y', 'x', 'a', 'b', 'c'])" , repr(e);

    f = _p2_deque([0, 1, 2, 3, 4, 5, 6, 7]);
    f.rotate(3);
    assert repr(f) == "deque([5, 6, 7, 0, 1, 2, 3, 4])" , repr(f);
    f.rotate(-5);
    assert repr(f) == "deque([2, 3, 4, 5, 6, 7, 0, 1])" , repr(f);
    f.rotate(100);
    assert repr(f) == "deque([6, 7, 0, 1, 2, 3, 4, 5])" , repr(f);
    f.rotate();
    assert repr(f) == "deque([5, 6, 7, 0, 1, 2, 3, 4])" , repr(f);

    g = _p2_deque([8, 9]);
    g.rotate(100);
    assert repr(g) == "deque([8, 9])" , repr(g);

    h = _p2_deque([3, 1, 2]);
    h.reverse();
    assert repr(h) == "deque([2, 1, 3])" , repr(h);

    i = _p2_deque(["a", "b", "c", "b"]);
    assert i.index("b") == 1;
    assert i.index("b", 2) == 3;
    assert i.index("a", -99) == 0;
    assert i.count("b") == 2;
    assert i.count("zz") == 0;
    assert ("c" in i) is True;
    assert ("z" in i) is False;

    j = _p2_deque([1, 2, 3]);
    j.remove(2);
    assert repr(j) == "deque([1, 3])" , repr(j);

    k = _p2_deque(maxlen=3);
    k.extend([1, 2, 3, 4]);
    assert repr(k) == "deque([2, 3, 4], maxlen=3)" , repr(k);

    m = _p2_deque([1, 2, 3]);
    m.clear();
    assert repr(m) == "deque([])";
    n = m.copy();
    n.append(42);
    assert repr(m) == "deque([])" and repr(n) == "deque([42])";

    full = _p2_deque([1], maxlen=1);
    raised = False;
    got = "";
    try {
        full.insert(0, 5);
    } except Exception as ex {
        raised = True;
        got = str(ex);
    }
    assert raised and got == "deque already at its maximum size" , got;
}


test "wave19 deque item access: get/set/del, slices rejected" {
    d = _p2_deque([10, 20, 30, 40]);
    assert d[0] == 10 and d[-1] == 40 and d[2] == 30;

    d[0] = "x";
    assert repr(d) == "deque(['x', 20, 30, 40])" , repr(d);
    del d[1];
    assert repr(d) == "deque(['x', 30, 40])" , repr(d);

    _expect_oob("getitem", "get");
    _expect_oob("setitem", "set");
    _expect_oob("delitem", "del");
    _expect_slice_reject("get");
    _expect_slice_reject("set");
    _expect_slice_reject("del");
    _expect_index_non_int();

    missing = _p2_deque([1, 2, 3]);
    raised = False;
    got = "";
    try {
        missing.index(12345);
    } except Exception as ex {
        raised = True;
        got = str(ex);
    }
    assert raised and got == "deque.index(x): x not in deque" , got;

    absent = _p2_deque([1, 2, 3]);
    raised = False;
    try {
        absent.remove(12345);
    } except Exception as ex {
        raised = True;
        got = str(ex);
    }
    assert raised and got == "deque.remove(x): x not in deque" , got;
}


test "wave19 deque concat/repeat/comparisons match host" {
    a = _p2_deque([1, 2]);
    b = _p2_deque([3]);
    assert repr(a.__add__(b)) == "deque([1, 2, 3])";
    assert repr(b.__add__(a)) == "deque([3, 1, 2])";
    assert repr(a.__mul__(2)) == "deque([1, 2, 1, 2])";
    assert repr(a.__rmul__(2)) == "deque([1, 2, 1, 2])";
    assert repr(a.__mul__(-1)) == "deque([])";
    assert repr(_p2_deque([1], maxlen=2) * 2) == "deque([1, 1], maxlen=2)";

    assert (a == _p2_deque([1, 2])) is True;
    assert (a == _p2_deque([1])) is False;
    assert (a != _p2_deque([1])) is True;
    assert (_p2_deque([1]) < _p2_deque([1, 0])) is True;
    assert (_p2_deque([1, 9]) <= _p2_deque([2])) is True;
    assert (_p2_deque([2]) > _p2_deque([1, 9])) is True;
    assert (_p2_deque([1]) >= _p2_deque([1])) is True;

    _expect_concat_error();
    _expect_repeat_error();
    _expect_order_vs_list();

    self_ref = _p2_deque([1, 2]);
    self_ref.extend(self_ref);
    assert repr(self_ref) == "deque([1, 2, 1, 2])" , repr(self_ref);
}


test "wave19 deque iterators invalidate on mutation" {
    d = _p2_deque([1, 2, 3]);
    assert _drain(iter(d)) == [1, 2, 3];
    assert _drain(reversed(d)) == [3, 2, 1];

    itv: any = iter(d);
    assert next(itv) == 1;
    assert itv.__length_hint__() == 2;
    d.append(4);
    _expect_iter_poisoned();
    _expect_reviter_poisoned();

    fresh = _p2_deque([5, 6]);
    redi: any = iter(fresh);
    red = redi.__reduce__();
    assert len(red) == 2 and red[1] == (fresh, 0) , "dequeiter_reduce shape";

    rev = reversed(fresh);
    assert _drain(rev) == [6, 5];
}


test "wave19 deque reduce/repr shapes are pickle-compat" {
    plain = _p2_deque([1, 2]);
    red = plain.__reduce__();
    assert len(red) == 4 , red;
    assert red[1] == () and red[2] is None;
    assert _drain(red[3]) == [1, 2];

    capped = _p2_deque([1], maxlen=2);
    redc = capped.__reduce__();
    assert redc[1] == (2,) , redc[1];

    assert repr(_p2_deque([1, 2], maxlen=9)) == "deque([1, 2], maxlen=9)";
}


test "wave19 defaultdict matches host semantics" {
    assert repr(_p2_defaultdict(int, {"a": 1}))
        == "defaultdict(<class 'int'>, {'a': 1})";
    assert repr(_p2_defaultdict()) == "defaultdict(None, {})";
    assert repr(_p2_defaultdict(list)) == "defaultdict(<class 'list'>, {})";

    dd = _p2_defaultdict(int, {"a": 1});
    assert dd["a"] == 1;
    assert dd["b"] == 0;
    assert repr(dd) == "defaultdict(<class 'int'>, {'a': 1, 'b': 0})" , repr(dd);

    d2 = _p2_defaultdict(list, [(1, "x"), (2, "y")]);
    assert repr(d2) == "defaultdict(<class 'list'>, {1: 'x', 2: 'y'})" , repr(d2);
    assert d2[9] == [] and len(d2) == 3;

    c = d2.copy();
    assert c.default_factory is list and c == d2;

    merged = d2 | {3: "z"};
    assert len(merged) == 4 and merged[3] == "z";
    assert len(d2) == 3 , "| must not mutate the left operand";

    e = _p2_defaultdict(int, {1: "x", 2: "y"});
    assert (e == {1: "x", 2: "y"}) is True;
    assert (e == {1: "x"}) is False;
    assert (e != {1: "x"}) is True;
    assert (e == _p2_defaultdict(int, {2: "y", 1: "x"})) is True , "order-free eq";

    del d2[1];
    assert repr(d2) == "defaultdict(<class 'list'>, {2: 'y', 9: []})" , repr(d2);
    assert d2.keys() == [2, 9] and d2.values() == ["y", []];
    assert list(iter(d2)) == [2, 9];

    calls: list = [];
    def factory() -> str {
        calls.append(1);
        return "v";
    }
    d3 = _p2_defaultdict(factory);
    assert d3["k"] == "v" and len(calls) == 1 , "factory called once, no args";
    assert d3.get("k") == "v" and d3.get("missing", "dflt") == "dflt";

    red = d2.__reduce__();
    assert len(red) == 5 , red;
    assert red[1] == (list,) and red[2] is None and red[3] is None;
}


test "wave19 defaultdict errors match host" {
    _expect_factory_not_callable();
    _expect_none_factory_keyerror();
    _expect_del_missing_key();
}
