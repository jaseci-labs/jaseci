import from jaclang.jac0core.unitree {
    Ability,
    ArchSpec,
    Archetype,
    AtomTrailer,
    CtrlStmt,
    EdgeOpRef,
    EdgeRefTrailer,
    Enum,
    EventSignature,
    Expr,
    FString,
    FilterCompr,
    FormattedValue,
    FuncCall,
    FuncSignature,
    ImplDef,
    Import,
    KWPair,
    LambdaExpr,
    Module,
    ModulePath,
    MultiString,
    Name,
    ParamVar,
    PyInlineCode,
    String,
    SubTag,
    Token,
    UnaryExpr,
    UniNode,
    YieldExpr
}
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.constant { SymbolType }
import from jaclang.jac0core.diagnostics { E5090, E5096, W6001, W6002, W6003, W6004 }
import from jaclang.jac0core.codeinfo { NATIVE_SUPPORTED_STDLIB }

glob NATIVE_REJECT_NODES: tuple = (PyInlineCode, );

def classify_native_import(item: UniNode) -> tuple;

def import_bound_name(item: UniNode) -> (str | None);

"""Whether `name_nd` sits inside the subtree headed by `top`."""
def node_within(name_nd: UniNode, top: (UniNode | None)) -> bool;

"""Whether a name is read by the compiler rather than by the running program.

Annotations, return types and base classes are all resolved at compile time:
`LayoutPass` looks a base up by name while building the hierarchy, and nothing
loads a base object at run time. A Python module named only in such a position
is therefore not a run-time dependency, and whether it can actually be lowered
is the backend's verdict to give rather than the import gate's.
"""
def name_in_type_position(name_nd: UniNode) -> bool;

def static_fstring_spec_text(spec: UniNode) -> (str | None);

def call_has_kwargs_sink(call: FuncCall) -> bool;

def native_capability_violations(mod: Module) -> list;

def native_capability_demotion_owner(viol_node: UniNode) -> (Ability | None);

def partition_native_capability_violations(viols: list) -> tuple;

obj PortabilityWarnPass(Transform[Module, Module]) {
    has ir_in: Module,
        prog: any,
        cancel_token: any = None;

    static has PROVIDES: tuple = ('portability', );

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _check_js_globals(mod: Module) -> None;
    def _check_js_methods(mod: Module) -> None;
    def _find_call_is_js_style(call: FuncCall) -> bool;
    def _check_js_keywords(mod: Module) -> None;
    def _check_js_properties(mod: Module) -> None;
}

obj NativeCapabilityCheckPass(Transform[Module, Module]) {
    static has PROVIDES: tuple = ('capability', );
    has ir_in: Module,
        prog: any,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
}

obj ClientCapabilityCheckPass(Transform[Module, Module]) {
    static has PROVIDES: tuple = ('client_capability', );
    has ir_in: Module,
        prog: any,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
}
