import from jaclang.compiler.frontend.unitree {
    Ability,
    Expr,
    ArchHas,
    Archetype,
    Assignment,
    Enum,
    EventSignature,
    FuncCall,
    HasVar,
    Import,
    Module,
    ModuleCode,
    ModulePath,
    Name,
    TupleVal,
    UniNode,
    UniScopeNode
}
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.frontend.diagnostics { E5030, E5091, W5031, W5032 }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
import type from jaclang.compiler.driver.program { JacProgram }

glob VTABLE_HEADER_SLOTS: int = 1,
     ACCESSOR_SLOT_SUFFIX: dict[str, str] = {
         "property": "__get__",
         "setter": "__set__",
         "deleter": "__del__"
     };

def layout_scalar_names -> set[str] {
    return {
        n
        for n in JAC_TYPE_REGISTRY.primitive_names()
        if JAC_TYPE_REGISTRY.is_numeric(n)
    }
        | {"str", "bytes"};
}

obj FieldInfo {
    has name: str,
        index: int,
        type: any = None,
        default_expr: (UniNode | None) = None,
        owner: str = "",
        is_func_ptr: bool = False,
        decl_node: (HasVar | None) = None;
}

obj MethodSlot {
    has name: str,
        index: int,
        owner: str,
        ability: (Ability | None) = None,
        field: (HasVar | None) = None;

    has signature: (UniNode | None) { getter; }
}

obj ClassConstInfo {
    has name: str,
        owner: str,
        assign: Assignment,
        target: UniNode,
        type: any = None;
}

obj ArchetypeLayout {
    has name: str,
        arch_type: str,
        decl_mod: str = "",
        decl_node: (Archetype | None) = None,
        class_type: any = None,
        parents: list[str] = [],
        mro: list[str] = [],
        fields: list[FieldInfo] = [],
        field_index: dict[str, int] = {},
        statics: list[FieldInfo] = [],
        class_consts: list[ClassConstInfo] = [],
        methods: list[MethodSlot] = [],
        method_index: dict[str, int] = {},
        has_vtable: bool = False,
        vtable_by_dispatch: bool = False,
        unadopted: list[str] = [],
        is_osp: bool = False,
        is_acyclic: bool = False,
        is_pod: bool = False,
        is_enum_form: bool = False,
        is_clib: bool = False,
        vtable_ptr_slot: (int | None) = None,
        type_tag_slot: (int | None) = None,
        reports_slot: (int | None) = None;

    has key: tuple { getter; }
}

obj EnumMemberLayout {
    has name: str,
        ordinal: int,
        int_value: int = 0,
        str_value: (str | None) = None;
}

obj EnumLayout {
    has name: str,
        decl_mod: str = "",
        decl_node: (Enum | Archetype | None) = None,
        class_type: any = None,
        underlying: str = "i64",
        is_string_enum: bool = False,
        is_class_form: bool = False,
        all_values_known: bool = True,
        members: list[EnumMemberLayout] = [];

    has key: tuple { getter; }
}

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

def module_real_path(module: (Module | None)) -> str {
    import os;
    if module is None or module.loc is None {
        return "";
    }
    path = module.loc.mod_path;
    return os.path.realpath(path) if path else "";
}

def get_layout_registry(module: Module, prog: any = None) -> LayoutRegistry {
    reg = module.gen.layout_registry;
    assert reg is not None , (
        f"no layout registry on {module.loc.mod_path if module.loc else module.name}: "
        "LayoutPass did not run for this module (it is scheduled in the native "
        "codegen tail and requires 'inference'); a dependency gets one through "
        "ensure_layout_registry"
    );
    return reg;
}

