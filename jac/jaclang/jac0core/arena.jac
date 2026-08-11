import from jaclang.jac0core.constant { EdgeDir, OwnershipKind }
import from jaclang.jac0core.ctlib { ct, fail, reflect }

type NodeId = int;

glob NIL: NodeId = 0;

enum Tag: int { NONE = 0, NODE = 1, LIST = 2, STR = 3, INT = 4, BOOL = 5, ENUM = 6 }

obj SyntaxArena {
    # Node i: kind in kinds[i]; kids at kids[kid_los[i] : kid_los[i] + kid_ns[i]];
    # args as (Tag, value) pairs, arg_ns[i] slots starting at arg_los[i].
    # Variable-length arg lists live in seqs as [n, id0..idn-1] at their offset.
    # Row 0 is the NIL sentinel so kind_of(NIL) and friends are always in range.
    has kinds: list[int] = [],
        kid_los: list[int] = [],
        kid_ns: list[int] = [],
        arg_los: list[int] = [],
        arg_ns: list[int] = [],
        kids: list[NodeId] = [],
        args: list[int] = [],
        seqs: list[int] = [],
        strtab: list[str] = [],
        posts: list[int] = [],
        _intern: dict[str, int] = {},
        root_id: NodeId = 0;

    def postinit {
        self._reserve_nil_row();
    }

    def _reserve_nil_row {
        self.kinds.append(0);
        self.kid_los.append(0);
        self.kid_ns.append(0);
        self.arg_los.append(0);
        self.arg_ns.append(0);
    }

    def node_count -> int {
        return len(self.kinds);
    }

    def intern(s: str) -> int {
        if s in self._intern {
            return self._intern[s];
        }
        idx = len(self.strtab);
        self.strtab.append(s);
        self._intern[s] = idx;
        return idx;
    }

    def _start(kind: int, kid: list[NodeId], arg_n: int) -> NodeId {
        idx = len(self.kinds);
        self.kinds.append(kind);
        self.kid_los.append(len(self.kids));
        self.kid_ns.append(len(kid));
        self.kids.extend(kid);
        self.arg_los.append(len(self.args));
        self.arg_ns.append(arg_n);
        return idx;
    }

    def _arg_node(v: NodeId) {
        if v == NIL {
            self.args.append(Tag.NONE);
            self.args.append(0);
        } else {
            self.args.append(Tag.NODE);
            self.args.append(v);
        }
    }

    def _arg_list(ids: (list[NodeId] | None)) {
        if ids is None {
            self.args.append(Tag.NONE);
            self.args.append(0);
            return;
        }
        off = len(self.seqs);
        self.seqs.append(len(ids));
        self.seqs.extend(ids);
        self.args.append(Tag.LIST);
        self.args.append(off);
    }

    def _arg_str(s: (str | None)) {
        if s is None {
            self.args.append(Tag.NONE);
            self.args.append(0);
        } else {
            self.args.append(Tag.STR);
            self.args.append(self.intern(s));
        }
    }

    def _arg_int(v: int) {
        self.args.append(Tag.INT);
        self.args.append(v);
    }

    def _arg_bool(v: bool) {
        self.args.append(Tag.BOOL);
        self.args.append(1 if v else 0);
    }

    def _arg_enum(v: int) {
        self.args.append(Tag.ENUM);
        self.args.append(v);
    }

    def _arg_poly(v: (NodeId | list[NodeId] | None)) {
        if v is None {
            self.args.append(Tag.NONE);
            self.args.append(0);
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

    def kind_of(i: NodeId) -> int {
        return self.kinds[i];
    }

    def kid_ids(i: NodeId) -> list[NodeId] {
        lo = self.kid_los[i];
        return self.kids[lo:lo + self.kid_ns[i]];
    }

    def arg_at(i: NodeId, slot: int) -> tuple[(int, int)] {
        if slot >= self.arg_ns[i] {
            raise ValueError(
                f"arg slot {slot} out of range for node {i} "
                f"(kind {self.kinds[i]}, {self.arg_ns[i]} args)"
            );
        }
        p = self.arg_los[i] + (slot * 2);
        return (self.args[p], self.args[p + 1]);
    }

    def arg_node(i: NodeId, slot: int) -> NodeId {
        if slot >= self.arg_ns[i] {
            return NIL;
        }
        (tag, v) = self.arg_at(i, slot);
        return v if tag == Tag.NODE else NIL;
    }

    def arg_str(i: NodeId, slot: int) -> (str | None) {
        if slot >= self.arg_ns[i] {
            return None;
        }
        (tag, v) = self.arg_at(i, slot);
        return self.strtab[v] if tag == Tag.STR else None;
    }

    def arg_int(i: NodeId, slot: int) -> int {
        if slot >= self.arg_ns[i] {
            return 0;
        }
        (tag, v) = self.arg_at(i, slot);
        return v;
    }

    def arg_bool(i: NodeId, slot: int) -> bool {
        if slot >= self.arg_ns[i] {
            return False;
        }
        (tag, v) = self.arg_at(i, slot);
        return tag == Tag.BOOL and v != 0;
    }

    def arg_list(i: NodeId, slot: int) -> (list[NodeId] | None) {
        if slot >= self.arg_ns[i] {
            return None;
        }
        (tag, v) = self.arg_at(i, slot);
        if tag != Tag.LIST {
            return None;
        }
        return self.seq_ids(v);
    }

    def seq_ids(off: int) -> list[NodeId] {
        n = self.seqs[off];
        return self.seqs[off + 1:off + 1 + n];
    }

    def set_arg_node(i: NodeId, slot: int, v: NodeId) {
        p = self.arg_los[i] + (slot * 2);
        if v == NIL {
            self.args[p] = Tag.NONE;
            self.args[p + 1] = 0;
        } else {
            self.args[p] = Tag.NODE;
            self.args[p + 1] = v;
        }
    }

    def set_arg_str(i: NodeId, slot: int, s: str) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = Tag.STR;
        self.args[p + 1] = self.intern(s);
    }

    def set_arg_bool(i: NodeId, slot: int, v: bool) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = Tag.BOOL;
        self.args[p + 1] = 1 if v else 0;
    }

    def set_arg_enum(i: NodeId, slot: int, v: int) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = Tag.ENUM;
        self.args[p + 1] = v;
    }

    def prepend_kids(i: NodeId, ids: list[NodeId]) {
        old = self.kid_ids(i);
        lo = len(self.kids);
        self.kids.extend(ids);
        self.kids.extend(old);
        self.kid_los[i] = lo;
        self.kid_ns[i] = len(ids) + len(old);
    }

    def append_kids(i: NodeId, ids: list[NodeId]) {
        old = self.kid_ids(i);
        lo = len(self.kids);
        self.kids.extend(old);
        self.kids.extend(ids);
        self.kid_los[i] = lo;
        self.kid_ns[i] = len(old) + len(ids);
    }

    def post_set(i: NodeId, key: str, v: int) {
        self.posts.append(i);
        self.posts.append(self.intern(key));
        self.posts.append(v);
    }

    def set_arg_list(i: NodeId, slot: int, ids: list[NodeId]) {
        p = self.arg_los[i] + (slot * 2);
        off = len(self.seqs);
        self.seqs.append(len(ids));
        self.seqs.extend(ids);
        self.args[p] = Tag.LIST;
        self.args[p + 1] = off;
    }

    def replace_kid(i: NodeId, old: NodeId, news: list[NodeId]) {
        cur = self.kid_ids(i);
        out: list[NodeId] = [];
        for k in cur {
            if k == old {
                out.extend(news);
            } else {
                out.append(k);
            }
        }
        lo = len(self.kids);
        self.kids.extend(out);
        self.kid_los[i] = lo;
        self.kid_ns[i] = len(out);
    }

    # >>> comptime-derived builder surface (one mk_* per unitree kind) >>>
    comptime for K in _ct_schema() {
        def mk_${K["snake"]}(
            comptime for p in K["bparams"] {
                ${ct.name(p["pname"])}: ${ct.typ(p["ptype"])} = ${ct.expr(p["pdflt"])}
            , }kid: list[NodeId] = []
        ) -> NodeId {
            idx = self._start(${K["kind"]}, kid, ${K["argn"]});
            comptime for p in K["bparams"] {
                self.${ct.name(p["writer"])}(${ct.expr(p["warg"])});
            }
            return idx;
        }
    }
    # <<< comptime-derived builder surface <<<
}


