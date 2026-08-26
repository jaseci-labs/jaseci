import from jaclang.compiler.backends.native.llvm { ir }

impl NaIRGenState.builder.getter -> ir.IRBuilder {
    if self._builder is None {
        raise RuntimeError(
            "NaIRGenPass.builder read with no active IRBuilder "
            "(outside a function body)"
        );
    }
    return self._builder;
}

impl NaIRGenState.llvm_module.getter -> ir.Module {
    if self._llvm_module is None {
        raise RuntimeError("NaIRGenPass.llvm_module read before postinit built it");
    }
    return self._llvm_module;
}

impl NaIRGenState.type_map.getter -> dict[str, ir.Type] {
    if self._type_map is None {
        raise RuntimeError("NaIRGenPass.type_map read before postinit built it");
    }
    return self._type_map;
}

impl NaIRGenState.complex_struct_type.getter -> ir.Type {
    if self._complex_struct_type is None {
        raise RuntimeError(
            "NaIRGenPass.complex_struct_type read before postinit built it"
        );
    }
    return self._complex_struct_type;
}

impl NaIRGenState.range_struct_type.getter -> ir.Type {
    if self._range_struct_type is None {
        raise RuntimeError(
            "NaIRGenPass.range_struct_type read before postinit built it"
        );
    }
    return self._range_struct_type;
}

impl NaIRGenState.slice_struct_type.getter -> ir.Type {
    if self._slice_struct_type is None {
        raise RuntimeError(
            "NaIRGenPass.slice_struct_type read before postinit built it"
        );
    }
    return self._slice_struct_type;
}

impl NaIRGenState.jacval_type.getter -> ir.Type {
    if self._jacval_type is None {
        raise RuntimeError("NaIRGenPass.jacval_type read before postinit built it");
    }
    return self._jacval_type;
}

impl NaIRGenState._loop_exit_blocks(
    func: ir.Function,
    nd: (uni.WhileStmt | uni.InForStmt | uni.IterForStmt),
    prefix: str
) -> tuple {
    else_bb = (
        func.append_basic_block(name=f"{prefix}.else")
            if nd.else_body is not None
            else None
    );
    end_bb = func.append_basic_block(name=f"{prefix}.end");
    return (else_bb, end_bb);
}

impl NaIRGenState._emit_loop_else(
    nd: (uni.WhileStmt | uni.InForStmt | uni.IterForStmt),
    else_bb: (ir.Block | None),
    end_bb: ir.Block
) -> None {
    if else_bb is not None {
        self.builder.position_at_end(else_bb);
        loop_else = nd.else_body;
        if loop_else is not None {
            self._codegen_body(loop_else.body);
        }
        if not self.builder.block.is_terminated {
            self.builder.branch(end_bb);
        }
    }
    self.builder.position_at_end(end_bb);
}
