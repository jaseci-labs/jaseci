"""Semantic facade parity: native jacpython bisect/heapq vs host stdlib.

Modules/*.jac stay C-API hand oracles (byte-identity is getplatform-only).
"""

import bisect as host_bisect;
import heapq as host_heapq;
import from _bisectmodule {
    _p2_bisect_right,
    _p2_bisect_left,
    _p2_insort,
    _p2_insort_left,
}
import from _heapqmodule { _p2_heappush, _p2_heappop, _p2_heapify }


test "P2 bisect facade agrees with host bisect on representative cases" {
    cases: list = [
        ([], 1),
        ([1], 1),
        ([1, 2, 3], 2),
        ([1, 1, 2, 2], 1.5),
        ([1, 2, 2, 3, 3, 3, 4, 4, 4, 4], 3),
        ([0, 0, 0, 0], 0),
        (list(range(20)), 7),
    ];
    for (data, item) in cases {
        a = list(data);
        b = list(data);
        assert _p2_bisect_right(a, item) == host_bisect.bisect_right(b, item) , (
            f"bisect_right {data!r} {item!r}"
        );
        assert _p2_bisect_left(a, item) == host_bisect.bisect_left(b, item) , (
            f"bisect_left {data!r} {item!r}"
        );
    }
    a = [1, 2, 3];
    b = [1, 2, 3];
    assert _p2_bisect_right(a, 2, 0, 2) == host_bisect.bisect_right(b, 2, 0, 2);
    assert _p2_bisect_left(a, 2, 1, 3) == host_bisect.bisect_left(b, 2, 1, 3);

    d1 = [1, 3, 5];
    d2 = [1, 3, 5];
    _p2_insort(d1, 4);
    host_bisect.insort(d2, 4);
    assert d1 == d2 , d1;
    _p2_insort_left(d1, 3);
    host_bisect.insort_left(d2, 3);
    assert d1 == d2 , d1;
}

test "P2 heapq facade agrees with host heapq on representative cases" {
    src = [5, 1, 9, 3, 7, 2, 8, 4, 6, 0];
    a = list(src);
    b = list(src);
    _p2_heapify(a);
    host_heapq.heapify(b);
    assert a == b , (a, b);

    a = [];
    b = [];
    for x in [3, 1, 4, 1, 5, 9, 2, 6] {
        _p2_heappush(a, x);
        host_heapq.heappush(b, x);
        assert a == b , (a, b);
    }
    out_a: list = [];
    out_b: list = [];
    while a {
        out_a.append(_p2_heappop(a));
        out_b.append(host_heapq.heappop(b));
    }
    assert out_a == out_b , (out_a, out_b);
    assert out_a == sorted([3, 1, 4, 1, 5, 9, 2, 6]);
}