# >>> comptime derivation of the arena schema (replaces jac gen-unitree) >>>
# The unitree constructor surface is the schema: reflect over it at
# expansion time and derive kind ids (sorted class-name order), the
# builder surface above, slot tables, kind-family membership, and the
# materializer SPECS. Deterministic by construction; drift is impossible
# because there is no second artifact to drift.

comptime def _ct_mod -> any {
    return reflect.module("jaclang.jac0core.unitree");
}

comptime def _ct_first_enum(name: str) -> str {
    mems = reflect.module("jaclang.jac0core.constant").enum_members(name);
    return mems[0];
}

comptime def _ct_cat(pname: str, ann: str, class_names: list[str]) -> dict {
    out: dict = {"cat": "", "optional": False, "enum": ""};
    if pname == "kid" {
        out["cat"] = "KID";
        return out;
    }
    parts = ct.parts(ann);
    optional = False;
    kept: list[str] = [];
    for p in parts {
        if p == "None" {
            optional = True;
        } else {
            kept.append(p);
        }
    }
    out["optional"] = optional;
    if len(kept) == 0 {
        out["cat"] = "NODE";
        out["optional"] = True;
        return out;
    }
    all_source = True;
    for p in kept {
        if p.split("[")[0].strip() != "Source" {
            all_source = False;
        }
    }
    if all_source {
        out["cat"] = "SOURCE";
        return out;
    }
    if len(kept) == 1 {
        p0 = kept[0];
        b = p0.split("[")[0].strip();
        if b == "str" {
            out["cat"] = "STR";
            return out;
        }
        if b == "int" {
            out["cat"] = "INT";
            return out;
        }
        if b == "bool" {
            out["cat"] = "BOOL";
            return out;
        }
        if b == "EdgeDir" or b == "OwnershipKind" {
            out["cat"] = "ENUM";
            out["enum"] = b;
            return out;
        }
        if p0.startswith("Sequence[") or p0.startswith("list[") {
            out["cat"] = "LIST";
            return out;
        }
        if b == "T" {
            out["cat"] = "POLY";
            return out;
        }
        if b in class_names or b == "UniNode" or b == "NameAtom" or b == "AtomExpr" {
            out["cat"] = "NODE";
            return out;
        }
        return out;
    }
    n_seq = 0;
    n_node = 0;
    all_str = True;
    for p in kept {
        if p.startswith("Sequence[") or p.startswith("list[") {
            n_seq += 1;
        } else {
            n_node += 1;
            if p.split("[")[0].strip() != "str" {
                all_str = False;
            }
        }
    }
    if n_seq > 0 and n_node == 0 {
        out["cat"] = "LIST";
        return out;
    }
    if n_node > 0 and n_seq == 0 {
        out["cat"] = "STR" if all_str else "NODE";
        return out;
    }
    out["cat"] = "POLY";
    return out;
}

