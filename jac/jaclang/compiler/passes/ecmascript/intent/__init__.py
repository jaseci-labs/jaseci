"""Backend-agnostic reactive intent IR.

IntentModule holds target-neutral semantics recorded by IntentCollector.
Target adapters lower recorded semantics to ESTree (React/Preact/Solid) or
kotlin_ast (native Compose) at codegen time. Native Compose view IR is stored
on ComposeModule, not IntentModule.
"""
