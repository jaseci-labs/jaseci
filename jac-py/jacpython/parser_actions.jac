# P0.7 parser action helpers (PLAN.md).
#
# Lowers CPython grammar actions (_PyAST_*, _PyPegen_*) into ast_nodes.jac
# objects. Generated parser rules call these helpers; this file is hand-written
# and grows with each grammar profile.

import from objects { PyObj, PyInt, PyBool, py_none }
import from ast_nodes {
    ast_node,
    expr,
    mod,
    operator,
    unaryop,
    boolop,
    cmpop,
    Expression,
    Constant,
    Name,
    Load,
    Store,
    BinOp,
    UnaryOp,
    BoolOp,
    Compare,
    Call,
    IfExp,
    Starred,
    Add,
    Sub,
    Mult,
    Div,
    FloorDiv,
    Mod,
    MatMult,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    USub,
    UAdd,
    Invert,
    Not,
    And,
    Or,
    Eq,
    NotEq,
    Lt,
    LtE,
    Gt,
    GtE,
    Is,
    IsNot,
    In,
    NotIn,
    cmpop,
    keyword,
}
import from peg_runtime { peg_parser, peg_token, peg_has_error, peg_raise_syntax_error }

obj pa_cmpop_expr_pair {
    has cmpop: cmpop,
        expr: expr;
}

def pa_extra(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> tuple[int, int, int, int] {
    return (lineno, col_offset, end_lineno, end_col_offset);
}

def pa_name_id(ast_name: expr) -> str {
    if isinstance(ast_name, Name) {
        n = ast_name as Name;
        return n.id;
    }
    return "";
}

def pa_name_from_token(tok: peg_token | None) -> Name | None {
    if tok is None {
        return None;
    }
    return Name(
        id=tok.spelling,
        ctx=Load(),
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def _digit_val(c: str) -> int {
    if c >= "0" and c <= "9" {
        return ord(c) - ord("0");
    }
    return -1;
}

def pa_parse_int_spelling(spelling: str) -> int {
    n = 0;
    i = 0;
    while i < len(spelling) {
        d = _digit_val(spelling[i]);
        if d >= 0 {
            n = n * 10 + d;
        }
        i = i + 1;
    }
    return n;
}

def pa_number_from_token(tok: peg_token | None) -> Constant | None {
    if tok is None {
        return None;
    }
    val = PyInt(t="int", val=pa_parse_int_spelling(tok.spelling));
    return Constant(
        value=val,
        kind=None,
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def pa_constant_none(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Constant {
    return Constant(
        value=py_none(),
        kind=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_constant_bool(
    val: bool,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Constant {
    return Constant(
        value=PyBool(t="bool", val=val),
        kind=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_expression(body: expr) -> Expression {
    return Expression(body=body);
}

def pa_ast_binop(
    left: expr,
    op: operator,
    right: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> BinOp {
    return BinOp(
        left=left,
        op=op,
        right=right,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_unaryop(
    op: unaryop,
    operand: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> UnaryOp {
    return UnaryOp(
        op=op,
        operand=operand,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_boolop(
    op: boolop,
    values: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> BoolOp {
    return BoolOp(
        op=op,
        values=values,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_compare(
    left: expr,
    ops: list[cmpop],
    comparators: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Compare {
    return Compare(
        left=left,
        ops=ops,
        comparators=comparators,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_call(
    func: expr,
    args: list[expr],
    keywords: list[keyword],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    return Call(
        func=func,
        args=args,
        keywords=keywords,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_starred(
    value: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Starred {
    return Starred(
        value=value,
        ctx=Load(),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_ifexp(
    test_expr: expr,
    body: expr,
    orelse: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> IfExp {
    return IfExp(
        test=test_expr,
        body=body,
        orelse=orelse,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_singleton_seq(item: expr) -> list[expr] {
    return [item];
}

def pa_seq_insert_front(head: expr, tail: list[expr]) -> list[expr] {
    out: list[expr] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_make_cmpop_pair(op: cmpop, rhs: expr) -> pa_cmpop_expr_pair {
    return pa_cmpop_expr_pair(cmpop=op, expr=rhs);
}

def pa_get_cmpops(pairs: list[pa_cmpop_expr_pair]) -> list[cmpop] {
    out: list[cmpop] = [];
    i = 0;
    while i < len(pairs) {
        out.append(pairs[i].cmpop);
        i = i + 1;
    }
    return out;
}

def pa_get_exprs(pairs: list[pa_cmpop_expr_pair]) -> list[expr] {
    out: list[expr] = [];
    i = 0;
    while i < len(pairs) {
        out.append(pairs[i].expr);
        i = i + 1;
    }
    return out;
}

def pa_collect_call_seqs(
    args: list[expr],
    kwargs: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    if kwargs is None {
        return pa_ast_call(
            Name(id="", ctx=Load(), lineno=lineno, col_offset=col_offset,
                 end_lineno=end_lineno, end_col_offset=end_col_offset),
            args,
            [],
            lineno,
            col_offset,
            end_lineno,
            end_col_offset
        );
    }
    if isinstance(kwargs, Call) {
        c = kwargs as Call;
        return pa_ast_call(
            c.func,
            args,
            c.keywords,
            lineno,
            col_offset,
            end_lineno,
            end_col_offset
        );
    }
    return pa_ast_call(
        Name(id="", ctx=Load(), lineno=lineno, col_offset=col_offset,
             end_lineno=end_lineno, end_col_offset=end_col_offset),
        args,
        [],
        lineno,
        col_offset,
        end_lineno,
        end_col_offset
    );
}

def pa_call_from_optional_args(
    func: expr,
    args_expr: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    args: list[expr] = [];
    keywords: list[keyword] = [];
    if args_expr is not None and isinstance(args_expr, Call) {
        c = args_expr as Call;
        args = c.args;
        keywords = c.keywords;
    }
    return pa_ast_call(
        func, args, keywords, lineno, col_offset, end_lineno, end_col_offset
    );
}

def pa_check_version(_msg: str, body: expr) -> expr {
    return body;
}

def pa_check(body: expr) -> expr {
    return body;
}

def pa_unsupported_action(p: peg_parser, label: str) -> None {
    if peg_has_error(p) {
        return None;
    }
    peg_raise_syntax_error(p, False, f"unsupported grammar action: {label}");
    return None;
}
