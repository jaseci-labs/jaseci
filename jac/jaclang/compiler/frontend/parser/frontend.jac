import jaclang.compiler.frontend.parser.lexer as na_lexer;
import jaclang.compiler.store.host as _tsr;

import from .lexer { Lexer }
import from .parser { Parser }
import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
import from jaclang.compiler.passes.transform { Alert }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.compiler.frontend.unitree { CommentToken, Module, Source }

def _replay_diags(diags: any, from_pass: type, prog: JacProgram, diag_src: Source) {
    for d in diags {
        loc = d.loc;
        span = Span.make(
            diag_src.file_path,
            diag_src.code,
            (loc.line, loc.end_line),
            (loc.col_start, loc.col_end),
            (loc.pos_start, loc.pos_end)
        );
        code = DIAGNOSTICS.get(d.code_str) if d.code_str else None;
        help_text = getattr(d, "help", "");
        alrt = Alert(d.message, span, from_pass, code=code, help_text=help_text);
        if d.is_error {
            prog.errors_had.append(alrt);
        } else {
            prog.warnings_had.append(alrt);
        }
    }
}

def parse_diags(source: str, file_path: str = "<input>") -> tuple[(bool, list, list)] {
    (tokens, _comments, lex_diags, lex_errs) = na_lexer.tokenize_full(
        source, file_path
    );
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    parser.parse();
    return (parser.error_count > 0 or lex_errs > 0, parser.diags, lex_diags, );
}


def parse(
    source: str,
    file_path: str = "<input>",
    prog: (JacProgram | None) = None,
    freeze: bool = True
) -> tuple[Module, bool] {
    _tsr.arena_begin(freeze_at_end=freeze);
    try {
        (tokens, comments, lex_diags, lex_errs) = na_lexer.tokenize_full(
            source, file_path
        );
        parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
        module = parser.parse();
        had_error = _finish_parse(
            module, parser.error_count, parser.diags, comments, lex_diags, lex_errs, prog
        );
    } finally {
        _tsr.arena_end();
    }
    return (module, had_error);
}

def _finish_parse(
    module: Module,
    p_errs: int,
    p_diags: any,
    comments: any,
    lex_diags: any,
    lex_errs: int,
    prog: (JacProgram | None)
) -> bool {
    diag_src: Source | None = None;
    if prog is not None and lex_diags {
        diag_src = module.source;
        _replay_diags(lex_diags, Lexer, prog, diag_src);
    }
    if prog is not None and p_diags {
        if diag_src is None {
            diag_src = module.source;
        }
        _replay_diags(p_diags, Parser, prog, diag_src);
    }
    if module.source and comments {
        for cdata in comments {
            ct = CommentToken(
                orig_src=module.source,
                name="COMMENT",
                value=cdata.value,
                line=cdata.line,
                end_line=cdata.end_line,
                col_start=cdata.col_start,
                col_end=cdata.col_end,
                pos_start=cdata.pos_start,
                pos_end=cdata.pos_end,
                kid=[]
            );
            module.source.comments.append(ct);
        }
    }

    if module.source {
        import re;
        ignore_pattern = re.compile(r'#\s*jac:ignore\[([^\]]+)\]');
        for comment in module.source.comments {
            m = ignore_pattern.search(comment.value);
            if m {
                codes = {c.strip() for c in m.group(1).split(',')};
                line = comment.line_no;
                if line in module.source.inline_suppressions {
                    module.source.inline_suppressions[line].update(codes);
                } else {
                    module.source.inline_suppressions[line] = codes;
                }
            }
        }
    }
    return p_errs > 0 or lex_errs > 0;
}

def _freeze_tree_arena(module: Module) -> None {
    h = getattr(module, "_ts", -1);
    if h >= 0 and (h & 4611686018427387904) == 0 {
        _tsr.arena_freeze(h >> 40);
    }
}

obj _NatLoc {
    has line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0;
}

obj _NatDiag {
    has message: str = "",
        code_str: str = "",
        is_error: bool = True,
        help: str = "",
        loc: (_NatLoc | None) = None;
}

obj _NatComment {
    has value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0;
}

