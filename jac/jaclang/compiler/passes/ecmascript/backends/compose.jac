"""Compose client framework — satisfies esast runtime resolution for Android targets.

Lowering inherits ReactBackend (esast output is unused when ComposeGenPass emits Kotlin).
"""
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }

obj ComposeBackend(ReactBackend) {
    def name -> str;
    def runtime_source_basename -> str;
}
