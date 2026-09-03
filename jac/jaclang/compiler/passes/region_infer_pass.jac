import from collections.abc { Sequence }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    FuncCall,
    Module,
    Name,
    NameAtom,
    OpenStmt,
    UniNode
}
import from jaclang.compiler.passes.transform { Transform }

walker RegionInferPass(Transform) {
    has ir_in: Module;

    static has PROVIDES: tuple = ('region-infer', );

    def transform(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _run_impl(ir_in: Module) -> Module;
    def _scan_block(body: Sequence[UniNode]) -> list[tuple[int, int]];
    def _arch_of_call(expr: (UniNode | None)) -> (Archetype | None);
    def _connect_chain_leaves(expr: UniNode) -> (list[Name] | None);
    def _blessed_arch_call(fc: FuncCall, member_sids: set[int]) -> bool;
    def _extent_poisoned(
        body: Sequence[UniNode], open_idx: int, close_idx: int, member_sids: set[int]
    ) -> bool;

    def _is_def_name(nm: NameAtom) -> bool;
    def _wrap_in_open(
        owner: UniNode, body: Sequence[UniNode], open_idx: int, close_idx: int
    ) -> (OpenStmt | None);
}
