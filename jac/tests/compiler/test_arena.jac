"""Unit tests for the SyntaxArena typed surface (#8030 Part A).

The arena owns its encoding: stride-2 tag/value args, length-prefixed
seqs, and stride-3 posts are readable and writable only through the
accessor surface exercised here.
"""

import from jaclang.jac0core.arena { NIL, SPECS, SyntaxArena, Tag }
import from jaclang.jac0core.constant { ArgCat }
import from jaclang.jac0core.parser.frontend { parse }


def _tok(a: SyntaxArena, s: str) -> int {
    return a.mk_token(
        name="NAME",
        value=s,
        line=1,
        end_line=1,
        col_start=1,
        col_end=1 + len(s),
        pos_start=0,
        pos_end=len(s)
    );
}


test "node_count property counts the NIL sentinel row" {
    a = SyntaxArena();
    assert a.node_count == 1;
    _tok(a, "x");
    assert a.node_count == 2;
}


test "arg_pair is total: in-range tagged, out-of-range NONE" {
    a = SyntaxArena();
    t = _tok(a, "x");
    (tag0, sid) = a.arg_pair(t, 0);
    assert tag0 == Tag.STR , f"slot 0 (name) should be STR, got {tag0}";
    assert a.str_of(sid) == "NAME";
    (tag2, line) = a.arg_pair(t, 2);
    assert tag2 == Tag.INT and line == 1;
    assert a.arg_pair(t, 99) == (Tag.NONE, 0);
    assert a.arg_pairs(t)[2] == a.arg_pair(t, 2);
    assert len(a.arg_pairs(t)) == a.arg_ns[t];
}


test "typed readers raise on present-but-mismatched tag" {
    a = SyntaxArena();
    t = _tok(a, "x");
    int_raised = False;
    try {
        a.arg_int(t, 0);
    } except ValueError {
        int_raised = True;
    }
    assert int_raised , "arg_int on a STR slot must raise, not return the strtab index";
    str_raised = False;
    try {
        a.arg_str(t, 2);
    } except ValueError {
        str_raised = True;
    }
    assert str_raised , "arg_str on an INT slot must raise, not return None";
    assert a.arg_str(t, 99) is None;
    assert a.arg_int(t, 99) == 0;
}


test "deps_of covers kids, node args, and list-arg members" {
    a = SyntaxArena();
    lt = _tok(a, "(");
    x = _tok(a, "x");
    y = _tok(a, "y");
    rt = _tok(a, ")");
    tv = a.mk_tuple_val(values=[x, y], kid=[lt, x, y, rt]);
    deps = a.deps_of(tv);
    for d in [lt, x, y, rt] {
        assert d in deps , f"dep {d} missing from {deps}";
    }
}


test "post_entries decodes stride-3 records" {
    a = SyntaxArena();
    t = _tok(a, "x");
    a.post_set(t, "param_kind", 2);
    assert (t, "param_kind", 2, ) in a.post_entries();
}


test "append_record and intern_seq round-trip a node" {
    a = SyntaxArena();
    t = _tok(a, "x");
    off = a.intern_seq([t]);
    assert a.seq_ids(off) == [t];
    dup = a.append_record(a.kind_of(t), a.kid_ids(t), a.arg_pairs(t));
    assert dup != t;
    assert a.kind_of(dup) == a.kind_of(t);
    assert a.arg_pairs(dup) == a.arg_pairs(t);
    assert a.kid_ids(dup) == a.kid_ids(t);
}


test "set_kids_of retables children" {
    a = SyntaxArena();
    x = _tok(a, "x");
    y = _tok(a, "y");
    tv = a.mk_tuple_val(values=[x], kid=[x]);
    a.set_kids_of(tv, [x, y]);
    assert a.kid_ids(tv) == [x, y];
}


test "adopt_columns rebuilds a readable arena from raw columns" {
    src = SyntaxArena();
    t = _tok(src, "z");
    a = SyntaxArena();
    a.adopt_columns(
        kinds=list(src.kinds),
        kid_los=list(src.kid_los),
        kid_ns=list(src.kid_ns),
        arg_los=list(src.arg_los),
        arg_ns=list(src.arg_ns),
        kids=list(src.kids),
        args=[int(v) for v in src.args],
        seqs=list(src.seqs),
        posts=list(src.posts),
        strtab=list(src.strtab),
        root_id=t
    );
    assert a.root_id == t;
    assert a.kind_of(t) == src.kind_of(t);
    assert a.arg_pairs(t) == src.arg_pairs(t);
    assert a.str_of(a.arg_pair(t, 1)[1]) == "z";
}


test "SPECS rows are structured data, not encoded strings" {
    a = SyntaxArena();
    t = _tok(a, "x");
    spec = SPECS[a.kind_of(t)];
    assert spec[0] == "Token" , spec;
    assert spec[1] == True , "Token is token-family";
    assert isinstance(spec[3], tuple) , "params must be a tuple, not a string";
    (pname, cat, ename, hd) = spec[3][0];
    assert pname == "orig_src" and cat == ArgCat.SOURCE , spec[3][0];
    name_row = spec[3][1];
    assert name_row[0] == "name" and name_row[1] == ArgCat.STR , name_row;
}


test "materialized module unparse reaches fixpoint" {
    src = (
        "glob N: int = 3;\n"
        "\n"
        "obj Foo {\n"
        "    def bump(n: int) -> int {\n"
        "        return n + N;\n"
        "    }\n"
        "}\n"
        "\n"
        "with entry {\n"
        "    print(Foo().bump(2));\n"
        "}\n"
    );
    (mod, err) = parse(src, "t.jac");
    assert not err;
    out1 = mod.unparse(requires_format=False);
    (mod2, err2) = parse(out1, "t.jac");
    assert not err2;
    assert mod2.unparse(requires_format=False) == out1;
}

test "kind-heterogeneous probe reads stay within their kind" {
    src = "class Foo {\n    def greet {\n        self\n    }\n}\n";
    (mod, err) = parse(src, "t.jac");
    assert mod is not None , "bare special-var statement must parse";
}