def _nat_diags(fe: any, prefix: str) -> list {
    out = [];
    n = fe.entry_int(f"np_{prefix}_count");
    for i in range(n) {
        loc = _NatLoc(
            line=fe.entry_int(f"np_{prefix}_pos", i, 0),
            end_line=fe.entry_int(f"np_{prefix}_pos", i, 1),
            col_start=fe.entry_int(f"np_{prefix}_pos", i, 2),
            col_end=fe.entry_int(f"np_{prefix}_pos", i, 3),
            pos_start=fe.entry_int(f"np_{prefix}_pos", i, 4),
            pos_end=fe.entry_int(f"np_{prefix}_pos", i, 5)
        );
        out.append(_NatDiag(
            message=fe.entry_str(f"np_{prefix}_msg", i),
            code_str=fe.entry_str(f"np_{prefix}_code", i),
            is_error=fe.entry_int(f"np_{prefix}_is_err", i) != 0,
            help=fe.entry_str(f"np_{prefix}_help", i),
            loc=loc
        ));
    }
    return out;
}

def _nat_comments(fe: any) -> list {
    out = [];
    n = fe.entry_int("np_comment_count");
    for i in range(n) {
        out.append(_NatComment(
            value=fe.entry_str("np_comment_val", i),
            line=fe.entry_int("np_comment_pos", i, 0),
            end_line=fe.entry_int("np_comment_pos", i, 1),
            col_start=fe.entry_int("np_comment_pos", i, 2),
            col_end=fe.entry_int("np_comment_pos", i, 3),
            pos_start=fe.entry_int("np_comment_pos", i, 4),
            pos_end=fe.entry_int("np_comment_pos", i, 5)
        ));
    }
    return out;
}

def _native_parse_woven(
    source_str: str, file_path: str, prog: (JacProgram | None), annexes: list
) -> (tuple | None) {
    fe = _tsr.frontend_lib();
    root_ptr = fe.parse(source_str, file_path);
    if not root_ptr {
        return None;
    }
    p_errs = fe.entry_int("np_err_count");
    lex_errs = fe.entry_int("np_lex_errs");
    p_diags = _nat_diags(fe, "diag");
    comments = _nat_comments(fe);
    lex_diags = _nat_diags(fe, "lexdiag");
    if p_errs == 0 and lex_errs == 0 {
        for (a_src, a_path) in annexes {
            rc = fe.weave(root_ptr, a_src, a_path);
            if rc != 0 {
                return None;
            }
        }
    }
    module = _tsr.native_view(root_ptr);
    had_error = _finish_parse(
        module, p_errs, p_diags, comments, lex_diags, lex_errs, prog
    );
    return (module, had_error);
}

def parse_woven(
    source_str: str, file_path: str, prog: (JacProgram | None), annexes: list
) -> tuple {
    if _tsr.frontend_active() {
        nat = _native_parse_woven(source_str, file_path, prog, annexes);
        if nat is not None {
            return nat;
        }
    }
    (module, had_error) = parse(source_str, file_path, prog=prog, freeze=False);
    if had_error or not annexes {
        _freeze_tree_arena(module);
        return (module, had_error);
    }
    import from jaclang.compiler.passes.annex_weave { merge_annex_into }
    a_mods = [];
    for (a_src, a_path) in annexes {
        (a_mod, _a_err) = parse(a_src, a_path, prog=prog, freeze=False);
        merge_annex_into(module, a_mod);
        a_mods.append(a_mod);
    }
    _freeze_tree_arena(module);
    for a_mod in a_mods {
        _freeze_tree_arena(a_mod);
    }
    return (module, had_error);
}

def annex_sources(file_path: str) -> list[tuple[str, str]] {
    if not file_path.endswith(".jac") {
        return [];
    }
    try {
        import from jaclang.compiler.driver.bccache {
            discover_annex_files,
            discover_base_file
        }
        import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
        if discover_base_file(file_path) is not None {
            return [];
        }
        paths = [
            *discover_annex_files(file_path, ".impl.jac"),
            *discover_annex_files(file_path, ".test.jac")
        ];
    } except Exception {
        return [];
    }
    out: list[tuple[str, str]] = [];
    seen: set[str] = set();
    for pth in paths {
        if pth in seen {
            continue;
        }
        seen.add(pth);
        try {
            out.append((read_file_with_encoding(pth), pth, ));
        } except Exception {
            continue;
        }
    }
    return out;
}
