import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.types.types { ClassType }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import jaclang.compiler.frontend.unitree as uni;
import os;

obj NaIRGenSets(NaIRGenState) {
    def _emit_set_helpers(
        elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
    ) -> None;

    def _codegen_set_val(nd: uni.SetVal) -> (ir.Value | None);
}
