"""P2 wave 21 itertools parity: islice/zip_longest/groupby/batched/takewhile/dropwhile.

jac-py/Modules/itertoolsmodule.{c,jac} grew the wave-12 kernel set with the
wave-21 slices (islice skip/stop ladder, zip_longest numactive countdown,
groupby head-run scan, batched short-batch decision, takewhile/dropwhile
sticky flips); this file gates the product-path facade behaviors those
kernels mirror, against the host itertools oracle. Expected values were
verified against real python3 at authoring time (see
tools/p2_corpus_wave21/probes/mutation_probe.py).
"""

import itertools as host_it;
import from itertoolsmodule {
    _p2_batched,
    _p2_chain,
    _p2_dropwhile,
    _p2_groupby,
    _p2_islice_full,
    _p2_islice_stop,
    _p2_takewhile,
    _p2_zip_longest,
}


def _drain(it: any) -> list {
    out: list = [];
    while True {
        try {
            out.append(it.__next__());
        } except StopIteration {
            return out;
        }
    }
}


test "wave21 islice step>1 clamps next at stop like host" {
    # python3: list(islice(range(100), 2, 10, 3)) == [2, 5, 8]
    want: list = [2, 5, 8];
    got_native = _drain(_p2_islice_full(range(100), 2, 10, 3));
    got_host = list(host_it.islice(range(100), 2, 10, 3));
    assert got_native == want , got_native;
    assert got_host == want , got_host;

    # stop smaller than start exhausts immediately on both sides
    assert _drain(_p2_islice_full(range(100), 10, 5, 3)) == [] , "empty native";
    assert list(host_it.islice(range(100), 10, 5, 3)) == [] , "empty host";

    # step advance beyond stop collapses to stop; iteration still ends
    got_native = _drain(_p2_islice_full(range(20), 0, None, 4));
    got_host = list(host_it.islice(range(20), 0, None, 4));
    assert got_native == got_host , (got_native, got_host);
}


test "wave21 islice stop-only matches host" {
    cases: list = [(0, []), (3, [0, 1, 2])];
    for (stop, want) in cases {
        got_native = _drain(_p2_islice_stop(range(10), stop));
        got_host = list(host_it.islice(range(10), stop));
        assert got_native == want , (stop, got_native);
        assert got_host == want , (stop, got_host);
    }
}


test "wave21 zip_longest pads with fillvalue and stops when all dry" {
    la: list = [1, 2, 3];
    lb: list = ["a"];
    got_native = _drain(
        _p2_zip_longest([iter(la), iter(lb)], fillvalue="FILL")
    );
    got_host = list(host_it.zip_longest(la, lb, fillvalue="FILL"));
    want: list = [(1, "a"), (2, "FILL"), (3, "FILL")];
    assert got_native == want , got_native;
    assert got_host == want , got_host;

    # zero active sources end immediately
    assert _drain(_p2_zip_longest([], fillvalue=None)) == [] , "no sources";
}


test "wave21 groupby peels one run per outer next like host" {
    keys = [1, 1, 2, 2, 2, 3];

    def _key(x: any) -> any {
        return x;
    }

    gb = _p2_groupby(keys, _key);
    got: list = [];
    while True {
        try {
            k_g = gb.__next__();
        } except StopIteration {
            break;
        }
        got.append((k_g[0], len(list(k_g[1]))));
    }
    got_host: list = [];
    for k_g in host_it.groupby(keys) {
        got_host.append((k_g[0], len(list(k_g[1]))));
    }
    want: list = [(1, 2), (2, 3), (3, 1)];
    assert got == want , got;
    assert got_host == want , got_host;
}


test "wave21 batched short tail: lenient resizes, strict raises" {
    seq = [1, 2, 3, 4, 5];
    got_native = [list(b) for b in _p2_batched(seq, 2)];
    want: list = [[1, 2], [3, 4], [5]];
    assert got_native == want , got_native;

    raised = False;
    try {
        list(_p2_batched(seq, 2, strict=True));
    } except ValueError as e {
        raised = True;
        assert str(e) == "batched(): incomplete batch" , str(e);
    }
    assert raised , "expected strict ValueError";

    raised = False;
    try {
        list(host_it.batched([1, 2, 3, 4, 5], 2, strict=True));
    } except ValueError as e {
        raised = True;
        assert str(e) == "batched(): incomplete batch" , str(e);
    }
    assert raised , "expected host strict ValueError";
}


test "wave21 takewhile/dropwhile latch exactly once like host" {
    seq = [1, 2, 3, 1, 2];

    def _lt3(x: any) -> bool {
        return x < 3;
    }

    got_native_tw = _drain(_p2_takewhile(_lt3, seq));
    got_host_tw = list(host_it.takewhile(_lt3, seq));
    want_tw: list = [1, 2];
    assert got_native_tw == want_tw , got_native_tw;
    assert got_host_tw == want_tw , got_host_tw;

    got_native_dw = _drain(_p2_dropwhile(_lt3, seq));
    got_host_dw = list(host_it.dropwhile(_lt3, seq));
    want_dw: list = [3, 1, 2];
    assert got_native_dw == want_dw , got_native_dw;
    assert got_host_dw == want_dw , got_host_dw;
}


test "wave21 lazy iterators observe post-creation source mutations" {
    # python3 ground truth via tools/p2_corpus_wave21/probes/mutation_probe.py
    lst: list = [1, 2, 3];
    ch = _p2_chain(lst, ["tail"]);
    lst.append(4);
    lst[0] = 99;
    assert _drain(ch) == [99, 2, 3, 4, "tail"] , "chain laziness";

    lst2: list = [10, 20, 30, 40];
    isl = _p2_islice_full(lst2, 1, None, None);
    lst2.append(50);
    lst2[1] = -20;
    assert _drain(isl) == [-20, 30, 40, 50] , "islice laziness";

    la: list = [1, 2, 3];
    lb: list = ["a", "b"];
    zl = _p2_zip_longest([iter(la), iter(lb)], fillvalue="FILL");
    la.append(4);
    la[0] = -1;
    assert _drain(zl) == [
        (-1, "a"), (2, "b"), (3, "FILL"), (4, "FILL")
    ] , "zip_longest laziness";
}
