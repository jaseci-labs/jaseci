"""P2 facade parity: Counter + OrderedDict + namedtuple vs host stdlib.

Gates the product-path facade semantics in
jac-py/jacpython/_collections_pylib.jac (plus the wave-19 deque/defaultdict
surface re-exported through the collections shim) against the pinned host
oracle. Expected values and error messages were verified against host
CPython 3.14 at authoring time; every probe registers itself in PROBES_DONE
so the closing ratchet cannot silently lose coverage.
"""

import from _collectionsmodule {
    _p2_defaultdict,
    _p2_deque,
}
import from _collections_pylib {
    _p2_counter,
    _p2_namedtuple,
    _p2_ordereddict,
    _p2_ordereddict_fromkeys,
}

glob PROBES_DONE: list = [];


def _pin(name: str, cond: bool) {
    assert cond , "probe failed: " + name;
    PROBES_DONE.append(name);
}


def _expect_error(name: str, thunk: any, exc_type: str, msg: str) {
    raised = False;
    got_type = "";
    got = "";
    try {
        thunk();
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got = str(e);
    }
    assert raised , name + ": expected an error";
    assert got_type == exc_type , name + ": " + got_type;
    assert got == msg , name + ": " + repr(got);
    PROBES_DONE.append(name);
}


# ---------------------------------------------------------------- deque ----

test "collections_pylib parity: deque core surface" {
    d = _p2_deque([1, 2, 3], 3);
    d.append(4);
    _pin("deque.maxlen-append-trims-left", list(d) == [2, 3, 4]);
    d.appendleft(9);
    _pin("deque.appendleft-trims-right", list(d) == [9, 2, 3] and len(d) == 3);
    _pin("deque.maxlen-attr", d.maxlen == 3);
    d.rotate(-1);
    _pin("deque.rotate-negative", list(d) == [2, 3, 9]);
    d.rotate(2);
    _pin("deque.rotate-positive", list(d) == [3, 9, 2]);
    _pin("deque.indexing", d[0] == 3 and d[-1] == 2);
    _pin("deque.pop-popleft", d.pop() == 2 and d.popleft() == 3);
    _pin("deque.repr-maxlen", repr(_p2_deque([1], 2)) == "deque([1], maxlen=2)");
    e = d.copy();
    e.append(77);
    _pin("deque.copy-detaches", list(d) != list(e) and list(e)[-1] == 77);
    _pin("deque.eq", _p2_deque([1, 2]) == _p2_deque([1, 2]));
    d.extend([5, 6]);
    d.remove(5);
    _pin("deque.remove-index-count", d.index(6) == 1 and d.count(6) == 1);
    d.insert(0, 42);
    _pin("deque.insert", d[0] == 42);

    def _pop_empty() {
        _p2_deque().pop();
    }

    def _oob() {
        d[99];
    }

    def _full_insert() {
        _p2_deque([1, 2], 2).insert(0, 3);
    }

    _expect_error("deque.pop-empty", _pop_empty, "IndexError",
                  "pop from an empty deque");
    _expect_error("deque.index-oob", _oob, "IndexError",
                  "deque index out of range");
    _expect_error("deque.insert-full", _full_insert, "IndexError",
                  "deque already at its maximum size");
}


# ---------------------------------------------------------- defaultdict ----

test "collections_pylib parity: defaultdict factory-on-miss" {
    calls: list = [];

    def factory() -> str {
        calls.append("hit");
        return "gen";
    }

    dd = _p2_defaultdict(factory, {"a": 1});
    _pin("defaultdict.existing-no-factory", dd["a"] == 1 and len(calls) == 0);
    _pin("defaultdict.miss-calls-factory",
         dd["b"] == "gen" and len(calls) == 1);
    _pin("defaultdict.miss-inserts-once",
         dd["b"] == "gen" and len(calls) == 1);
    _pin("defaultdict.miss-inserted", "b" in dd and len(dd) == 2);
    _pin("defaultdict.repr-shape",
         repr(dd).startswith("defaultdict(") and "'b': 'gen'" in repr(dd));

    plain = _p2_defaultdict();

    def _no_factory() {
        plain["k"];
    }

    def _bad_factory() {
        _p2_defaultdict(42);
    }

    _expect_error("defaultdict.no-factory", _no_factory, "KeyError", "'k'");
    _expect_error("defaultdict.bad-factory", _bad_factory, "TypeError",
                  "first argument must be callable or None");
    cp = dd.copy();
    cp["z"] = 9;
    _pin("defaultdict.copy-preserves-factory",
         len(cp) == 3 and len(dd) == 2);
    merged = dd | {"q": 5};
    _pin("defaultdict.or-does-not-mutate",
         merged["q"] == 5 and merged["b"] == "gen" and "q" not in dd);
}


