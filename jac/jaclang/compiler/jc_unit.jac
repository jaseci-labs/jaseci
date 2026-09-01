"""Entry unit for libjac_compiler: the native compiler kernel's C ABI surface."""

import from jaclang.compiler.frontend.parser.parser { parse_program }
import from jaclang.compiler.frontend.parser.tokens { SrcDiag, CommentData }
import from jaclang.compiler.frontend.unitree { Module, UniNode }

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

def:pub jc_parse_count(src: str, path: str) -> int {
    (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = parse_program(src, path);
    _JC.mod = mod;
    _JC.p_errs = p_errs;
    _JC.p_diags = p_diags;
    _JC.comments = comments;
    _JC.lex_diags = lex_diags;
    _JC.lex_errs = lex_errs;
    n = 0;
    stack: list[UniNode] = [mod];
    while stack {
        cur = stack.pop();
        n += 1;
        for k in cur.kid {
            stack.append(k);
        }
    }
    return n;
}

def:pub jc_err_count -> int {
    return _JC.p_errs;
}

def:pub jc_lex_errs -> int {
    return _JC.lex_errs;
}
