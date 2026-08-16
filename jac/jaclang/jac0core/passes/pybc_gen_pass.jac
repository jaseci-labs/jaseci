import ast as ast3;
import marshal;
import from jaclang.jac0core.unitree { Module }
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.diagnostics { E5040, E5043 }

class PyBytecodeGenPass(Transform[Module, Module]) {
    def transform(self: PyBytecodeGenPass, ir_in: Module) -> Module;
    def process_modules(self: PyBytecodeGenPass, root_module: Module) -> None;
    def compile_module_to_bytecode(self: PyBytecodeGenPass, mod: Module) -> None;
}
