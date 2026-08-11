"""Comptime prelude: the names available to comptime code.

At expansion time the evaluators (jac0core/ct_expand.jac in the full
compiler; the text-level expander in jac0.py for the bootstrap) bind
`ct`, `reflect`, `target`, and `fail` to the live comptime namespaces --
fragment builders, syntactic reflection, the target-codespace set, and
the diagnostic raise. Importing this module gives those same names a
runtime identity so files containing comptime helper defs type-check and
import cleanly; the runtime values are inert placeholders, and calling
into them outside comptime evaluation is an error.
"""

glob ct: any = None,
     reflect: any = None,
     target: any = None;


def fail(msg: str) -> None {
    raise RuntimeError(f"comptime: {msg}");
}