def ensure_layout_registry(module: Module, prog: any) -> LayoutRegistry {
    reg = module.gen.layout_registry;
    if reg is not None {
        return reg;
    }
    import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
    import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
    provided = prog.analysis.analyses_run.get(id(module));
    if provided is None {
        provided = set();
        prog.analysis.analyses_run[id(module)] = provided;
    }
    passes: list = [];
    if 'cfg' not in provided {
        passes.append(CFGBuildPass);
    }
    if 'inference' not in provided {
        passes.append(TypeCheckPass);
    }
    passes.append(LayoutPass);
    prog._get_compiler().run_schedule(mod=module, target_program=prog, passes=passes);
    return get_layout_registry(module, prog);
}

def native_dep_path_ok(path: str) -> bool {
    import os;
    import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }
    import from jaclang.compiler.placement.placement_solver { native_default_path_ok }
    if not path or not path.endswith(".jac") {
        return False;
    }
    stdlib_root = native_stdlib_root();
    if stdlib_root is not None {
        real = os.path.realpath(path);
        if real.startswith(os.path.realpath(stdlib_root) + os.sep) {
            return True;
        }
    }
    return native_default_path_ok(path);
}

def native_dep_modules(module: Module, prog: any) -> list[Module] {
    import os;
    import from pathlib { Path }
    own_path = module_real_path(module);
    out: list[Module] = [];
    seen: set[str] = set();
    for imp in module.get_all_sub_nodes(Import) {
        if imp.clib_decls or imp.is_virtual_jac {
            continue;
        }
        targets: list[ModulePath] = [];
        if imp.from_loc is not None {
            if imp.from_loc.string_path_value is None {
                targets.append(imp.from_loc);
            }
        } else {
            for item in imp.items {
                if isinstance(item, ModulePath) and item.string_path_value is None {
                    targets.append(item);
                }
            }
        }
        paths: list[str] = [];
        for tgt in targets {
            try {
                paths.append(tgt.resolve_relative_path());
            } except Exception {
                continue;
            }
        }
        if imp.absorbed_mod is not None and imp.absorbed_mod.loc is not None {
            paths.append(imp.absorbed_mod.loc.mod_path);
        }
        for raw in paths {
            if not isinstance(raw, str) or not raw.endswith(".jac") {
                continue;
            }
            if not os.path.isfile(raw) {
                continue;
            }
            real = os.path.realpath(raw);
            if real == own_path or real in seen {
                continue;
            }
            seen.add(real);
            if not native_dep_path_ok(real) {
                continue;
            }
            dep = prog.find_module(str(Path(raw).resolve()));
            if dep is None {
                dep = prog.load_dependency_module(raw, importer_path=own_path or None);
            }
            if dep is None or dep.stub_only or dep.parse_failed {
                continue;
            }
            out.append(dep);
        }
    }
    return out;
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

def clone_field(finfo: FieldInfo, index: int) -> FieldInfo {
    return FieldInfo(
        name=finfo.name,
        index=index,
        type=finfo.type,
        default_expr=finfo.default_expr,
        owner=finfo.owner,
        is_func_ptr=finfo.is_func_ptr,
        decl_node=finfo.decl_node
    );
}

def base_expr_is_erased(base: UniNode) -> bool {
    import from jaclang.compiler.types.types { ClassType }
    _ty = base.type if isinstance(base, Expr) else None;
    return isinstance(_ty, ClassType) and _ty.shared.is_native_erased;
}

def is_enum_class_type(t: any) -> bool {
    import from jaclang.compiler.types.types { ClassType }
    return isinstance(t, ClassType)
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
    import from jaclang.compiler.types.types { ClassType }
    _vt = t.shared.enum_value_type;
    if isinstance(_vt, ClassType) and _vt._shared is not None {
        _vname = _vt.shared.class_name;
        return _vname if _vname in ("str", "int") else None;
    }
    import from jaclang.compiler.types.type_utils { enum_literal_scalar_name }
    return enum_literal_scalar_name(t);
}

def class_form_enum_member(t: any) -> (tuple[(str, (str | int), str)] | None) {
    import from jaclang.compiler.types.types { EnumMemberType }
    if not isinstance(t, EnumMemberType) or t.enum_class is None {
        return None;
    }
    _scalar = class_form_enum_scalar(t.enum_class);
    if _scalar is None or t.member_info is None {
        return None;
    }
    _name = t.member_info.member_name;
    _lit = t.member_info.literal_value;
    if _scalar == "str" and isinstance(_lit, str) {
        return (_scalar, _lit, _name);
    }
    if _scalar == "int" and isinstance(_lit, int) and not isinstance(_lit, bool) {
        return (_scalar, _lit, _name);
    }
    return None;
}

obj LayoutRegistry {
    has module_path: str = "",
        layouts: dict[str, ArchetypeLayout] = {},
        by_key: dict[tuple, ArchetypeLayout] = {},
        name_collisions: dict[str, list[str]] = {},
        class_parents: dict[str, list[str]] = {},
        mro_order: dict[str, list[str]] = {},
        topo_order: list[str] = [],
        local_names: list[str] = [],
        enums: dict[str, EnumLayout] = {},
        enums_by_key: dict[tuple, EnumLayout] = {},
        local_enum_names: list[str] = [],
        subclasses: dict[str, list[str]] = {},
        overriders: dict[str, dict[int, set[str]]] = {},
        vtable_less_reach: set[str] = set(),
        dep_modules: list[Module] = [],
        complete: bool = False;

    def get_layout(name: str) -> (ArchetypeLayout | None);
    def layout_for(decl_mod: str, name: str) -> (ArchetypeLayout | None);
    def get_enum_layout(name: str) -> (EnumLayout | None);
    def resolve_method_owner(arch_name: str, method_name: str) -> (str | None);
    def get_mro(name: str) -> list[str];
    def get_topo_order -> list[str];
    def is_primary_ancestor(child: str, ancestor: str) -> bool;
    def add_layout(lay: ArchetypeLayout, local: bool) -> None;
    def add_enum(lay: EnumLayout, local: bool) -> None;
    def merge_from(other: LayoutRegistry) -> None;
}

obj LayoutPass(Transform) {
    has ir_in: Module,
        prog: JacProgram,
        cancel_token: any = None,
        registry: LayoutRegistry postinit,
        isinstance_targets: set[str] postinit,
        _module_path: str postinit;

    static has PROVIDES: tuple = ('layout', ),
        REQUIRES: tuple = ('inference', ),
        HOST_PASS: bool = True;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _merge_dependencies(module: Module) -> None;
    def _collect_archetypes(module: Module) -> dict[str, Archetype];
    def _class_type_of(arch: (Archetype | Enum)) -> any;
    def _field_type_of(var: HasVar) -> any;
    def _collect_isinstance_targets(module: Module) -> None;
    def _build_hierarchy(archetypes: dict[str, Archetype]) -> None;
    def _layout_name_of(t: any) -> (str | None);
    def _topo_sort(arch_map: dict[str, Archetype]) -> list[str];
    def _build_layout(arch: Archetype) -> ArchetypeLayout;
    def _build_enum_layouts(module: Module) -> None;
    def _enum_layout_from_type(
        decl: (Enum | Archetype), ct: any, class_form: bool
    ) -> EnumLayout;

    def _compute_acyclicity -> None;
    def _acyclic_walk(name: str, state: dict[str, int]) -> int;
    def _reachable_layout_names(t: any, out: list[str]) -> bool;
    def _build_vtable_layout(arch_name: str, arch_map: dict[str, Archetype]) -> None;
    def _build_dispatch_facts -> None;
    def _validate_obj_fields(arch: Archetype) -> None;
    def _is_layout_compatible_type(t: any) -> bool;
    def _validate_union_triggers(module: Module) -> None;
    def _union_field_conflict(members: list[str]) -> (str | None);
    def _field_named(lay: ArchetypeLayout, name: str) -> (FieldInfo | None);
    def _same_field_type(a: any, b: any) -> bool;
    def _is_pod_type(t: any) -> bool;
}
