import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.frontend.diagnostics { E5040, E5043 }

class JcirBytecodeGenPass(Transform) {
    def transform(self: JcirBytecodeGenPass, ir_in: Module) -> Module;
    def process_modules(self: JcirBytecodeGenPass, root_module: Module) -> None;
    def transcribe_module(self: JcirBytecodeGenPass, mod: Module) -> None;
}
