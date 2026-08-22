"""P2 wave 12 facade parity: native itertools count/cycle/repeat/chain vs host stdlib.

jac-py/Modules/itertoolsmodule.{c,jac} stay the staged c2jac corpus pair
(staging=lift); this file gates the product-path facade semantics.
"""

import itertools as host_it;
import from itertoolsmodule {
    _p2_count,
    _p2_cycle,
    _p2_cycle_setstate,
    _p2_repeat,
    _p2_chain,
    _p2_chain_from_iterable,
}


def _advance(it: any) -> any {
    return it.__next__();
}


def _take(it: any, n: int) -> list {
    out: list = [];
    for i in range(n) {
        out.append(_advance(it));
    }
    return out;
}


def _take_until_stop(it: any) -> list {
    out: list = [];
    while True {
        try {
            out.append(_advance(it));
        } except StopIteration {
            return out;
        }
    }
}


test "wave12 count agrees with host itertools.count" {
    cases: list = [(None, None), (5, None), (10, -2), (0, 0), (7, 3)];
    for (start, step) in cases {
        if start is None and step is None {
            got = _take(_p2_count(), 6);
            want = _take(host_it.count(), 6);
        } elif step is None {
            got = _take(_p2_count(start), 6);
            want = _take(host_it.count(start), 6);
        } else {
            got = _take(_p2_count(start, step), 6);
            want = _take(host_it.count(start, step), 6);
        }
        assert got == want , (start, step, got, want);
    }
    # float step forces CPython slow_mode (object arithmetic); both must agree
    got = _take(_p2_count(0, 0.5), 5);
    want = _take(host_it.count(0, 0.5), 5);
    assert got == want , (got, want);
    # non-number start is a TypeError on both sides
    raised = False;
    try {
        _p2_count("x");
    } except TypeError {
        raised = True;
    }
    assert raised , "count('x') must raise TypeError";
    # repr parity after advancing
    c = _p2_count();
    _advance(c);
    h = host_it.count();
    _advance(h);
    assert str(c) == str(h) , (str(c), str(h));
    c2 = _p2_count(1, 2);
    h2 = host_it.count(1, 2);
    assert str(c2) == str(h2) , (str(c2), str(h2));
    # large-step counts stay exact (arbitrary precision, no ssize_t clamp)
    big = _take(_p2_count(0, 2**64), 3);
    assert big == [0, 2**64, 2 * 2**64] , big;
}


test "wave12 cycle agrees with host itertools.cycle" {
    sources: list = ["AB", [1], [], (1, 2, 3)];
    for src in sources {
        got = _take(_p2_cycle(src), 7);
        want = _take(host_it.cycle(src), 7);
        assert got == want , (src, got, want);
    }
    # empty source exhausts immediately instead of spinning forever
    exhausted = False;
    try {
        _advance(_p2_cycle([]));
    } except StopIteration {
        exhausted = True;
    }
    assert exhausted , "cycle([]) must raise StopIteration";
    # setstate restore resumes from the saved sequence without re-draining
    lz = _p2_cycle([]);
    _p2_cycle_setstate(lz, ["x", "y"], 1);
    assert _take(lz, 3) == ["y", "x", "y"] , "setstate resume";
}


test "wave12 repeat agrees with host itertools.repeat" {
    assert _take(_p2_repeat("x"), 3) == _take(host_it.repeat("x"), 3);
    assert _take_until_stop(_p2_repeat(9, 4)) == [9, 9, 9, 9] , "bounded";
    assert _take_until_stop(_p2_repeat(1, 0)) == [] , "zero times";
    assert _take_until_stop(_p2_repeat(1, -5)) == [] , "negative times clamps to zero";
    assert str(_p2_repeat(2)) == str(host_it.repeat(2));
    assert str(_p2_repeat(2, 5)) == str(host_it.repeat(2, 5));
    ro = _p2_repeat(7, 3);
    ho = host_it.repeat(7, 3);
    _advance(ro);
    _advance(ho);
    assert ro.__length_hint__() == ho.__length_hint__() , "length_hint after advance";
    assert str(ro) == str(ho) , "bounded repr after advance";
    bad = False;
    try {
        _p2_repeat(1).__length_hint__();
    } except TypeError {
        bad = True;
    }
    assert bad , "unbounded length_hint raises TypeError";
}


test "wave12 chain agrees with host itertools.chain" {
    argsets: list = [
        [],
        ["ab"],
        ["ab", [1, 2]],
        [[], [1], [], (2, 3), ""],
    ];
    for args in argsets {
        got = _take_until_stop(_p2_chain(*args));
        want = _take_until_stop(host_it.chain(*args));
        assert got == want , (args, got, want);
    }
    nested = _take_until_stop(_p2_chain_from_iterable(["ab", [1, 2], (9,)]));
    want_nested = _take_until_stop(host_it.chain.from_iterable(["ab", [1, 2], (9,)]));
    assert nested == want_nested , (nested, want_nested);
}
