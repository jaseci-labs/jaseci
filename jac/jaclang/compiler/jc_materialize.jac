"""The materializer: walks the kernel's parse tree and builds the ordinary
Python unitree through the CPython C API, in one pass; the kernel's graph
state for the parse is dropped afterwards (jc_graph_wipe at next parse).

This is the raw side of the kernel: everything here is an address. Node
kinds are discriminated by the type tag OSP archetypes carry at a fixed
offset; plain (tag-less) objects are discriminated statically, by the aux
class of the field or call site that referenced them. Field decoding is
driven by per-class tables registered once per process by the Python
loader (native_compiler.jac) from the layout sidecar the backend emits at
lib build. Adjacency is copied straight out of the shared OSP kernel's
per-node index into the Python runtime's light-edge structures
(out_light / in_light), so role semantics never need naming here: the
graph is the data.

Typed reads (role shapes, native list access) re-enter the typed world
through jc_unit's exported helpers: a raw handle passed to a C-ABI export
whose parameter is declared with the real type.
"""

import from jaclang.runtime.osp_graph { DEFAULT_GRAPH }

import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }
import from c { def PyType_GenericAlloc(t: int, n: int) -> int;  }
import from c { def PyObject_SetAttr(o: int, k: int, v: int) -> int;  }
import from c { def PyObject_GetAttr(o: int, k: int) -> int;  }
import from c { def PyErr_Clear() -> int;  }
import from c { def PyUnicode_FromString(p: int) -> int;  }
import from c { def PyLong_FromLongLong(v: int) -> int;  }
import from c { def PyList_New(n: int) -> int;  }
import from c { def PyList_SetItem(l: int, i: int, v: int) -> int;  }
import from c { def PyList_Append(l: int, v: int) -> int;  }
import from c { def PyDict_New() -> int;  }
import from c { def PyDict_SetItem(d: int, k: int, v: int) -> int;  }
import from c { def PyDict_GetItem(d: int, k: int) -> int;  }
import from c { def PySet_New(i: int) -> int;  }
import from c { def PyWeakref_NewRef(o: int, cb: int) -> int;  }
import from c { def Py_IncRef(o: int) -> int;  }
import from c { def Py_DecRef(o: int) -> int;  }
import from c { def jc_shape3(nd: int) -> int;  }
import from c { def jc_nlist_len(l: int) -> int;  }
import from c { def jc_nlist_get(l: int, i: int) -> int;  }

glob CODE_SKIP: int = 0,
     CODE_INT: int = 1,
     CODE_BOOL: int = 2,
     CODE_STR: int = 3,
     CODE_ENUM: int = 4,
     CODE_OPTREF: int = 5,
     CODE_OBJ: int = 6,
     CODE_NATLIST: int = 7,
     CODE_UNION: int = 8,
     CODE_OPTENUM: int = 9;

obj FieldRow {
    has key_h: int,
        code: int,
        off: int,
        aux_tag: int = 0,
        enum_h: int = 0,
        flags: int = 0;
}

obj ClassRow {
    has cls_h: int,
        size: int,
        tagged: int = 0,
        is_node: int = 0,
        rows: list[FieldRow] = [],
        dflt_k: list[int] = [],
        dflt_kind: list[int] = [];
}

obj MzConsts {
    has none_h: int = 0,
        true_h: int = 0,
        false_h: int = 0,
        empty_h: int = 0,
        s_none: int = 0,
        s_one: int = 0,
        s_many: int = 0,
        k_out: int = 0,
        k_in: int = 0,
        k_jac: int = 0,
        k_shapes: int = 0,
        body_h: int = 0,
        spec_h: int = 0,
        acc_h: int = 0;
}

glob _CLS: dict[int, ClassRow] = {},
     _EDGE: dict[int, int] = {},
     _K: MzConsts = MzConsts(),
     _STATS: list[int] = [0];

def:pub jc_reg_consts(
    none_h: int,
    true_h: int,
    false_h: int,
    empty_h: int,
    s_none: int,
    s_one: int,
    s_many: int,
    k_out: int,
    k_in: int,
    k_jac: int,
    k_shapes: int
) -> int {
    _K.none_h = none_h;
    _K.true_h = true_h;
    _K.false_h = false_h;
    _K.empty_h = empty_h;
    _K.s_none = s_none;
    _K.s_one = s_one;
    _K.s_many = s_many;
    _K.k_out = k_out;
    _K.k_in = k_in;
    _K.k_jac = k_jac;
    _K.k_shapes = k_shapes;
    return 0;
}

def:pub jc_reg_shape_roles(body_h: int, spec_h: int, acc_h: int) -> int {
    _K.body_h = body_h;
    _K.spec_h = spec_h;
    _K.acc_h = acc_h;
    return 0;
}

