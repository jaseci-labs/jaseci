import from jaclang.compiler.frontend.constant { Tokens as Tok }

impl MethodSlot.signature.getter -> (UniNode | None) {
    return self.ability.signature if self.ability is not None else None;
}

impl ArchetypeLayout.key.getter -> tuple {
    return (self.decl_mod, self.name, );
}

impl EnumLayout.key.getter -> tuple {
    return (self.decl_mod, self.name, );
}

impl LayoutPass.postinit -> None {
    self.registry = LayoutRegistry();
    self.isinstance_targets = set();
    self._module_path = "";
    super.postinit();
}

impl LayoutPass.transform(ir_in: Module) -> Module {
    module = self.ir_in;
    self._module_path = module_real_path(module);
    self.registry.module_path = self._module_path;
    module.gen.layout_registry = self.registry;

    self._merge_dependencies(module);
    self._build_enum_layouts(module);

    arch_map = self._collect_archetypes(module);
    if arch_map {
        self._build_hierarchy(arch_map);
        self._collect_isinstance_targets(module);

        local_order = self._topo_sort(arch_map);
        for name in local_order {
            layout = self._build_layout(arch_map[name]);
            self.registry.add_layout(layout, local=True);
            self.registry.topo_order.append(name);
        }
        for name in local_order {
            self._build_vtable_layout(name, arch_map);
        }
    }

    self._compute_acyclicity();
    self._build_dispatch_facts();

    for name in self.registry.local_names {
        self._validate_obj_fields(arch_map[name]);
    }
    self._validate_union_triggers(module);

    self.registry.complete = True;
    return ir_in;
}

impl LayoutPass._merge_dependencies(module: Module) -> None {
    if self.prog is None {
        return;
    }
    for dep in native_dep_modules(module, self.prog) {
        dep_reg = ensure_layout_registry(dep, self.prog);
        self.registry.merge_from(dep_reg);
        if dep not in self.registry.dep_modules {
            self.registry.dep_modules.append(dep);
        }
    }
}

impl LayoutPass._collect_archetypes(module: Module) -> dict[str, Archetype] {
    arch_map: dict[str, Archetype] = {};
    for nd in module.get_all_sub_nodes(Archetype) {
        aname = nd.name.value if nd.name else None;
        if aname is None {
            continue;
        }
        if aname not in arch_map or nd.body is not None {
            arch_map[aname] = nd;
        }
    }
    return arch_map;
}

impl LayoutPass._class_type_of(arch: (Archetype | Enum)) -> any {
    import from jaclang.compiler.types.types { ClassType }
    stamped = arch.name_spec.type;
    if isinstance(stamped, ClassType) {
        return stamped;
    }
    if self.prog is None {
        return None;
    }
    ev = self.prog.get_type_evaluator();
    ct = ev.get_type_of_enum(arch)
        if isinstance(arch, Enum)
        else ev.get_type_of_class(arch);
    return ct if isinstance(ct, ClassType) else None;
}

impl LayoutPass._field_type_of(var: HasVar) -> any {
    if var.type is not None {
        return var.type;
    }
    sym = var.sym;
    if sym is None or self.prog is None {
        return None;
    }
    t = self.prog.get_type_evaluator().get_type_of_symbol(sym);
    var.type = t;
    return t;
}

impl LayoutPass._collect_isinstance_targets(module: Module) -> None {
    import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
    import from jaclang.compiler.frontend.constant { CodeContext }
    calls: list = [];
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, FuncCall) {
            calls.append(stmt);
        }
        calls.extend(stmt.get_all_sub_nodes(typ=FuncCall));
    }
    for call in calls {
        tgt = call.target;
        if not (isinstance(tgt, Name) and tgt.value == "isinstance") {
            continue;
        }
        params = call.params or [];
        if len(params) < 2 {
            continue;
        }
        type_arg = params[1];
        cands: list = [];
        if isinstance(type_arg, TupleVal) {
            for v in (type_arg.values or []) {
                cands.append(v);
            }
        } else {
            cands.append(type_arg);
        }
        for c in cands {
            if isinstance(c, Name) {
                self.isinstance_targets.add(c.value);
            }
        }
    }
}

