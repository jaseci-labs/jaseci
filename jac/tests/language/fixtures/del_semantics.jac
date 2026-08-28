# Every `del` form, per issue #8756.
#
# Attribute and subscript targets are pure Python: they remove a reference and
# never destroy. Names destroy when they hold graph objects, and also unbind.
# Every other expression destroys and does not unbind. Target lists recurse.
#
# The body lives in a function rather than in `with entry` so that `jac fmt
# --lintfix` cannot hoist a literal assignment into a `glob` and split the
# block in half.
node N {
    has t: str;
}

edge E {
    has w: int = 1;
}

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

def stale_edges(n: N) -> list[E] {
    return [edge n->:E:->];
}

"""A. Location targets: pure Python, no destruction."""
def location_targets {
    # A1: del d["k"]
    a1 = fresh("a1");
    d1 = {"k": a1};
    before = nkids();
    del d1["k"];
    assert "k" not in d1 , "A1 key survived";
    assert nkids() == before , "A1 graph effect";
    assert a1.t == "a1" , "A1 node still usable";
    # A2: del L[i]
    a2 = fresh("a2");
    l2 = [a2];
    before = nkids();
    del l2[0];
    assert len(l2) == 0 , "A2 list not spliced";
    assert nkids() == before , "A2 graph effect";
    # A3: del o.x
    a3 = fresh("a3");
    h3 = Holder(slot=a3);
    before = nkids();
    del h3.slot;
    assert "slot" not in h3.__dict__ , "A3 slot survived";
    assert nkids() == before , "A3 graph effect";
    # A4: del L[i:j], which index deletion now agrees with
    s1 = fresh("s1");
    s2 = fresh("s2");
    s3 = fresh("s3");
    l4 = [s1, s2, s3];
    before = nkids();
    del l4[0:2];
    assert len(l4) == 1 , "A4 slice not spliced";
    assert nkids() == before , "A4 graph effect";
    # A5: del L[::2]
    l5 = [1, 2, 3, 4, 5];
    del l5[::2];
    assert l5 == [2, 4] , "A5 strided removal";
    # A6: del L[i][j]
    l6 = [[1, 2, 3]];
    del l6[0][1];
    assert l6 == [[1, 3]] , "A6 nested delitem";
    # A7: del <name> holding a node, the one deliberate divergence from Python
    a7 = fresh("a7");
    before = nkids();
    del a7;
    assert nkids() == before - 1 , "A7 graph effect";
    # A8: del <name> holding a plain value is an unbind only
    a8 = 5;
    before = nkids();
    del a8;
    assert nkids() == before , "A8 graph effect";
    # A9: del (a, b) recurses per target
    a9 = fresh("a9");
    b9 = fresh("b9");
    before = nkids();
    del (a9, b9);
    assert nkids() == before - 2 , "A9 graph effect";
    # A10: del [a, b] recurses per target
    a10 = fresh("a10");
    b10 = fresh("b10");
    before = nkids();
    del [a10, b10];
    assert nkids() == before - 2 , "A10 graph effect";
    # A11: del [d[k], o.x] is a delitem plus a delattr, with no destruction
    a11 = fresh("a11");
    b11 = fresh("b11");
    d11 = {"k": a11};
    h11 = Holder(slot=b11);
    before = nkids();
    del [d11["k"], h11.slot];
    assert "k" not in d11 , "A11 key survived";
    assert "slot" not in h11.__dict__ , "A11 slot survived";
    assert nkids() == before , "A11 graph effect";
    # A12: the single element tuple idiom
    d12 = {"k": 1};
    del (d12["k"], );
    assert "k" not in d12 , "A12 key survived";
}

