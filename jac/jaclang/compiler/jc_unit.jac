import from c { def PyList_New(n: int) -> int;  }
import from c { def PyList_SetItem(l: int, i: int, v: int) -> int;  }
import from c { def Py_DecRef(o: int) -> int;  }

import from jaclang.compiler.jc_materialize {
    hint_commentdata,
    hint_srcdiag,
    jc_graph_wipe,
    jc_mz_dispose,
    jc_mz_obj,
    jc_mz_run,
    jc_mz_shapes3
}

import from jaclang.compiler.frontend.parser.parser { parse_program }
import from jaclang.compiler.frontend.parser.tokens { SrcDiag, CommentData }
import from jaclang.compiler.frontend.unitree { Module, UniNode }
import from jaclang.compiler.frontend.roles { AccessorsRole, BodyRole, SpecRole }

obj JcState {
    has p_errs: int = 0,
        lex_errs: int = 0,
        mod_h: int = 0,
        diags_h: int = 0,
        lexdiags_h: int = 0,
        comments_h: int = 0;
}

glob _JC: JcState = JcState(),
     _ANNEX_SRC: list[str] = [],
     _ANNEX_PATH: list[str] = [];

def:pub jc_probe -> int {
    return 44061;
}

def _drop_h(h: int) {
    if h != 0 {
        Py_DecRef(h);
    }
}

def _clear_results {
    _drop_h(_JC.mod_h);
    _drop_h(_JC.diags_h);
    _drop_h(_JC.lexdiags_h);
    _drop_h(_JC.comments_h);
    _JC.mod_h = 0;
    _JC.diags_h = 0;
    _JC.lexdiags_h = 0;
    _JC.comments_h = 0;
    _JC.p_errs = 0;
    _JC.lex_errs = 0;
}

def _clear_annexes {
    while _ANNEX_SRC {
        _ANNEX_SRC.pop();
    }
    while _ANNEX_PATH {
        _ANNEX_PATH.pop();
    }
}

def:pub jc_annex(src: str, path: str) -> int {
    _ANNEX_SRC.append(src);
    _ANNEX_PATH.append(path);
    return 0;
}

def _weave(r: Region, main_mod: Module, annex_src: str, annex_path: str) -> int {
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

def _materialize(
    r: Region,
    mod: Module,
    p_diags: list[SrcDiag],
    comments: list[CommentData],
    lex_diags: list[SrcDiag]
) -> int {
    out = jc_mz_run(id(mod));
    if out == 0 {
        jc_mz_dispose();
        return 1;
    }
    _apply_shapes(mod);
    _JC.mod_h = out;
    _JC.diags_h = _mz_list(p_diags, hint_srcdiag());
    _JC.lexdiags_h = _mz_list(lex_diags, hint_srcdiag());
    _JC.comments_h = _mz_list(comments, hint_commentdata());
    jc_mz_dispose();
    return 0;
}

def _run_in_region(src: str, path: str) -> int {
    status = 0;
    r = Region();
    in r {
        (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = parse_program(
            src, path
        );
        _JC.p_errs = p_errs;
        _JC.lex_errs = lex_errs;
        if p_errs == 0 and lex_errs == 0 {
            i = 0;
            n = len(_ANNEX_SRC);
            while i < n and status == 0 {
                status = _weave(r, mod, _ANNEX_SRC[i], _ANNEX_PATH[i]);
                i += 1;
            }
        }
        if status == 0 {
            status = _materialize(r, mod, p_diags, comments, lex_diags);
        }
        jc_graph_wipe();
    }
    return status;
}

def:pub jc_run(src: str, path: str) -> int {
    _clear_results();
    jc_graph_wipe();
    status = _run_in_region(src, path);
    _clear_annexes();
    return status;
}

def:pub jc_take_module -> int {
    h = _JC.mod_h;
    _JC.mod_h = 0;
    return h;
}

def:pub jc_take_diags -> int {
    h = _JC.diags_h;
    _JC.diags_h = 0;
    return h;
}

def:pub jc_take_lexdiags -> int {
    h = _JC.lexdiags_h;
    _JC.lexdiags_h = 0;
    return h;
}

def:pub jc_take_comments -> int {
    h = _JC.comments_h;
    _JC.comments_h = 0;
    return h;
}

def:pub jc_err_count -> int {
    return _JC.p_errs;
}

def:pub jc_lex_errs -> int {
    return _JC.lex_errs;
}

def _mz_list(items: list, hint: int) -> int {
    out = PyList_New(len(items));
    i = 0;
    for it in items {
        PyList_SetItem(out, i, jc_mz_obj(id(it), hint));
        i += 1;
    }
    return out;
}

def _shape_code(s: (str | None)) -> int {
    if s is None {
        return 0;
    }
    if s == "one" {
        return 2;
    }
    if s == "many" {
        return 3;
    }
    return 1;
}

def _packed_shapes(nd: UniNode) -> int {
    shapes = nd._role_shapes;
    if shapes is None {
        return 0;
    }
    b = _shape_code(shapes.get(BodyRole));
    sp = _shape_code(shapes.get(SpecRole));
    a = _shape_code(shapes.get(AccessorsRole));
    return b | (sp << 4) | (a << 8);
}

def _apply_shapes(mod: Module) {
    stack: list[UniNode] = [mod];
    seen: set[int] = set();
    while stack {
        cur = stack.pop();
        if id(cur) in seen {
            continue;
        }
        seen.add(id(cur));
        sc = _packed_shapes(cur);
        if sc != 0 {
            jc_mz_shapes3(id(cur), sc);
        }
        for k in cur._children() {
            stack.append(k);
        }
    }
}

def:pub jc_rc_debug(v: int) -> int {
    if v != 0 {
        __rc_debug_enable();
    } else {
        __rc_debug_disable();
    }
    return 0;
}
