# P0.5 source-string tokenizer (PLAN.md) — expression eval slice.
#
# Re-hosts the CPython 3.14 UTF-8 string tokenizer state machine for the P4
# expression fixtures. Full indentation/f-string/encoding coverage lands in
# follow-on slices; this module accepts UTF-8 source text directly (file I/O
# and decoding stay outside the scanner).
#
# Product module: imports token_model only.

import from token_model {
    ENDMARKER,
    NAME,
    NUMBER,
    NEWLINE,
    ERRORTOKEN,
    LPAR,
    RPAR,
    COMMA,
    TOK_NO_COLUMN,
    EXACT_TOKEN_TYPES,
    exact_token_type,
    tok_token,
    tok_diag,
    mk_diag,
    tok_loc_span,
    tok_no_loc,
}

# ---------------- tokenizer state ----------------
obj tok_state {
    has source: str,
        pos: int = 0,
        lineno: int = 1,
        col_offset: int = 0,
        line_start: int = 0,
        filename: str = "<unknown>",
        exec_input: bool = False,
        done: bool = False,
        error: tok_diag | None = None;
}

def _is_id_start(ch: str) -> bool {
    if ch >= "a" and ch <= "z" {
        return True;
    }
    if ch >= "A" and ch <= "Z" {
        return True;
    }
    if ch == "_" {
        return True;
    }
    return False;
}

def _is_id_continue(ch: str) -> bool {
    if _is_id_start(ch) {
        return True;
    }
    if ch >= "0" and ch <= "9" {
        return True;
    }
    return False;
}

def _is_digit(ch: str) -> bool {
    return ch >= "0" and ch <= "9";
}

def _peek(st: tok_state) -> str {
    if st.pos >= len(st.source) {
        return "";
    }
    return st.source[st.pos];
}

def _advance(st: tok_state) -> str {
    if st.pos >= len(st.source) {
        return "";
    }
    ch = st.source[st.pos];
    st.pos = st.pos + 1;
    st.col_offset = st.col_offset + 1;
    return ch;
}

def _match_operator(st: tok_state) -> tok_token | None {
    rest = st.source[st.pos:];
    # Longest match first (CPython _PyToken_ThreeChars / TwoChars / OneChar).
    if len(rest) >= 3 {
        spell = rest[0:3];
        if spell in EXACT_TOKEN_TYPES {
            start_col = st.col_offset;
            st.pos = st.pos + 3;
            st.col_offset = st.col_offset + 3;
            return tok_token(
                tok_type=EXACT_TOKEN_TYPES[spell],
                spelling=spell,
                lineno=st.lineno,
                col_offset=start_col,
                end_lineno=st.lineno,
                end_col_offset=st.col_offset
            );
        }
    }
    if len(rest) >= 2 {
        spell = rest[0:2];
        if spell in EXACT_TOKEN_TYPES {
            start_col = st.col_offset;
            st.pos = st.pos + 2;
            st.col_offset = st.col_offset + 2;
            return tok_token(
                tok_type=EXACT_TOKEN_TYPES[spell],
                spelling=spell,
                lineno=st.lineno,
                col_offset=start_col,
                end_lineno=st.lineno,
                end_col_offset=st.col_offset
            );
        }
    }
    if len(rest) >= 1 {
        spell = rest[0:1];
        typ = exact_token_type(spell);
        start_col = st.col_offset;
        st.pos = st.pos + 1;
        st.col_offset = st.col_offset + 1;
        return tok_token(
            tok_type=typ,
            spelling=spell,
            lineno=st.lineno,
            col_offset=start_col,
            end_lineno=st.lineno,
            end_col_offset=st.col_offset
        );
    }
    return None;
}

def _read_number(st: tok_state) -> tok_token {
    start = st.pos;
    start_col = st.col_offset;
    ch = _peek(st);
    if ch == "0" {
        _advance(st);
        nxt = _peek(st);
        if nxt == "x" or nxt == "X" or nxt == "b" or nxt == "B" or nxt == "o" or nxt == "O" {
            _advance(st);
            while st.pos < len(st.source) {
                c = _peek(st);
                if c == "_" {
                    _advance(st);
                    continue;
                }
                if _is_digit(c) or c >= "a" and c <= "f" or c >= "A" and c <= "F" {
                    _advance(st);
                    continue;
                }
                break;
            }
        } else {
            while st.pos < len(st.source) {
                c = _peek(st);
                if c == "_" {
                    _advance(st);
                    continue;
                }
                if _is_digit(c) {
                    _advance(st);
                    continue;
                }
                break;
            }
        }
    } else {
        while st.pos < len(st.source) {
            c = _peek(st);
            if c == "_" {
                _advance(st);
                continue;
            }
            if _is_digit(c) {
                _advance(st);
                continue;
            }
            break;
        }
        if _peek(st) == "." {
            _advance(st);
            while st.pos < len(st.source) {
                c = _peek(st);
                if c == "_" {
                    _advance(st);
                    continue;
                }
                if _is_digit(c) {
                    _advance(st);
                    continue;
                }
                break;
            }
        }
        c = _peek(st);
        if c == "e" or c == "E" {
            _advance(st);
            c2 = _peek(st);
            if c2 == "+" or c2 == "-" {
                _advance(st);
            }
            while st.pos < len(st.source) {
                c3 = _peek(st);
                if c3 == "_" {
                    _advance(st);
                    continue;
                }
                if _is_digit(c3) {
                    _advance(st);
                    continue;
                }
                break;
            }
        }
    }
    spell = st.source[start:st.pos];
    return tok_token(
        tok_type=NUMBER,
        spelling=spell,
        lineno=st.lineno,
        col_offset=start_col,
        end_lineno=st.lineno,
        end_col_offset=st.col_offset
    );
}