def:pub jc_reg_class(
    tag: int, cls_h: int, size: int, tagged: int, is_node: int
) -> int {
    _CLS[tag] = ClassRow(
        cls_h=cls_h,
        size=size,
        tagged=tagged,
        is_node=is_node,
        rows=[],
        dflt_k=[],
        dflt_kind=[]
    );
    return 0;
}

def:pub jc_reg_field(
    tag: int, key_h: int, code: int, off: int, aux_tag: int, enum_h: int, flags: int
) -> int {
    if tag not in _CLS {
        return 1;
    }
    row: ClassRow = _CLS[tag];
    row.rows.append(
        FieldRow(
            key_h=key_h, code=code, off=off, aux_tag=aux_tag, enum_h=enum_h,
            flags=flags
        )
    );
    return 0;
}

def:pub jc_reg_default(tag: int, key_h: int, kind: int) -> int {
    if tag not in _CLS {
        return 1;
    }
    row: ClassRow = _CLS[tag];
    row.dflt_k.append(key_h);
    row.dflt_kind.append(kind);
    return 0;
}

def:pub jc_reg_edge(tag: int, cls_h: int) -> int {
    _EDGE[tag] = cls_h;
    return 0;
}

def _ld64u(buf: bytes, off: int) -> int {
    return int.from_bytes(buf[off:off + 8], "little");
}

def _ld64s(buf: bytes, off: int) -> int {
    v = int.from_bytes(buf[off:off + 8], "little");
    if v >= 9223372036854775808 {
        v -= 18446744073709551616;
    }
    return v;
}

def _ld8(buf: bytes, off: int) -> int {
    return int.from_bytes(buf[off:off + 1], "little");
}

def _tag_at(h: int) -> int {
    buf = b"\x00" * 8;
    memcpy(buf, h + 8, u64(8));
    return int.from_bytes(buf, "little");
}

obj Mz {
    has map: dict[int, int] = {},
        q: list[int] = [],
        q_hint: list[int] = [],
        ref_o: list[int] = [],
        ref_k: list[int] = [],
        ref_t: list[int] = [],
        lst_l: list[int] = [],
        lst_i: list[int] = [],
        lst_t: list[int] = [],
        skipped: int = 0;
}

def _enqueue(m: Mz, h: int, hint: int) -> None {
    if h != 0 and h not in m.map {
        m.q.append(h);
        m.q_hint.append(hint);
    }
}

def _defer_ref(m: Mz, o: int, k: int, t: int, hint: int) -> None {
    m.ref_o.append(o);
    m.ref_k.append(k);
    m.ref_t.append(t);
    _enqueue(m, t, hint);
}

def _set_fresh(o: int, k: int, v: int) -> None {
    if v == 0 {
        PyErr_Clear();
        PyObject_SetAttr(o, k, _K.none_h);
        return;
    }
    PyObject_SetAttr(o, k, v);
    Py_DecRef(v);
}

def _fill_defaults(row: ClassRow, o: int) -> None {
    n = len(row.dflt_k);
    i = 0;
    while i < n {
        kind = row.dflt_kind[i];
        k = row.dflt_k[i];
        if kind == 0 {
            PyObject_SetAttr(o, k, _K.none_h);
        } elif kind == 1 {
            _set_fresh(o, k, PyList_New(0));
        } elif kind == 2 {
            _set_fresh(o, k, PyDict_New());
        } elif kind == 3 {
            _set_fresh(o, k, PySet_New(0));
        }
        i += 1;
    }
}

def _set_enum(o: int, k: int, enum_h: int, raw: int) -> None {
    if enum_h == 0 {
        PyObject_SetAttr(o, k, _K.none_h);
        return;
    }
    kk = PyLong_FromLongLong(raw);
    member = PyDict_GetItem(enum_h, kk);
    Py_DecRef(kk);
    if member != 0 {
        PyObject_SetAttr(o, k, member);
    } else {
        PyObject_SetAttr(o, k, _K.none_h);
    }
}

def _copy_union(m: Mz, o: int, fr: FieldRow, buf: bytes) -> None {
    kind = _ld8(buf, fr.off);
    pay = _ld64s(buf, fr.off + 8);
    if kind == 7 {
        PyObject_SetAttr(o, fr.key_h, _K.true_h if pay != 0 else _K.false_h);
        return;
    }
    if kind == 0 and pay != 0 {
        _set_fresh(o, fr.key_h, PyLong_FromLongLong(pay));
        return;
    }
    if kind == 2 and (fr.flags & 1) != 0 and pay != 0 {
        _set_fresh(o, fr.key_h, PyUnicode_FromString(pay));
        return;
    }
    if kind == 6 and pay != 0 {
        _defer_ref(m, o, fr.key_h, pay, 0);
        return;
    }
    PyObject_SetAttr(o, fr.key_h, _K.none_h);
}

