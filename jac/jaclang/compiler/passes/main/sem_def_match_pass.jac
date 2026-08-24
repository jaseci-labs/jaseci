import from jaclang.jac0core.unitree { Module, SemDef, Symbol, UniScopeNode }
import from jaclang.jac0core.passes.transform { Transform }

class SemDefMatchPass(Transform) {
    def transform(self: SemDefMatchPass, ir_in: Module) -> Module;
    def resolve_sem_target(
        self: SemDefMatchPass, semdef: SemDef, target_sym_tab: UniScopeNode
    ) -> (Symbol | None);

    def connect_sems(
        self: SemDefMatchPass,
        source_sym_tab: UniScopeNode,
        target_sym_tab: UniScopeNode
    ) -> None;
}
