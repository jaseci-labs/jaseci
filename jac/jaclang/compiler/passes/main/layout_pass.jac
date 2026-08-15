import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    BuiltinType,
    Enum,
    FuncCall,
    FuncSignature,
    HasVar,
    Module,
    Name,
    TupleVal,
    UnaryExpr,
    UniNode
}
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.const_fold { fold_const }
import from jaclang.jac0core.constant { OwnershipKind, Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5030, W5031, W5032 }

glob LAYOUT_COMPATIBLE_PRIMITIVES: set[str] = {
         "int",
         "float",
         "bool",
         "str",
         "bytes",
         "i8",
         "u8",
         "i16",
         "u16",
         "i32",
         "u32",
         "i64",
         "u64",
         "f32",
         "f64",

     },
     VTABLE_HEADER_SLOTS: int = 1;

glob LAYOUT_COMPATIBLE_SCALARS: set[str] = LAYOUT_COMPATIBLE_PRIMITIVES | {"type"};

obj FieldInfo {
    has name: str,
        index: int,
        type_tag: str,
        type_node: (UniNode | None) = None,
        default_expr: (UniNode | None) = None,
        owner: str = "",
        is_func_ptr: bool = False,
        decl_node: (UniNode | None) = None;
}

obj MethodSlot {
    has name: str,
        index: int,
        owner: str,
        signature: (UniNode | None) = None;
}

obj ArchetypeLayout {
    has name: str,
        arch_type: str,
        parents: list[str] = [],
        mro: list[str] = [],
        fields: list[FieldInfo] = [],
        field_index: dict[str, int] = {},
        methods: list[MethodSlot] = [],
        method_index: dict[str, int] = {},
        has_vtable: bool = False,
        parent_field_start: dict[str, int] = {},
        is_osp: bool = False,
        is_acyclic: bool = False,
        vtable_ptr_slot: (int | None) = None,
        type_tag_slot: (int | None) = None,
        reports_slot: (int | None) = None;
}

obj EnumMemberLayout {
    has name: str,
        ordinal: int,
        int_value: int = 0,
        str_value: (str | None) = None;
}

obj EnumLayout {
    has name: str,
        underlying: str = "i64",
        is_string_enum: bool = False,
        is_class_form: bool = False,
        members: list[EnumMemberLayout] = [];
}

glob ACCESSOR_SLOT_SUFFIX: dict[str, str] = {
         "property": "__get__",
         "setter": "__set__",
         "deleter": "__del__"
     };

def accessor_slot_name(field_name: str, acc: Ability) -> (str | None) {
    suffix = ACCESSOR_SLOT_SUFFIX.get(acc.accessor_kind);
    return None if suffix is None else f"{field_name}.{suffix}";
}

def archetype_accessors(arch: Archetype) -> list[tuple[(str, HasVar, Ability)]] {
    out: list[tuple[(str, HasVar, Ability)]] = [];
    for var in arch.get_has_vars() {
        if not var.accessors {
            continue;
        }
        fname = var.name.value if var.name else "field";
        for acc in var.accessors {
            slot = accessor_slot_name(fname, acc);
            if slot is not None {
                out.append((slot, var, acc, ));
            }
        }
    }
    return out;
}

def get_layout_registry(module: Module, prog: any = None) -> LayoutRegistry {
    reg = module.gen.layout_registry;
    if reg is not None {
        return reg;
    }

    import from jaclang.jac0core.compiler { run_pass }
    run_pass(LayoutPass, module, prog);
    return module.gen.layout_registry or LayoutRegistry();
}

def is_comptime_base_name(name: str, archetypes: dict[str, Archetype]) -> bool {
    import from jaclang.jac0core.codeinfo { NATIVE_COMPTIME_BASES }
    return name in NATIVE_COMPTIME_BASES and name not in archetypes;
}

def is_enum_class_type(t: any) -> bool {
    try {
        import from jaclang.compiler.type_system.types { ClassType as _ClassType }
    } except ImportError {
        return False;
    }
    return isinstance(t, _ClassType)
        and t._shared is not None
        and t.shared.is_enum_class;
}

def enum_decl_of(t: any) -> (Enum | Archetype | None) {
    if not is_enum_class_type(t) {
        return None;
    }
    _scope = t.shared.symbol_table;
    if isinstance(_scope, Enum) {
        return _scope;
    }
    return _scope if class_form_enum_scalar(t) is not None else None;
}

