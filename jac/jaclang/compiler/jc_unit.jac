"""Entry unit for libjac_compiler: the native compiler kernel's C ABI surface.

The kernel parses (and weaves annexes) natively, then hands the whole tree
to Python in one call: jc_parse -> jc_weave* -> jc_finish. jc_finish runs
the materializer (jc_materialize.jac), which builds the ordinary Python
unitree and purges the kernel's graph state for the parse.

This unit is the typed side of the kernel: it holds the parse state and the
typed helpers the raw-world materializer reaches through the C ABI (a raw
handle re-enters the typed world by being passed to an exported function
whose parameter is declared with the real type).
"""

import from c { def PyList_New(n: int) -> int;  }
import from c { def PyList_SetItem(l: int, i: int, v: int) -> int;  }

import from jaclang.compiler.jc_materialize {
    jc_graph_wipe,
    jc_mz_obj,
    jc_mz_run
}

import from jaclang.compiler.frontend.parser.parser { parse_program }
import from jaclang.compiler.frontend.parser.tokens { SrcDiag, CommentData }
import from jaclang.compiler.frontend.unitree { Module, UniNode }
import from jaclang.compiler.frontend.roles { AccessorsRole, BodyRole, SpecRole }
import from jaclang.runtime.osp_model { stable_osp_tag }

obj JcState {
    has mod: (Module | None) = None,
        p_errs: int = 0,
        p_diags: list[SrcDiag] = [],
        comments: list[CommentData] = [],
        lex_diags: list[SrcDiag] = [],
        lex_errs: int = 0;
}

glob _JC: JcState = JcState();

def:pub jc_probe -> int {
    return 44061;
}

def:pub jc_parse(src: str, path: str) -> int {
    _JC.mod = None;
    jc_graph_wipe();
    (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = parse_program(src, path);
    _JC.mod = mod;
    _JC.p_errs = p_errs;
    _JC.p_diags = p_diags;
    _JC.comments = comments;
    _JC.lex_diags = lex_diags;
    _JC.lex_errs = lex_errs;
    return 0 if mod is not None else 1;
}

def:pub jc_weave(annex_src: str, annex_path: str) -> int {
    main_mod = _JC.mod;
    if main_mod is None {
        return 1;
    }
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

def:pub jc_finish -> int {
    mod = _JC.mod;
    if mod is None {
        return 0;
    }
    out = jc_mz_run(id(mod));
    _JC.mod = None;
    return out;
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

def:pub jc_diags -> int {
    out = _mz_list(_JC.p_diags, stable_osp_tag("SrcDiag"));
    _JC.p_diags = [];
    return out;
}

def:pub jc_lexdiags -> int {
    out = _mz_list(_JC.lex_diags, stable_osp_tag("SrcDiag"));
    _JC.lex_diags = [];
    return out;
}

def:pub jc_comments -> int {
    out = _mz_list(_JC.comments, stable_osp_tag("CommentData"));
    _JC.comments = [];
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

def:pub jc_shape3(nd: UniNode) -> int {
    shapes = nd._role_shapes;
    if shapes is None {
        return 0;
    }
    b = _shape_code(shapes.get(BodyRole));
    s = _shape_code(shapes.get(SpecRole));
    a = _shape_code(shapes.get(AccessorsRole));
    return b | (s << 4) | (a << 8);
}

def:pub jc_nlist_len(l: list[UniNode]) -> int {
    return len(l);
}

def:pub jc_nlist_get(l: list[UniNode], i: int) -> UniNode {
    return l[i];
}
