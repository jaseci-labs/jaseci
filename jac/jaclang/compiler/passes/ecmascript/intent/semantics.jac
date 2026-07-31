"""Target-neutral reactive intent semantics.

Detection records these structs into IntentModule. Leaf payloads are opaque
per-target expression nodes (ESTree on the JS path, kotlin_ast on Compose).
"""
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.compose.kotlin_ast { KtNode }
import from typing { TypeAlias }

glob IntentLeaf: TypeAlias = es.Expression | KtNode;

obj StateField {
    has name: str,
        init_expr: IntentLeaf;
}

obj RefField {
    has name: str,
        init_expr: IntentLeaf;
}

obj StateUpdate {
    has name: str,
        value: IntentLeaf,
        aug_op: (str | None) = None;
}

obj Effect {
    has body: list[IntentLeaf],
        deps: list[IntentLeaf],
        is_entry: bool = True,
        is_async: bool = False;
}

obj AsyncBoundary {
    has try_expr: IntentLeaf,
        awaiting_expr: (IntentLeaf | None),
        except_exprs: list[IntentLeaf];
}
