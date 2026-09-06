"""Bridge metadata uses the target ABI, including small nested aggregates."""

import from jaclang.compiler.backends.native.abi { struct_layouts }
import from jaclang.compiler.backends.native.llvm { binding, ir }

test "a nullable boolean does not add eight bytes of padding" {
    binding.initialize_native_target();
    target = binding.Target.from_default_triple().create_target_machine();
    module = ir.Module(context=ir.Context());
    module.data_layout = str(target.target_data);
    small = ir.LiteralStructType([ir.IntType(8), ir.IntType(1)]);
    example = module.context.get_identified_type("Example");
    example.set_body(ir.IntType(8), small, ir.IntType(8));
    assert struct_layouts(module)["Example"] == ([0, 1, 3], 4);
}
