import jaclang.compiler.frontend.unitree as uni;
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.program { JacProgram }

obj ArtifactStore {
    has compiler: JacCompiler;

    def load(full_target: str, program: JacProgram) -> (bytes | None);
    def persist(full_target: str, mod: uni.Module, program: JacProgram) -> None;
    def evict_slim(
        full_target: str, result: (uni.Module | None), collect: bool = True
    ) -> None;
}
