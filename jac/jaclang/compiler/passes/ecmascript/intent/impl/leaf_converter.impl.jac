"""LeafConverter base method implementations."""
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.semantics { IntentLeaf }

impl LeafConverter.convert_ref_seed(nd: uni.UniNode) -> IntentLeaf {
    expr = self.convert_expr(nd);
    if expr is not None {
        return expr;
    }
    return self.null_expr;
}

impl LeafConverter.convert_assignment_value(
    nd: uni.Assignment, value_nd: (uni.UniNode | None)
) -> (IntentLeaf | None) {
    if value_nd is None {
        return None;
    }
    return self.convert_expr(value_nd);
}

impl LeafConverter.convert_stmts(nodes: list[uni.UniNode]) -> list[IntentLeaf] {
    return [];
}
