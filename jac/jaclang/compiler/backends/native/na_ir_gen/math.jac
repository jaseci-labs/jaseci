import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenMath(NaIRGenState) {
    def _codegen_int_pow(
        base: ir.Value, exp: ir.Value, unsigned: bool = False, checked: bool = False
    ) -> ir.Value;

    def _emit_float_pow(
        base: ir.Value, exp: ir.Value, unsigned: bool = False
    ) -> ir.Value;

    def _emit_pow_zero_guard(base: ir.Value) -> None;
    def _codegen_pow(
        base: ir.Value,
        exp: ir.Value,
        exp_node: (uni.Expr | None) = None,
        unsigned: bool = False,
        checked: bool = False
    ) -> ir.Value;

    def _emit_math_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_math_const(name: str) -> (ir.Value | None);
}
