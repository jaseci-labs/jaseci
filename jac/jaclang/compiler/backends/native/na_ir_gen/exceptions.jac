import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenExceptions(NaIRGenState) {
    def _get_exception_state_type -> ir.Type;
    def _declare_exception_runtime -> None;
    def _emit_exc_push_helper -> None;
    def _emit_exc_pop_helper -> None;
    def _emit_exc_raise_helper -> None;
    def _emit_runtime_raise(is_error: ir.Value, exc_type_name: str, msg: str) -> None;
    def _get_or_register_exc_type(exc_name: str) -> int;
    def _get_exc_descendants(type_name: str) -> list[str];
    def _codegen_raise(nd: uni.RaiseStmt) -> None;
    def _raise_has_frame_handler(nd: uni.RaiseStmt) -> bool;
    def _codegen_try(nd: uni.TryStmt) -> None;
    def _slot_lowering_active -> bool;
    def _nogc_err_slot -> tuple;
    def _emit_err_check(callee: (uni.Ability | None)) -> None;
    def _emit_err_propagate(loc: str = "") -> None;
    def _codegen_raise_slot(payload: ir.Value, type_id: int, msg: ir.Value) -> None;
    def _codegen_try_slot(nd: uni.TryStmt) -> None;
}
