import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }

obj GraphBreakDetectPass(UniPass) {
    has _enabled: bool = False,
        _entry_ids: set[int] = set(),
        _mat_seen: set[str] = set();

    def before_pass -> None;
    def _collect_entry_points -> set[int];
    def _resolve_wrapped_entry(call: uni.FuncCall) -> (uni.UniNode | None);
    def _def_node(name: str, ctx: uni.UniNode) -> (uni.UniNode | None);
    def _var_assignment(name: str, ctx: uni.UniNode) -> (uni.Assignment | None);
    def _in_torch_compiled_scope(nd: uni.UniNode) -> bool;
    def enter_if_stmt(nd: uni.IfStmt) -> None;
    def enter_func_call(nd: uni.FuncCall) -> None;
    def _call_name(nd: uni.FuncCall) -> (str | None);
    def _is_user_defined(nd: uni.FuncCall, name: str) -> bool;
    def _body_is_only_raise(body: Sequence[uni.CodeBlockStmt]) -> bool;
}
