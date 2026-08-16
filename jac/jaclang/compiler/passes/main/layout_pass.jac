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

def layout_slot_count(lay: ArchetypeLayout) -> int {
    top = 0;
    for slot in [lay.vtable_ptr_slot, lay.type_tag_slot, lay.reports_slot] {
        if slot is not None and (slot + 1) > top {
            top = slot + 1;
        }
    }
    for finfo in lay.fields {
        if (finfo.index + 1) > top {
            top = finfo.index + 1;
        }
    }
    return top;
}

def headers_agree(child: ArchetypeLayout, base: ArchetypeLayout) -> bool {
    return child.vtable_ptr_slot == base.vtable_ptr_slot
        and child.type_tag_slot == base.type_tag_slot
        and child.reports_slot == base.reports_slot;
}

def adopt_imported_bases(module: Module) -> list[str] {
    """Flatten ancestors that only reached the registry after the pass ran.

    A consumer that subclasses an imported archetype linearizes it from a
    base whose declaration lives in another module, so `_collect_archetypes`
    never sees it and `_build_layout` skips the ancestor whose layout is
    absent. The importing codegen merges the defining module's layouts in
    afterwards, which is late for a registry nothing revisits -- so revisit
    it here, once, with the ancestors in hand.

    A subclass adopts its primary ancestor's slot assignment verbatim, which
    is what makes the two units agree: the ancestor's own methods, and the
    consumer's when it passes the object back, read the object through the
    offsets the defining module assigned. Where the header slots disagree --
    a flat ancestor with no vtable under a subclass that needs one -- no
    assignment satisfies both, so the layout is left as it was and the field
    access stays refused.

    Only layouts this module built are eligible: the merge shares the very
    objects the defining module's registry holds, and reassigning slots in
    one of those would move a field under the unit that owns it.
    """;
    reg = module.gen.layout_registry;
    if reg is None {
        return [];
    }
    adopted: list[str] = [];
    for name in reg.local_names {
        lay = reg.layouts.get(name);
        if lay is None {
            continue;
        }
        ancestors: list[ArchetypeLayout] = [];
        for anc in (lay.mro or [])[1:] {
            anc_lay = reg.layouts.get(anc);
            if anc_lay is not None {
                ancestors.append(anc_lay);
            }
        }
        if not ancestors {
            continue;
        }
        absent = False;
        for anc_lay in ancestors {
            for finfo in anc_lay.fields {
                if finfo.name not in lay.field_index {
                    absent = True;
                }
            }
            for mslot in anc_lay.methods {
                if mslot.name not in lay.method_index {
                    absent = True;
                }
            }
        }
        if not absent or not headers_agree(lay, ancestors[0]) {
            continue;
        }
        adopt_ancestor_slots(lay, ancestors);
        adopted.append(name);
    }
    return adopted;
}

def adopt_ancestor_slots(lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]) {
    primary = ancestors[0];
    fields: list[FieldInfo] = [];
    field_index: dict[str, int] = {};
    parent_field_start: dict[str, int] = {};
    seen: set[str] = set();
    if lay.reports_slot is not None {
        field_index["reports"] = lay.reports_slot;
        seen.add("reports");
    }
    for finfo in primary.fields {
        if finfo.name in seen {
            continue;
        }
        seen.add(finfo.name);
        fields.append(clone_field(finfo, finfo.index));
        field_index[finfo.name] = finfo.index;
    }
    parent_field_start[primary.name] = layout_slot_count(primary) - len(primary.fields);
    next_idx = layout_slot_count(primary);
    for anc_lay in ancestors[1:] {
        parent_field_start[anc_lay.name] = next_idx;
        for finfo in anc_lay.fields {
            if finfo.name in seen {
                continue;
            }
            seen.add(finfo.name);
            fields.append(clone_field(finfo, next_idx));
            field_index[finfo.name] = next_idx;
            next_idx += 1;
        }
    }
    for finfo in lay.fields {
        if finfo.name in seen {
            continue;
        }
        seen.add(finfo.name);
        fields.append(clone_field(finfo, next_idx));
        field_index[finfo.name] = next_idx;
        next_idx += 1;
    }
    lay.fields = sorted(fields, key=lambda (f) { f.index; });
    lay.field_index = field_index;
    lay.parent_field_start = parent_field_start;
    adopt_ancestor_methods(lay, ancestors);
    for anc_lay in ancestors {
        lay.is_acyclic = lay.is_acyclic and anc_lay.is_acyclic;
    }
}

def clone_field(finfo: FieldInfo, index: int) -> FieldInfo {
    return FieldInfo(
        name=finfo.name,
        index=index,
        type_tag=finfo.type_tag,
        type_node=finfo.type_node,
        default_expr=finfo.default_expr,
        owner=finfo.owner,
        is_func_ptr=finfo.is_func_ptr,
        decl_node=finfo.decl_node
    );
}

def adopt_ancestor_methods(lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]) {
    order: list[str] = [];
    source: dict[str, MethodSlot] = {};
    for anc_lay in ancestors {
        for mslot in anc_lay.methods {
            if mslot.name not in source {
                source[mslot.name] = mslot;
                order.append(mslot.name);
            }
        }
    }
    for mslot in lay.methods {
        if mslot.name not in source {
            order.append(mslot.name);
        }
        source[mslot.name] = mslot;
    }
    methods: list[MethodSlot] = [];
    method_index: dict[str, int] = {};
    for (i, mname) in enumerate(order) {
        held = source[mname];
        methods.append(
            MethodSlot(name=mname, index=i, owner=held.owner, signature=held.signature)
        );
        method_index[mname] = i;
    }
    lay.methods = methods;
    lay.method_index = method_index;
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
        local_names: list[str] = [],
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
