"""P2 wave 14 facade parity: native array vs host stdlib array.

jac-py/Modules/arraymodule.{c,jac} stay the staged c2jac corpus pair
(staging=lift); this file gates the product-path facade semantics in
jacpython/arrayobject.jac against the pinned host oracle (CPython 3.14).
Run with JACPATH=jac-py/jacpython (same pattern as test_p2_facade_parity).
"""

import array as host_arr;
import from arrayobject {
    _p2_array,
}
import from warnings { catch_warnings, simplefilter }


def _take(it: any) -> list {
    out: list = [];
    while True {
        try {
            out.append(it.__next__());
        } except StopIteration {
            return out;
        }
    }
}


test "wave14 typecode table matches host itemsize" {
    codes: list = ["b", "B", "u", "w", "h", "H", "i", "I", "l", "L", "q", "Q", "f", "d"];
    for tc in codes {
        mine = _p2_array(tc);
        # Host promotes DeprecationWarning to error under the test runner;
        # 'u' warns by design (deprecated, removal slated 3.16).
        with catch_warnings() {
            simplefilter("ignore");
            host = host_arr.array(tc);
        }
        assert mine.itemsize == host.itemsize , (tc, mine.itemsize, host.itemsize);
        assert mine.typecode == host.typecode , tc;
        assert len(mine) == len(host) , tc;
    }
    raised = False;
    try {
        _p2_array("z");
    } except ValueError as e {
        raised = str(e) == "bad typecode (must be b, B, u, w, h, H, i, I, l, L, q, Q, f or d)";
    }
    assert raised , "unknown typecode";
}


test "wave14 int storage round-trips within typecode bounds" {
    cases: list = [
        ("b", [0, 1, -1, 127, -128]),
        ("B", [0, 255, 7]),
        ("h", [32767, -32768, 0]),
        ("H", [65535, 0]),
        ("i", [2147483647, -2147483648]),
        ("I", [4294967295, 0]),
        ("l", [9223372036854775807, -9223372036854775808]),
        ("L", [18446744073709551615, 0]),
        ("q", [9223372036854775807, -9223372036854775808]),
        ("Q", [18446744073709551615, 0]),
    ];
    for (tc, vals) in cases {
        mine = _p2_array(tc, vals);
        host = host_arr.array(tc, vals);
        assert mine.tolist() == host.tolist() , (tc,);
        assert str(mine) == str(host) , (tc, str(mine), str(host));
    }
    # byte-level identity for multi-byte signed/unsigned pairs
    assert _p2_array("i", [-2]).tobytes() == host_arr.array("i", [-2]).tobytes();
    assert _p2_array("I", [4294967294]).tobytes() == host_arr.array("I", [4294967294]).tobytes();
}


test "wave14 overflow and type errors agree with host messages" {
    bads: list = [
        ("b", 128), ("b", -129),
        ("B", 256), ("B", -1),
        ("h", 32768), ("h", -32769),
        ("H", 65536), ("H", -1),
        ("i", 2147483648), ("i", -2147483649),
        ("I", 4294967296), ("I", -1),
        ("l", 9223372036854775808), ("l", -9223372036854775809),
        ("q", 9223372036854775808), ("q", -9223372036854775809),
        ("Q", 18446744073709551616), ("Q", -1),
    ];
    for (tc, v) in bads {
        got_msg: str = "";
        want_msg: str = "";
        try {
            _p2_array(tc, [v]);
        } except OverflowError as e {
            got_msg = str(e);
        }
        try {
            host_arr.array(tc, [v]);
        } except OverflowError as e {
            want_msg = str(e);
        }
        assert got_msg == want_msg and got_msg != "" , (tc, v, got_msg, want_msg);
    }
    # float into int arrays
    got_type: bool = False;
    want_type: bool = False;
    try {
        _p2_array("b", [1.5]);
    } except TypeError as e {
        got_type = str(e) == "'float' object cannot be interpreted as an integer";
    }
    try {
        host_arr.array("b", [1.5]);
    } except TypeError as e {
        want_type = str(e) == "'float' object cannot be interpreted as an integer";
    }
    assert got_type and want_type , (got_type, want_type);
}