impl LayoutPass._layout_name_of(t: any) -> (str | None) {
    import from jaclang.compiler.types.types { ClassType }
    if not isinstance(t, ClassType) or t._shared is None {
        return None;
    }
    sh = t.shared;
    if sh.is_native_erased or sh.is_builtin_class or sh.is_from_stdlib_stub {
        return None;
    }
    decl = sh.symbol_table;
    if not isinstance(decl, Archetype) {
        return None;
    }
    decl_mod = decl.find_parent_of_type(Module);
    path = decl_mod.loc.mod_path if (decl_mod is not None and decl_mod.loc) else "";
    if not path or not path.endswith(".jac") {
        return None;
    }
    return sh.class_name;
}

impl LayoutPass._build_hierarchy(archetypes: dict[str, Archetype]) -> None {
    import from jaclang.compiler.types.types { ClassType }
    reg = self.registry;
    for (aname, arch) in archetypes.items() {
        ct = self._class_type_of(arch);
        if not isinstance(ct, ClassType) {
            reg.mro_order[aname] = [aname];
            continue;
        }
        parents: list[str] = [];
        for base in (ct.shared.base_classes or []) {
            pname = self._layout_name_of(base);
            if pname is not None and pname != aname and pname not in parents {
                parents.append(pname);
            }
        }
        if parents {
            reg.class_parents[aname] = parents;
        }
        mro: list[str] = [aname];
        for anc in ct.shared.mro[1:] {
            nm = self._layout_name_of(anc);
            if nm is not None and nm not in mro {
                mro.append(nm);
            }
        }
        expected: set[str] = set();
        for base in (ct.shared.base_classes or []) {
            if isinstance(base, ClassType) and base._shared is not None {
                for anc in base.shared.mro {
                    nm = self._layout_name_of(anc);
                    if nm is not None {
                        expected.add(nm);
                    }
                }
            }
        }
        if not expected.issubset(set(mro)) {
            self.emit(E5030, node_override=arch, name=aname);
        }
        reg.mro_order[aname] = mro;
    }
}

impl LayoutPass._topo_sort(arch_map: dict[str, Archetype]) -> list[str] {
    visited: set[str] = set();
    order: list[str] = [];
    reg = self.registry;
    for aname in arch_map {
        if aname in visited {
            continue;
        }
        stack: list[tuple] = [(aname, False)];
        while stack {
            (name, processed) = stack.pop();
            if name in visited {
                continue;
            }
            if processed {
                visited.add(name);
                order.append(name);
                continue;
            }
            stack.append((name, True));
            mro = reg.mro_order.get(name, [name]);
            for ancestor in reversed(mro[1:]) {
                if ancestor not in visited and ancestor in arch_map {
                    stack.append((ancestor, False));
                }
            }
        }
    }
    return order;
}

impl LayoutPass._build_layout(arch: Archetype) -> ArchetypeLayout {
    import from jaclang.compiler.types.types { FunctionType }
    reg = self.registry;
    aname = arch.name.value if arch.name else "unknown";
    mro = reg.mro_order.get(aname, [aname]);
    parents = reg.class_parents.get(aname, []);
    ct = self._class_type_of(arch);

    arch_type_str = arch.arch_kind or "object";
    is_osp = arch.arch_kind is not None;
    is_clib = arch.find_parent_of_type(Import) is not None;

    parents_set: set[str] = set();
    for (_, plist) in reg.class_parents.items() {
        for p in plist {
            parents_set.add(p);
        }
    }

    vtable_by_dispatch = (
        is_osp or aname in parents_set or aname in self.isinstance_targets
    );
    ancestors: list[ArchetypeLayout] = [];
    for ancestor_name in mro[1:] {
        anc_lay = reg.get_layout(ancestor_name);
        if anc_lay is not None {
            ancestors.append(anc_lay);
        }
    }
    inherits_header = any(a.has_vtable for a in ancestors);
    needs_vtable = vtable_by_dispatch or inherits_header;

    fields: list[FieldInfo] = [];
    field_index: dict[str, int] = {};
    seen_fields: set[str] = set();
    unadopted: list[str] = [];
    current_idx = 0;