comptime def _ct_bparam(
    pname: str, cat: str, ename: str, opt: bool, hd: bool, dsrc: str
) -> dict {
    ptype = "NodeId";
    pdflt = "NIL";
    writer = "_arg_node";
    warg = pname;
    if cat == "LIST" {
        ptype = "(list[NodeId] | None)";
        pdflt = "None";
        writer = "_arg_list";
    } elif cat == "POLY" {
        ptype = "(NodeId | list[NodeId] | None)";
        pdflt = "None";
        writer = "_arg_poly";
    } elif cat == "STR" {
        pdflt = dsrc if hd else "\"\"";
        ptype = "(str | None)" if (opt and hd and dsrc == "None") else "str";
        writer = "_arg_str";
    } elif cat == "INT" {
        ptype = "int";
        pdflt = dsrc if hd else "0";
        writer = "_arg_int";
    } elif cat == "BOOL" {
        ptype = "bool";
        pdflt = dsrc if hd else "False";
        writer = "_arg_bool";
    } elif cat == "ENUM" {
        ptype = ename;
        pdflt = dsrc if hd else (ename + "." + _ct_first_enum(ename));
        writer = "_arg_enum";
    }
    return {
        "pname": pname,
        "ptype": ptype,
        "pdflt": pdflt,
        "writer": writer,
        "warg": warg
    };
}

