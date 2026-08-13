"""Fixture for the str()-of-a-str pass-through under native lowering.

str(x) on a value that is already a str is identity: the result aliases the
argument. The call machinery releases owned argument temporaries after the
call, so the alias must carry its own reference or the buffer is freed while
the enclosing expression still reads it (#8109: every `str("".join(...))`
came back empty, which renamed every quoted test block to _jac_gen_N in the
sealed parser).
"""

def join_ident(src_text: str) -> str {
    chs: list[str] = [];
    for ch in src_text {
        chs.append(ch);
    }
    return str("".join(chs));
}

def join_sep_len(src_text: str) -> int {
    chs: list[str] = [];
    for ch in src_text {
        chs.append(ch);
    }
    return len(str("-".join(chs)));
}

def str_of_owned_slice(src_text: str) -> str {
    return str(src_text[1:]);
}