def _copy_fields(m: Mz, row: ClassRow, h: int, o: int) -> None {
    buf = b"\x00" * row.size;
    memcpy(buf, h, u64(row.size));
    for fr in row.rows {
        code = fr.code;
        if code == CODE_INT {
            _set_fresh(o, fr.key_h, PyLong_FromLongLong(_ld64s(buf, fr.off)));
        } elif code == CODE_BOOL {
            PyObject_SetAttr(
                o, fr.key_h, _K.true_h if _ld8(buf, fr.off) != 0 else _K.false_h
            );
        } elif code == CODE_STR {
            p = _ld64u(buf, fr.off);
            if p != 0 {
                _set_fresh(o, fr.key_h, PyUnicode_FromString(p));
            } else {
                PyObject_SetAttr(o, fr.key_h, _K.empty_h);
            }
        } elif code == CODE_ENUM {
            _set_enum(o, fr.key_h, fr.enum_h, _ld64s(buf, fr.off));
        } elif code == CODE_OPTREF {
            t = _ld64u(buf, fr.off + 8);
            if _ld8(buf, fr.off) != 0 and t != 0 {
                _defer_ref(m, o, fr.key_h, t, fr.aux_tag);
            } else {
                PyObject_SetAttr(o, fr.key_h, _K.none_h);
            }
        } elif code == CODE_OBJ {
            t = _ld64u(buf, fr.off);
            if t != 0 {
                _defer_ref(m, o, fr.key_h, t, fr.aux_tag);
            } else {
                PyObject_SetAttr(o, fr.key_h, _K.none_h);
            }
        } elif code == CODE_NATLIST {
            p = _ld64u(buf, fr.off);
            n = jc_nlist_len(p) if p != 0 else 0;
            pl = PyList_New(n);
            if pl != 0 {
                i = 0;
                while i < n {
                    t = jc_nlist_get(p, i);
                    m.lst_l.append(pl);
                    m.lst_i.append(i);
                    m.lst_t.append(t);
                    _enqueue(m, t, fr.aux_tag);
                    i += 1;
                }
                PyObject_SetAttr(o, fr.key_h, pl);
                Py_DecRef(pl);
            } else {
                PyErr_Clear();
            }
        } elif code == CODE_UNION {
            _copy_union(m, o, fr, buf);
        } elif code == CODE_OPTENUM {
            if _ld8(buf, fr.off) != 0 {
                _set_enum(o, fr.key_h, fr.enum_h, _ld64s(buf, fr.off + 8));
            } else {
                PyObject_SetAttr(o, fr.key_h, _K.none_h);
            }
        }
    }
}

def _shape_entry(d: int, cls_h: int, code: int) -> None {
    if code == 1 {
        PyDict_SetItem(d, cls_h, _K.s_none);
    } elif code == 2 {
        PyDict_SetItem(d, cls_h, _K.s_one);
    } elif code == 3 {
        PyDict_SetItem(d, cls_h, _K.s_many);
    }
}

def _copy_shapes(h: int, o: int) -> None {
    sc = jc_shape3(h);
    if sc == 0 {
        return;
    }
    d = PyDict_New();
    if d == 0 {
        PyErr_Clear();
        return;
    }
    _shape_entry(d, _K.body_h, sc & 15);
    _shape_entry(d, _K.spec_h, (sc >> 4) & 15);
    _shape_entry(d, _K.acc_h, (sc >> 8) & 15);
    PyObject_SetAttr(o, _K.k_shapes, d);
    Py_DecRef(d);
}

def _resolve_row(h: int, hint: int) -> int {
    if hint != 0 and hint in _CLS {
        hrow: ClassRow = _CLS[hint];
        if hrow.tagged == 0 {
            return hint;
        }
    }
    rt = _tag_at(h);
    if rt in _CLS {
        return rt;
    }
    if hint != 0 and hint in _CLS {
        return hint;
    }
    return 0;
}

def _visit(m: Mz, h: int, hint: int) -> None {
    if h in m.map {
        return;
    }
    tag = _resolve_row(h, hint);
    if tag == 0 {
        m.map[h] = 0;
        m.skipped += 1;
        return;
    }
    row: ClassRow = _CLS[tag];
    o = PyType_GenericAlloc(row.cls_h, 0);
    if o == 0 {
        PyErr_Clear();
        m.map[h] = 0;
        m.skipped += 1;
        return;
    }
    m.map[h] = o;
    _fill_defaults(row, o);
    _copy_fields(m, row, h, o);
    if row.is_node != 0 {
        _copy_shapes(h, o);
        if h in DEFAULT_GRAPH.adj {
            a = DEFAULT_GRAPH.adj[h];
            for tg in a.out {
                peers: list[int] = a.out[tg];
                for t in peers {
                    _enqueue(m, t, 0);
                }
            }
            for tg in a.inn {
                srcs: list[int] = a.inn[tg];
                for t in srcs {
                    _enqueue(m, t, 0);
                }
            }
        }
    }
}

