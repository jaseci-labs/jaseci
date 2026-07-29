import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.compose.kotlin_ast { KtNode }
import from typing { TypeAlias }

glob IntentExpr: TypeAlias = es.Expression | KtNode;
glob IntentStmt: TypeAlias = es.Statement | KtNode;

obj StateField {
    has name: str,
        init_expr: IntentExpr;
}

obj RefField {
    has name: str,
        init_expr: IntentExpr;
}

obj StateUpdate {
    has name: str,
        value: IntentExpr,
        aug_op: (str | None) = None;
}

obj Effect {
    has body: list[IntentStmt],
        deps: list[IntentExpr],
        is_entry: bool = True,
        is_async: bool = False;
}

obj AsyncBoundary {
    has try_expr: IntentExpr,
        awaiting_expr: (IntentExpr | None),
        except_exprs: list[IntentExpr];
}
