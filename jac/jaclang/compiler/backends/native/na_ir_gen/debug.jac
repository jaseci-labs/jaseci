import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }

obj NaIRGenDebug(NaIRGenState) {
    def _na_debug_on -> bool;
    def _attach_di_subprogram(func: ir.Function, name: str, line: int) -> None;
    def _finalize_di_locations(func: ir.Function, fallback_line: int) -> None;
    def post_transform -> None;
}