def _patch_refs(m: Mz) -> None {
    n = len(m.ref_o);
    i = 0;
    while i < n {
        t = m.ref_t[i];
        po = 0;
        if t in m.map {
            po = m.map[t];
        }
        PyObject_SetAttr(m.ref_o[i], m.ref_k[i], po if po != 0 else _K.none_h);
        i += 1;
    }
    n = len(m.lst_l);
    i = 0;
    while i < n {
        t = m.lst_t[i];
        po = 0;
        if t in m.map {
            po = m.map[t];
        }
        if po == 0 {
            po = _K.none_h;
        }
        Py_IncRef(po);
        PyList_SetItem(m.lst_l[i], m.lst_i[i], po);
        i += 1;
    }
}

def _edge_lists(m: Mz, h: int, o: int) -> None {
    a = DEFAULT_GRAPH.adj[h];
    d_out = 0;
    for tg in a.out {
        if tg not in _EDGE {
            continue;
        }
        peers: list[int] = a.out[tg];
        pl = PyList_New(0);
        if pl == 0 {
            PyErr_Clear();
            continue;
        }
        for t in peers {
            if t in m.map and m.map[t] != 0 {
                PyList_Append(pl, m.map[t]);
            }
        }
        if d_out == 0 {
            d_out = PyDict_New();
        }
        if d_out != 0 {
            PyDict_SetItem(d_out, _EDGE[tg], pl);
        }
        Py_DecRef(pl);
    }
    d_in = 0;
    for tg in a.inn {
        if tg not in _EDGE {
            continue;
        }
        srcs: list[int] = a.inn[tg];
        wl = PyList_New(0);
        if wl == 0 {
            PyErr_Clear();
            continue;
        }
        for t in srcs {
            if t in m.map and m.map[t] != 0 {
                w = PyWeakref_NewRef(m.map[t], 0);
                if w != 0 {
                    PyList_Append(wl, w);
                    Py_DecRef(w);
                } else {
                    PyErr_Clear();
                }
            }
        }
        if d_in == 0 {
            d_in = PyDict_New();
        }
        if d_in != 0 {
            PyDict_SetItem(d_in, _EDGE[tg], wl);
        }
        Py_DecRef(wl);
    }
    if d_out != 0 or d_in != 0 {
        anchor = PyObject_GetAttr(o, _K.k_jac);
        if anchor != 0 {
            if d_out != 0 {
                PyObject_SetAttr(anchor, _K.k_out, d_out);
            }
            if d_in != 0 {
                PyObject_SetAttr(anchor, _K.k_in, d_in);
            }
            Py_DecRef(anchor);
        } else {
            PyErr_Clear();
        }
        if d_out != 0 {
            Py_DecRef(d_out);
        }
        if d_in != 0 {
            Py_DecRef(d_in);
        }
    }
}

def _run(root: int, root_hint: int, do_edges: int) -> int {
    m = Mz(
        map={},
        q=[],
        q_hint=[],
        ref_o=[],
        ref_k=[],
        ref_t=[],
        lst_l=[],
        lst_i=[],
        lst_t=[],
        skipped=0
    );
    m.q.append(root);
    m.q_hint.append(root_hint);
    while m.q {
        h = m.q.pop();
        hint = m.q_hint.pop();
        _visit(m, h, hint);
    }
    _patch_refs(m);
    if do_edges != 0 {
        for h in m.map {
            if m.map[h] != 0 and h in DEFAULT_GRAPH.adj {
                _edge_lists(m, h, m.map[h]);
            }
        }
    }
    out = 0;
    if root in m.map {
        out = m.map[root];
    }
    if out != 0 {
        Py_IncRef(out);
    }
    for h in m.map {
        po = m.map[h];
        if po != 0 {
            Py_DecRef(po);
        }
    }
    _STATS[0] = m.skipped;
    return out;
}

def:pub jc_mz_run(root: int) -> int {
    return _run(root, 0, 1);
}

def:pub jc_mz_obj(h: int, hint: int) -> int {
    return _run(h, hint, 0);
}

def:pub jc_mz_skipped -> int {
    return _STATS[0];
}

def:pub jc_graph_wipe -> int {
    DEFAULT_GRAPH.adj = {};
    DEFAULT_GRAPH.rows = [];
    DEFAULT_GRAPH.free_rows = [];
    DEFAULT_GRAPH.row_of = {};
    DEFAULT_GRAPH.dead = {};
    DEFAULT_GRAPH.regions = {};
    return 0;
}
