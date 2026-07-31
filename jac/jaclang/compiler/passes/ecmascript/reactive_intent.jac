"""Backward-compatible ESTree reactive intent types.

Target-neutral semantics live in intent/semantics.jac. This module re-exports
them with ESTree leaf aliases for existing JS backend and test imports.
"""
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    IntentLeaf,
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
import from jaclang.compiler.passes.ecmascript.intent.es_leaves {
    IntentExpr,
    IntentStmt
}
