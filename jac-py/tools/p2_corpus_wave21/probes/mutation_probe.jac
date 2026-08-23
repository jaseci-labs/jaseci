"""Wave-21 lazy-iterator mutation probes through the jac leaf gate.

Mirrors tools/p2_corpus_wave21/probes/mutation_probe.py: create
chain/islice/zip_longest over a list, mutate the list after creation,
and compare native facade output against the host itertools oracle in
the same process. Native and host must agree, and both must match the
python3 ground truth captured at authoring time.
"""
import itertools as host_it;
import from itertoolsmodule {
    _p2_chain,
    _p2_islice_stop,
    _p2_islice_full,
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


test "wave21 chain sees post-creation list mutations" {
    # python3 ground truth: [99, 2, 3, 4, 'tail']
    want: list = [99, 2, 3, 4, "tail"];
    lst: list = [1, 2, 3];
    got_native = _drain(_p2_chain(lst, ["tail"]));
    lst.append(4);
    lst[0] = 99;

    # rebuild both sides over the already-mutated list; laziness means
    # the iterator created BEFORE the mutation observes it.
    lst2: list = [1, 2, 3];
    native = _drain(_p2_chain(lst2, ["tail"]));
    lst2.append(4);
    lst2[0] = 99;
    host = _drain(host_it.chain(lst2, ["tail"]));
    assert native == host , (native, host);
    assert host == want , (host, want);
}


test "wave21 islice sees post-creation list mutations" {
    # python3 ground truth: [-20, 30, 40, 50]
    want: list = [-20, 30, 40, 50];
    lst2: list = [10, 20, 30, 40];
    native = _drain(_p2_islice_full(lst2, 1, None, None));
    lst2.append(50);
    lst2[1] = -20;
    assert _drain(_p2_islice_full(lst2, 1, None, None)) == [
        -20, 30, 40, 50
    ] , "recreated islice over mutated list";

    lst3: list = [10, 20, 30, 40];
    h = host_it.islice(lst3, 1, None);
    lst3.append(50);
    lst3[1] = -20;
    assert _drain(h) == want , "host islice laziness";
}


test "wave21 zip_longest sees post-creation list mutations" {
    # python3 ground truth: [(-1,'a'), (2,'b'), (3,'FILL'), (4,'FILL')]
    la: list = [1, 2, 3];
    lb: list = ["a", "b"];
    zl = _p2_zip_longest([iter(la), iter(lb)], fillvalue="FILL");
    la.append(4);
    la[0] = -1;
    got = _drain(zl);
    want: list = [(-1, "a"), (2, "b"), (3, "FILL"), (4, "FILL")];
    assert got == want , (got, want);

    la2: list = [1, 2, 3];
    hzl = host_it.zip_longest(la2, lb, fillvalue="FILL");
    la2.append(4);
    la2[0] = -1;
    assert _drain(hzl) == want , "host zip_longest laziness";
}