def enum_value_type_of(t: any) -> (any | None) {
    return t.shared.enum_value_type if is_enum_class_type(t) else None;
}

def class_form_enum_scalar(t: any) -> (str | None) {
    if not is_enum_class_type(t) {
        return None;
    }
    if not isinstance(t.shared.symbol_table, Archetype) {
        return None;
    }
    _vt = t.shared.enum_value_type;
    if _vt is None or not (_vt?.shared) {
        return None;
    }
    _vname = _vt.shared.class_name;
    return _vname if _vname in ("str", "int") else None;
}

def class_form_enum_decls(module: Module) -> list[Archetype] {
    out: list[Archetype] = [];
    for nd in UniPass.get_all_sub_nodes(module, Archetype) {
        if nd.name is None {
            continue;
        }
        if class_form_enum_scalar(nd.name.type) is not None {
            out.append(nd);
        }
    }
    return out;
}

def enum_member_literal(value_expr: (UniNode | None)) -> (str | int | None) {
    (folded, val) = fold_const(value_expr);
    if not folded or isinstance(val, bool) or not isinstance(val, (str, int)) {
        return None;
    }
    return val;
}

def class_form_enum_literal(t: any, member: str) -> (str | int | None) {
    _scope = t.shared.symbol_table;
    _sym = _scope.names_in_scope.get(member) if (_scope?.names_in_scope) else None;
    _decl = _sym.decl if _sym is not None else None;
    _asn = _decl.parent if (_decl is not None) else None;
    if not isinstance(_asn, Assignment) or _asn.value is None {
        return None;
    }
    return enum_member_literal(_asn.value);
}

def class_form_enum_member(t: any) -> (tuple | None) {
    try {
        import from jaclang.compiler.type_system.types {
            EnumMemberType as _EnumMemberType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _EnumMemberType) or t.enum_class is None {
        return None;
    }
    _scalar = class_form_enum_scalar(t.enum_class);
    if _scalar is None or t.member_info is None {
        return None;
    }
    _name = t.member_info.member_name;
    _lit = class_form_enum_literal(t.enum_class, _name);
    if _scalar == "str" and isinstance(_lit, str) {
        return (_scalar, _lit, _name);
    }
    if _scalar == "int" and isinstance(_lit, int) and not isinstance(_lit, bool) {
        return (_scalar, _lit, _name);
    }
    return None;
}

obj LayoutRegistry {
    has layouts: dict[str, ArchetypeLayout] = {},
        class_parents: dict[str, list[str]] = {},
        mro_order: dict[str, list[str]] = {},
        topo_order: list[str] = [],
        enums: dict[str, EnumLayout] = {};

    def get_layout(name: str) -> (ArchetypeLayout | None);
    def get_enum_layout(name: str) -> (EnumLayout | None);
    def resolve_method_owner(arch_name: str, method_name: str) -> (str | None);
    def get_mro(name: str) -> list[str];
    def get_topo_order -> list[str];
    def is_primary_ancestor(child: str, ancestor: str) -> bool;
}

obj LayoutPass(Transform[Module, Module]) {
    has ir_in: Module,
        prog: any,
        cancel_token: any = None,
        registry: LayoutRegistry postinit,
        isinstance_targets: set[str] postinit;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _collect_archetypes(module: Module) -> dict[str, Archetype];
    def _collect_isinstance_targets(module: Module) -> None;
    def _build_hierarchy(archetypes: dict[str, Archetype]) -> None;
    def _compute_c3_mro(class_name: str) -> list[str];
    def _topo_sort(arch_map: dict[str, Archetype]) -> list[str];
    def _build_layout(arch: Archetype) -> ArchetypeLayout;
    def _build_enum_layouts(module: Module) -> None;
    def _compute_acyclicity -> None;
    def _acyclic_walk(name: str, state: dict[str, int]) -> int;
    def _expand_type_keys(key: str) -> (list[str] | None);
    def _split_top_level(s: str, sep: str) -> list[str];
    def _build_vtable_layout(arch_name: str, arch_map: dict[str, Archetype]) -> None;
    def _validate_obj_fields(arch: Archetype, arch_map: dict[str, Archetype]) -> None;
    def _is_layout_compatible_type(
        type_node: (UniNode | None), arch_map: dict[str, Archetype]
    ) -> bool;
}