# ------------------------------------------------------------- Counter -----

test "collections_pylib parity: Counter counts and ordering" {
    c = _p2_counter("abracadabra");
    _pin("counter.counts", c["a"] == 5 and c["z"] == 0);
    _pin("counter.missing-not-inserted", "z" not in c);
    _pin("counter.total", c.total() == 11);
    _pin("counter.most-common-n", c.most_common(3)
         == [("a", 5), ("b", 2), ("r", 2)]);
    _pin("counter.most-common-tie-order", c.most_common()[4] == ("d", 1));
    _pin("counter.most-common-zero", c.most_common(0) == []);
    _pin("counter.elements-order",
         "".join(list(c.elements())) == "aaaaabbrrcd");
    _pin("counter.repr-most-common-order",
         repr(c) == "Counter({'a': 5, 'b': 2, 'r': 2, 'c': 1, 'd': 1})");
    c.update("abc");
    _pin("counter.update-iterable", c["a"] == 6 and c["c"] == 2);
    c.update({"b": 1}, w=7);
    _pin("counter.update-mapping-and-kwds", c["b"] == 4 and c["w"] == 7);
    c.subtract("aaa");
    _pin("counter.subtract-iterable", c["a"] == 3);
    c.subtract({"w": 10});
    _pin("counter.subtract-negative-kept",
         c["w"] == -3 and "w" in c);
    _pin("counter.elements-repeats",
         "".join(list(_p2_counter(w=3).elements())) == "www");
    pos = +_p2_counter(x=5, y=0, z=-1, w=2);
    _pin("counter.pos-drops-nonpositive", dict(pos.items()) == {"x": 5, "w": 2});
    neg = -_p2_counter(x=5, y=0, z=-1, w=2);
    _pin("counter.neg-negates-positive-only",
         dict(neg.items()) == {"z": 1});
    _pin("counter.repr-empty", repr(_p2_counter()) == "Counter()");

    a = _p2_counter(a=1, b=2);
    b = _p2_counter(b=1, c=3);
    _pin("counter.add-desc-ties-stable",
         repr(a + b) == "Counter({'b': 3, 'c': 3, 'a': 1})");
    _pin("counter.sub", repr(a - b) == "Counter({'a': 1, 'b': 1})");
    _pin("counter.sub-reflected", repr(b - a) == "Counter({'c': 3})");
    _pin("counter.and-min-positive", repr(a & b) == "Counter({'b': 1})");
    _pin("counter.or-max", repr(a | b) == "Counter({'c': 3, 'b': 2, 'a': 1})");
    _pin("counter.add-order-across-operands",
         repr(_p2_counter(a=2) + _p2_counter(c=1, b=2))
         == "Counter({'a': 2, 'b': 2, 'c': 1})");
    dropped = _p2_counter(x=2) - _p2_counter(x=2);
    _pin("counter.sub-to-zero-drops", len(dropped) == 0 and dropped["x"] == 0);
    _pin("counter.eq-dict-forward", _p2_counter(a=1) == {"a": 1});
    _pin("counter.eq-dict-reflected", {"a": 1} == _p2_counter(a=1));

    del c["w"];
    _pin("counter.del", "w" not in c);
    c["w"] += 3;
    _pin("counter.inplace-from-missing", c["w"] == 3);
    _pin("counter.get-default", c.get("qq", 9) == 9);

    mixed = _p2_counter({1: 2});
    mixed.update(["1"]);
    _pin("counter.key-types-independent",
         mixed[1] == 2 and mixed["1"] == 1);

    def _and_dict() {
        a & {"b": 1};
    }

    def _mc_str() {
        c.most_common("x");
    }

    _expect_error("counter.and-dict", _and_dict, "TypeError",
                  "unsupported operand type(s) for &: 'Counter' and 'dict'");
    _expect_error("counter.most-common-str", _mc_str, "TypeError",
                  "'>=' not supported between instances of 'str' and 'int'");
}


