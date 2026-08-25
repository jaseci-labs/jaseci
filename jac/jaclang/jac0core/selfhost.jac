"""The self-host program cache: where the toolchain's own modules compile.

Jac's compiler is written in jac, so importing any module under the
jaclang tree compiles toolchain sources. Those compiles must not pollute
the program a user's code is building into: they run a different pass
schedule and their units are evicted aggressively once bytecode exists.
This object owns that separate program and the redirect decision that
routes toolchain sources into it. JacRuntime owns the single process-wide
instance (its composition root hands it to every compiler it mints), so
the redirect is a named, visible decision instead of a hidden per-compiler
substitution, and the self-hosted tree compiles once per process rather
than once per compiler (#8681).
"""
import os;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;

obj SelfHostCache {
    has _program: (JacProgram | None) = None,
        _jaclang_root: (str | None) = None,
        _bytecode_depth: int = 0;

    has program: JacProgram { getter; }

    "Return the self-host program if it has been minted, without minting it."
    def peek_program -> (JacProgram | None) {
        return self._program;
    }

    "Whether prog is the (already minted) self-host program."
    def is_selfhost(prog: (JacProgram | None)) -> bool {
        return self._program is not None and prog is self._program;
    }

    def jaclang_root -> str {
        resolved = self._jaclang_root;
        if (resolved is None) {
            resolved = os.path.realpath(os.path.dirname(os.path.dirname(__file__)));
            self._jaclang_root = resolved;
        }
        return resolved;
    }

    """Whether the self-host cache owns compiles of this file.

    Toolchain sources are everything under the jaclang tree except its
    test suites and fixtures: those are ordinary compile targets and
    belong to whatever program the caller is building, so tests no
    longer need force_target_program just because their fixtures live
    inside the package.
    """
    def owns(file_path: str) -> bool {
        normalized_path = os.path.realpath(file_path);
        jl_root = self.jaclang_root();
        if not normalized_path.startswith((jl_root + os.sep)) {
            return False;
        }
        parts = normalized_path[len(jl_root) + 1:].split(os.sep);
        return ("tests" not in parts) and ("fixtures" not in parts);
    }

    """Route a compile to the self-host program or the caller's target.

    The one redirect decision: a file under the jaclang tree compiles into
    the self-host program unless the caller explicitly forces its own
    target (CompileOptions.force_target_program).
    """
    def resolve(
        file_path: str, target_program: JacProgram, force: bool = False
    ) -> JacProgram {
        if not force and self.owns(file_path) {
            return self.program;
        }
        return target_program;
    }

    """Release a self-host compile unit once its bytecode exists.

    Toolchain units are not kept in tree form after their bytecode is
    built; a native engine's artifacts survive on a slim CodeGenTarget so
    interop keeps working after the tree is dropped.
    """
    def evict_unit(full_target: str, result: (uni.Module | None)) -> None {
        import os;
        if os.environ.get("JAC_NO_UNIT_EVICT") {
            return;
        }
        if result is not None and result.gen.native_engine is not None {
            import from jaclang.jac0core.codeinfo { CodeGenTarget }
            slim = CodeGenTarget();
            slim.native_engine = result.gen.native_engine;
            slim.native_layout = result.gen.native_layout;
            slim.interop_py_funcs = result.gen.interop_py_funcs;
            slim._interop_callbacks = result.gen._interop_callbacks;
            slim.interop_manifest = result.gen.interop_manifest;
            self.program.hub.artifacts[full_target] = slim;
        }
        self.program.release_compile_closure(keep_stubs=True);
    }

    "Track nesting of self-host bytecode builds (eviction fires at depth 1)."
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
