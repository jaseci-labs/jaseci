# P4 product compilation entry (PLAN.md P0.3 / P0.13).
#
# source -> PyCode. It MUST NOT import host_oracle, marshal transport, or host
# tokenize/ast/compile. The eval-mode path is fully native: tokenizer -> parser
# -> codegen -> assembler. exec/single (statement) modes are Phase C and fail
# loudly rather than falling back to the host.

import from objects { PyObj, py_error }
import from parser_expr { parse_eval_expr }
import from compiler_codegen { compile_eval }
import from assembler { assemble }

# Set True only while the native pipeline runs. Test harnesses use this to
# detect accidental host-bridge calls on the product path. compile_source wraps
# the real work in compile_eval_path so the flag is reset on every return path,
# even when the inner reports a PyError result.
glob product_compile_active: bool = False;

def compile_source(
    source: str, filename: str, mode: str, optimize: int
) -> PyObj {
    product_compile_active = True;
    result = compile_eval_path(source, filename, mode);
    product_compile_active = False;
    return result;
}

# eval-mode native front end. Connects the already byte-exact-verified modules
# (parse_eval_expr -> compile_eval -> assemble). `optimize` is accepted for the
# public contract but does not affect eval expressions (no docstrings/asserts to
# strip); it threads through to Phase C statement compilation unchanged.
def compile_eval_path(source: str, filename: str, mode: str) -> PyObj {
    if mode != "eval" {
        return py_error(
            "NotImplementedError",
            "compile_source: mode '" + mode + "' not yet supported (Phase C)"
        );
    }
    e = parse_eval_expr(source, filename);
    if e is None {
        return py_error(
            "SyntaxError", "compile_source: failed to parse eval expression"
        );
    }
    u = compile_eval(e, filename, "<module>", 1);
    return assemble(u);
}