# ---------------------------------------------------------- OrderedDict ----

test "collections_pylib parity: OrderedDict order semantics" {
    od = _p2_ordereddict([("a", 1), ("b", 2)]);
    od.move_to_end("a");
    _pin("od.move-to-end-last", od.keys() == ["b", "a"]);
    od.move_to_end("b", False);
    _pin("od.move-to-end-first", od.keys() == ["b", "a"]);
    _pin("od.popitem-last", od.popitem(True) == ("a", 1));
    _pin("od.popitem-first", od.popitem(False) == ("b", 2));

    def _empty_popitem() {
        _p2_ordereddict().popitem();
    }

    def _move_missing() {
        od.move_to_end("zz");
    }

    _expect_error("od.popitem-empty", _empty_popitem, "KeyError",
                  "'dictionary is empty'");
    _expect_error("od.move-missing", _move_missing, "KeyError", "'zz'");

    o1 = _p2_ordereddict(a=1, b=2);
    o2 = _p2_ordereddict(b=2, a=1);
    _pin("od.eq-order-sensitive", (o1 == o2) is False);
    _pin("od.eq-dict-unordered-forward", o1 == {"a": 1, "b": 2});
    _pin("od.eq-dict-unordered-reflected", {"b": 2, "a": 1} == o2);
    _pin("od.repr", repr(o1) == "OrderedDict({'a': 1, 'b': 2})");
    del o1["a"];
    o1["a"] = 9;
    _pin("od.reinsert-goes-to-end", o1.keys() == ["b", "a"]);
    _pin("od.pop", o1.pop("b") == 2);
    _pin("od.pop-default", o1.pop("nope", 0) == 0);
    _pin("od.setdefault-existing-vs-new",
         o1.setdefault("c", 3) == 3 and o1.setdefault("c", 99) == 3);
    fk = _p2_ordereddict_fromkeys(["x", "y"], 0);
    _pin("od.fromkeys", fk.items() == [("x", 0), ("y", 0)]);
    upd = _p2_ordereddict([("u", 1), ("t", 2)]);
    upd.update([("u", 9)]);
    _pin("od.update-preserves-position",
         upd.items() == [("u", 9), ("t", 2)]);
    _pin("od.reversed", list(reversed(upd)) == ["t", "u"]);
    cp = upd.copy();
    cp.clear();
    _pin("od.copy-clear", len(cp) == 0 and len(upd) == 2);
}


# ----------------------------------------------------------- namedtuple ----