    vtable_ptr_slot: (int | None) = None;
    type_tag_slot: (int | None) = None;
    reports_slot: (int | None) = None;
    if needs_vtable or is_osp {
        vtable_ptr_slot = current_idx;
        current_idx += 1;
    }
    if is_osp {
        type_tag_slot = current_idx;
        current_idx += 1;
    }
    if arch_type_str == "walker" {
        reports_slot = current_idx;
        field_index["reports"] = current_idx;
        seen_fields.add("reports");
        current_idx += 1;
    }
    probe = ArchetypeLayout(
        name=aname,
        arch_type=arch_type_str,
        vtable_ptr_slot=vtable_ptr_slot,
        type_tag_slot=type_tag_slot,
        reports_slot=reports_slot
    );

    for anc_lay in ancestors {
        if anc_lay.decl_mod != self._module_path
            and not headers_agree(probe, anc_lay) {
            unadopted.append(anc_lay.name);
            continue;
        }
        for finfo in anc_lay.fields {
            if finfo.name in seen_fields {
                continue;
            }
            seen_fields.add(finfo.name);
            fields.append(clone_field(finfo, current_idx));
            field_index[finfo.name] = current_idx;
            current_idx += 1;
        }
    }

    statics: list[FieldInfo] = [];
    for var in arch.get_has_vars() {
        fname = var.name.value if var.name else "field";
        if var.accessors {
            continue;
        }
        _archhas = var.find_parent_of_type(ArchHas);
        ftype = self._field_type_of(var);
        if _archhas is not None and _archhas.is_static {
            statics.append(
                FieldInfo(
                    name=fname,
                    index=len(statics),
                    type=ftype,
                    default_expr=var.value,
                    owner=aname,
                    is_func_ptr=isinstance(ftype, FunctionType),
                    decl_node=var
                )
            );
            continue;
        }
        if fname in seen_fields {
            continue;
        }
        seen_fields.add(fname);
        fields.append(
            FieldInfo(
                name=fname,
                index=current_idx,
                type=ftype,
                default_expr=var.value,
                owner=aname,
                is_func_ptr=isinstance(ftype, FunctionType),
                decl_node=var
            )
        );
        field_index[fname] = current_idx;
        current_idx += 1;
    }

    class_consts: list[ClassConstInfo] = [];
    if arch.body is not None {
        for stmt in arch._get_impl_resolved_body() {
            if not isinstance(stmt, ModuleCode) {
                continue;
            }
            for asn in (stmt.body or []) {
                if not isinstance(asn, Assignment) or asn.value is None {
                    continue;
                }
                targets = asn.target
                    if isinstance(asn.target, (list, tuple))
                    else [asn.target];
                for tgt in targets {
                    if not isinstance(tgt, Name) {
                        continue;
                    }
                    class_consts.append(
                        ClassConstInfo(
                            name=tgt.value,
                            owner=aname,
                            assign=asn,
                            target=tgt,
                            type=(tgt.type if isinstance(tgt, Expr) else None)
                        )
                    );
                }
            }
        }
    }

    is_pod = not is_osp and not needs_vtable and len(fields) > 0;
    for finfo in fields {
        if not self._is_pod_type(finfo.type) {
            is_pod = False;
            break;
        }
    }

    return ArchetypeLayout(
        name=aname,
        arch_type=arch_type_str,
        decl_mod=self._module_path,
        decl_node=arch,
        class_type=ct,
        parents=parents,
        mro=mro,
        fields=fields,
        field_index=field_index,
        statics=statics,
        class_consts=class_consts,
        has_vtable=needs_vtable,
        vtable_by_dispatch=vtable_by_dispatch,
        unadopted=unadopted,
        is_osp=is_osp,
        is_pod=is_pod,
        is_enum_form=(ct is not None and ct.shared.is_enum_class),
        is_clib=is_clib,
        vtable_ptr_slot=vtable_ptr_slot,
        type_tag_slot=type_tag_slot,
        reports_slot=reports_slot
    );
}

