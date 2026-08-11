impl SyntaxArena.postinit{
    self._reserve_nil_row();
}

impl SyntaxArena.node_count.getter -> int {
    return len(self.kinds);
}

impl SyntaxArena.intern(s: str) -> StrId {
    if s in self._intern {
        return self._intern[s];
    }
    idx = len(self.strtab);
    self.strtab.append(s);
    self._intern[s] = idx;
    return idx;
}

impl SyntaxArena.str_of(sid: StrId) -> str {
    return self.strtab[sid];
}

impl SyntaxArena.kind_of(i: NodeId) -> KindId {
    return self.kinds[i];
}

impl SyntaxArena.kid_ids(i: NodeId) -> list[NodeId] {
    lo = self.kid_los[i];
    return self.kids[lo:lo + self.kid_ns[i]];
}

impl SyntaxArena.arg_pair(i: NodeId, slot: int) -> tuple[(Tag, int)] {
    if slot < 0 or slot >= self.arg_ns[i] {
        return (Tag.NONE, 0);
    }
    p = self._arg_ptr(i, slot);
    return (self.args[p], self.args[p + 1]);
}

impl SyntaxArena.arg_pairs(i: NodeId) -> list[tuple[(Tag, int)]] {
    lo = self.arg_los[i];
    out: list[tuple[(Tag, int)]] = [];
    for s in range(self.arg_ns[i]) {
        p = lo + (s * 2);
        out.append((self.args[p], self.args[p + 1], ));
    }
    return out;
}

impl SyntaxArena.arg_node(i: NodeId, slot: int) -> NodeId {
    (tag, v) = self.arg_pair(i, slot);
    if tag == Tag.NONE {
        return NIL;
    }
    if tag != Tag.NODE {
        self._bad_tag(i, slot, Tag.NODE, tag);
    }
    return v;
}

impl SyntaxArena.arg_str(i: NodeId, slot: int) -> (str | None) {
    (tag, v) = self.arg_pair(i, slot);
    if tag == Tag.NONE {
        return None;
    }
    if tag != Tag.STR {
        self._bad_tag(i, slot, Tag.STR, tag);
    }
    return self.strtab[v];
}

impl SyntaxArena.arg_int(i: NodeId, slot: int) -> int {
    (tag, v) = self.arg_pair(i, slot);
    if tag == Tag.NONE {
        return 0;
    }
    if tag != Tag.INT {
        self._bad_tag(i, slot, Tag.INT, tag);
    }
    return v;
}

impl SyntaxArena.arg_bool(i: NodeId, slot: int) -> bool {
    (tag, v) = self.arg_pair(i, slot);
    if tag == Tag.NONE {
        return False;
    }
    if tag != Tag.BOOL {
        self._bad_tag(i, slot, Tag.BOOL, tag);
    }
    return v != 0;
}

impl SyntaxArena.arg_list(i: NodeId, slot: int) -> (list[NodeId] | None) {
    (tag, v) = self.arg_pair(i, slot);
    if tag == Tag.NONE {
        return None;
    }
    if tag != Tag.LIST {
        self._bad_tag(i, slot, Tag.LIST, tag);
    }
    return self.seq_ids(v);
}

impl SyntaxArena.seq_ids(off: SeqOff) -> list[NodeId] {
    n = self.seqs[off];
    return self.seqs[off + 1:off + 1 + n];
}

impl SyntaxArena.deps_of(i: NodeId) -> list[NodeId] {
    deps = self.kid_ids(i);
    for pr in self.arg_pairs(i) {
        (tag, v) = pr;
        if tag == Tag.NODE {
            deps.append(v);
        } elif tag == Tag.LIST {
            deps.extend(self.seq_ids(v));
        }
    }
    return deps;
}

impl SyntaxArena.post_entries -> list[tuple[(NodeId, str, int)]] {
    out: list[tuple[(NodeId, str, int)]] = [];
    j = 0;
    n = len(self.posts);
    while j + 2 < n {
        out.append(
            (self.posts[j], self.strtab[self.posts[j + 1]], self.posts[j + 2], )
        );
        j += 3;
    }
    return out;
}

impl SyntaxArena.intern_seq(ids: list[NodeId]) -> SeqOff {
    off = len(self.seqs);
    self.seqs.append(len(ids));
    self.seqs.extend(ids);
    return off;
}

impl SyntaxArena.append_record(
    kind: KindId, kid: list[NodeId], pairs: list[tuple[(Tag, int)]]
) -> NodeId {
    idx = self._start(kind, kid, len(pairs));
    for pr in pairs {
        (tag, v) = pr;
        self.args.append(tag);
        self.args.append(v);
    }
    return idx;
}

impl SyntaxArena.set_arg_node(i: NodeId, slot: int, v: NodeId) {
    p = self._arg_ptr(i, slot);
    if v == NIL {
        self.args[p] = Tag.NONE;
        self.args[p + 1] = 0;
    } else {
        self.args[p] = Tag.NODE;
        self.args[p + 1] = v;
    }
}

impl SyntaxArena.set_arg_str(i: NodeId, slot: int, s: str) {
    p = self._arg_ptr(i, slot);
    self.args[p] = Tag.STR;
    self.args[p + 1] = self.intern(s);
}

