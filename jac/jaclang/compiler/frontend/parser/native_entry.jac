import from jaclang.compiler.frontend.parser.parser { parse_program }
import from jaclang.compiler.frontend.parser.tokens { SrcDiag, CommentData }
import from jaclang.compiler.frontend.unitree {
    UniNode, Module, nu_role_shape, nu_sym_category, nu_subtag_tag
}
import from jaclang.compiler.frontend.parser.native_queries { qo_Kid }
import from jaclang.compiler.frontend.parser.native_fields { nf_g_Module_name }

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

def:pub np_role_shape(nd: UniNode, role_name: str) -> int {
    return nu_role_shape(nd, role_name);
}

def:pub np_sym_category(nd: UniNode) -> str {
    return nu_sym_category(nd);
}

def:pub np_subtag_tag(nd: UniNode) -> (UniNode | None) {
    return nu_subtag_tag(nd);
}

def:pub np_err_count -> int {
    return _NP.p_errs;
}

def:pub np_lex_errs -> int {
    return _NP.lex_errs;
}

def:pub np_diag_count -> int {
    return len(_NP.p_diags);
}

def:pub np_diag_msg(i: int) -> str {
    return _NP.p_diags[i].message;
}

def:pub np_diag_code(i: int) -> str {
    return _NP.p_diags[i].code_str;
}

def:pub np_diag_help(i: int) -> str {
    return _NP.p_diags[i].help;
}

def:pub np_diag_is_err(i: int) -> int {
    return 1 if _NP.p_diags[i].is_error else 0;
}

def:pub np_diag_pos(i: int, f: int) -> int {
    loc = _NP.p_diags[i].loc;
    if f == 0 {
        return loc.line;
    }
    if f == 1 {
        return loc.end_line;
    }
    if f == 2 {
        return loc.col_start;
    }
    if f == 3 {
        return loc.col_end;
    }
    if f == 4 {
        return loc.pos_start;
    }
    return loc.pos_end;
}

def:pub np_lexdiag_count -> int {
    return len(_NP.lex_diags);
}

def:pub np_lexdiag_msg(i: int) -> str {
    return _NP.lex_diags[i].message;
}

def:pub np_lexdiag_code(i: int) -> str {
    return _NP.lex_diags[i].code_str;
}

def:pub np_lexdiag_help(i: int) -> str {
    return _NP.lex_diags[i].help;
}

def:pub np_lexdiag_is_err(i: int) -> int {
    return 1 if _NP.lex_diags[i].is_error else 0;
}

def:pub np_lexdiag_pos(i: int, f: int) -> int {
    loc = _NP.lex_diags[i].loc;
    if f == 0 {
        return loc.line;
    }
    if f == 1 {
        return loc.end_line;
    }
    if f == 2 {
        return loc.col_start;
    }
    if f == 3 {
        return loc.col_end;
    }
    if f == 4 {
        return loc.pos_start;
    }
    return loc.pos_end;
}

def:pub np_comment_count -> int {
    return len(_NP.comments);
}

def:pub np_comment_val(i: int) -> str {
    return _NP.comments[i].value;
}

def:pub np_comment_pos(i: int, f: int) -> int {
    c = _NP.comments[i];
    if f == 0 {
        return c.line;
    }
    if f == 1 {
        return c.end_line;
    }
    if f == 2 {
        return c.col_start;
    }
    if f == 3 {
        return c.col_end;
    }
    if f == 4 {
        return c.pos_start;
    }
    return c.pos_end;
}

def:pub np_comment_isblock(i: int) -> int {
    return 1 if _NP.comments[i].is_block else 0;
}

def:pub ql_len(l: list[UniNode]) -> int {
    return len(l);
}

def:pub ql_get(l: list[UniNode], i: int) -> UniNode {
    return l[i];
}

def:pub np_probe -> int {
    m = _NP.mod;
    if m is None {
        return -1;
    }
    return len(qo_Kid(m)) + (len(nf_g_Module_name(m)) * 0);
}