impl LayoutPass._build_enum_layouts(module: Module) -> None {
    for nd in module.get_all_sub_nodes(Enum) {
        ename = nd.name.value if nd.name else None;
        if ename is None or nd.body is None {
            continue;
        }
        if ename in self.registry.local_enum_names {
            continue;
        }
        ct = self._class_type_of(nd);
        if ct is None {
            continue;
        }
        self.registry.add_enum(self._enum_layout_from_type(nd, ct, False), local=True);
    }
    for nd in module.get_all_sub_nodes(Archetype) {
        ename = nd.name.value if nd.name else None;
        if ename is None or ename in self.registry.local_enum_names {
            continue;
        }
        ct = self._class_type_of(nd);
        if ct is None or class_form_enum_scalar(ct) is None {
            continue;
        }
        self.registry.add_enum(self._enum_layout_from_type(nd, ct, True), local=True);
    }
}

impl LayoutPass._enum_layout_from_type(
    decl: (Enum | Archetype), ct: any, class_form: bool
) -> EnumLayout {
    ename = ct.shared.class_name;
    infos = ct.shared.enum_members or {};
    placed: list[tuple] = [];
    scope: UniScopeNode = decl;
    for (mname, info) in infos.items() {
        sym = scope.names_in_scope.get(str(mname));
        loc = sym.decl.loc if (sym is not None and sym.decl is not None) else None;
        line = loc.first_line if loc is not None else 0;
        col = loc.col_start if loc is not None else 0;
        placed.append((line, col, len(placed), mname, info));
    }
    placed.sort();
    scalar = class_form_enum_scalar(ct) if class_form else None;
    is_string_enum = scalar == "str";
    if not class_form {
        for `entry in placed {
            if isinstance(`entry[4].literal_value, str) {
                is_string_enum = True;
            }
        }
    }
    members: list[EnumMemberLayout] = [];
    all_known = True;
    for `entry in placed {
        mname = `entry[3];
        lit = `entry[4].literal_value;
        if isinstance(lit, bool) {
            lit = None;
        }
        if lit is None {
            all_known = False;
            if class_form {
                continue;
            }
        }
        if class_form and (scalar == "str") != isinstance(lit, str) {
            all_known = False;
        }
        members.append(
            EnumMemberLayout(
                name=mname,
                ordinal=len(members),
                int_value=(lit if isinstance(lit, int) else 0),
                str_value=(
                    (lit if isinstance(lit, str) else "") if is_string_enum else None
                )
            )
        );
    }
    return EnumLayout(
        name=ename,
        decl_mod=self._module_path,
        decl_node=decl,
        class_type=ct,
        underlying=("str" if is_string_enum and class_form else "i64"),
        is_string_enum=is_string_enum,
        is_class_form=class_form,
        all_values_known=all_known,
        members=members
    );
}

impl LayoutPass._build_vtable_layout(
    arch_name: str, arch_map: dict[str, Archetype]
) -> None {
    reg = self.registry;
    layout_obj = reg.get_layout(arch_name);
    if layout_obj is None {
        return;
    }
    method_list: list[str] = [];
    seen_methods: set[str] = set();
    mro = reg.mro_order.get(arch_name, [arch_name]);

    for ancestor_name in mro[1:] {
        ancestor_layout = reg.get_layout(ancestor_name);
        if ancestor_layout is None {
            continue;
        }
        for mslot in ancestor_layout.methods {
            if mslot.name not in seen_methods {
                method_list.append(mslot.name);
                seen_methods.add(mslot.name);
            }
        }
    }

    arch = arch_map.get(arch_name);
    if arch is not None {
        for method in arch.get_methods() {
            method_name = method.name_ref.sym_name if method.name_ref else None;
            if method_name is not None and method_name not in seen_methods {
                method_list.append(method_name);
                seen_methods.add(method_name);
            }
        }
        for (slot_name, _var, _acc) in archetype_accessors(arch) {
            if slot_name not in seen_methods {
                method_list.append(slot_name);
                seen_methods.add(slot_name);
            }
        }
    }

    methods: list[MethodSlot] = [];
    method_index: dict[str, int] = {};
    for (i, mname) in enumerate(method_list) {
        ability: (Ability | None) = None;
        field: (HasVar | None) = None;
        owner = arch_name;
        for check_name in mro {
            check_lay = reg.get_layout(check_name);
            check_arch = arch_map.get(check_name)
                if check_name == arch_name
                else (check_lay.decl_node if check_lay is not None else None);
            if check_arch is None {
                continue;
            }
            found = False;
            for method in check_arch.get_methods() {
                mn = method.name_ref.sym_name if method.name_ref else None;
                if mn == mname {
                    ability = method;
                    owner = check_name;
                    found = True;
                    break;
                }
            }
            if not found {
                for (slot_name, var, acc) in archetype_accessors(check_arch) {
                    if slot_name == mname {
                        ability = acc;
                        field = var;
                        owner = check_name;
                        found = True;
                        break;
                    }
                }
            }
            if found {
                break;
            }
        }
        methods.append(
            MethodSlot(name=mname, index=i, owner=owner, ability=ability, field=field)
        );
        method_index[mname] = i;
    }

    layout_obj.methods = methods;
    layout_obj.method_index = method_index;
}

impl LayoutPass._compute_acyclicity -> None {
    state: dict[str, int] = {};
    for name in self.registry.local_names {
        self._acyclic_walk(name, state);
    }
    for name in self.registry.local_names {
        lay = self.registry.get_layout(name);
        if lay is not None {
            lay.is_acyclic = state.get(name) == 1;
        }
    }
}

impl LayoutPass._acyclic_walk(name: str, state: dict[str, int]) -> int {
    if name in state {
        cur = state[name];
        if cur == 0 {
            return 2;
        }
        return cur;
    }
    lay = self.registry.get_layout(name);
    if lay is None or lay.has_vtable or lay.is_osp {
        state[name] = 2;
        return 2;
    }
    if lay.decl_mod != self._module_path {
        state[name] = 1 if lay.is_acyclic else 2;
        return state[name];
    }
    state[name] = 0;
    result = 1;
    for finfo in lay.fields {
        parts: list[str] = [];
        if not self._reachable_layout_names(finfo.type, parts) {
            result = 2;
            break;
        }
        for part in parts {
            if self._acyclic_walk(part, state) == 2 {
                result = 2;
                break;
            }
        }
        if result == 2 {
            break;
        }
    }
    state[name] = result;
    return result;
}

impl LayoutPass._reachable_layout_names(t: any, out: list[str]) -> bool {
    import from jaclang.compiler.types.types { ClassType, TypeVarType, UnionType }
    if t is None {
        return False;
    }
    if isinstance(t, UnionType) {
        for m in (t.types or []) {
            if not self._reachable_layout_names(m, out) {
                return False;
            }
        }
        return True;
    }
    if not isinstance(t, ClassType) or t._shared is None {
        return False;
    }
    sh = t.shared;
    name = sh.class_name;
    if name in ("None", "NoneType") or name in layout_scalar_names() {
        return True;
    }
    if sh.is_enum_class {
        return True;
    }
    if not t.is_instance() {
        return True;
    }
    if name == "type" {
        return True;
    }
    if name in ("list", "set", "frozenset", "tuple", "dict") {
        for arg in (t.private.type_args or []) {
            if isinstance(arg, TypeVarType) {
                return False;
            }
            if not self._reachable_layout_names(arg, out) {
                return False;
            }
        }
        return True;
    }
    lname = self._layout_name_of(t);
    if lname is None or self.registry.get_layout(lname) is None {
        return False;
    }
    out.append(lname);
    return True;
}

impl LayoutPass._build_dispatch_facts -> None {
    reg = self.registry;
    subclasses: dict[str, list[str]] = {};
    overriders: dict[str, dict[int, set[str]]] = {};
    reach: set[str] = set();
    for (name, lay) in reg.layouts.items() {
        for anc in lay.mro[1:] {
            if anc not in subclasses {
                subclasses[anc] = [];
            }
            subclasses[anc].append(name);
        }
        if not lay.has_vtable {
            for step in lay.mro {
                reach.add(step);
            }
        }
    }
    for (base, kids) in subclasses.items() {
        base_lay = reg.get_layout(base);
        if base_lay is None {
            continue;
        }
        per_slot: dict[int, set[str]] = {};
        for mslot in base_lay.methods {
            for kid in kids {
                kid_lay = reg.get_layout(kid);
                if kid_lay is None {
                    continue;
                }
                ki = kid_lay.method_index.get(mslot.name);
                if ki is None {
                    continue;
                }
                if kid_lay.methods[ki].owner != mslot.owner {
                    if mslot.index not in per_slot {
                        per_slot[mslot.index] = set();
                    }
                    per_slot[mslot.index].add(kid);
                }
            }
        }
        overriders[base] = per_slot;
    }
    reg.subclasses = subclasses;
    reg.overriders = overriders;
    reg.vtable_less_reach = reach;
}

impl LayoutRegistry.add_layout(lay: ArchetypeLayout, local: bool) -> None {
    self.by_key[lay.key] = lay;
    held = self.layouts.get(lay.name);
    if held is None or local {
        if held is not None and held.decl_mod != lay.decl_mod {
            self.name_collisions.setdefault(lay.name, []).append(held.decl_mod);
        }
        self.layouts[lay.name] = lay;
    } elif held.decl_mod != lay.decl_mod {
        self.name_collisions.setdefault(lay.name, []).append(lay.decl_mod);
    }
    if local and lay.name not in self.local_names {
        self.local_names.append(lay.name);
    }
    if lay.name not in self.mro_order {
        self.mro_order[lay.name] = list(lay.mro);
    }
    if lay.parents and lay.name not in self.class_parents {
        self.class_parents[lay.name] = list(lay.parents);
    }
}

impl LayoutRegistry.add_enum(lay: EnumLayout, local: bool) -> None {
    self.enums_by_key[lay.key] = lay;
    held = self.enums.get(lay.name);
    if held is None or local {
        self.enums[lay.name] = lay;
    }
    if local and lay.name not in self.local_enum_names {
        self.local_enum_names.append(lay.name);
    }
}

impl LayoutRegistry.merge_from(other: LayoutRegistry) -> None {
    for dep in other.dep_modules {
        if dep not in self.dep_modules and module_real_path(dep) != self.module_path {
            self.dep_modules.append(dep);
        }
    }
    for name in other.topo_order {
        lay = other.layouts.get(name);
        if lay is None {
            continue;
        }
        self.add_layout(lay, local=False);
        if name not in self.topo_order {
            self.topo_order.append(name);
        }
    }
    for (key, lay) in other.by_key.items() {
        if key not in self.by_key {
            self.add_layout(lay, local=False);
        }
    }
    for (key, elay) in other.enums_by_key.items() {
        if key not in self.enums_by_key {
            self.add_enum(elay, local=False);
        }
    }
}

impl LayoutRegistry.get_layout(name: str) -> (ArchetypeLayout | None) {
    lay = self.layouts.get(name);
    if lay is not None and name in self.name_collisions {
        others = self.name_collisions[name];
        assert lay.decl_mod == self.module_path or not others , (
            f"archetype name '{name}' is ambiguous in this unit: declared by "
            f"{lay.decl_mod} and by {', '.join(others)}; look it up by "
            f"(decl_mod, name) through layout_for"
        );
    }
    return lay;
}

impl LayoutRegistry.layout_for(decl_mod: str, name: str) -> (ArchetypeLayout | None) {
    lay = self.by_key.get((decl_mod, name, ));
    if lay is not None {
        return lay;
    }
    return self.get_layout(name);
}

impl LayoutRegistry.get_enum_layout(name: str) -> (EnumLayout | None) {
    return self.enums.get(name);
}

impl LayoutRegistry.resolve_method_owner(
    arch_name: str, method_name: str
) -> (str | None) {
    lay = self.get_layout(arch_name);
    if lay is None {
        return None;
    }
    for mslot in lay.methods {
        if mslot.name == method_name {
            return mslot.owner;
        }
    }
    return None;
}

impl LayoutRegistry.get_mro(name: str) -> list[str] {
    return self.mro_order.get(name, [name]);
}

impl LayoutRegistry.get_topo_order -> list[str] {
    return self.topo_order;
}

impl LayoutRegistry.is_primary_ancestor(child: str, ancestor: str) -> bool {
    current = child;
    while current is not None {
        parents = self.class_parents.get(current);
        if parents is None or not parents {
            return False;
        }
        primary = parents[0];
        if primary == ancestor {
            return True;
        }
        current = primary;
    }
    return False;
}

impl LayoutPass._validate_obj_fields(arch: Archetype) -> None {
    if arch.arch_type {
        tok_name = arch.arch_type.name;
        if tok_name != Tok.KW_OBJECT.value {
            return;
        }
    }
    if arch.find_parent_of_type(Import) is not None {
        return;
    }
    aname = arch.name.value if arch.name else "unknown";
    for var in arch.get_has_vars() {
        fname = var.name.value if var.name else "field";
        if var.accessors {
            continue;
        }
        _archhas = var.find_parent_of_type(ArchHas);
        if _archhas is not None and _archhas.is_static {
            continue;
        }
        if not var.type_tag or not var.type_tag.tag {
            self.emit(W5031, node_override=var, arch=aname, field=fname);
            continue;
        }
        ftype = self._field_type_of(var);
        if not self._is_layout_compatible_type(ftype) {
            self.emit(
                W5032, node_override=var, arch=aname, field=fname, type=str(ftype)
            );
        }
    }
}

impl LayoutPass._validate_union_triggers(module: Module) -> None {
    """Report an event trigger union whose members disagree on a shared field.

    A `with entry {A | B}` ability reads its visitor through one layout, so a
    field the members place at different slots or hold at different types has
    no single reachable offset. The backend used to notice this from the two
    lowered struct types; the field indexes and their checker types are both
    here, so the verdict is a layout fact.
    """;
    for ability in module.get_all_sub_nodes(Ability) {
        sig = ability.signature;
        if not isinstance(sig, EventSignature) or sig.arch_tag_info is None {
            continue;
        }
        names = ability.event_trigger_type_names();
        members: list[str] = [
            nm
            for nm in (names or [])
            if self.registry.get_layout(nm) is not None
        ];
        conflict = self._union_field_conflict(members);
        if conflict is not None {
            self.emit(
                E5091,
                node_override=sig.arch_tag_info,
                members=", ".join(members),
                field=conflict
            );
        }
    }
}

impl LayoutPass._union_field_conflict(members: list[str]) -> (str | None) {
    if len(members) <= 1 {
        return None;
    }
    base_lay = self.registry.get_layout(members[0]);
    if base_lay is None {
        return None;
    }
    for finfo in base_lay.fields {
        fname = finfo.name;
        for other in members[1:] {
            other_lay = self.registry.get_layout(other);
            if other_lay is None or fname not in other_lay.field_index {
                continue;
            }
            other_field = self._field_named(other_lay, fname);
            if other_lay.field_index[fname] != finfo.index
                or other_field is None
                or not self._same_field_type(finfo.type, other_field.type) {
                return fname;
            }
        }
    }
    return None;
}

impl LayoutPass._field_named(lay: ArchetypeLayout, name: str) -> (FieldInfo | None) {
    for finfo in lay.fields {
        if finfo.name == name {
            return finfo;
        }
    }
    return None;
}

impl LayoutPass._same_field_type(a: any, b: any) -> bool {
    if a is None or b is None {
        return a is b;
    }
    return a.mangle() == b.mangle();
}

impl LayoutPass._is_layout_compatible_type(t: any) -> bool {
    import from jaclang.compiler.types.types { ClassType, FunctionType, UnionType }
    if t is None {
        return False;
    }
    if isinstance(t, FunctionType) {
        return True;
    }
    if isinstance(t, UnionType) {
        for m in (t.types or []) {
            if not self._is_layout_compatible_type(m) {
                return False;
            }
        }
        return True;
    }
    if not isinstance(t, ClassType) or t._shared is None {
        return False;
    }
    sh = t.shared;
    name = sh.class_name;
    if name in ("None", "NoneType") or name in layout_scalar_names() {
        return True;
    }
    if name == "type" or not t.is_instance() {
        return True;
    }
    if sh.is_enum_class {
        return True;
    }
    if name in ("list", "set", "frozenset", "tuple", "dict") {
        for arg in (t.private.type_args or []) {
            if not self._is_layout_compatible_type(arg) {
                return False;
            }
        }
        return True;
    }
    return self._layout_name_of(t) is not None;
}

impl LayoutPass._is_pod_type(t: any) -> bool {
    import from jaclang.compiler.types.types { ClassType }
    if not isinstance(t, ClassType) or t._shared is None or not t.is_instance() {
        return False;
    }
    return t.shared.class_name in layout_scalar_names()
        and t.shared.class_name not in ("str", "bytes");
}