comptime def _ct_schema -> list[dict] {
    mod = _ct_mod();
    class_names = mod.type_names();
    excluded = ["Source", "CommentToken", "ProgramModule", "PythonModuleAst"];
    kept: list[str] = [];
    for nm in sorted(mod.subtypes_of("UniNode")) {
        if nm not in excluded {
            kept.append(nm);
        }
    }
    out: list[dict] = [];
    kind = 1;
    for nm in kept {
        sparams: list[dict] = [];
        bparams: list[dict] = [];
        has_kid = False;
        argn = 0;
        for f in mod.ctor_fields(nm) {
            got = _ct_cat(f.name, f.ann, class_names);
            cat = got["cat"];
            if cat == "KID" {
                has_kid = True;
            } elif cat == "" {
                fail("unclassifiable ctor param " + nm + "." + f.name + ": " + f.ann);
            } else {
                sparams.append(
                    {
                        "pname": f.name,
                        "cat": cat,
                        "enum": got["enum"],
                        "hd": f.has_default
                    }
                );
                if cat != "SOURCE" {
                    argn += 1;
                    bparams.append(
                        _ct_bparam(
                            f.name,
                            cat,
                            got["enum"],
                            got["optional"] or f.has_default,
                            f.has_default,
                            f.default_src
                        )
                    );
                }
            }
        }
        out.append(
            {
                "name": nm,
                "snake": ct.snake(nm),
                "usnake": ct.snake(nm).upper(),
                "kind": kind,
                "tokfam": mod.is_subtype(nm, "Token"),
                "has_kid": has_kid,
                "sparams": sparams,
                "bparams": bparams,
                "argn": argn
            }
        );
        kind += 1;
    }
    return out;
}

comptime def _ct_specs_table -> dict {
    out: dict = {};
    for K in _ct_schema() {
        nm: str = K["name"];
        enc: str = nm;
        enc += "|1|" if K["tokfam"] else "|0|";
        enc += "1" if K["has_kid"] else "0";
        ptxt: str = "";
        sparams: list[dict] = K["sparams"];
        for p in sparams {
            if ptxt {
                ptxt += ";";
            }
            pname: str = p["pname"];
            cat: str = p["cat"];
            en: str = p["enum"];
            hd: str = "1" if p["hd"] else "0";
            ptxt += pname + "," + cat + "," + en + "," + hd;
        }
        out[K["kind"]] = enc + "|" + ptxt;
    }
    return out;
}

comptime def _ct_slot_table(fld: str) -> dict {
    out: dict = {};
    for K in _ct_schema() {
        slot = 0;
        sparams: list = K["sparams"];
        for p in sparams {
            if p["cat"] == "SOURCE" {
                continue;
            }
            if p["pname"] == fld {
                out[K["kind"]] = slot;
                break;
            }
            slot += 1;
        }
    }
    return out;
}

comptime def _ct_family_rows -> list[dict] {
    mod = _ct_mod();
    fams = [
        "Token",
        "Name",
        "String",
        "MultiString",
        "EmptyToken",
        "Semi",
        "ExprStmt",
        "KWPair",
        "KVPair",
        "GenCompr",
        "JsxElement",
        "ParamVar",
        "ContextAwareNode",
        "FuncSignature",
        "EventSignature",
        "YieldExpr"
    ];
    out: list[dict] = [];
    for fam in fams {
        members: list[int] = [];
        for K in _ct_schema() {
            if mod.is_subtype(K["name"], fam) {
                members.append(K["kind"]);
            }
        }
        out.append({"uname": ct.snake(fam).upper(), "members": members});
    }
    return out;
}

comptime for K in _ct_schema() {
    glob ${ct.name("KIND_" + K["usnake"])}: int = ${K["kind"]};
}

glob DOC_SLOTS: dict[int, int] = comptime { _ct_slot_table("doc") },
     ENUM_STMT_SLOTS: dict[int, int] = comptime { _ct_slot_table("is_enum_stmt") };

comptime for F in _ct_family_rows() {
    glob ${ct.name("KS_" + F["uname"])}: list[int] = ${F["members"]};
}

glob SPECS: dict[int, str] = comptime { _ct_specs_table() };
# <<< comptime derivation of the arena schema <<<