def _read_name(st: tok_state) -> tok_token {
    start = st.pos;
    start_col = st.col_offset;
    _advance(st);
    while st.pos < len(st.source) {
        c = _peek(st);
        if not _is_id_continue(c) {
            break;
        }
        _advance(st);
    }
    spell = st.source[start:st.pos];
    return tok_token(
        tok_type=NAME,
        spelling=spell,
        lineno=st.lineno,
        col_offset=start_col,
        end_lineno=st.lineno,
        end_col_offset=st.col_offset
    );
}

def tokenizer_from_string(
    source: str, filename: str, exec_input: bool
) -> tok_state {
  # Eval/single input: ensure a trailing newline like decode_str(single=1).
    buf = source;
    if not exec_input {
        if len(buf) == 0 or buf[len(buf) - 1] != "\n" {
            buf = buf + "\n";
        }
    }
    return tok_state(source=buf, filename=filename, exec_input=exec_input);
}

def _endmarker_lineno(st: tok_state) -> int {
    lineno = st.lineno;
    if st.col_offset == 0 and lineno > 1 {
        return lineno - 1;
    }
    return lineno;
}

def tokenizer_next(st: tok_state) -> tok_token | tok_diag {
    if st.done {
        em = _endmarker_lineno(st);
        return tok_token(
            tok_type=ENDMARKER,
            spelling="",
            lineno=em,
            col_offset=TOK_NO_COLUMN,
            end_lineno=em,
            end_col_offset=TOK_NO_COLUMN
        );
    }
    if st.error is not None {
        return st.error;
    }
    while st.pos < len(st.source) {
        ch = _peek(st);
        if ch == " " or ch == "\t" or ch == "\f" {
            _advance(st);
            continue;
        }
        if ch == "\n" {
            start_col = st.col_offset;
            _advance(st);
            st.line_start = st.pos;
            st.lineno = st.lineno + 1;
            st.col_offset = 0;
            return tok_token(
                tok_type=NEWLINE,
                spelling="",
                lineno=st.lineno - 1,
                col_offset=start_col,
                end_lineno=st.lineno - 1,
                end_col_offset=start_col
            );
        }
        if ch == "\r" {
            start_col = st.col_offset;
            _advance(st);
            if _peek(st) == "\n" {
                _advance(st);
            }
            st.line_start = st.pos;
            st.lineno = st.lineno + 1;
            st.col_offset = 0;
            return tok_token(
                tok_type=NEWLINE,
                spelling="",
                lineno=st.lineno - 1,
                col_offset=start_col,
                end_lineno=st.lineno - 1,
                end_col_offset=start_col
            );
        }
        if _is_digit(ch) {
            return _read_number(st);
        }
        if _is_id_start(ch) {
            return _read_name(st);
        }
        op = _match_operator(st);
        if op is not None {
            return op;
        }
        bad = mk_diag(
            "SyntaxError",
            "invalid character in identifier",
            tok_loc_span(st.lineno, st.lineno, st.col_offset, st.col_offset + 1),
            st.filename
        );
        st.error = bad;
        st.done = True;
        return bad;
    }
    st.done = True;
    em = _endmarker_lineno(st);
    return tok_token(
        tok_type=ENDMARKER,
        spelling="",
        lineno=em,
        col_offset=TOK_NO_COLUMN,
        end_lineno=em,
        end_col_offset=TOK_NO_COLUMN
    );
}

def tokenize_all(source: str, filename: str, exec_input: bool) -> list[tok_token | tok_diag] {
    st = tokenizer_from_string(source, filename, exec_input);
    out: list[tok_token | tok_diag] = [];
    while True {
        tok = tokenizer_next(st);
        out.append(tok);
        if isinstance(tok, tok_diag) {
            break;
        }
        if tok.tok_type == ENDMARKER {
            break;
        }
    }
    return out;
}
