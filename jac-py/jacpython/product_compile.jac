# P4 product compilation entry (PLAN.md P0.3 / P0.13).
#
# The eventual source -> PyCode path. It MUST NOT import host_oracle, marshal
# transport, or host tokenize/ast/compile. Until the front end lands, calls
# fail loudly rather than falling back to the host.

import from objects { PyObj, PyCode, py_error, is_error }

# Set True only inside compile_source while the native pipeline runs. Test
# harnesses use this to detect accidental host-bridge calls on the product path.
glob product_compile_active: bool = False;

def compile_source(
    source: str, filename: str, mode: str, optimize: int
) -> PyObj {
    product_compile_active = True;
    # P0.13 will wire tokenizer -> parser -> symtable -> codegen -> assembler.
    product_compile_active = False;
    return py_error(
        "NotImplementedError",
        "compile_source: native front end not yet connected (P4)"
    );
}