"""B. Value targets: destroy, no unbind."""
def value_targets {
    # B1: a name bound to a collection of edges
    n1 = N("n1");
    n2 = N("n2");
    n1 +>:E:+> n2;
    n1 +>:E:+> n2;
    n1 +>:F:+> n2;
    es = [edge n1->:E:->];
    assert len(es) == 2 , "B1 setup";
    del es;
    assert len([edge n1->:E:->]) == 0 , "B1 graph effect";
    assert len([edge n1->:F:->]) == 1 , "B1 other edge types";
    # B2: an edge-ref trailer, the form that did not compile at all before
    b1 = N("b1");
    b2 = N("b2");
    b1 +>:E:+> b2;
    b1 +>:E:+> b2;
    b1 +>:F:+> b2;
    del [edge b1->:E:->];
    assert len([edge b1->:E:->]) == 0 , "B2 E edges";
    assert len([edge b1->:F:->]) == 1 , "B2 F edges untouched";
    # B3: the node-yielding form destroys the nodes, not the edges
    c1 = fresh("c1");
    c2 = N("c2");
    c1 +>:E:+> c2;
    before = nkids();
    del [c1->:E:->];
    assert nkids() == before , "B3 c1 survives";
    assert len([edge c1->:E:->]) == 0 , "B3 edge went with the node";
    # B4: an untyped traversal
    d1n = fresh("d1n");
    d1n ++> N("d2n");
    d1n ++> N("d3n");
    del [d1n-->];
    assert len([d1n-->]) == 0 , "B4 successors";
    # B5: a filtered edge-ref trailer
    e1 = N("e1");
    e2 = N("e2");
    e1 +>:E:+> e2;
    e1 +>:E:+> e2;
    del [edge e1->:E:w>0:->];
    assert len([edge e1->:E:->]) == 0 , "B5 filtered";
    # B6: a comprehension over edges
    f1 = N("f1");
    f2 = N("f2");
    f1 +>:E:+> f2;
    f1 +>:F:+> f2;
    del [
        e
        for e in [edge f1-->]
        if isinstance(e, E)
    ];
    assert len([edge f1->:E:->]) == 0 , "B6 comprehension E";
    assert len([edge f1->:F:->]) == 1 , "B6 comprehension F";
    # B7: a call returning graph objects
    g1 = N("g1");
    g2 = N("g2");
    g1 +>:E:+> g2;
    del stale_edges(g1);
    assert len([edge g1->:E:->]) == 0 , "B7 call target";
    # B8: nested value targets are flattened
    h1 = N("h1");
    h2 = N("h2");
    h1 +>:E:+> h2;
    i1 = N("i1");
    i2 = N("i2");
    i1 +>:E:+> i2;
    del [[edge h1->:E:->], [edge i1->:E:->]];
    assert len([edge h1->:E:->]) == 0 , "B8 first";
    assert len([edge i1->:E:->]) == 0 , "B8 second";
    # B9: a set literal is a value target, not a target list
    j1 = fresh("j1");
    j2 = fresh("j2");
    before = nkids();
    del {j1, j2};
    assert nkids() == before - 2 , "B9 set literal";
    # B10: a value target that yields nothing is not an error
    k1 = N("k1");
    del [edge k1->:E:->];
    # B11: a value target yielding a non-graph object raises, and nothing is
    # destroyed before it does
    l1 = fresh("l1");
    before = nkids();
    raised = False;
    try {
        del [l1, 5];
    } except TypeError {
        raised = True;
    }
    assert raised , "B11 no TypeError";
    assert nkids() == before , "B11 destroyed before validating";
    # B12: del <name> holding a plain collection is an unbind, not an error
    m1 = [1, 2, 3];
    del m1;
}

"""C. Several comma separated targets."""
def multi_targets {
    # C1: names, attributes and subscripts in one statement
    n1c = fresh("n1c");
    n2c = fresh("n2c");
    d1c = {"k": 1};
    h1c = Holder(slot=None);
    before = nkids();
    del n1c , n2c , d1c["k"] , h1c.slot;
    assert nkids() == before - 2 , "C1 graph effect";
    assert "k" not in d1c , "C1 key survived";
    assert "slot" not in h1c.__dict__ , "C1 slot survived";
    # C2: destruction across targets is all or nothing
    o1c = fresh("o1c");
    before = nkids();
    raised = False;
    try {
        del o1c , [2];
    } except TypeError {
        raised = True;
    }
    assert raised , "C2 no TypeError";
    assert nkids() == before , "C2 destroyed before validating";
}

with entry {
    location_targets();
    value_targets();
    multi_targets();
    print("del semantics: all cases ok");
}
