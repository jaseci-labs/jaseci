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

"""Create the loop-exit blocks for a loop that may carry an `else` clause.

Python loop semantics (PEP 530/341): the else body runs only when the loop
exhausts normally, so exhaustion must land on a dedicated block that falls
through to the loop's end while `break` still targets the end directly.
Returns (else_bb, end_bb); else_bb is None when the loop has no else."""
impl NaIRGenState._loop_exit_blocks(func: object, nd: uni.UniNode, prefix: str) -> tuple {
    else_bb = (
        func.append_basic_block(name=f"{prefix}.else")
        if nd.else_body is not None
        else None
    );
    end_bb = func.append_basic_block(name=f"{prefix}.end");
    return (else_bb, end_bb);
}

"""Emit the else body of a loop between its exhaustion edge and the end block.

Call right after popping the loop stack; positions at end_bb afterwards."""
impl NaIRGenState._emit_loop_else(
    nd: uni.UniNode, else_bb: (object | None), end_bb: object
) -> None {
    if else_bb is not None {
        self.builder.position_at_end(else_bb);
        self._codegen_body(nd.else_body.body);
        if not self.builder.block.is_terminated {
            self.builder.branch(end_bb);
        }
    }
    self.builder.position_at_end(end_bb);
}
