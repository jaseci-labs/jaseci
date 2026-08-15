import from jaclang.jac0core.unitree { Module }
import from jaclang.jac0core.passes.transform { Transform }

class JacAnnexPass(Transform[Module, Module]) {
    def transform(self: JacAnnexPass, ir_in: Module) -> Module;
    def _merge_annex(self: JacAnnexPass, nd: Module, annex_mod: Module) -> None;
}
