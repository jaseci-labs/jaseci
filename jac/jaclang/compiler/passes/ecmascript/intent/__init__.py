"""Backend-agnostic reactive/view intent IR.

IntentModule is the single source of truth for "what is a state field / ref /
effect / async boundary / state update / view" — recorded exactly once by the
IntentCollector during the EsastGenPass uni walk, with no backend-specific
lowering baked into the recording. JS backends (React/Preact/Solid) lower it to
estree; the Compose emitter lowers it to Kotlin. Neither lowering lives here.
"""
