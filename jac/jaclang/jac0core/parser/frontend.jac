import jaclang.jac0core.parser.lexer as na_lexer;

import from .lexer { Lexer }
import from .parser { Parser }
import from jaclang.jac0core.arena { SyntaxArena }
import from jaclang.jac0core.arena_materialize { materialize_module }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.diagnostics { DIAGNOSTICS }
import from jaclang.jac0core.passes.transform { Alert }
import type from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.unitree { CommentToken, Module, Source, Token as UniToken }

glob _NATIVE_PARSE_MEMO: list = [];

def _native_parse -> any {
    if _NATIVE_PARSE_MEMO {
        return _NATIVE_PARSE_MEMO[0];
    }
    fn: any = None;
    try {
        import from jaclang.jac0core.sealed { native_artifact_for }
        found = native_artifact_for("jaclang.jac0core.parser.parser");
        if found is not None {
            import jaclang.jac0core.parser.parser as na_parser;
            import from jaclang.jac0core.native_dylib { DylibEngine, layout_from_dict }
            import from jaclang.jac0core.native_marshal {
                build_ctypes_classes,
                build_enum_maps,
                wrap_native_function
            }
            (lib_path, layout_dict) = found;
            eng = DylibEngine(lib_path);
            eng.initialize();
            layout = layout_from_dict(layout_dict);
            ns = na_parser.__dict__;
            cc = build_ctypes_classes(layout);
            em = build_enum_maps(layout, ns);
            pc: dict = {};
            for sn in layout.structs {
                if ns.get(sn) is not None {
                    pc[sn] = ns[sn];
                }
            }
            fl = layout.functions.get("parse_program");
            bl = layout.functions.get("arena_strtab_blob");
            if fl is not None and bl is not None {
                fn = wrap_native_function(eng, fl, cc, em, pc, layout=layout);
                blob_fn = wrap_native_function(eng, bl, cc, em, pc, layout=layout);
                if fn is not None and blob_fn is not None {
                    fn.__jac_engine__ = eng;
                    fn.__jac_strtab_blob__ = blob_fn;
                }
            }
            if fn is not None {
                _sc = _arena_from_native(
                    fn("with entry { print(1); }", "__seal_selfcheck__.jac")[0], blob_fn
                );
                canary = materialize_module(
                    _sc,
                    Source(
                        "with entry { print(1); }", mod_path="__seal_selfcheck__.jac"
                    )
                );
                if canary.name != "__seal_selfcheck__" or len(canary.body) != 1 {
                    fn = None;
                }
            }
        }
    } except Exception {
        fn = None;
    }
    _NATIVE_PARSE_MEMO.append(fn);
    return fn;
}


def _split_strtab(blob: str) -> list[str] {
    out: list[str] = [];
    i = 0;
    n = len(blob);
    while i < n {
        j = blob.index(":", i);
        ln = int(blob[i:j]);
        out.append(blob[j + 1:j + 1 + ln]);
        i = j + 1 + ln;
    }
    return out;
}


def _arena_from_native(view: any, blob_fn: any) -> SyntaxArena {
    import from jaclang.jac0core.native_marshal { bulk_int_list }
    a = SyntaxArena();
    a.kinds = bulk_int_list(view.kinds);
    a.kid_los = bulk_int_list(view.kid_los);
    a.kid_ns = bulk_int_list(view.kid_ns);
    a.arg_los = bulk_int_list(view.arg_los);
    a.arg_ns = bulk_int_list(view.arg_ns);
    a.kids = bulk_int_list(view.kids);
    a.args = bulk_int_list(view.args);
    a.seqs = bulk_int_list(view.seqs);
    a.posts = bulk_int_list(view.posts);
    a.strtab = _split_strtab(blob_fn(view));
    a.root_id = view.root_id;
    return a;
}


def _replay_diags(diags: any, from_pass: type, prog: JacProgram, diag_src: Source) {
    for d in diags {
        loc = d.loc;
        dtok = UniToken(
            orig_src=diag_src,
            name="ERROR" if d.is_error else "WARNING",
            value="",
            line=loc.line,
            end_line=loc.end_line,
            col_start=loc.col_start,
            col_end=loc.col_end,
            pos_start=loc.pos_start,
            pos_end=loc.pos_end
        );
        code = DIAGNOSTICS.get(d.code_str) if d.code_str else None;
        help_text = getattr(d, "help", "");
        alrt = Alert(
            d.message,
            CodeLocInfo(dtok, dtok),
            from_pass,
            code=code,
            help_text=help_text
        );
        if d.is_error {
            prog.errors_had.append(alrt);
        } else {
            prog.warnings_had.append(alrt);
        }
    }
}

def parse_diags(source: str, file_path: str = "<input>") -> tuple[(bool, list, list)] {
    _np = _native_parse();
    if _np is not None {
        (_arena_v, p_errs, p_diags, _comments, lex_diags, lex_errs) = _np(
            source, file_path
        );
        return (p_errs > 0 or lex_errs > 0, list(p_diags), list(lex_diags));
    }
    (tokens, _comments, lex_diags, lex_errs) = na_lexer.tokenize_full(
        source, file_path
    );
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    parser.parse();
    return (parser.error_count > 0 or lex_errs > 0, parser.diags, lex_diags, );
}


def parse(
    source: str, file_path: str = "<input>", prog: (JacProgram | None) = None
) -> tuple[Module, bool] {
    _np = _native_parse();
    if _np is not None {
        (arena_v, p_errs, p_diags, comments, lex_diags, lex_errs) = _np(
            source, file_path
        );
        arena = _arena_from_native(arena_v, _np.__jac_strtab_blob__);
    } else {
        (tokens, comments, lex_diags, lex_errs) = na_lexer.tokenize_full(
            source, file_path
        );
        parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
        parser.parse();
        arena = parser.b;
        p_errs = parser.error_count;
        p_diags = parser.diags;
    }

    diag_src: Source | None = None;
    if prog is not None and lex_diags {
        diag_src = Source(source, mod_path=file_path);
        _replay_diags(lex_diags, Lexer, prog, diag_src);
    }
    if prog is not None and p_diags {
        if diag_src is None {
            diag_src = Source(source, mod_path=file_path);
        }
        _replay_diags(p_diags, Parser, prog, diag_src);
    }
    module = materialize_module(arena, Source(source, mod_path=file_path));

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
    had_error = p_errs > 0 or lex_errs > 0;
    return (module, had_error);
}