test "wave14 float arrays round-trip through bytes" {
    fvals: list = [0.5, -1.25, 0.1, 123456.789];
    dvals: list = [0.1, -2.25, 1e300, 5e-324];
    mine_f = _p2_array("f", fvals);
    host_f = host_arr.array("f", fvals);
    assert mine_f.tobytes() == host_f.tobytes() , "f32 bytes";
    assert mine_f.tolist() == host_f.tolist() , (mine_f.tolist(), host_f.tolist());
    mine_d = _p2_array("d", dvals);
    host_d = host_arr.array("d", dvals);
    assert mine_d.tobytes() == host_d.tobytes() , "f64 bytes";
    assert mine_d.tolist() == host_d.tolist();
    # saturation past float32 range is silent on both sides
    assert _p2_array("f", [5e38])[0] == host_arr.array("f", [5e38])[0] , "sat +inf";
    assert _p2_array("f", [-5e38])[0] == host_arr.array("f", [-5e38])[0] , "sat -inf";
    # ints coerce into float arrays
    assert _p2_array("f", [2])[0] == host_arr.array("f", [2])[0];
    rt: bool = False;
    try {
        _p2_array("f", ["x"]);
    } except TypeError as e {
        rt = str(e) == "must be real number, not str";
    }
    hwant: bool = False;
    try {
        host_arr.array("f", ["x"]);
    } except TypeError as e {
        hwant = str(e) == "must be real number, not str";
    }
    assert rt and hwant;
}


test "wave14 char arrays match host u/w behavior" {
    # 'u' is deprecated on the host (DeprecationWarning, removal 3.16);
    # suppress so warning-as-error does not mask value parity.
    mine_u = _p2_array("u", "ab\u00e9");
    # same runner-promoted warning as above
    with catch_warnings() {
        simplefilter("ignore");
        host_u = host_arr.array("u", "ab\u00e9");
    }
    assert mine_u[2] == host_u[2] , "char getitem";
    assert mine_u.tounicode() == host_u.tounicode();
    assert str(mine_u) == str(host_u) , (str(mine_u), str(host_u));
    mine_w = _p2_array("w");
    host_w = host_arr.array("w");
    mine_w.fromunicode("xy");
    host_w.fromunicode("xy");
    assert mine_w.tounicode() == host_w.tounicode();
    assert mine_w.tobytes() == host_w.tobytes() , "ucs4 le bytes";
    raised_mine: bool = False;
    raised_host: bool = False;
    try {
        _p2_array("b").tounicode();
    } except ValueError {
        raised_mine = True;
    }
    try {
        host_arr.array("b").tounicode();
    } except ValueError {
        raised_host = True;
    }
    assert raised_mine and raised_host;
}


test "wave14 construction from bytes/list/array agrees with host" {
    src_b = b"\x01\x02\x03\x04";
    assert _p2_array("H", bytearray(src_b)).tolist() == host_arr.array("H", bytearray(src_b)).tolist();
    assert _p2_array("h", src_b).tolist() == host_arr.array("h", src_b).tolist();
    assert _p2_array("d", host_arr.array("d", [1.5]).tobytes()).tolist() == [1.5];
    m = _p2_array("b", [1, 2]);
    h2 = host_arr.array("b", [1, 2]);
    assert _p2_array("b", m).tolist() == host_arr.array("b", h2).tolist();
    short: bool = False;
    try {
        _p2_array("I", b"\x01\x02\x03");
    } except ValueError as e {
        short = str(e) == "bytes length not a multiple of item size";
    }
    assert short , "misaligned frombytes";
    wrong: bool = False;
    try {
        _p2_array("b", "ab");
    } except TypeError as e {
        wrong = str(e) == "cannot use a str to initialize an array with typecode 'b'";
    }
    assert wrong;
}


test "wave14 index access and slices agree with host" {
    mine = _p2_array("i", [10, 20, 30, 40, 50]);
    host = host_arr.array("i", [10, 20, 30, 40, 50]);
    for idx in [0, 4, -1, -5] {
        assert mine[idx] == host[idx] , idx;
    }
    oob: bool = False;
    try {
        mine[5];
    } except IndexError as e {
        oob = str(e) == "array index out of range";
    }
    assert oob;
    for sl in [(1, 3, 1), (None, None, 2), (3, None, -1), (None, None, -2), (0, 0, 1)] {
        s = slice(sl[0], sl[1], sl[2]);
        assert mine[s].tolist() == host[s].tolist() , sl;
        assert str(mine[s]) == str(host[s]) , sl;
    }
    # setitem / delitem
    mine[0] = 99;
    host[0] = 99;
    assert mine.tolist() == host.tolist();
    mine[-1] = 11;
    host[-1] = 11;
    assert mine.tolist() == host.tolist();
    assign_fail: bool = False;
    try {
        mine[9] = 1;
    } except IndexError as e {
        assign_fail = str(e) == "array assignment index out of range";
    }
    assert assign_fail;
    del mine[1];
    del host[1];
    assert mine.tolist() == host.tolist();
    del mine[0:2];
    del host[0:2];
    assert mine.tolist() == host.tolist();
}