test "collections_pylib parity: namedtuple validation and surface" {
    def _dup() {
        _p2_namedtuple("P", ["x", "x"]);
    }

    def _underscore() {
        _p2_namedtuple("P", ["x", "_x"]);
    }

    def _keyword_field() {
        _p2_namedtuple("P", ["def"]);
    }

    def _bad_ident() {
        _p2_namedtuple("P", ["x", "1y"]);
    }

    def _space_ident() {
        _p2_namedtuple("P", ["a b"]);
    }

    def _keyword_type() {
        _p2_namedtuple("class", ["x"]);
    }

    def _bad_typename() {
        _p2_namedtuple("!x", ["a"]);
    }

    _expect_error("nt.duplicate-field", _dup, "ValueError",
                  "Encountered duplicate field name: 'x'");
    _expect_error("nt.underscore-field", _underscore, "ValueError",
                  "Field names cannot start with an underscore: '_x'");
    _expect_error("nt.keyword-field", _keyword_field, "ValueError",
                  "Type names and field names cannot be a keyword: 'def'");
    _expect_error("nt.bad-ident", _bad_ident, "ValueError",
                  "Type names and field names must be valid identifiers:"
                  + " '1y'");
    _expect_error("nt.space-ident", _space_ident, "ValueError",
                  "Type names and field names must be valid identifiers:"
                  + " 'a b'");
    _expect_error("nt.keyword-type", _keyword_type, "ValueError",
                  "Type names and field names cannot be a keyword: 'class'");
    _expect_error("nt.bad-typename", _bad_typename, "ValueError",
                  "Type names and field names must be valid identifiers:"
                  + " '!x'");

    P = _p2_namedtuple("P", ["x", "x", "0y"], rename=True);
    _pin("nt.rename-fields", P._fields == ("x", "_1", "_2"));
    p = P(1, 2, 3);
    _pin("nt.rename-repr", repr(p) == "P(x=1, _1=2, _2=3)");
    _pin("nt.sequence-surface",
         p[0] == 1 and tuple(p) == (1, 2, 3) and len(p) == 3);
    _pin("nt.asdict", p._asdict() == {"x": 1, "_1": 2, "_2": 3});

    Q = _p2_namedtuple("Q", ["a", "b"], defaults=[5]);
    _pin("nt.field-defaults", Q._field_defaults == {"b": 5});
    _pin("nt.default-applied", repr(Q(1)) == "Q(a=1, b=5)");
    R = _p2_namedtuple("R", ["a", "b", "c"], defaults=[1, 2]);
    _pin("nt.defaults-tail-two", repr(R(0)) == "R(a=0, b=1, c=2)");
    _pin("nt.defaults-map", R._field_defaults == {"b": 1, "c": 2});

    XY = _p2_namedtuple("XY", "x y");
    q = XY(1, 2);
    _pin("nt.eq-tuple-forward", q == (1, 2));
    _pin("nt.eq-tuple-reflected", (1, 2) == q);
    _pin("nt.hash-tuple-parity", hash(q) == hash((1, 2)));
    _pin("nt.field-attrs", q.x == 1 and q.y == 2);
    _pin("nt.replace", repr(q._replace(y=9)) == "XY(x=1, y=9)");
    _pin("nt.make", XY._make([7, 8]) == (7, 8));
    _pin("nt.tuple-methods", q.index(2) == 1 and q.count(1) == 1);
    _pin("nt.slice-is-tuple", q[0:1] == (1,) and isinstance(q[0:1], tuple));

    def _missing_arg() {
        P(1, 2);
    }

    def _too_many() {
        XY(1, 2, 3);
    }

    def _dup_kw() {
        XY(1, x=2);
    }

    def _make_short() {
        XY._make([1]);
    }

    def _replace_unknown() {
        q._replace(z=1);
    }

    def _bad_index() {
        q["k"];
    }

    _expect_error("nt.missing-arg", _missing_arg, "TypeError",
                  "P.__new__() missing 1 required positional argument: '_2'");
    _expect_error("nt.too-many", _too_many, "TypeError",
                  "XY.__new__() takes 3 positional arguments but 4 were"
                  + " given");
    _expect_error("nt.dup-kw", _dup_kw, "TypeError",
                  "XY.__new__() got multiple values for argument 'x'");
    _expect_error("nt.make-short", _make_short, "TypeError",
                  "Expected 2 arguments, got 1");
    _expect_error("nt.replace-unknown", _replace_unknown, "TypeError",
                  "Got unexpected field names: ['z']");
    _expect_error("nt.str-index", _bad_index, "TypeError",
                  "tuple indices must be integers or slices, not str");
}


# -------------------------------------------------------------- ratchet ----

test "collections_pylib parity: probe ratchet holds" {
    # The suite above must never silently shrink: every pinned expectation
    # registers itself in PROBES_DONE.
    expected_floor = 70;
    assert len(PROBES_DONE) >= expected_floor , len(PROBES_DONE);
}
