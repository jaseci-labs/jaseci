import os;
import from jaclang.compiler.driver.program { JacProgram }

obj SelfHostCache {
    has _program: (JacProgram | None) = None,
        _jaclang_root: (str | None) = None,
        _bytecode_depth: int = 0;

    has program: JacProgram { getter; }

    def peek_program -> (JacProgram | None) {
        return self._program;
    }

    def is_selfhost(prog: (JacProgram | None)) -> bool {
        return self._program is not None and prog is self._program;
    }

    def jaclang_root -> str {
        resolved = self._jaclang_root;
        if (resolved is None) {
            import jaclang;
            resolved = os.path.realpath(os.path.dirname(str(jaclang.__file__)));
            self._jaclang_root = resolved;
        }
        return resolved;
    }

    def owns(file_path: str) -> bool {
        normalized_path = os.path.realpath(file_path);
        return normalized_path.startswith((self.jaclang_root() + os.sep));
    }

    def resolve(
        file_path: str, target_program: JacProgram, force: bool = False
    ) -> JacProgram {
        if not force and self.owns(file_path) {
            return self.program;
        }
        return target_program;
    }

    def enter_bytecode {
        self._bytecode_depth += 1;
    }

    def exit_bytecode {
        self._bytecode_depth -= 1;
    }

    def at_outermost_bytecode -> bool {
        return self._bytecode_depth == 1;
    }
}

impl SelfHostCache.program.getter -> JacProgram {
    if (self._program is None) {
        self._program = JacProgram();
    }
    return self._program;
}