test "wave14 mutation ops agree with host" {
    mine = _p2_array("q", [3, 1, 2]);
    host = host_arr.array("q", [3, 1, 2]);
    mine.append(9);
    host.append(9);
    mine.insert(0, 7);
    host.insert(0, 7);
    mine.insert(-2, 6);
    host.insert(-2, 6);
    assert mine.tolist() == host.tolist() , "insert";
    assert mine.pop() == host.pop();
    assert mine.pop(0) == host.pop(0);
    assert mine.pop(-1) == host.pop(-1);
    assert mine.tolist() == host.tolist();
    empty_fail: bool = False;
    try {
        _p2_array("b").pop();
    } except IndexError as e {
        empty_fail = str(e) == "pop from empty array";
    }
    assert empty_fail;
    mine.remove(1);
    host.remove(1);
    miss: bool = False;
    try {
        mine.remove(1000);
    } except ValueError as e {
        miss = str(e) == "array.remove(x): x not in array";
    }
    assert miss;
    mine.extend(mine);
    host.extend(host);
    assert mine.tolist() == host.tolist() , "self extend";
    mine.extend([42, 43]);
    host.extend([42, 43]);
    assert mine.tolist() == host.tolist();
    mine.reverse();
    host.reverse();
    assert mine.tolist() == host.tolist();
    assert mine.count(42) == host.count(42);
    assert mine.index(43) == host.index(43);
    mine.clear();
    host.clear();
    assert len(mine) == len(host) == 0;
}


test "wave14 arithmetic agrees with host" {
    a = _p2_array("b", [1, 2]);
    ha = host_arr.array("b", [1, 2]);
    b = _p2_array("b", [3]);
    hb = host_arr.array("b", [3]);
    assert str(a + b) == str(ha + hb);
    c = _p2_array("b", [1]);
    hc = host_arr.array("b", [1]);
    c += _p2_array("b", [2, 3]);
    hc += host_arr.array("b", [2, 3]);
    assert str(c) == str(hc);
    assert str(a * 2) == str(ha * 2);
    assert str(3 * b) == str(3 * hb);
    add_bad: bool = False;
    try {
        a + [1];
    } except TypeError {
        add_bad = True;
    }
    assert add_bad;
    mul_neg = a * -1;
    assert len(mul_neg) == 0 and len(ha * -1) == 0;
}


test "wave14 comparisons agree with host" {
    cases: list = [
        ([1, 2], [1, 2]),
        ([1, 2], [1, 3]),
        ([1, 2], [1, 2, 3]),
        ([], []),
        ([2], [1, 9]),
    ];
    for (x, y) in cases {
        mx = _p2_array("b", x);
        my = _p2_array("b", y);
        hx = host_arr.array("b", x);
        hy = host_arr.array("b", y);
        assert (mx == my) == (hx == hy) , (x, y);
        assert (mx != my) == (hx != hy) , (x, y);
        assert (mx < my) == (hx < hy) , (x, y);
        assert (mx <= my) == (hx <= hy) , (x, y);
        assert (mx > my) == (hx > hy) , (x, y);
        assert (mx >= my) == (hx >= hy) , (x, y);
    }
    # cross-typecode equality compares values, not typecodes
    assert (_p2_array("b", [1]) == _p2_array("B", [1])) == (
        host_arr.array("b", [1]) == host_arr.array("B", [1])
    );
}


test "wave14 iterators behave like host" {
    mine_it = _p2_array("i", [5, 6, 7]).__iter__();
    host_it = iter(host_arr.array("i", [5, 6, 7]));
    assert _take(mine_it) == list(host_it);
    # for-in protocol
    total: int = 0;
    for v in _p2_array("i", [1, 2, 3]) {
        total += v;
    }
    assert total == 6;
}


test "wave14 buffer_info shape and byteswap agree with host" {
    mine = _p2_array("H", [1, 258]);
    host = host_arr.array("H", [1, 258]);
    mine.byteswap();
    host.byteswap();
    assert mine.tolist() == host.tolist() , (mine.tolist(), host.tolist());
    odd = _p2_array("b", [3, 1, 2]);
    odd.byteswap();
    assert odd.tolist() == [3, 1, 2] , "itemsize 1 no-op";
    bi = mine.buffer_info();
    assert len(bi) == 2 and bi[1] == len(host) , "buffer_info count element";
}
