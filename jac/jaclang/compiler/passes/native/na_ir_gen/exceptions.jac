import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.type_system.types { ClassType }
import jaclang.jac0core.unitree as uni;

obj NaIRGenExceptions(NaIRGenState) {
    def _get_exception_state_type -> ir.Type;
    def _declare_exception_runtime -> None;
    def _emit_exc_push_helper -> None;
    def _emit_exc_pop_helper -> None;
    def _emit_exc_raise_helper -> None;
    def _emit_runtime_raise(is_error: ir.Value, exc_type_name: str, msg: str) -> None;
    def _exc_class_name_of(t: any, at: uni.UniNode) -> str;
    def _register_exc_class(t: any, at: uni.UniNode) -> str;
    def _user_exc_subclasses(type_name: str) -> list[str];
    def _get_or_register_exc_type(exc_name: str) -> int;
    def _get_exc_descendants(type_name: str) -> list[str];
    def _codegen_raise(nd: uni.RaiseStmt) -> None;
    def _raise_has_frame_handler(nd: uni.RaiseStmt) -> bool;
    def _except_clause_classes(except_node: uni.Except) -> list[str];
    def _codegen_try(nd: uni.TryStmt) -> None;
}
