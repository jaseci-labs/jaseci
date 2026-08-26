import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenBytearrayNa(NaIRGenState) {
    def _ensure_bytearray_type -> ir.Type;
    def _bytearray_runtime_fns -> dict;
    def _bytearray_src_of(val: ir.Value) -> (tuple | None);
    def _dispatch_bytearray_method(
        method_name: str, recv: ir.Value, nd: uni.FuncCall
    ) -> (ir.Value | None);

    def _emit_struct_pack_into(
        nd: uni.FuncCall,
        params: Sequence[uni.Expr | uni.KWPair],
        fields: list[tuple[str, int, bool]],
        total: int,
        little: bool
    ) -> (ir.Value | None);
}
