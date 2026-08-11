import from jaclang.jac0core.constant { EdgeDir, OwnershipKind }
import from jaclang.jac0core.ctlib { ct, fail, reflect }

glob NIL: int = 0;

glob TAG_NONE: int = 0,
     TAG_NODE: int = 1,
     TAG_LIST: int = 2,
     TAG_STR: int = 3,
     TAG_INT: int = 4,
     TAG_BOOL: int = 5,
     TAG_ENUM: int = 6;

obj SyntaxArena {
    has kinds: list[int] = [],
        kid_los: list[int] = [],
        kid_ns: list[int] = [],
        arg_los: list[int] = [],
        arg_ns: list[int] = [],
        kids: list[int] = [],
        args: list[int] = [],
        seqs: list[int] = [],
        strtab: list[str] = [],
        posts: list[int] = [],
        _intern: dict[str, int] = {},
        root_id: int = 0;

    def postinit {
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
        got = self._intern.get(s, -1);
        if got >= 0 {
            return got;
        }
        idx = len(self.strtab);
        self.strtab.append(s);
        self._intern[s] = idx;
        return idx;
    }

    def _start(kind: int, kid: list[int], arg_n: int) -> int {
        idx = len(self.kinds);
        self.kinds.append(kind);
        self.kid_los.append(len(self.kids));
        self.kid_ns.append(len(kid));
        for k in kid {
            self.kids.append(k);
        }
        self.arg_los.append(len(self.args));
        self.arg_ns.append(arg_n);
        return idx;
    }

    def _arg_node(v: int) {
        if v == NIL {
            self.args.append(TAG_NONE);
            self.args.append(0);
        } else {
            self.args.append(TAG_NODE);
            self.args.append(v);
        }
    }

    def _arg_list(ids: (list[int] | None)) {
        if ids is None {
            self.args.append(TAG_NONE);
            self.args.append(0);
            return;
        }
        ids2: list[int] = ids;
        off = len(self.seqs);
        self.seqs.append(len(ids2));
        for i in ids2 {
            self.seqs.append(i);
        }
        self.args.append(TAG_LIST);
        self.args.append(off);
    }

    def _arg_str(s: (str | None)) {
        if s is None {
            self.args.append(TAG_NONE);
            self.args.append(0);
        } else {
            s2: str = s;
            self.args.append(TAG_STR);
            self.args.append(self.intern(s2));
        }
    }

    def _arg_int(v: int) {
        self.args.append(TAG_INT);
        self.args.append(v);
    }

    def _arg_bool(v: bool) {
        self.args.append(TAG_BOOL);
        self.args.append(1 if v else 0);
    }

    def _arg_enum(v: int) {
        self.args.append(TAG_ENUM);
        self.args.append(v);
    }

    def _arg_poly(v: (int | list[int] | None)) {
        if v is None {
            self.args.append(TAG_NONE);
            self.args.append(0);
        } elif isinstance(v, int) {
            vi: int = v;
            self._arg_node(vi);
        } else {
            vl: list[int] = v;
            self._arg_list(vl);
        }
    }

    def kind_of(i: int) -> int {
        return self.kinds[i];
    }

    def kid_ids(i: int) -> list[int] {
        lo = self.kid_los[i];
        return self.kids[lo:lo + self.kid_ns[i]];
    }

    def arg_at(i: int, slot: int) -> tuple[(int, int)] {
        if slot >= self.arg_ns[i] {
            raise ValueError(
                f"arg slot {slot} out of range for node {i} "
                f"(kind {self.kinds[i]}, {self.arg_ns[i]} args)"
            );
        }
        p = self.arg_los[i] + (slot * 2);
        return (self.args[p], self.args[p + 1]);
    }

    def arg_node(i: int, slot: int) -> int {
        if slot >= self.arg_ns[i] {
            return NIL;
        }
        (tag, v) = self.arg_at(i, slot);
        return v if tag == TAG_NODE else NIL;
    }

    def arg_str(i: int, slot: int) -> (str | None) {
        if slot >= self.arg_ns[i] {
            return None;
        }
        (tag, v) = self.arg_at(i, slot);
        return self.strtab[v] if tag == TAG_STR else None;
    }

    def arg_int(i: int, slot: int) -> int {
        if slot >= self.arg_ns[i] {
            return 0;
        }
        (tag, v) = self.arg_at(i, slot);
        return v;
    }

    def arg_bool(i: int, slot: int) -> bool {
        if slot >= self.arg_ns[i] {
            return False;
        }
        (tag, v) = self.arg_at(i, slot);
        return tag == TAG_BOOL and v != 0;
    }

    def arg_list(i: int, slot: int) -> (list[int] | None) {
        if slot >= self.arg_ns[i] {
            return None;
        }
        (tag, v) = self.arg_at(i, slot);
        if tag != TAG_LIST {
            return None;
        }
        return self.seq_ids(v);
    }

    def seq_ids(off: int) -> list[int] {
        n = self.seqs[off];
        return self.seqs[off + 1:off + 1 + n];
    }

    def set_arg_node(i: int, slot: int, v: int) {
        p = self.arg_los[i] + (slot * 2);
        if v == NIL {
            self.args[p] = TAG_NONE;
            self.args[p + 1] = 0;
        } else {
            self.args[p] = TAG_NODE;
            self.args[p + 1] = v;
        }
    }

    def set_arg_str(i: int, slot: int, s: str) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = TAG_STR;
        self.args[p + 1] = self.intern(s);
    }

    def set_arg_bool(i: int, slot: int, v: bool) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = TAG_BOOL;
        self.args[p + 1] = 1 if v else 0;
    }

    def set_arg_enum(i: int, slot: int, v: int) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = TAG_ENUM;
        self.args[p + 1] = v;
    }

    def prepend_kids(i: int, ids: list[int]) {
        old = self.kid_ids(i);
        lo = len(self.kids);
        for k in ids {
            self.kids.append(k);
        }
        for k in old {
            self.kids.append(k);
        }
        self.kid_los[i] = lo;
        self.kid_ns[i] = len(ids) + len(old);
    }

    def append_kids(i: int, ids: list[int]) {
        old = self.kid_ids(i);
        lo = len(self.kids);
        for k in old {
            self.kids.append(k);
        }
        for k in ids {
            self.kids.append(k);
        }
        self.kid_los[i] = lo;
        self.kid_ns[i] = len(old) + len(ids);
    }

    def post_set(i: int, key: str, v: int) {
        self.posts.append(i);
        self.posts.append(self.intern(key));
        self.posts.append(v);
    }

    def set_arg_list(i: int, slot: int, ids: list[int]) {
        p = self.arg_los[i] + (slot * 2);
        off = len(self.seqs);
        self.seqs.append(len(ids));
        for k in ids {
            self.seqs.append(k);
        }
        self.args[p] = TAG_LIST;
        self.args[p + 1] = off;
    }

    def replace_kid(i: int, old: int, news: list[int]) {
        cur = self.kid_ids(i);
        out: list[int] = [];
        for k in cur {
            if k == old {
                for n in news {
                    out.append(n);
                }
            } else {
                out.append(k);
            }
        }
        lo = len(self.kids);
        for k in out {
            self.kids.append(k);
        }
        self.kid_los[i] = lo;
        self.kid_ns[i] = len(out);
    }

    # >>> comptime-derived builder surface (one mk_* per unitree kind) >>>
    comptime for K in _ct_schema() {
        def mk_${K["snake"]}(
            comptime for p in K["bparams"] {
                ${ct.name(p["pname"])}: ${ct.typ(p["ptype"])} = ${ct.expr(p["pdflt"])}
            , }kid: list[int] = []
        ) -> int {
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

def _ct_mod -> any {
    return reflect.module("jaclang.jac0core.unitree");
}

def _ct_first_enum(name: str) -> str {
    mems = reflect.module("jaclang.jac0core.constant").enum_members(name);
    return mems[0];
}

def _ct_cat(pname: str, ann: str, class_names: list[str]) -> dict {
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

def _ct_bparam(
    pname: str, cat: str, ename: str, opt: bool, hd: bool, dsrc: str
) -> dict {
    ptype = "int";
    pdflt = "NIL";
    writer = "_arg_node";
    warg = pname;
    if cat == "LIST" {
        ptype = "(list[int] | None)";
        pdflt = "None";
        writer = "_arg_list";
    } elif cat == "POLY" {
        ptype = "(int | list[int] | None)";
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
        warg = pname + ".value";
    }
    return {
        "pname": pname,
        "ptype": ptype,
        "pdflt": pdflt,
        "writer": writer,
        "warg": warg
    };
}

def _ct_schema -> list[dict] {
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

def _ct_specs_table -> dict {
    out: dict = {};
    for K in _ct_schema() {
        plist: list = [];
        sparams: list = K["sparams"];
        for p in sparams {
            plist.append(tuple([p["pname"], p["cat"], p["enum"], p["hd"]]));
        }
        out[K["kind"]] = tuple([K["name"], tuple(plist), K["tokfam"], K["has_kid"]]);
    }
    return out;
}

def _ct_slot_table(fld: str) -> dict {
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

def _ct_family_rows -> list[dict] {
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

glob SPECS: dict[int, tuple] = comptime { _ct_specs_table() };
# <<< comptime derivation of the arena schema <<<
