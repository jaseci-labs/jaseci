import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.runtime.scalars { ScalarShape }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenSized(NaIRGenState) {
    def _scalar_shape(nd: (uni.UniNode | None)) -> (ScalarShape | None);
    def _scalar_shape_named(name: (str | None)) -> (ScalarShape | None);
    def _is_unsigned_node(nd: (uni.UniNode | None)) -> bool;
    def _is_sized_node(nd: (uni.UniNode | None)) -> bool;
    def _is_signed_sized_node(nd: (uni.UniNode | None)) -> bool;
    def _scalar_llvm(shape: ScalarShape) -> ir.Type;
    def _lower_coercion(nd: uni.Expr, val: ir.Value) -> ir.Value;
    def _convert_scalar(val: ir.Value, src: ScalarShape, dst: ScalarShape) -> ir.Value;
    def _codegen_sized_cast(nd: uni.FuncCall, name: str) -> (ir.Value | None);
    def _codegen_sized_wrap(nd: uni.FuncCall, name: str) -> (ir.Value | None);
    def _codegen_sized_bound(name: str, attr: str) -> (ir.Value | None);
    def _codegen_wrapping(nd: uni.FuncCall, name: str) -> (ir.Value | None);
    def _codegen_type_name_str(name: str) -> ir.Value;
    def _emit_checked_int_cast(
        val: ir.Value, src: ScalarShape, dst: ScalarShape
    ) -> ir.Value;

    def _emit_float_to_int_cast(
        val: ir.Value, src: ScalarShape, dst: ScalarShape
    ) -> ir.Value;

    def _emit_wrap_to(val: ir.Value, src: ScalarShape, dst: ScalarShape) -> ir.Value;
    def _emit_overflow_op(
        op: str, left: ir.Value, right: ir.Value, unsigned: bool
    ) -> ir.Value;

    def _emit_checked_neg(val: ir.Value) -> ir.Value;
    def _emit_checked_abs(val: ir.Value) -> ir.Value;
    def _emit_shift_count_check(count: ir.Value, width: int) -> None;
    def _shift_count_as(count: ir.Value, target: ir.Type) -> ir.Value;
    def _emit_checked_shl(left: ir.Value, right: ir.Value, unsigned: bool) -> ir.Value;
    def _emit_shr(left: ir.Value, right: ir.Value, unsigned: bool) -> ir.Value;
    def _emit_int_divmod(
        left: ir.Value, right: ir.Value, unsigned: bool, trap_min: bool = True
    ) -> tuple[(ir.Value, ir.Value)];
}
