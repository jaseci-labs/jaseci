"""Neutral intent leaf helpers."""
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.compose.kotlin_ast { KtNode }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    IntentExpr,
    IntentStmt
}
import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }

impl is_kt_leaf(item: any) -> bool {
    return isinstance(item, KtNode);
}

impl intent_expr_to_kt(expr: (IntentExpr | None)) -> (KtNode | None) {
    if expr is None {
        return None;
    }
    if isinstance(expr, KtNode) {
        return expr;
    }
    import from jaclang.compiler.passes.compose.es_to_kotlin { es_expr_to_kt }
    return es_expr_to_kt(expr);
}

impl intent_stmt_to_kt(stmt: IntentStmt) -> (KtNode | None) {
    if isinstance(stmt, KtNode) {
        return stmt;
    }
    import from jaclang.compiler.passes.compose.es_to_kotlin { es_stmt_to_kt }
    return es_stmt_to_kt(stmt);
}

impl intent_stmts_to_kt(stmts: list[IntentStmt]) -> list[KtNode] {
    out: list[KtNode] = [];
    for stmt in stmts {
        kt_node = intent_stmt_to_kt(stmt);
        if kt_node is not None {
            out.append(kt_node);
        }
    }
    return out;
}

impl intent_expr_to_src(expr: (IntentExpr | None)) -> str {
    if expr is None {
        return "null";
    }
    kt_node = intent_expr_to_kt(expr);
    if kt_node is None {
        return "null";
    }
    return kt_to_source(kt_node).strip();
}

impl intent_stmts_to_src(
    stmts: list[IntentStmt], indent: str = "        "
) -> str {
    lines: list[str] = [];
    for stmt in stmts {
        kt_node = intent_stmt_to_kt(stmt);
        if kt_node is None {
            continue;
        }
        src = kt_to_source(kt_node).strip();
        for line in src.split("\n") {
            lines.append(f"{indent}{line}" if line else "");
        }
    }
    if not lines {
        return f"{indent}// effect body";
    }
    return "\n".join(lines);
}
