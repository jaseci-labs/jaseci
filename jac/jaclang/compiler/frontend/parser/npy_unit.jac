"""The native front end's Python-facing surface (#8789 PyObject-unitree).

Nodes built by the natively compiled parser carry CPython object headers,
so this unit's exports traffic in Python objects directly: np_parse returns
the Module, the diagnostic getters return PyLists of header-carrying diag
objects, and the adjacency/connect wrappers take node addresses that ARE
PyObject pointers. There is no handle scheme, no proxy layer, and no
per-field accessor surface -- scalar fields cross through the generated
type slots the installer builds from the layout sidecar.
"""

import from c { def PyList_New(n: int) -> int;  }
import from c { def PyList_SetItem(l: int, i: int, v: int) -> int;  }

import from jaclang.compiler.frontend.parser.parser { parse_program }
import from jaclang.compiler.frontend.parser.tokens { SrcDiag, CommentData }
import from jaclang.compiler.frontend.unitree { UniNode, Module, nu_role_shape }
import from jaclang.runtime.osp_graph {
    osp_conn, osp_refs, osp_disconn_between
}

obj NpState {
    has mod: (Module | None) = None,
        p_errs: int = 0,
        p_diags: list[SrcDiag] = [],
        comments: list[CommentData] = [],
        lex_diags: list[SrcDiag] = [],
        lex_errs: int = 0;
}

glob _NP: NpState = NpState();

def:pub np_parse(src: str, path: str) -> UniNode {
    (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = parse_program(src, path);
    _NP.mod = mod;
    _NP.p_errs = p_errs;
    _NP.p_diags = p_diags;
    _NP.comments = comments;
    _NP.lex_diags = lex_diags;
    _NP.lex_errs = lex_errs;
    return mod;
}

def:pub np_weave(main_mod: Module, annex_src: str, annex_path: str) -> int {
    (a_mod, a_errs, _pd, _cm, _ld, a_lex_errs) = parse_program(annex_src, annex_path);
    if a_errs > 0 or a_lex_errs > 0 {
        return 1;
    }
    stmts = list(a_mod.body);
    if stmts {
        main_mod.absorb_annex_body(stmts);
        for sub in a_mod._in_mod_nodes {
            if sub is not a_mod {
                main_mod._in_mod_nodes.append(sub);
            }
        }
    }
    return 0;
}

def:pub np_err_count -> int {
    return _NP.p_errs;
}

def:pub np_lex_errs -> int {
    return _NP.lex_errs;
}

def _pyobj_list(items: list) -> int {
    """A PyList of header-carrying unit objects: the element addresses are
    already PyObject pointers, and immortality makes the stolen references
    PyList_SetItem takes a no-op."""
    out = PyList_New(len(items));
    i = 0;
    for it in items {
        PyList_SetItem(out, i, id(it));
        i += 1;
    }
    return out;
}

def:pub np_diags -> int {
    return _pyobj_list(_NP.p_diags);
}

def:pub np_lexdiags -> int {
    return _pyobj_list(_NP.lex_diags);
}

def:pub np_comments -> int {
    return _pyobj_list(_NP.comments);
}

def:pub npy_adj(nd: int, tag: int, dir: int) -> int {
    """One adjacency read as a PyList of nodes. dir: 1 = in, 2 = out."""
    peers = osp_refs(nd, dir, tag, 0);
    out = PyList_New(len(peers));
    i = 0;
    for p in peers {
        PyList_SetItem(out, i, p);
        i += 1;
    }
    return out;
}

def:pub npy_conn(src: int, tgt: int, tag: int) -> int {
    return osp_conn(src, tgt, 0, 0, tag, 0, 0);
}

def:pub npy_disconn(src: int, tgt: int, dir: int, tag: int) -> int {
    return osp_disconn_between(src, tgt, dir, tag);
}

def:pub npy_role_clear(nd: int, dir: int, tag: int) -> int {
    peers = osp_refs(nd, dir, tag, 0);
    n = 0;
    for p in peers {
        if dir == 2 {
            n += osp_disconn_between(nd, p, 2, tag);
        } else {
            n += osp_disconn_between(p, nd, 2, tag);
        }
    }
    return n;
}

def:pub np_role_shape(nd: UniNode, role_name: str) -> int {
    return nu_role_shape(nd, role_name);
}

def:pub np_probe -> int {
    return 44061;
}

def:pub npy_list_len(l: list[UniNode]) -> int {
    return len(l);
}

def:pub npy_list_get(l: list[UniNode], i: int) -> UniNode {
    return l[i];
}

def:pub npy_list_append(l: list[UniNode], v: UniNode) -> int {
    l.append(v);
    return len(l);
}

def:pub npy_list_new -> list[UniNode] {
    out: list[UniNode] = [];
    return out;
}
