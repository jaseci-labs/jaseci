import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    DictCompr,
    ExprStmt,
    FuncCall,
    FuncSignature,
    InForStmt,
    InnerCompr,
    IterForStmt,
    KVPair,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    Module,
    ModuleCode,
    Name,
    NameAtom,
    ParamVar,
    ReturnStmt,
    SetVal,
    Symbol,
    Test,
    TupleVal,
    UniNode,
    WhileStmt
}
import from jaclang.compiler.driver.mtp { UseSiteInfo }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.transform { Transform }

walker UseSitePass(Transform) {
    has ir_in: Module,
        prog: JacProgram,
        cancel_token: any = None;

    static has REQUIRES: tuple = ('TypeOf', ),
        HOST_PASS: bool = True;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _analyze(mod: Module, nd: Ability) -> UseSiteInfo;
    def _analyze_site(
        nd: Ability, call: FuncCall
    ) -> tuple[((Ability | None), UseSiteInfo, list[tuple[(int, str)]])];

    def _analyze_local(
        nd: Ability, sym: Symbol, home: (UniNode | None)
    ) -> tuple[((Ability | None), UseSiteInfo, list[tuple[(int, str)]])];

    def _classify(u: NameAtom) -> tuple[(str, any)];
    def _walk_trailer_chain(u: NameAtom) -> tuple[(str, any)];
    def _consumer_from(
        nd: Ability,
        call: FuncCall,
        arg_node: UniNode,
        field_pairs: list[tuple[(int, str)]]
    ) -> tuple[((Ability | None), UseSiteInfo)];

    def _param_for_arg(
        cd: Ability, sig: FuncSignature, call: FuncCall, arg_node: UniNode
    ) -> (ParamVar | None);

    def _strip_receiver(
        cd: Ability, call: FuncCall, positional: list, by_name: list
    ) -> tuple[(bool, list, list)];

    def _param_semstr(pv: ParamVar) -> (str | None);
    def _param_type_str(pv: ParamVar) -> str;
    def _norm_type(text: str) -> str;
    def _is_def_name(nm: NameAtom) -> bool;
    def _enclosing_fn_scope(nd: UniNode) -> (UniNode | None);
    def _merge_fields(pairs: list[tuple[(int, str)]]) -> list[str];
    def _reject(reason: str) -> UseSiteInfo;
    def _report_enabled -> bool;
    def _emit_report(rows: list[tuple[(str, UseSiteInfo)]]) -> None;
}
