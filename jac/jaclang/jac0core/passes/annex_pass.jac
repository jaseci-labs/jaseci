import from jaclang.jac0core.unitree { Module }
import from jaclang.jac0core.bccache { discover_annex_files }
import from jaclang.jac0core.passes.transform { Transform }
import type from jaclang.jac0core.program { JacProgram }

class JacAnnexPass(Transform[Module, Module]) {
    def transform(self: JacAnnexPass, ir_in: Module) -> Module;
    def _load_annexes(
        self: JacAnnexPass, jac_program: JacProgram, nd: Module, mod_path: str
    ) -> None;

    def _merge_annex_group(
        self: JacAnnexPass, nd: Module, base_path: str, ctx_path: str, seen: set[str]
    ) -> None;

    def _merge_annex(
        self: JacAnnexPass, nd: Module, path: str, ctx_path: str, seen: set[str]
    ) -> None;
}
