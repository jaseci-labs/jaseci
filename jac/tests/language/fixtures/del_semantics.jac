# Characterization of every `del` form, per issue #8756.
#
# DS0 lands this against TODAY's behavior so that the DS1 rule change shows up
# as an intended diff in this file rather than as a silent behavior swap. Cases
# whose meaning changes in DS1 are marked `# DS1:`.
node N {
    has t: str;
}

edge E {}

edge F {}

obj Holder {
    has slot: N | None = None;
}

def nkids -> int {
    return len([root-->]);
}

def fresh(t: str) -> N {
    n = N(t);
    root ++> n;
    return n;
}

with entry {
    # ------------------------------------------------------------------
    # A. Location targets
    # ------------------------------------------------------------------
    # A1: del d["k"]
    a1 = fresh("a1");
    d1 = {"k": a1};
    before = nkids();
    del d1["k"];
    assert "k" not in d1 , "A1 key survived";
    # DS1: the node must survive; today the entry removal destroys it.
    assert nkids() == before - 1 , "A1 graph effect";
    # A2: del L[i]
    a2 = fresh("a2");
    l2 = [a2];
    before = nkids();
    del l2[0];
    assert len(l2) == 0 , "A2 list not spliced";
    # DS1: the node must survive.
    assert nkids() == before - 1 , "A2 graph effect";
    # A3: del o.x
    a3 = fresh("a3");
    h3 = Holder(slot=a3);
    before = nkids();
    del h3.slot;
    assert "slot" not in h3.__dict__ , "A3 slot survived";
    # DS1: the node must survive.
    assert nkids() == before - 1 , "A3 graph effect";
    # A4: del L[i:j] -- slices already leave the graph alone, by accident.
    s1 = fresh("s1");
    s2 = fresh("s2");
    s3 = fresh("s3");
    l4 = [s1, s2, s3];
    before = nkids();
    del l4[0:2];
    assert len(l4) == 1 , "A4 slice not spliced";
    assert nkids() == before , "A4 graph effect";
}

glob
     # A5: del L[::2]
     l5 = [1, 2, 3, 4, 5];

with entry {
    del l5[::2];
    assert l5 == [2, 4] , "A5 strided removal";
}

glob
     # A6: del L[i][j]
     l6 = [[1, 2, 3]];

with entry {
    del l6[0][1];
    assert l6 == [[1, 3]] , "A6 nested delitem";
    # A7: del <name> holding a node -- destroy plus unbind.
    a7 = fresh("a7");
    before = nkids();
    del a7;
    assert nkids() == before - 1 , "A7 graph effect";
}

glob
     # A8: del <name> holding a plain value -- unbind only.
     a8 = 5;

with entry {
    before = nkids();
    del a8;
    assert nkids() == before , "A8 graph effect";
    # A9: del (a, b) -- recurse per target.
    a9 = fresh("a9");
    b9 = fresh("b9");
    before = nkids();
    del (a9, b9);
    assert nkids() == before - 2 , "A9 graph effect";
    # A10: del [a, b] -- recurse per target.
    a10 = fresh("a10");
    b10 = fresh("b10");
    before = nkids();
    del [a10, b10];
    assert nkids() == before - 2 , "A10 graph effect";
    # A11: del [d[k], o.x] -- delitem plus delattr, no destroy.
    a11 = fresh("a11");
    b11 = fresh("b11");
    d11 = {"k": a11};
    h11 = Holder(slot=b11);
    before = nkids();
    del [d11["k"], h11.slot];
    assert "k" not in d11 , "A11 key survived";
    assert "slot" not in h11.__dict__ , "A11 slot survived";
    # DS1: both nodes must survive.
    assert nkids() == before - 2 , "A11 graph effect";
}

glob
     # A12: del (d[k], ) -- the single-element-tuple idiom used in the tree.
     d12 = {"k": 1};

with entry {
    del (d12["k"], );
    assert "k" not in d12 , "A12 key survived";
    # ------------------------------------------------------------------
    # B. Value targets -- every one of these is E5043 today, so DS0 can only
    # characterize the shapes that do compile.
    # ------------------------------------------------------------------
    # B1: a name bound to a collection of edges.
    n1 = N("n1");
    n2 = N("n2");
    n1 +>:E:+> n2;
    n1 +>:E:+> n2;
    n1 +>:F:+> n2;
    es = [edge n1->:E:->];
    assert len(es) == 2 , "B1 setup";
    del es;
    # DS1: the two E edges must be destroyed, the F edge left alone.
    assert len([edge n1->:E:->]) == 2 , "B1 graph effect";
    assert len([edge n1->:F:->]) == 1 , "B1 other edge types";
    print("del semantics: all cases ok");
}