impl SyntaxArena.set_arg_bool(i: NodeId, slot: int, v: bool) {
    p = self._arg_ptr(i, slot);
    self.args[p] = Tag.BOOL;
    self.args[p + 1] = 1 if v else 0;
}

impl SyntaxArena.set_arg_enum(i: NodeId, slot: int, v: int) {
    p = self._arg_ptr(i, slot);
    self.args[p] = Tag.ENUM;
    self.args[p + 1] = v;
}

impl SyntaxArena.set_arg_list(i: NodeId, slot: int, ids: list[NodeId]) {
    p = self._arg_ptr(i, slot);
    self.args[p] = Tag.LIST;
    self.args[p + 1] = self.intern_seq(ids);
}

impl SyntaxArena.set_kids_of(i: NodeId, ids: list[NodeId]) {
    self._retable_kids(i, ids);
}

impl SyntaxArena.prepend_kids(i: NodeId, ids: list[NodeId]) {
    self._retable_kids(i, ids + self.kid_ids(i));
}

impl SyntaxArena.append_kids(i: NodeId, ids: list[NodeId]) {
    self._retable_kids(i, self.kid_ids(i) + ids);
}

impl SyntaxArena.replace_kid(i: NodeId, old: NodeId, news: list[NodeId]) {
    out: list[NodeId] = [];
    for k in self.kid_ids(i) {
        if k == old {
            out.extend(news);
        } else {
            out.append(k);
        }
    }
    self._retable_kids(i, out);
}

impl SyntaxArena.post_set(i: NodeId, key: str, v: int) {
    self.posts.append(i);
    self.posts.append(self.intern(key));
    self.posts.append(v);
}

impl SyntaxArena.adopt_columns(
    kinds: list[int],
    kid_los: list[int],
    kid_ns: list[int],
    arg_los: list[int],
    arg_ns: list[int],
    kids: list[int],
    args: list[int],
    seqs: list[int],
    posts: list[int],
    strtab: list[str],
    root_id: int
) {
    self.kinds = kinds;
    self.kid_los = kid_los;
    self.kid_ns = kid_ns;
    self.arg_los = arg_los;
    self.arg_ns = arg_ns;
    self.kids = kids;
    self.args = args;
    self.seqs = seqs;
    self.posts = posts;
    self.strtab = strtab;
    self.root_id = root_id;
    rebuilt: dict[str, int] = {};
    idx = 0;
    for s in strtab {
        if s not in rebuilt {
            rebuilt[s] = idx;
        }
        idx += 1;
    }
    self._intern = rebuilt;
}

impl SyntaxArena._reserve_nil_row{
    self.kinds.append(0);
    self.kid_los.append(0);
    self.kid_ns.append(0);
    self.arg_los.append(0);
    self.arg_ns.append(0);
}

impl SyntaxArena._start(kind: KindId, kid: list[NodeId], arg_n: int) -> NodeId {
    idx = len(self.kinds);
    self.kinds.append(kind);
    self.kid_los.append(len(self.kids));
    self.kid_ns.append(len(kid));
    self.kids.extend(kid);
    self.arg_los.append(len(self.args));
    self.arg_ns.append(arg_n);
    return idx;
}

impl SyntaxArena._arg_ptr(i: NodeId, slot: int) -> int {
    return self.arg_los[i] + (slot * 2);
}

impl SyntaxArena._push_none{
    self.args.append(Tag.NONE);
    self.args.append(0);
}

impl SyntaxArena._arg_node(v: NodeId) {
    if v == NIL {
        self._push_none();
    } else {
        self.args.append(Tag.NODE);
        self.args.append(v);
    }
}

impl SyntaxArena._arg_list(ids: (list[NodeId] | None)) {
    if ids is None {
        self._push_none();
        return;
    }
    off = self.intern_seq(ids);
    self.args.append(Tag.LIST);
    self.args.append(off);
}

impl SyntaxArena._arg_str(s: (str | None)) {
    if s is None {
        self._push_none();
    } else {
        self.args.append(Tag.STR);
        self.args.append(self.intern(s));
    }
}

impl SyntaxArena._arg_int(v: int) {
    self.args.append(Tag.INT);
    self.args.append(v);
}

impl SyntaxArena._arg_bool(v: bool) {
    self.args.append(Tag.BOOL);
    self.args.append(1 if v else 0);
}

impl SyntaxArena._arg_enum(v: int) {
    self.args.append(Tag.ENUM);
    self.args.append(v);
}

impl SyntaxArena._arg_poly(v: (NodeId | list[NodeId] | None)) {
    if v is None {
        self._push_none();
    } elif isinstance(v, int) {
        # Typed rebinds stay: isinstance branches do not narrow in native
        # lowering (E5092); `is None` branches do.
        vi: NodeId = v;
        self._arg_node(vi);
    } else {
        vl: list[NodeId] = v;
        self._arg_list(vl);
    }
}

impl SyntaxArena._retable_kids(i: NodeId, ids: list[NodeId]) {
    lo = len(self.kids);
    self.kids.extend(ids);
    self.kid_los[i] = lo;
    self.kid_ns[i] = len(ids);
}

impl SyntaxArena._bad_tag(i: NodeId, slot: int, want: Tag, got: int) {
    raise ValueError(
        f"arena node {i} (kind {self.kinds[i]}) slot {slot}: "
        f"expected {want} arg, found tag {got}"
    );
}
