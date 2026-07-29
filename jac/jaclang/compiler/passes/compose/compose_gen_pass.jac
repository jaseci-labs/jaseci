"""ComposeGenPass — walks uni directly for the native Compose/Android path.

Sibling to EsastGenPass; never produces estree. Records reactive/view intent
into a pass-scoped IntentModule with kotlin_ast leaves and native Compose view IR.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.passes.ecmascript.intent.model { IntentModule }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect
}
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }
import from jaclang.compiler.passes.compose.compose_view_builder { ComposeViewBuilder }

obj ComposeGenPass(UniPass) {
    has model: IntentModule = IntentModule(),
        lowerer: JacToKotlin = JacToKotlin(),
        view_builder: ComposeViewBuilder = ComposeViewBuilder(),
        reactive_vars: set[str] = set(),
        reactive_vars_stack: list[set[str]] = [],
        _view_stack: list[(str | None)] = [],
        _recorded_arch_has: set[int] = set();

    def before_pass -> None;
    def after_pass -> None;
    def enter_ability(nd: uni.Ability) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def exit_arch_has(nd: uni.ArchHas) -> None;
    def exit_jsx_element(nd: uni.JsxElement) -> None;
    def exit_assignment(nd: uni.Assignment) -> None;
    def _return_type_includes_composable(rt: uni.Expr) -> bool;
    def _return_type_route_role(rt: uni.Expr) -> (str | None);
    def _unwrap_body(nd: uni.Ability) -> (list[uni.UniNode] | None);
    def _transform_to_effect(nd: uni.Ability) -> None;
    def _record_arch_has(nd: uni.ArchHas) -> None;
    def _sync_lowerer_reactive_vars -> None;
}

def run_compose_gen_pass(
    mod: uni.Module, prog: any = None, into: (IntentModule | None) = None
) -> IntentModule;
