import from jaclang.jac0core.constant { EdgeDir, OwnershipKind }
import from jaclang.jac0core.ctlib { ct, fail, reflect }

type NodeId = int;
type StrId = int;
type SeqOff = int;
type KindId = int;

glob NIL: NodeId = 0;

enum Tag: int { NONE = 0, NODE = 1, LIST = 2, STR = 3, INT = 4, BOOL = 5, ENUM = 6 }

obj SyntaxArena {
    # Node i: kind in kinds[i]; kids at kids[kid_los[i] : kid_los[i] + kid_ns[i]];
    # args as (Tag, value) pairs, arg_ns[i] slots starting at arg_los[i].
    # Variable-length arg lists live in seqs as [n, id0..idn-1] at their offset.
    # Row 0 is the NIL sentinel so kind_of(NIL) and friends are always in range.
    # The stride-2 args, length-prefixed seqs, and stride-3 posts encodings are
    # layout knowledge private to this obj: consumers read and write through
    # the accessor surface below. The columns stay public only for wholesale
    # serialization (adopt_columns, strtab blobs), never for pointer math.
    has kinds: list[KindId] = [],
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

    def postinit -> None;

    has node_count: int { getter; }

    # -- string table --
    def intern(s: str) -> StrId;
    def str_of(sid: StrId) -> str;
    # -- node reads --
    def kind_of(i: NodeId) -> KindId;
    def kid_ids(i: NodeId) -> list[NodeId];
    def arg_pair(i: NodeId, slot: int) -> tuple[(Tag, int)];
    def arg_pairs(i: NodeId) -> list[tuple[(Tag, int)]];
    def arg_node(i: NodeId, slot: int) -> NodeId;
    def arg_str(i: NodeId, slot: int) -> (str | None);
    def arg_int(i: NodeId, slot: int) -> int;
    def arg_bool(i: NodeId, slot: int) -> bool;
    def arg_list(i: NodeId, slot: int) -> (list[NodeId] | None);
    def seq_ids(off: SeqOff) -> list[NodeId];
    def deps_of(i: NodeId) -> list[NodeId];
    def post_entries -> list[tuple[(NodeId, str, int)]];
    # -- node writes --
    def intern_seq(ids: list[NodeId]) -> SeqOff;
    def append_record(
        kind: KindId, kid: list[NodeId], pairs: list[tuple[(Tag, int)]]
    ) -> NodeId;

    def set_arg_node(i: NodeId, slot: int, v: NodeId) -> None;
    def set_arg_str(i: NodeId, slot: int, s: str) -> None;
    def set_arg_bool(i: NodeId, slot: int, v: bool) -> None;
    def set_arg_enum(i: NodeId, slot: int, v: int) -> None;
    def set_arg_list(i: NodeId, slot: int, ids: list[NodeId]) -> None;
    def set_kids_of(i: NodeId, ids: list[NodeId]) -> None;
    def prepend_kids(i: NodeId, ids: list[NodeId]) -> None;
    def append_kids(i: NodeId, ids: list[NodeId]) -> None;
    def replace_kid(i: NodeId, old: NodeId, news: list[NodeId]) -> None;
    def post_set(i: NodeId, key: str, v: int) -> None;
    # -- bulk adoption: the one sanctioned column-level write (deserialization) --
    def adopt_columns(
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
    ) -> None;

    # -- private layout helpers --
    def _reserve_nil_row -> None;
    def _start(kind: KindId, kid: list[NodeId], arg_n: int) -> NodeId;
    def _arg_ptr(i: NodeId, slot: int) -> int;
    def _push_none -> None;
    def _arg_node(v: NodeId) -> None;
    def _arg_list(ids: (list[NodeId] | None)) -> None;
    def _arg_str(s: (str | None)) -> None;
    def _arg_int(v: int) -> None;
    def _arg_bool(v: bool) -> None;
    def _arg_enum(v: int) -> None;
    def _arg_poly(v: (NodeId | list[NodeId] | None)) -> None;
    def _retable_kids(i: NodeId, ids: list[NodeId]) -> None;
    def _bad_tag(i: NodeId, slot: int, want: Tag, got: int) -> None;

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
