impl NaIRGenObjects._native_archetypes(module: uni.Module) -> list[uni.Archetype] {
    result: dict[(str, uni.Archetype)] = {};

    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else "unknown";
            if aname not in result or stmt.body is not None {
                result[aname] = stmt;
            }
        }
    }

    for arch in ModuleCodegenPass.shared_archetypes_for_context(
        module, CodeContext.NATIVE
    ) {
        aname = arch.name.value if arch.name else "unknown";
        if aname not in result {
            result[aname] = arch;
        }
    }

    layout_reg = self._registry();
    out: list[uni.Archetype] = [];
    for a in result.values() {
        if a.type_params {
            aname = a.name.value if a.name else "unknown";
            if layout_reg.get_layout(aname) is None {
                continue;
            }
        }
        out.append(a);
    }
    return out;
}

impl NaIRGenObjects._forward_declare_archetype_names(module: uni.Module) -> None {
    for arch in self._native_archetypes(module) {
        aname = arch.name.value if arch.name else None;
        if aname is not None and aname not in self.struct_types {
            struct_type = self.llvm_module.context.get_identified_type(aname);
            self.struct_types[aname] = struct_type;
        }
    }
}

impl NaIRGenObjects._register_archetypes(module: uni.Module) -> None {
    archetypes: list[uni.Archetype] = self._native_archetypes(module);
    arch_map: dict[(str, uni.Archetype)] = {};
    for arch in archetypes {
        arch_map[arch.name.value if arch.name else "unknown"] = arch;
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        struct_type = self.llvm_module.context.get_identified_type(arch_name);
        self.struct_types[arch_name] = struct_type;
        self.has_native_code = True;
    }

    self._compute_osp_model(archetypes);

    layout_reg = self._registry();
    topo_order = layout_reg.get_topo_order();
    for topo_name in topo_order {
        if topo_name in arch_map {
            self._codegen_archetype(arch_map[topo_name]);
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        lay = self._arch_layout(arch_name);
        if lay is None {
            continue;
        }
        for mslot in self._own_method_slots(lay) {
            stmt = mslot.ability;
            if stmt is None {
                continue;
            }
            if mslot.field is not None {
                self._forward_declare_method(arch_name, stmt, field=mslot.field);
            } elif stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature) {
                self._forward_declare_method(arch_name, stmt);
            } elif stmt.signature is None and stmt.body is not None {
                full_name = f"{arch_name}.{mslot.name}";
                struct_ptr = self.struct_types[arch_name].as_pointer();
                fnty = ir.FunctionType(ir.VoidType(), [struct_ptr]);
                func = ir.Function(self.llvm_module, fnty, name=full_name);
                func.args[0].name = "self";
                self.func_symtab[full_name] = func;
                self.method_funcs[full_name] = func;
                self.has_native_code = True;
            } elif isinstance(stmt.signature, uni.EventSignature) {
                self._forward_declare_event_method(arch_name, stmt);
                if lay.is_osp {
                    self._emit_osp_thunk(arch_name, stmt);
                }
            } else {
                _sig_kind = (
                    type(stmt.signature).__name__
                        if stmt.signature is not None
                        else "no-signature"
                );
                self.emit(
                    E5092,
                    node_override=stmt,
                    kind="archetype method",
                    name=f"{arch_name}.{mslot.name} ({_sig_kind})"
                );
            }
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self._emit_struct_release_fn(arch_name);
        self._emit_trace_fn(arch_name);
    }

    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=True);
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if self._arch_has_vtable(arch_name) {
            self._emit_vtable_global(arch_name);
        }
    }

    self._forward_declare_functions(module);

    self._register_osp_kernel_module();
    self._emit_osp_setup();

    self._predemote_capability_constructors();
    self._codegen_constructors_first(archetypes);

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        lay = self._arch_layout(arch_name);
        if lay is None {
            continue;
        }
        for mslot in self._own_method_slots(lay) {
            stmt = mslot.ability;
            if stmt is None {
                continue;
            }
            if mslot.field is not None {
                self._codegen_method(arch_name, stmt, field=mslot.field);
            } elif stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature) {
                self._codegen_method(arch_name, stmt);
            } elif isinstance(stmt.signature, uni.EventSignature) {
                self._codegen_event_method(arch_name, stmt);
            } elif stmt.signature is None and stmt.body is not None {
                self._codegen_no_sig_method(arch_name, stmt);
            }
        }
    }

    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=False);
    }

    self._generate_inherited_method_wrappers();
}

impl NaIRGenObjects._registry -> any {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    return get_layout_registry(self.ir_in, self.prog);
}

impl NaIRGenObjects._own_path -> str {
    import from jaclang.compiler.passes.layout_pass { module_real_path }
    return module_real_path(self.ir_in);
}

impl NaIRGenObjects._arch_key(lay: ArchetypeLayout) -> str {
    return lay.name;
}

impl NaIRGenObjects._own_method_slots(lay: ArchetypeLayout) -> list {
    return [
        m
        for m in lay.methods
        if m.owner == lay.name and m.ability is not None
    ];
}

impl NaIRGenObjects._is_virtual_slot(arch_name: str, method_name: str) -> bool {
    lay = self._arch_layout(arch_name);
    return lay is not None and lay.has_vtable and method_name in lay.method_index;
}

impl NaIRGenObjects._member_field_of(nd: (uni.UniNode | None)) -> (uni.HasVar | None) {
    if not isinstance(nd, uni.AtomTrailer) or not nd.is_attr {
        return None;
    }
    right = nd.right;
    sym = right.sym if isinstance(right, uni.AstSymbolNode) else None;
    if sym is None {
        return None;
    }
    decl = sym.decl;
    if isinstance(decl, uni.HasVar) {
        return decl;
    }
    owner = decl?.name_of if decl is not None else None;
    return owner if isinstance(owner, uni.HasVar) else None;
}

impl NaIRGenObjects._member_ability_of(
    nd: (uni.UniNode | None)
) -> (uni.Ability | None) {
    if not isinstance(nd, uni.AtomTrailer) or not nd.is_attr {
        return None;
    }
    right = nd.right;
    sym = right.sym if isinstance(right, uni.AstSymbolNode) else None;
    if sym is None {
        return None;
    }
    decl = sym.decl;
    if isinstance(decl, uni.Ability) {
        return decl;
    }
    owner = decl?.name_of if decl is not None else None;
    return owner if isinstance(owner, uni.Ability) else None;
}

impl NaIRGenObjects._init_ability_of(owner: str) -> (uni.Ability | None) {
    lay = self._arch_layout(owner);
    if lay is None {
        return None;
    }
    for nm in ("init", "__init__") {
        idx = lay.method_index.get(nm);
        if idx is None {
            continue;
        }
        ab = lay.methods[idx].ability;
        if ab is not None {
            return ab;
        }
    }
    return None;
}

impl NaIRGenObjects._tb_is_class_ref(t: any) -> bool {
    return isinstance(t, ClassType)
        and t._shared is not None
        and not t.is_instance()
        and t.is_instantiable();
}

impl NaIRGenObjects._module_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    import from jaclang.compiler.types.types { ModuleType }
    t = expr.type if isinstance(expr, uni.Expr) else None;
    if not isinstance(t, ModuleType) {
        return None;
    }
    parts = list(t.file_uri.with_suffix("").parts) if t.file_uri.name else [];
    if "typeshed" in parts {
        _ti = parts.index("typeshed");
        if "stdlib" in parts[_ti:] {
            _si = parts.index("stdlib", _ti) + 1;
            tail = parts[_si:];
            if tail and tail[-1] == "__init__" {
                tail = tail[:-1];
            }
            if tail {
                return ".".join(tail);
            }
        }
    }
    return t.mod_name;
}

impl NaIRGenObjects._receiver_arch_name(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    t = self._flow_narrowed_type_of(expr);
    kind = self._tb_kind(t);
    if kind == "optional" {
        t = self._tb_opt_payload(t);
        kind = self._tb_kind(t);
    }
    if kind in ("struct", "typevar") {
        name = self._struct_name_of(expr);
        if name is not None {
            return name;
        }
    }
    if kind == "struct" {
        return self._tb_class_name(t);
    }
    if kind in ("file", "binary_file") {
        self._emit_file_helpers();
        return self._tb_class_name(t);
    }
    return self._struct_name_of(expr);
}

impl NaIRGenObjects._constructor_slots -> tuple {
    return ("init", "__init__", "postinit", "__post_init__", );
}

impl NaIRGenObjects._constructor_ability_for(
    cls: str, slot: str
) -> (uni.Ability | None) {
    lay = self._arch_layout(cls);
    if lay is None {
        return None;
    }
    idx = lay.method_index.get(slot);
    if idx is None or idx >= len(lay.methods) {
        return None;
    }
    return lay.methods[idx].ability;
}

impl NaIRGenObjects._predemote_capability_constructors -> None {
    if not self._capability_demotions {
        return;
    }
    _slots = self._constructor_slots();
    for _full in list(self.method_funcs.keys()) {
        (_cls, _dot, _slot) = _full.rpartition(".");
        if not _dot or _slot not in _slots {
            continue;
        }
        _ability = self._constructor_ability_for(_cls, _slot);
        if _ability is None {
            continue;
        }
        _viols = self._capability_demotions.get(id(_ability));
        if _viols is None {
            continue;
        }
        _func = self.method_funcs.get(_full);
        if _func is None {
            continue;
        }
        self._claimed_capability_demotions.add(id(_ability));
        self._predemote_capability_unit(
            _full, _func, _viols, keep_func=self._is_virtual_slot(_cls, _slot)
        );
    }
}

impl NaIRGenObjects._codegen_constructors_first(archetypes: list) -> None {
    _slots = self._constructor_slots();
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        lay = self._arch_layout(arch_name);
        if lay is None {
            continue;
        }
        for mslot in self._own_method_slots(lay) {
            stmt = mslot.ability;
            if (
                mslot.field is None
                and stmt is not None
                and isinstance(stmt.signature, uni.FuncSignature)
                and mslot.name in _slots
            ) {
                self._codegen_method(arch_name, stmt);
            }
        }
    }
}

impl NaIRGenObjects._visit_nonprimary_ancestor_methods(
    arch: uni.Archetype, declare: bool
) -> None {
    layout_reg = self._registry();
    arch_name = arch.name.value if arch.name else "unknown";
    lay = self._arch_layout(arch_name);
    if lay is None or len(lay.mro) < 2 {
        return;
    }
    for mslot in lay.methods {
        if mslot.owner == arch_name
            or mslot.ability is None
            or layout_reg.is_primary_ancestor(arch_name, mslot.owner) {
            continue;
        }
        stmt = mslot.ability;
        if mslot.field is None
            and not (
                stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature)
            ) {
            continue;
        }
        full_name = f"{arch_name}.{mslot.name}";
        if declare and full_name not in self.method_funcs {
            self._forward_declare_method(arch_name, stmt, field=mslot.field);
        } elif not declare and full_name in self.method_funcs {
            self._codegen_method(arch_name, stmt, field=mslot.field);
        }
    }
}

impl NaIRGenObjects._codegen_archetype(nd: uni.Archetype) -> None {
    arch_name = (nd).name.value if (nd).name else "unknown";
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or arch_name in self._struct_bodies_done {
        return;
    }
    self._struct_bodies_done.add(arch_name);
    layout = self._arch_layout(arch_name);
    if layout is None {
        return;
    }

    field_types: list[ir.Type] = [];
    field_index_map: dict[(str, int)] = {};
    field_type_map: dict[(str, ir.Type)] = {};
    field_default_map: dict[(str, object)] = {};
    foreign_fields: set = set();

    if layout.vtable_ptr_slot is not None {
        field_types.append(ir.IntType(8).as_pointer().as_pointer());
    }
    if layout.type_tag_slot is not None {
        field_types.append(ir.IntType(64));
    }
    if layout.reports_slot is not None {
        self._emit_list_helpers("jacval", self.jacval_type);
        _rep_lt = self.list_types.get("jacval");
        if _rep_lt is not None {
            field_types.append(_rep_lt.as_pointer());
            field_index_map["reports"] = layout.reports_slot;
            field_type_map["reports"] = _rep_lt.as_pointer();
        }
    }

    for finfo in layout.fields {
        fname = finfo.name;
        var = finfo.decl_node;
        if var is None {
            raise AssertionError(
                f"layout field {arch_name}.{fname} has no declaring HasVar"
            );
        }
        ftype: (ir.Type | None) = None;
        if finfo.owner in self.clib_struct_names {
            if isinstance(finfo.type, FunctionType) {
                ftype = self._lower_clib_function_type(arch_name, fname, finfo.type);
            } else {
                ftype = self._resolve_field_type(var);
            }
        } else {
            _fld_mark = len(self.errors_had);
            ftype = self._resolve_field_type(var);
            _opaque = self._opaque_field_if_unlowerable(arch_name, fname, _fld_mark);
            if _opaque is not None {
                ftype = _opaque;
                foreign_fields.add(fname);
            }
            if self._foreign_optional_field(finfo.type) {
                foreign_fields.add(fname);
            }
            if self._nogc_headerless()
                and self._hasvar_is_own(var)
                and isinstance(ftype, ir.PointerType) {
                _fpn = getattr(ftype.pointee, "name", "") or "";
                _fstruct = self.struct_types.get(_fpn);
                if _fstruct is not None
                    and _fpn != arch_name
                    and _fstruct?.elements is not None
                    and self._arch_is_acyclic(_fpn)
                    and not self._arch_is_osp_name(_fpn)
                    and _fpn not in self.clib_vtable_structs {
                    ftype = _fstruct;
                    if arch_name not in self.struct_field_inline {
                        self.struct_field_inline[arch_name] = set();
                    }
                    self.struct_field_inline[arch_name].add(fname);
                }
            }
        }
        if ftype is None {
            raise AssertionError(
                f"field {arch_name}.{fname} did not lower and was not erased"
            );
        }
        field_types.append(ftype);
        field_index_map[fname] = finfo.index;
        field_type_map[fname] = ftype;

        if finfo.default_expr is not None and fname not in foreign_fields {
            field_default_map[fname] = finfo.default_expr;
        }
    }

    self._register_static_fields(arch_name, layout);
    self._register_class_consts(arch_name, layout);

    _ident_struct = isinstance(struct_type, ir.IdentifiedStructType);
    _clib_defined = (
        arch_name in self.clib_struct_names
        and _ident_struct
        and not struct_type.is_opaque
    );
    if _ident_struct and not _clib_defined {
        struct_type.set_body(*field_types);
    }
    self.struct_field_indices[arch_name] = field_index_map;
    self.struct_field_order[arch_name] = [f.name for f in layout.fields];
    self.struct_field_types[arch_name] = field_type_map;
    self.struct_field_defaults[arch_name] = field_default_map;
    self.struct_field_foreign[arch_name] = foreign_fields;
}

impl NaIRGenObjects._erased_sig_typevars(lay: ArchetypeLayout) -> dict {
    out: dict = {};
    for mslot in self._own_method_slots(lay) {
        stmt = mslot.ability;
        if stmt is None
            or mslot.field is not None
            or not isinstance(stmt.signature, uni.FuncSignature) {
            continue;
        }
        for p in stmt.signature.get_parameters() {
            if p.type_tag is None or self._erased_seq_type(p.type) is None {
                continue;
            }
            _pname = p.name.value if p.name else "arg";
            _star = "*" if p.is_vararg else "";
            out[f"{mslot.name}({_star}{_pname})"] = self._erased_typevar_names(
                self._tb_elem(p.type)
            );
        }
    }
    return out;
}

impl NaIRGenObjects._reject_scalar_type_args(nd: uni.UniNode, type_name: str) -> bool {
    lay = self._arch_layout(type_name);
    if lay is None or lay.class_type is None {
        return False;
    }
    _params = [tp.name for tp in (lay.class_type.shared.type_params or [])];
    if not _params {
        return False;
    }
    _erased: dict = {};
    for finfo in lay.fields {
        _etv = self._erased_typevar_names(finfo.type);
        if _etv {
            _erased[finfo.name] = _etv;
        }
    }
    for (_esn, _esv) in self._erased_sig_typevars(lay).items() {
        if _esn not in _erased {
            _erased[_esn] = _esv;
        }
    }
    if not _erased {
        return False;
    }
    _args = self._tb_args(nd.type if isinstance(nd, uni.Expr) else None);
    if not _args {
        return False;
    }
    for (fname, tv_names) in _erased.items() {
        for tv_name in tv_names {
            if tv_name not in _params {
                continue;
            }
            _idx = _params.index(tv_name);
            if _idx >= len(_args) {
                continue;
            }
            _solved = self._lower_type(_args[_idx]);
            if _solved is None or isinstance(_solved, ir.PointerType) {
                continue;
            }
            return self._emit_scalar_type_arg_refusal(
                nd, type_name, fname, tv_name, _args[_idx]
            );
        }
    }
    return False;
}

impl NaIRGenObjects._emit_scalar_type_arg_refusal(
    nd: uni.UniNode, type_name: str, fname: str, tv_name: str, arg: any
) -> bool {
    self.emit(
        E5092,
        node_override=nd,
        kind="type argument",
        name=f"{type_name}[{arg}]",
        help_text=(
            f"A generic archetype is type-erased natively: one struct is "
            f"shared by every instantiation, so a slot typed by '{tv_name}' "
            f"-- here '{type_name}.{fname}' -- is a raw pointer. A pointer "
            f"slot cannot carry '{arg}', whose native representation is a "
            f"value rather than a reference, and for an optional slot the "
            f"null that spells None would alias a zero payload. Instantiate "
            f"'{type_name}' at an archetype type, or declare '{fname}' with "
            f"a concrete type."
        )
    );
    return True;
}

impl NaIRGenObjects._register_static_fields(
    arch_name: str, lay: ArchetypeLayout
) -> None {
    for finfo in lay.statics {
        fname = finfo.name;
        var = finfo.decl_node;
        full_name = f"{arch_name}.{fname}";
        if full_name in self.static_fields or var is None {
            continue;
        }
        ftype = self._lower_type(finfo.type);
        if ftype is None and var.value is not None {
            ftype = self._widened_tuple_decl_type(var.type_tag, var.value);
        }
        if ftype is None and var.value is not None {
            ftype = self._infer_global_init_type(var.value);
        }
        if ftype is None {
            self.emit(
                E5092,
                node_override=var,
                kind="static field",
                name=full_name,
                help_text="The static field's declared type has no native lowering."
            );
            continue;
        }

        if full_name in self.llvm_module.globals {
            continue;
        }
        gv = ir.GlobalVariable(self.llvm_module, ftype, name=full_name);

        gv.linkage = "";
        const_init = self._codegen_const_expr(var.value, ftype)
            if var.value is not None
            else None;
        if const_init is not None {
            gv.initializer = const_init;
        } else {
            gv.initializer = ir.Constant(ftype, None);
        }
        self.static_fields[full_name] = gv;
        self.global_vars[full_name] = gv;
        self.global_var_types[full_name] = ftype;
        self.has_native_code = True;

        if var.value is not None and const_init is None {
            if not self?._global_init_nodes {
                self._global_init_nodes: list = [];
            }
            self._global_init_nodes.append((full_name, var.value, ftype));
        }
    }
}

impl NaIRGenObjects._register_class_consts(
    arch_name: str, lay: ArchetypeLayout
) -> None {
    if lay.is_enum_form {
        return;
    }
    _owns = lay.decl_mod == self._own_path();
    for cinfo in lay.class_consts {
        self._register_one_class_const(arch_name, cinfo, _owns);
    }
}

impl NaIRGenObjects._register_one_class_const(
    arch_name: str, cinfo: ClassConstInfo, owns: bool
) -> None {
    full_name = f"{arch_name}.{cinfo.name}";
    if full_name in self.static_fields or full_name in self.llvm_module.globals {
        return;
    }
    assign = cinfo.assign;
    ftype = self._lower_type(cinfo.type) if assign.type_tag is not None else None;
    if ftype is None and assign.value is not None {
        ftype = self._infer_global_init_type(assign.value);
    }
    if ftype is None {
        return;
    }
    gv = ir.GlobalVariable(self.llvm_module, ftype, name=full_name);
    gv.linkage = "";
    self.static_fields[full_name] = gv;
    self.global_vars[full_name] = gv;
    self.global_var_types[full_name] = ftype;
    self.has_native_code = True;
    if not owns {
        return;
    }
    const_init = self._codegen_const_expr(assign.value, ftype);
    if const_init is None {
        const_init = self._class_const_enum_init(assign.value, ftype);
    }
    gv.initializer = const_init if const_init is not None else ir.Constant(ftype, None);

    if const_init is None {
        if not self?._global_init_nodes {
            self._global_init_nodes: list = [];
        }
        self._global_init_nodes.append((full_name, assign.value, ftype));
    }
}

impl NaIRGenObjects._class_const_enum_init(
    value: uni.UniNode, ftype: ir.Type
) -> (ir.Constant | None) {
    if not isinstance(value, uni.Expr) or not isinstance(ftype, ir.IntType) {
        return None;
    }
    _val = self._enum_member_const(value.type);
    if _val is None and isinstance(value, uni.AtomTrailer) {
        _val = self._codegen_class_form_enum_member(value);
    }
    if not isinstance(_val, ir.Constant) {
        return None;
    }
    return ir.Constant(ftype, _val.constant);
}

impl NaIRGenObjects._method_slot_name(
    method: uni.Ability, field: (uni.HasVar | None)
) -> str {
    if field is not None {
        _fname = field.name.value if field.name else "field";
        _slot = accessor_slot_name(_fname, method);
        if _slot is not None {
            return _slot;
        }
    }
    return method.name_ref.sym_name if method.name_ref else "unnamed";
}

impl NaIRGenObjects._forward_declare_method(
    arch_name: str,
    method: uni.Ability,
    field: (uni.HasVar | None) = None,
    imported: bool = False
) -> None {
    method_name = self._method_slot_name(method, field);
    full_name = f"{arch_name}.{method_name}";

    if method.type_params {
        self._generic_methods[full_name] = method;
        self.has_native_code = True;
        return;
    }
    if full_name in self.method_funcs {
        return;
    }
    if full_name in self._native_skipped_methods {
        return;
    }
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or (sig is None and field is None) {
        return;
    }

    _is_static = method.is_static or method.is_classmethod;

    _m_params = sig.get_parameters() if sig is not None else [];
    if (
        not _is_static
        and _m_params
        and _m_params[0].name
        and _m_params[0].name.value == "self"
    ) {
        _m_params = _m_params[1:];
    }
    if (
        method.is_classmethod
        and _m_params
        and _m_params[0].name
        and _m_params[0].name.value == "cls"
    ) {
        _m_params = _m_params[1:];
    }

    _self_type = self._class_form_enum_self_type(arch_name) or struct_type.as_pointer();

    _sig_mark = len(self.errors_had);
    _saved_sig_kind = self._sig_decl_kind;
    self._sig_decl_kind = "signature type";

    param_types: list[ir.Type] = [] if _is_static else [_self_type];
    for p in _m_params {
        param_types.append(self._resolve_sig_type(p));
    }

    ret_type = self._resolve_sig_type(sig.return_type)
        if sig is not None
        else ir.IntType(64);

    if sig is None and field is not None {
        if method.accessor_kind == "property" {
            ret_type = self._resolve_sig_type(field);
        } elif method.accessor_kind == "setter" {
            param_types.append(self._resolve_sig_type(field));
        }
    }
    self._sig_decl_kind = _saved_sig_kind;
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=full_name);

    _base = 0 if _is_static else 1;
    if not _is_static {
        func.args[0].name = "self";
    }
    for (i, p) in enumerate(_m_params) {
        func.args[i + _base].name = p.name.value if p.name else f"arg{i}";
    }
    if len(func.args) > _base + len(_m_params) {
        func.args[_base + len(_m_params)].name = "value";
    }
    _own_params = list(self._ability_fn_type(method).parameters or []);
    if _own_params and (_own_params[0].is_self or _own_params[0].is_cls) {
        _own_params = _own_params[1:];
    }
    self._apply_ownership_param_attrs(func, _own_params, _base);
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;

    if len(self.errors_had) > _sig_mark {
        self._demote_method_if_unlowerable(
            full_name,
            func,
            _sig_mark,
            keep_func=self._is_virtual_slot(arch_name, method_name),
            stub_body=not imported
        );
    }
}

impl NaIRGenObjects._codegen_method(
    arch_name: str,
    method: uni.Ability,
    symbol_override: (str | None) = None,
    field: (uni.HasVar | None) = None
) -> None {
    method_name = self._method_slot_name(method, field);

    full_name = symbol_override or f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }
    if full_name in self._native_skipped_methods or func.blocks {
        return;
    }

    _pre_viols = self._capability_demotions.get(id(method));
    if _pre_viols is not None {
        self._claimed_capability_demotions.add(id(method));
        _pre_virtual = self._is_virtual_slot(arch_name, method_name);
        if self._predemote_capability_unit(
            full_name, func, _pre_viols, keep_func=_pre_virtual
        ) {
            return;
        }
    }

    block = func.append_basic_block(name="entry");
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    saved_self_arch = self._self_arch;
    self._self_arch = arch_name;

    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );

    _scan_body = ModuleCodegenPass.unwrap_body(method);
    if _scan_body is not None {
        _scan_owner = method.body if isinstance(method.body, uni.ImplDef) else method;
        self._scan_closure_escapes(_scan_owner, _scan_body);
    }

    _is_static = method.is_static or method.is_classmethod;
    _base = 0;
    if not _is_static {
        self_alloca = self.builder.alloca(func.args[0].type, name="self");
        self.builder.store(func.args[0], self_alloca);
        self.local_vars["self"] = self_alloca;
        self.param_vars.add("self");
        _base = 1;
    }

    sig = method.signature;
    _body_params = sig.get_parameters() if sig is not None else [];
    if (
        not _is_static
        and _body_params
        and _body_params[0].name
        and _body_params[0].name.value == "self"
    ) {
        _body_params = _body_params[1:];
    }
    if (
        method.is_classmethod
        and _body_params
        and _body_params[0].name
        and _body_params[0].name.value == "cls"
    ) {
        _body_params = _body_params[1:];
    }

    _bound_params: list[tuple[(str, bool)]] = [
        ((p.name.value if p.name else f"arg{i}"), bool(p.name?.sym?.param_rebound), )
        for (i, p) in enumerate(_body_params)
    ];
    if sig is None and len(func.args) > _base + len(_bound_params) {
        _bound_params.append(("value", False, ));
    }
    for (i, (param_name, _p_rebound)) in enumerate(_bound_params) {
        arg_val = func.args[i + _base];
        if param_name in self.closure_cell_vars {
            slot = self._emit_closure_cell(param_name, arg_val.type);
            self.builder.store(arg_val, slot);
            self.local_vars[param_name] = slot;
            if isinstance(arg_val.type, ir.PointerType) {
                self._emit_rc_retain(arg_val, op="param_cell", loc=full_name);
            }
            continue;
        }
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;

        if isinstance(arg_val.type, ir.PointerType) and _p_rebound {
            self._emit_rc_retain(arg_val, op="param_promote", loc=full_name);
        } else {
            self.param_vars.add(param_name);
        }
    }

    _is_virtual = self._is_virtual_slot(arch_name, method_name);
    _local_mark = len(self.errors_had);

    try {
        body = ModuleCodegenPass.unwrap_body(method);
        if body is not None {
            self._codegen_body(body);
        }

        if not self.builder.block.is_terminated {
            _mth_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
                if method.loc
                else 0}";

            self._emit_scope_cleanup(skip_var=None, loc=_mth_loc);
            ret_type = func.return_value.type;
            if isinstance(ret_type, ir.VoidType) {
                self.builder.ret_void();
            } else {
                self.builder.ret(self._zero_const(ret_type));
            }
        }
        method.gen.llvm_ir = func;

        self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    } except Exception as _codegen_exc {
        if self._na_debug_on() {
            import sys;
            import traceback;
            sys.stderr.write(f"NA_DEBUG raise {full_name}\n");
            traceback.print_exc(file=sys.stderr);
        }
        self.emit(
            E5092,
            node_override=method,
            kind="method (native emitter error in)",
            name=full_name,
            help_text=f"The native backend raised {type(_codegen_exc).__name__} "
            f"while lowering this method; it falls back to its Python "
            f"implementation. Original error: {_codegen_exc}"
        );
    }

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;

    self._demote_method_if_unlowerable(
        full_name, func, _local_mark, keep_func=_is_virtual
    );
}

impl NaIRGenObjects._demote_method_if_unlowerable(
    full_name: str,
    func: ir.Function,
    local_mark: int,
    keep_func: bool = False,
    stub_body: bool = True
) -> bool {
    if len(self.errors_had) <= local_mark {
        return False;
    }
    _own = list(self.errors_had[local_mark:]);

    _na_debug = self._na_debug_on();
    if self._seam_warnings_on() {
        import from jaclang.cli.console { console }
        _why = "; ".join(str(e) for e in _own);
        console.warning(
            f"native seam -- demoting {full_name} to Python-only "
            f"(un-lowerable): {_why}"
        );
    }
    if _na_debug {
        import sys;
        sys.stderr.write(f"NA_DEBUG demote {full_name}\n");
        for _diag in _own {
            sys.stderr.write(f"NA_DEBUG   {_diag.pretty_print()}\n");
        }
    }
    if stub_body {
        try {
            import from jaclang.compiler.driver.na_coverage { na_coverage_seam }
            _first_code = _own[0].code.code if _own[0].code is not None else "";
            _code_tag = f"[{_first_code}] " if _first_code else "";
            na_coverage_seam(
                self.ir_in.loc.mod_path,
                f"{full_name}: {_code_tag}" + str(_own[0]).split('\n')[0]
            );
        } except Exception { }
    }
    del self.errors_had[local_mark:];

    if stub_body {
        func.blocks.clear();
        blk = func.append_basic_block(name="entry");
        b = ir.IRBuilder(blk);
        self._get_or_declare_extern("abort", ir.VoidType(), []);
        b.call(self.extern_funcs["abort"], []);
        b.unreachable();
    }
    if not keep_func {
        self.method_funcs.pop(full_name, None);
    }
    self.func_symtab.pop(full_name, None);
    self._native_skipped_methods.add(full_name);
    return True;
}

impl NaIRGenObjects._seam_warnings_on -> bool {
    """Whether a seam this run takes should also be announced on stderr.""";
    if self._na_debug_on() or bool(self.prog.options.native_debug) {
        return True;
    }
    try {
        import from jaclang.project.config { get_config }
        _cfg = get_config();
        if _cfg and _cfg.check {
            return bool(_cfg.check.warn_native_seams);
        }
    } except Exception { }
    return True;
}

impl NaIRGenObjects._arch_decl_mod_path(arch_name: str) -> str {
    lay = self._registry().get_layout(arch_name);
    _ct = lay.class_type if lay is not None else None;
    _decl = (
        _ct.shared.symbol_table
            if isinstance(_ct, ClassType) and _ct._shared is not None
            else None
    );
    if _decl is not None and _decl.loc and _decl.loc.mod_path {
        return _decl.loc.mod_path;
    }
    return self.ir_in.loc.mod_path;
}

impl NaIRGenObjects._opaque_field_if_unlowerable(
    arch_name: str, fname: str, local_mark: int
) -> (ir.Type | None) {
    """Spend a field declaration's refusal on the field, not on the module.

    A `has` type with no native layout sits outside every ability body, so
    `_demote_method_if_unlowerable` has nothing to take it from and the
    diagnostic used to survive to the end of the run, where a non-empty
    `errors_had` withholds the module's IR. The declaration owns it here the
    way #8285 made a signature's declaration own its own: the slot erases to
    an opaque pointer, the field is recorded so that every read and write of
    it refuses inside the callable that performs it, and the refusal is
    re-published as a coverage seam keyed on the field rather than swallowed.

    An erased slot is storage the native side never writes, so the field also
    joins `struct_field_foreign` -- the constructor, the tracer, the arena and
    the reference counter all already skip that set.
    """;
    if len(self.errors_had) <= local_mark {
        return None;
    }
    _own = list(self.errors_had[local_mark:]);
    _first = _own[0];
    _code = _first.code.code if _first.code is not None else "";
    _why = str(_first).split('\n')[0];

    if self._seam_warnings_on() {
        import from jaclang.cli.console { console }
        console.warning(
            f"native seam -- erasing field {arch_name}.{fname} to an "
            f"opaque slot (un-lowerable declaration): "
                + "; ".join(str(e) for e in _own)
        );
    }
    try {
        import from jaclang.compiler.driver.na_coverage { na_coverage_seam }
        na_coverage_seam(
            self._arch_decl_mod_path(arch_name),
            f"{arch_name}.{fname}: " + (f"[{_code}] " if _code else "") + _why
        );
    } except Exception { }
    del self.errors_had[local_mark:];
    if arch_name not in self.struct_field_opaque {
        self.struct_field_opaque[arch_name] = {};
    }
    self.struct_field_opaque[arch_name][fname] = _why;
    return ir.IntType(8).as_pointer();
}

impl NaIRGenObjects._refuse_opaque_field(
    nd: (uni.UniNode | None), type_name: (str | None), fname: str
) -> bool {
    """Refuse a touch of an erased slot, inside the callable that touches it.

    The slot carries no value the native side put there, so answering with
    its bits would be wrong rather than merely un-lowered. Emitting here puts
    the diagnostic inside the enclosing callable's demotion window, which is
    what turns one un-lowerable declaration into a seam per method that reads
    or writes it instead of a dead module.
    """;
    if type_name is None {
        return False;
    }
    _why = self.struct_field_opaque.get(type_name, {}).get(fname);
    if _why is None {
        return False;
    }
    lay = self._arch_layout(type_name);
    _owner = (
        lay.fields[lay.field_index[fname]].owner
            if lay is not None and fname in lay.field_index
            else type_name
    );
    self.emit(E5092, node_override=nd, kind="erased field", name=f"{_owner}.{fname}");
    return True;
}

impl NaIRGenObjects._codegen_no_sig_method(
    arch_name: str, method: uni.Ability
) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }

    block = func.append_basic_block(name="entry");
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    saved_self_arch = self._self_arch;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    self._self_arch = arch_name;
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );

    _scan_body = ModuleCodegenPass.unwrap_body(method);
    if _scan_body is not None {
        _scan_owner = method.body if isinstance(method.body, uni.ImplDef) else method;
        self._scan_closure_escapes(_scan_owner, _scan_body);
    }

    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    self.param_vars.add("self");

    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }

    if not self.builder.block.is_terminated {
        _nosig_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
            if method.loc
            else 0}";

        self._emit_scope_cleanup(skip_var=None, loc=_nosig_loc);
        self.builder.ret_void();
    }
    method.gen.llvm_ir = func;

    self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;
}

impl NaIRGenObjects._trigger_struct_names(method: uni.Ability) -> list[str] {
    names = method.event_trigger_type_names();
    if names is None {
        return [];
    }
    return [
        nm
        for nm in names
        if nm in self.struct_types
    ];
}

impl NaIRGenObjects._read_field_or_refuse(
    nd: uni.UniNode, obj_val: ir.Value, field_name: str, arch_name: str
) -> (ir.Value | None) {
    """Read a field, naming the ancestor when an inherited one is unreachable.

    Only the inherited case speaks up here. Every other way a name can miss
    the layout already has an owner further out that reports it, and claiming
    them from this depth would rename diagnostics this change has no business
    touching.
    """;
    _mark = len(self.errors_had);
    _val = self._codegen_field_access(obj_val, field_name, arch_name, nd);
    if _val is None and len(self.errors_had) == _mark {
        _val = self._codegen_class_const_read(obj_val, arch_name, field_name);
        if _val is None {
            self._emit_field_access_refusal(nd, arch_name, field_name);
        }
    }
    return _val;
}

impl NaIRGenObjects._unadopted_field_owner(
    arch_name: str, field_name: str
) -> (str | None) {
    lay = self._arch_layout(arch_name);
    if lay is None {
        return None;
    }
    for _anc in lay.unadopted {
        _alay = self._arch_layout(_anc);
        if _alay is not None and field_name in _alay.field_index {
            return _anc;
        }
    }
    for _anc in lay.mro[1:] {
        _alay = self._arch_layout(_anc);
        if _alay is None {
            continue;
        }
        for _deep in _alay.unadopted {
            _dlay = self._arch_layout(_deep);
            if _dlay is not None and field_name in _dlay.field_index {
                return _deep;
            }
        }
    }
    return None;
}

impl NaIRGenObjects._emit_field_access_refusal(
    nd: uni.UniNode, arch_name: str, field_name: str
) -> None {
    _owner = self._unadopted_field_owner(arch_name, field_name);
    if _owner is None {
        _decl = self._class_const_declarer(arch_name, field_name);
        if _decl is not None {
            self.emit(
                E5092,
                node_override=nd,
                kind="class-level attribute read",
                name=field_name,
                help_text=(
                    f"'{field_name}' is a class-level attribute of '{_decl}', "
                    f"not an instance field. Reading it through an instance "
                    f"needs every declaring class in the hierarchy to carry "
                    f"the value in one shape the receiver's vtable can select "
                    f"between, and this hierarchy does not. Read it off the "
                    f"class, or move this code to a @sv/Python context."
                )
            );
        }
        return;
    }
    self.emit(
        E5092,
        node_override=nd,
        kind="inherited field access",
        name=field_name,
        help_text=(
            f"'{field_name}' is declared by '{_owner}', which lays out in "
            f"another unit with no vtable slot, while '{arch_name}' needs "
            f"that slot for one. No offset satisfies both units, so the "
            f"field is not reachable from here. Read it through an "
            f"'{_owner}'-typed value, or move this code to a @sv/Python "
            f"context."
        )
    );
}

impl NaIRGenObjects._class_const_declarer(
    arch_name: str, field_name: str
) -> (str | None) {
    reg = self._registry();
    _own_lay = self._arch_layout(arch_name);
    _seen: list[str] = list(_own_lay.mro) if _own_lay is not None else [arch_name];
    for _cls in (reg.subclasses.get(arch_name) or []) {
        if _cls not in _seen {
            _seen.append(_cls);
        }
    }
    for _cls in _seen {
        _lay = self._arch_layout(_cls);
        if _lay is None {
            continue;
        }
        for cinfo in _lay.class_consts {
            if cinfo.name == field_name {
                return _cls;
            }
        }
    }
    return None;
}

impl NaIRGenObjects._mro_of(arch_name: str) -> list[str] {
    mro = self._registry().get_mro(arch_name);
    return mro or [arch_name];
}

impl NaIRGenObjects._arch_layout(arch_name: str) -> (ArchetypeLayout | None) {
    return self._registry().get_layout(arch_name);
}

impl NaIRGenObjects._arch_has_vtable(arch_name: str) -> bool {
    if arch_name not in self.struct_types {
        return False;
    }
    lay = self._arch_layout(arch_name);
    return lay is not None and lay.has_vtable;
}

impl NaIRGenObjects._nearest_slot(arch_name: str, names: list[str]) -> (tuple | None) {
    lay = self._arch_layout(arch_name);
    if lay is None {
        return None;
    }
    best: (tuple | None) = None;
    best_rank = -1;
    for nm in names {
        idx = lay.method_index.get(nm);
        if idx is None or idx >= len(lay.methods) {
            continue;
        }
        mslot = lay.methods[idx];
        if mslot.ability is None {
            continue;
        }
        rank = lay.mro.index(mslot.owner) if mslot.owner in lay.mro else len(lay.mro);
        if best is None or rank < best_rank {
            best = (mslot.owner, nm, );
            best_rank = rank;
        }
    }
    return best;
}

impl NaIRGenObjects._slot_function(arch_name: str, names: list[str]) -> tuple {
    hit = self._nearest_slot(arch_name, names);
    if hit is None {
        return (None, None, False, );
    }
    (owner, slot) = hit;
    cands = [arch_name, owner] if owner != arch_name else [owner];
    for cls in cands {
        cand = f"{cls}.{slot}";
        if cand in self._native_skipped_methods {
            return (cls, slot, True, );
        }
        if cand in self.method_funcs {
            return (cls, slot, False, );
        }
    }
    return (None, slot, False, );
}

impl NaIRGenObjects._forward_declare_event_method(
    arch_name: str, method: uni.Ability
) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    if full_name in self.method_funcs {
        return;
    }
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or not isinstance(sig, uni.EventSignature) {
        return;
    }
    loc_type: ir.Type = ir.IntType(8).as_pointer();
    if sig.arch_tag_info is not None {
        _members = self._trigger_struct_names(method);
        if _members {
            loc_type = self.struct_types[_members[0]].as_pointer();
        } else {
            loc_type = self._resolve_jac_type(sig.arch_tag_info);
        }
    }
    fnty = ir.FunctionType(ir.VoidType(), [struct_type.as_pointer(), loc_type]);
    func = ir.Function(self.llvm_module, fnty, name=full_name);
    func.args[0].name = "self";
    func.args[1].name = "here" if sig.from_walker else "visitor";
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
}

impl NaIRGenObjects._codegen_event_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    sig = method.signature;
    if func is None or not isinstance(sig, uni.EventSignature) {
        return;
    }
    _pre_viols = self._capability_demotions.get(id(method));
    if _pre_viols is not None {
        self._claimed_capability_demotions.add(id(method));
        if self._predemote_capability_unit(
            full_name, func, _pre_viols, keep_func=True
        ) {
            return;
        }
    }
    block = func.append_basic_block(name="entry");
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    saved_self_arch = self._self_arch;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    self._self_arch = arch_name;
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};
    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );
    _scan_body = ModuleCodegenPass.unwrap_body(method);
    if _scan_body is not None {
        _scan_owner = method.body if isinstance(method.body, uni.ImplDef) else method;
        self._scan_closure_escapes(_scan_owner, _scan_body);
    }
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    self.param_vars.add("self");

    loc_name = "here" if sig.from_walker else "visitor";
    loc_arg = func.args[1];
    loc_alloca = self.builder.alloca(loc_arg.type, name=loc_name);
    self.builder.store(loc_arg, loc_alloca);
    self.local_vars[loc_name] = loc_alloca;
    self.param_vars.add(loc_name);
    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }
    if not self.builder.block.is_terminated {
        _ev_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
            if method.loc
            else 0}";
        self._emit_scope_cleanup(skip_var=None, loc=_ev_loc);
        self.builder.ret_void();
    }
    method.gen.llvm_ir = func;
    self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;
}

impl NaIRGenObjects._stack_alloc_target_ok(nd: uni.UniNode) -> bool {
    p = nd.parent;
    if not isinstance(p, uni.Assignment) or p.aug_op is not None or p.value is not nd {
        return False;
    }
    targets = p.target if isinstance(p.target, (list, tuple)) else [(p.target)];
    if len(targets) != 1 or not isinstance(targets[0], uni.Name) {
        return False;
    }
    sym = targets[0].sym;
    return sym is not None and sym.na_stack_ok;
}

impl NaIRGenObjects._codegen_instantiation(
    nd: (uni.FuncCall | uni.Name),
    type_name_override: (str | None) = None,
    ctor_params: (list | None) = None
) -> (ir.Value | None) {
    _is_call = isinstance(nd, uni.FuncCall);
    type_name = type_name_override;
    if type_name is None {
        _nt = nd.type if isinstance(nd, uni.Expr) else None;
        if self._tb_kind(_nt) in ("struct", "class") {
            type_name = self._tb_class_name(_nt);
        }
        if type_name is None {
            type_name = self._get_name(nd.target if _is_call else nd);
        }
    }
    if type_name is None or type_name not in self.struct_types {
        return None;
    }
    lay = self._arch_layout(type_name);
    if lay is None {
        return None;
    }
    if self._reject_scalar_type_args(nd, type_name) {
        return None;
    }
    (_init_fn_owner, _init_slot, _init_demoted) = self._slot_function(
        type_name, ["init", "__init__"]
    );
    if _init_demoted {
        self.emit(
            E5092,
            node_override=nd,
            kind="constructor",
            name=f"{type_name}() via {_init_fn_owner}.{_init_slot}",
            help_text=(
                "The initializer was demoted to its Python implementation, so "
                "native construction has no initializer to call and would "
                "leave the object half-built. Construct this class from a "
                "Python/@sv context, or make the initializer lowerable."
            )
        );
        return None;
    }
    if _init_slot is not None and _init_fn_owner is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="constructor",
            name=f"{type_name}() via {_init_slot}",
            help_text=(
                "The initializer this class resolves to has no native "
                "function, so native construction cannot run it."
            )
        );
        return None;
    }
    struct_type = self.struct_types[type_name];
    struct_ptr_type = struct_type.as_pointer();

    params = ctor_params
        if ctor_params is not None
        else ((nd.params or []) if _is_call else []);
    _has_init = _init_fn_owner is not None;
    _pos_field_pairs: list = [];
    if not _has_init {
        _pos_args = [
            p
            for p in params
            if not isinstance(p, uni.KWPair)
        ];
        if _pos_args and self._pyb_base_of(type_name) is not None {
            self.emit(
                E5092,
                node_override=nd,
                kind="constructor call",
                name=type_name,
                help_text=(
                    f"'{type_name}' inherits from a Python-side base, so its "
                    f"constructor arguments cannot be matched positionally; "
                    f"use keyword arguments."
                )
            );
            return None;
        }
        if _pos_args {
            _order = [f.name for f in lay.fields];
            if len(_pos_args) > len(_order) {
                _ct = lay.class_type;
                _is_exc = isinstance(_ct, ClassType)
                    and any(
                        self._tb_class_name(_anc) in ("BaseException", "Exception")
                        for _anc in (_ct.shared.mro or [])
                    );
                if _is_exc {
                    _pos_args = _pos_args[:len(_order)];
                } else {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="constructor call",
                        name=type_name,
                        help_text=(
                            f"'{type_name}' declares {len(_order)} field(s) but is "
                            f"called with {len(_pos_args)} positional argument(s); "
                            "the surplus has no field to bind to natively."
                        )
                    );
                    return None;
                }
            }
            for (_pi, _pv) in enumerate(_pos_args) {
                _pos_field_pairs.append((_order[_pi], _pv));
            }
        }
    }

    _vt_struct = type_name in self.clib_vtable_structs;
    _stack_ok = (
        not _vt_struct
        and self._stack_alloc_target_ok(nd)
        and self._arch_is_acyclic(type_name)
        and not self._struct_has_ref_fields(type_name)
        and not self._arch_has_vtable(type_name)
        and not self._arch_is_osp_name(type_name)
        and f"{type_name}.drop" not in self.func_symtab
        and not self.struct_field_inline.get(type_name, None)
        and not self.region_stack
        and self._pyb_base_of(type_name) is None
    );
    _headerless = self._nogc_headerless() and not self._arch_is_osp_name(type_name);
    if _stack_ok and _headerless {
        obj_ptr = self._entry_alloca(struct_type, f"stk.{type_name}");
        self.rc_stack_promotions += 1;
        _tgt_asgn = nd.find_parent_of_type(uni.Assignment);
        if _tgt_asgn is not None
            and len(_tgt_asgn.target) == 1
            and isinstance(_tgt_asgn.target[0], uni.Name) {
            self.nogc_no_free_vars.add(_tgt_asgn.target[0].sym_name);
        }
    } elif _stack_ok {
        self.rc_stack_promotions += 1;
        _i8 = ir.IntType(8);
        _i32s = ir.IntType(32);
        _i64s = ir.IntType(64);
        _hdr_arr = ir.ArrayType(_i8, HDR_TOTAL);
        _slab_ty = ir.LiteralStructType([_hdr_arr, struct_type]);
        _slab = self._entry_alloca(_slab_ty, f"stk.{type_name}");
        obj_ptr = self.builder.gep(
            _slab, [ir.Constant(_i32s, 0), ir.Constant(_i32s, 1)], name="stk.obj"
        );
        _stk_i8 = self.builder.bitcast(obj_ptr, _i8.as_pointer(), name="stk.i8");
        _stk_rc_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_RC_OFF)], name="stk.rc.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, RC_SENTINEL),
            self.builder.bitcast(_stk_rc_slot, _i64s.as_pointer(), name="stk.rc.p")
        );
        _stk_dtor_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_DTOR_OFF)], name="stk.dtor.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, 0),
            self.builder.bitcast(_stk_dtor_slot, _i64s.as_pointer(), name="stk.dtor.p")
        );
        _stk_aid_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_ALLOC_ID_OFF)], name="stk.aid.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, 0),
            self.builder.bitcast(_stk_aid_slot, _i64s.as_pointer(), name="stk.aid.p")
        );
        if self.rc_set_type_fn is not None {
            self._emit_set_type_tag(self.builder, _stk_i8, type_name);
        }
    } elif _vt_struct {
        obj_ptr = self._clib_alloc_vtable(type_name);
    } elif _headerless and not self.region_stack {
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        _malloc_fn = self._get_or_declare_extern(
            "malloc", ir.IntType(8).as_pointer(), [ir.IntType(64)]
        );
        raw_ptr = self.builder.call(_malloc_fn, [size], name="raw.ptr");
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
        self._emit_struct_drop_fn(type_name);
    } elif self.region_stack and not self._arch_is_walker_name(type_name) {
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        raw_ptr = self._region_alloc(size, name="region.obj");
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
        if self._gc_mode() == "none" {
            _rg_asgn = nd.find_parent_of_type(uni.Assignment);
            if _rg_asgn is not None
                and len(_rg_asgn.target) == 1
                and isinstance(_rg_asgn.target[0], uni.Name) {
                self.nogc_no_free_vars.add(_rg_asgn.target[0].sym_name);
            }
        }
        if self.rc_set_type_fn is not None {
            _obj_i8_r = self.builder.bitcast(
                obj_ptr, ir.IntType(8).as_pointer(), name="obj.i8.rtag"
            );
            self._emit_set_type_tag(self.builder, _obj_i8_r, type_name);
        }
        self._region_log_dtor_if_needed(raw_ptr, type_name);
    } elif (
        self._arch_is_osp_name(type_name)
        and not self._arch_is_walker_name(type_name)
        and "here" in self.local_vars
    ) {
        self._emit_arena_helpers();
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        _i8p_g = ir.IntType(8).as_pointer();
        _here_val = self.builder.load(self.local_vars["here"], name="growth.here");
        _here_i8 = self.builder.bitcast(_here_val, _i8p_g, name="growth.here.i8");
        _gdtor = self._emit_struct_drop_fields_fn(type_name);
        _gdtor_i8 = (
            self.builder.bitcast(_gdtor, _i8p_g, name="growth.dtor")
                if _gdtor is not None
                else ir.Constant(_i8p_g, None)
        );
        raw_ptr = self.builder.call(
            self.osp_anchor_alloc_fn, [_here_i8, size, _gdtor_i8], name="growth.obj"
        );
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
        if self.rc_set_type_fn is not None {
            _obj_i8_g = self.builder.bitcast(
                obj_ptr, ir.IntType(8).as_pointer(), name="obj.i8.gtag"
            );
            self._emit_set_type_tag(self.builder, _obj_i8_g, type_name);
        }
    } else {
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        _inst_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
            if nd.loc
            else 0}";
        if self.rc_alloc_fn is None {
            self._emit_rc_helpers();
        }
        _alloc_fn = self.rc_alloc_fn;
        assert _alloc_fn is not None , "rc helpers are emitted before allocation";
        raw_ptr = self._rc_call_with_ctx(
            _alloc_fn, [size], op="new", loc=_inst_loc, name="raw.ptr"
        );
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
        self._emit_struct_release_fn(type_name);
        _dtor_fn_s = self.struct_release_fns.get(type_name);
        if _dtor_fn_s is not None {
            _i8p_s = ir.IntType(8).as_pointer();
            _i64_s = ir.IntType(64);
            _i64p_s = _i64_s.as_pointer();
            _raw_s = self.builder.bitcast(obj_ptr, _i8p_s, name="obj_raw_s");
            _dtor_slot_s = self.builder.gep(
                _raw_s, [ir.Constant(_i64_s, HDR_DTOR_OFF)], name="obj_dtor_slot"
            );
            _dtor_slot_i64_s = self.builder.bitcast(
                _dtor_slot_s, _i64p_s, name="obj_dtor_i64p"
            );
            _dtor_i64_s = self.builder.ptrtoint(
                _dtor_fn_s, _i64_s, name="obj_dtor_i64"
            );
            self.builder.store(_dtor_i64_s, _dtor_slot_i64_s);
        }
        self._emit_trace_fn(type_name);
        _trace_fn_s = self.struct_trace_fns.get(type_name);
        self._require_trace_fn(
            type_name,
            (
                self._struct_has_ref_fields(type_name)
                and not self._arch_is_acyclic(type_name)
            ),
            _trace_fn_s is not None
        );
        if self.rc_set_type_fn is not None {
            _obj_i8 = self.builder.bitcast(
                obj_ptr, ir.IntType(8).as_pointer(), name="obj.i8.tag"
            );
            self._emit_set_type_tag(self.builder, _obj_i8, type_name);
        }
    }

    vtable_global = self._vtable_global_for(type_name);
    if vtable_global is not None {
        vtable_base = self.builder.gep(
            vtable_global,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.base"
        );
        vtable_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.slot"
        );
        self.builder.store(vtable_base, vtable_slot);
    }

    _tt_idx = lay.type_tag_slot;
    if _tt_idx is not None {
        _tt_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _tt_idx)],
            name="type_tag.slot"
        );

        _tt_val = stable_osp_tag(type_name);
        self.builder.store(ir.Constant(ir.IntType(64), _tt_val), _tt_slot);

        if not self._arch_is_walker_name(type_name) {
            self._osp_make_immortal(obj_ptr);
        }
    }

    _rep_idx = lay.reports_slot;
    if _rep_idx is not None {
        _rep_h = self.list_helpers.get("jacval");
        if _rep_h is not None {
            _rep_list = self._rc_call_with_ctx(
                _rep_h["new"], [], op="new", loc="", name="reports.init"
            );
            self.builder.store(
                _rep_list,
                self.builder.gep(
                    obj_ptr,
                    [
                        ir.Constant(ir.IntType(32), 0),
                        ir.Constant(ir.IntType(32), _rep_idx)
                    ],
                    name="reports.slot"
                )
            );
        }
    }

    field_indices = dict(lay.field_index);
    field_types = self.struct_field_types.get(type_name, {});
    foreign_fields = self.struct_field_foreign.get(type_name, set());
    field_defaults: dict = {};
    for _finfo in lay.fields {
        if _finfo.default_expr is not None and _finfo.name not in foreign_fields {
            field_defaults[_finfo.name] = _finfo.default_expr;
        }
    }

    set_fields: set[str] = set();
    _field_inits: list = list(_pos_field_pairs);
    for param in params {
        if isinstance(param, uni.KWPair) {
            _kn = param.key.sym_name if param.key else None;
            if _kn is not None {
                _field_inits.append((_kn, param.value));
            }
        }
    }
    for (key_name, init_expr) in _field_inits {
        if key_name not in field_indices or key_name in set_fields {
            continue;
        }
        if self._refuse_opaque_field(init_expr, type_name, key_name) {
            continue;
        }
        if key_name in foreign_fields {
            continue;
        }
        _fi_mark = len(self.errors_had);
        val = self._codegen_expr(init_expr);
        if val is None {
            if len(self.errors_had) == _fi_mark {
                self.emit(
                    E5092,
                    node_override=init_expr,
                    kind="constructor argument",
                    name=f"{type_name}({key_name}=...)"
                );
            }
            continue;
        }
        idx = field_indices[key_name];
        ftype = field_types[key_name];

        if key_name in self.struct_field_inline.get(type_name, set()) {
            _inl_fp = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"field.{key_name}"
            );
            self._store_inline_field(type_name, key_name, _inl_fp, val, False);
            set_fields.add(key_name);
            continue;
        }

        _is_clib_cb = (
            type_name in self.clib_vtable_structs
            and isinstance(ftype, ir.PointerType)
            and isinstance(ftype.pointee, ir.FunctionType)
        );
        if _is_clib_cb {
            val = self._clib_coerce_callback(val, ftype);
        } else {
            val = self._coerce_typed(val, ftype, self._expr_type_of(init_expr));
        }

        if not _vt_struct {
            self._emit_take_ref(
                val,
                op="ctor_field",
                loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                    if nd.loc
                    else 0}"
            );
        }
        field_ptr = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{key_name}"
        );
        self.builder.store(val, field_ptr);
        set_fields.add(key_name);
    }

    for (fname, default_expr) in field_defaults.items() {
        if fname not in set_fields {
            _fd_mark = len(self.errors_had);
            val = self._codegen_expr(default_expr);
            if val is None and len(self.errors_had) == _fd_mark {
                self.emit(
                    E5092,
                    node_override=default_expr,
                    kind="field default",
                    name=f"{type_name}.{fname}"
                );
            }
            if val is not None
                and fname in self.struct_field_inline.get(type_name, set()) {
                _inl_fp = self.builder.gep(
                    obj_ptr,
                    [
                        ir.Constant(ir.IntType(32), 0),
                        ir.Constant(ir.IntType(32), field_indices[fname])
                    ],
                    name=f"field.{fname}"
                );
                self._store_inline_field(type_name, fname, _inl_fp, val, False);
                set_fields.add(fname);
                continue;
            }
            if val is not None {
                idx = field_indices[fname];
                ftype = field_types[fname];

                _is_clib_cb_d = (
                    type_name in self.clib_vtable_structs
                    and isinstance(ftype, ir.PointerType)
                    and isinstance(ftype.pointee, ir.FunctionType)
                );
                if _is_clib_cb_d {
                    val = self._clib_coerce_callback(val, ftype);
                } else {
                    val = self._coerce_typed(
                        val, ftype, self._expr_type_of(default_expr)
                    );
                }

                if not _vt_struct {
                    self._emit_take_ref(
                        val,
                        op="ctor_field",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
                }
                field_ptr = self.builder.gep(
                    obj_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                    name=f"default.{fname}"
                );
                self.builder.store(val, field_ptr);
                set_fields.add(fname);
            }
        }
    }

    for (fname, idx) in field_indices.items() {
        if fname not in set_fields {
            ftype = field_types[fname];
            zero_val = ir.Constant(ftype, None);
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"zero.{fname}"
            );
            self.builder.store(zero_val, field_ptr);
        }
    }

    if not self._codegen_pyb_shadow_init(
        nd, type_name, obj_ptr, params, field_indices
    ) {
        return None;
    }

    init_fn: (ir.Function | None) = None;
    _init_owner: str = type_name;
    if _init_fn_owner is not None {
        init_fn = self.method_funcs[f"{_init_fn_owner}.{_init_slot}"];
        _init_owner = _init_fn_owner;
    }
    if init_fn is not None and _init_owner != type_name {
        if not self._registry().is_primary_ancestor(type_name, _init_owner) {
            self.emit(
                E5092,
                node_override=nd,
                kind="constructor",
                name=f"{type_name}() via {_init_owner}.init",
                help_text=(
                    "The inherited initializer belongs to an ancestor that is "
                    "not layout-prefix-compatible with this class, so calling "
                    "it directly would address the wrong field offsets."
                )
            );
            return None;
        }
    }
    if init_fn is not None {
        init_args: list[ir.Value] = [obj_ptr];
        if _is_call and isinstance(nd, uni.FuncCall) {
            init_args.extend(self._codegen_bound_args(nd, init_fn, self_offset=1));
        } else {
            _io_ab = self._init_ability_of(_init_owner);
            _io_ft = (
                _io_ab.name_spec.type
                    if _io_ab is not None and _io_ab.name_spec is not None
                    else None
            );
            _io_params = list(_io_ft.parameters)
                if isinstance(_io_ft, FunctionType)
                else [];
            if _io_params and (_io_params[0].is_self or _io_params[0].is_cls) {
                _io_params = _io_params[1:];
            }
            for _ip in _io_params {
                if _ip.default_value is None {
                    raise AssertionError(
                        f"{type_name}(): constructor parameter '{_ip.name}' has no argument and no default at {nd.loc}"
                    );
                }
                _dv = self._codegen_expr(_ip.default_value);
                if _dv is None {
                    raise AssertionError(
                        f"{type_name}(): default for '{_ip.name}' did not lower at {nd.loc}"
                    );
                }
                init_args.append(_dv);
            }
        }

        coerced_args: list[ir.Value] = [];
        for (i, arg) in enumerate(init_args) {
            if i < len(init_fn.args) {
                coerced_args.append(self._coerce_type(arg, init_fn.args[i].type));
            } else {
                coerced_args.append(arg);
            }
        }
        self.builder.call(init_fn, coerced_args, name="call.init");
    }

    _pi_auto = init_fn is None;
    _init_hit = self._nearest_slot(type_name, ["init", "__init__"]);
    _init_decl_owner = _init_hit[0] if _init_hit is not None else None;
    for _pi_cls in lay.mro {
        if _pi_cls == _init_decl_owner {
            _pi_auto = False;
            break;
        }
        _pi_lay = self._arch_layout(_pi_cls);
        if _pi_lay is None {
            continue;
        }
        _pi_fielded = bool(_pi_lay.statics)
            or any(_pi_f.owner == _pi_cls for _pi_f in _pi_lay.fields);
        if _pi_fielded {
            _pi_auto = True;
            break;
        }
    }
    _pi_owner: (str | None) = None;
    _pi_slot: (str | None) = None;
    if _pi_auto {
        (_pi_owner, _pi_slot, _pi_demoted) = self._slot_function(
            type_name, ["__post_init__", "postinit"]
        );
        if _pi_demoted {
            self.emit(
                E5092,
                node_override=nd,
                kind="constructor",
                name=f"{type_name}() via {_pi_owner}.{_pi_slot}",
                help_text=(
                    "The post-initializer was demoted to its Python "
                    "implementation, so native construction has no "
                    "post-initializer to call and would leave the "
                    "object half-built. Construct this class from a "
                    "Python/@sv context, or make the post-initializer "
                    "lowerable."
                )
            );
            return None;
        }
    }
    if _pi_owner is not None and _pi_slot is not None {
        postinit_fn = self._receiver_routed_method_fn(
            nd, _pi_owner, _pi_slot, type_name
        );
        if postinit_fn is None {
            return None;
        }
        self.builder.call(
            postinit_fn, [self._coerce_type(obj_ptr, postinit_fn.args[0].type)]
        );
    }
    return obj_ptr;
}

impl NaIRGenObjects._unregistered_class_target(target: uni.UniNode) -> (str | None) {
    """The class a `Cls.method(...)` names when the native lane has no `Cls`.

    The native import walk registers a struct type for an imported archetype
    only when it walked that archetype's module; a module it classified
    Python-side (a Python base, a `::py::` body) leaves nothing behind, so the
    class name resolves to no native type at all. That is the same crossing a
    cross-module free-function call makes, and the free-function form refuses
    out loud -- this lookup is what lets the class-qualified form say the same
    thing instead of dropping the call on the floor.

    Only a name that resolves to an archetype declared in *another* Jac module
    answers, so an instance receiver, an enum, and an in-module class that has
    simply not been registered yet all stay out of it.
    """;
    import os;
    name = self._get_name(target);
    if name is None or name in self.struct_types or name in self.local_vars {
        return None;
    }
    sym = target?.sym;
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return None;
    }
    arch = decl.find_parent_of_type(uni.Archetype);
    if arch is None or arch.name is None or arch.name.value != name {
        return None;
    }
    decl_mod = decl.find_parent_of_type(uni.Module);
    path = decl_mod.loc.mod_path if decl_mod?.loc else None;
    if not path or not path.endswith(".jac") {
        return None;
    }
    own_path = os.path.realpath(self.ir_in.loc.mod_path) if self.ir_in?.loc else "";
    if os.path.realpath(path) == own_path {
        return None;
    }
    return name;
}

impl NaIRGenObjects._codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None) {
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }
    target_name = self._get_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if method_name is None {
        return None;
    }
    _recv_nd = trailer.target;
    if isinstance(_recv_nd, uni.AtomTrailer) and _recv_nd.is_attr {
        _recv_owner = self._struct_name_of(_recv_nd.target);
        _recv_fname = self._get_name(_recv_nd.right);
        if (
            _recv_owner is not None
            and _recv_fname is not None
            and self._refuse_opaque_field(_recv_nd, _recv_owner, _recv_fname)
        ) {
            return None;
        }
    }
    _wrap_owner = self._tb_solve(trailer.target.type);
    if (
        method_name == "wrap"
        and self._tb_is_class_ref(_wrap_owner)
        and JAC_TYPE_REGISTRY.is_sized(self._tb_class_name(_wrap_owner) or "")
    ) {
        return self._codegen_sized_wrap(nd, self._tb_class_name(_wrap_owner) or "");
    }
    _is_super = (
        isinstance(trailer.target, uni.SpecialVarRef)
        and trailer.target.name == Tok.KW_SUPER
    )
        or (
            isinstance(trailer.target, uni.FuncCall)
            and isinstance(trailer.target.target, uni.Name)
            and trailer.target.target.value == "super"
            and not trailer.target.params
        );
    if _is_super and self._self_arch is not None {
        _sup_names = [method_name];
        if method_name == "postinit" {
            _sup_names.append("__post_init__");
        } elif method_name == "init" {
            _sup_names.append("__init__");
        }
        _sup_ab = self._member_ability_of(trailer);
        _sup_arch = _sup_ab.method_owner if _sup_ab is not None else None;
        _sup_owner: (str | None) = None;
        if isinstance(_sup_arch, uni.Archetype) and _sup_arch.name is not None {
            _sup_owner = _sup_arch.name.value;
        } else {
            _sup_t = self._flow_narrowed_type_of(trailer.target);
            _sup_owner = (
                self._tb_class_name(_sup_t)
                    if self._tb_kind(_sup_t) == "struct"
                    else None
            );
        }
        _sup_fn_owner: (str | None) = None;
        _sup_slot: (str | None) = None;
        _sup_demoted = False;
        if _sup_owner is not None and _sup_owner in self.struct_types {
            (_sup_fn_owner, _sup_slot, _sup_demoted) = self._slot_function(
                _sup_owner, _sup_names
            );
        }
        if _sup_demoted {
            self.emit(
                E5092,
                node_override=nd,
                kind="call",
                name=f"super.{method_name}",
                help_text=(
                    f"'{_sup_fn_owner}.{_sup_slot}' was demoted to its Python "
                    f"implementation, so the super call has no native body "
                    f"to reach."
                )
            );
            return None;
        }
        _self_slot = self.local_vars.get("self");
        if _sup_fn_owner is not None
            and _sup_slot is not None
            and _self_slot is not None {
            _self_val = self.builder.load(_self_slot, name="super.self");
            return self._emit_class_routed_call(
                nd, _sup_fn_owner, _sup_slot, _self_val, self._self_arch
            );
        }
        if self._pyb_base_of(self._self_arch) is not None {
            _pyb_sup = self._codegen_pyb_super_call(nd, method_name);
            if _pyb_sup is not None {
                return _pyb_sup;
            }
            return None;
        }
        if (
            method_name in ("__repr__", "__str__")
            and _self_slot is not None
            and self._self_arch is not None
            and not (nd.params or [])
        ) {
            return self._emit_default_obj_repr(
                self.builder.load(_self_slot, name="super.self"), self._self_arch
            );
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="call",
            name=f"super.{method_name}",
            help_text=(
                "No MRO ancestor of this class provides a native lowering "
                "of this method, so the super call cannot lower."
            )
        );
        return None;
    }
    _recv_t = self._flow_narrowed_type_of(trailer.target)
        if isinstance(trailer.target, uni.Expr)
        else None;
    _recv_kind = self._tb_kind(_recv_t);
    if method_name == "partition"
        and (
            _recv_kind == "region"
            or (target_name is not None and target_name in self.region_handle_vars)
        ) {
        self._emit_arena_helpers();
        _pt_recv = self._codegen_expr(trailer.target);
        if _pt_recv is None or self.region_partition_fn is None {
            return None;
        }
        _pt_i8p = ir.IntType(8).as_pointer();
        if _pt_recv.type != _pt_i8p {
            _pt_recv = self.builder.bitcast(_pt_recv, _pt_i8p, name="part.hdl");
        }
        return self.builder.call(
            self.region_partition_fn, [_pt_recv], name="region.part"
        );
    }
    _cls_target: (str | None) = None;
    if self._tb_is_class_ref(_recv_t) {
        _cls_target = self._tb_class_name(_recv_t);
    }
    if _cls_target is not None and _cls_target in self.struct_types {
        target_name = _cls_target;
        _mnames = [method_name];
        if method_name == "postinit" {
            _mnames.append("__post_init__");
        } elif method_name == "init" {
            _mnames.append("__init__");
        }
        _cls_ab = self._member_ability_of(trailer);
        if _cls_ab is not None and (_cls_ab.is_static or _cls_ab.is_classmethod) {
            _cls_owner = _cls_ab.method_owner;
            _cls_owner_name = (
                _cls_owner.name.value
                    if isinstance(_cls_owner, uni.Archetype)
                        and _cls_owner.name is not None
                    else target_name
            );
            _sfull = f"{_cls_owner_name}.{method_name}";
            if _sfull in self._native_skipped_methods
                or _sfull not in self.method_funcs {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="method",
                    name=_sfull,
                    help_text=(
                        f"'{method_name}' has no native lowering and was demoted "
                        f"to its Python implementation; it cannot be called from "
                        f"native code. Call it from a Python/@sv context instead."
                    )
                );
                return None;
            }
            return self._emit_class_routed_call(
                nd, _cls_owner_name, method_name, None, None
            );
        }
        (_cr_owner, _cr_slot, _cr_demoted) = self._slot_function(target_name, _mnames);
        if _cr_demoted {
            self.emit(
                E5092,
                node_override=nd,
                kind="method",
                name=f"{_cr_owner}.{_cr_slot}",
                help_text=(
                    f"'{method_name}' has no native lowering and was demoted "
                    f"to its Python implementation; it cannot be called from "
                    f"native code. Call it from a Python/@sv context instead."
                )
            );
            return None;
        }
        if _cr_owner is not None and _cr_slot is not None {
            return self._emit_class_routed_call(nd, _cr_owner, _cr_slot, None, None);
        }
    }

    _xmod_cls = self._unregistered_class_target(trailer.target);
    if _xmod_cls is not None {
        self.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{_xmod_cls}.{method_name}",
            help_text=(
                f"'{_xmod_cls}' is declared in a module the native lane did "
                f"not lower, so it has no native '{method_name}' to call. A "
                f"free function from that module refuses here for the same "
                f"reason. Call it from a Python/@sv context, or move the "
                f"shared code into a module the native lane can lower."
            )
        );
        return None;
    }

    _fld_struct = self._receiver_arch_name(trailer.target);
    _fld_lay = self._arch_layout(_fld_struct) if _fld_struct is not None else None;
    if _fld_lay is not None and method_name in _fld_lay.field_index {
        _fld_info = _fld_lay.fields[_fld_lay.field_index[method_name]];
        _fld_ty = self.struct_field_types.get(_fld_struct, {}).get(method_name);
        if (
            not _fld_info.is_func_ptr
            or not isinstance(_fld_ty, ir.PointerType)
            or not isinstance(_fld_ty.pointee, ir.FunctionType)
        ) {
            self.emit(
                E5092,
                node_override=nd,
                kind="call through field",
                name=f"{_fld_struct}.{method_name}",
                help_text=(
                    f"'{method_name}' is a field of '{_fld_struct}' whose type "
                    f"'{_fld_info.type}' is not a function pointer, so there is "
                    f"nothing native to call through it."
                )
            );
            return None;
        }
        _obj_v = self._codegen_expr(trailer.target);
        if _obj_v is None {
            return None;
        }
        _idx = _fld_lay.field_index[method_name];
        _fld_ptr = self.builder.gep(
            _obj_v,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _idx)],
            name=f"{method_name}.fldptr"
        );
        _fnp = self.builder.load(_fld_ptr, name=f"{method_name}.fn");
        _fn_ty = _fld_ty.pointee;
        _is_clib = _fld_struct in self.clib_struct_names;
        _cargs: list[ir.Value] = [];
        for (_i, _p) in enumerate(nd.params or []) {
            _pv = self._codegen_expr(_p);
            if _pv is not None {
                if _i < len(_fn_ty.args) {
                    _pv = (
                        self._clib_fnptr_arg(_pv, _fn_ty.args[_i])
                            if _is_clib
                            else self._coerce_type(_pv, _fn_ty.args[_i])
                    );
                }
                _cargs.append(_pv);
            }
        }
        _r = self.builder.call(_fnp, _cargs, name=f"icall.{method_name}");
        if isinstance(_fn_ty.return_type, ir.VoidType) {
            return ir.Constant(ir.IntType(64), 0);
        }
        if _is_clib {
            return self._clib_fnptr_ret(_fld_struct, method_name, _r);
        }
        return _r;
    }

    _mod_name = self._module_name_of(trailer.target);
    _mod_root = _mod_name.split(".")[0] if _mod_name else None;
    _stdlib_native = bool(self?._native_stdlib_modules)
        and _mod_root is not None
        and _mod_root in self._native_stdlib_modules;

    if _stdlib_native and _mod_name == "sys" {
        if method_name == "exit" {
            arg_vals = self._codegen_call_args(nd);
            return self._emit_sys_exit(arg_vals);
        }
    }

    if _stdlib_native and _mod_name == "math" {
        _mres = self._emit_math_call(method_name, nd);
        if _mres is not None {
            return _mres;
        }
    }

    if _stdlib_native and _mod_name == "time" and method_name in NATIVE_TIME_FUNCS {
        return self._emit_time_call(method_name, nd);
    }

    if _stdlib_native and _mod_name in ("os.path", "posixpath", "ntpath") {
        if method_name not in NATIVE_OSPATH_FUNCS {
            self.emit(E5092, node_override=nd, kind="os.path member", name=method_name);
            return None;
        }
        return self._emit_ospath_call(method_name, nd);
    }

    if (
        isinstance(trailer.target, uni.AtomTrailer)
        and trailer.target.is_attr
        and self._module_name_of(trailer.target.target) == "os"
        and self._get_name(trailer.target.right) == "environ"
        and self?._native_stdlib_modules
        and "os" in self._native_stdlib_modules
    ) {
        _env_res = self._emit_os_environ_call(method_name, nd);
        if _env_res is not None {
            return _env_res;
        }
    }

    if _stdlib_native and _mod_name == "os" and method_name in NATIVE_OS_FUNCS {
        return self._emit_os_call(method_name, nd);
    }

    if _stdlib_native
        and _mod_name == "random"
        and method_name in NATIVE_RANDOM_FUNCS {
        return self._emit_random_call(method_name, nd);
    }

    if _stdlib_native
        and _mod_name == "struct"
        and method_name in NATIVE_STRUCT_FUNCS {
        return self._emit_struct_call(method_name, nd);
    }

    if _recv_kind == "class" {
        _cls_name = self._tb_class_name(_recv_t);
        if (_cls_name, method_name) in (("int", "from_bytes"), ("float", "fromhex")) {
            return self._dispatch_primitive_method(
                _cls_name,
                method_name,
                None,
                self._codegen_call_args(nd),
                "",
                recv_type=_recv_t,
                call=nd
            );
        }
    }

    _prim_t = self._tb_opt_payload(_recv_t) if _recv_kind == "optional" else _recv_t;
    _prim_kind = self._tb_kind(_prim_t);
    if _prim_kind == "tuple" and self._tuple_has_variadic_arg(self._tb_args(_prim_t)) {
        _prim_kind = "list";
    }
    _prim_emitter: (str | None) = None;
    if _prim_kind
        in (
            "int",
            "bool",
            "float",
            "complex",
            "str",
            "bytes",
            "list",
            "dict",
            "tuple",
            "range"
        ) {
        _prim_emitter = _prim_kind;
    } elif _prim_kind == "set" {
        _prim_emitter = (
            "frozenset" if self._tb_class_name(_prim_t) == "frozenset" else "set"
        );
    } elif _prim_kind == "bytearray" {
        if method_name in ("append", "extend") {
            _ba_recv = self._codegen_receiver(trailer.target);
            if _ba_recv is None {
                return None;
            }
            _ba_res = self._dispatch_bytearray_method(method_name, _ba_recv, nd);
            if _ba_res is None {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="method",
                    name=f"bytearray.{method_name}",
                    help_text=(
                        "The argument is not a byte value or byte source the "
                        "native bytearray helpers accept."
                    )
                );
            }
            return _ba_res;
        }
        _prim_emitter = "list";
    }
    if _prim_emitter is not None {
        _prim_key: (str | None) = "";
        if _prim_emitter == "list" {
            _prim_key = self._list_spec_for_expr(trailer.target);
        } elif _prim_emitter == "dict" {
            _prim_key = self._dict_spec_for_expr(trailer.target);
        } elif _prim_emitter in ("set", "frozenset") {
            _prim_key = self._set_spec_for_expr(trailer.target);
        } elif _prim_emitter == "tuple" {
            _prim_key = self._tuple_key_of(trailer.target);
        }
        if _prim_key is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="method",
                name=f"{_prim_kind}.{method_name}",
                help_text=(
                    "The receiver's element type did not resolve to one native "
                    "container layout, so there is no helper set to lower the "
                    "method against. Annotate the receiver with a concrete "
                    "element type."
                )
            );
            return None;
        }
        recv_val = self._codegen_receiver(trailer.target);
        if recv_val is None {
            return None;
        }
        _want = self._lower_type(_prim_t);
        if (
            _want is not None
            and recv_val.type != _want
            and self._opt_payload_of(recv_val.type) is not None
        ) {
            recv_val = self._coerce_type(recv_val, _want);
        }
        arg_vals = self._codegen_call_args(nd);
        _orig_args = list(arg_vals);
        _prep_idx = -1;
        if (
            method_name in ("append", "add")
            and arg_vals
            and _prim_emitter in ("list", "set")
        ) {
            _prep_idx = 0;
        } elif method_name == "insert"
            and len(arg_vals) > 1
            and _prim_emitter == "list" {
            _prep_idx = 1;
        }
        if _prep_idx >= 0 {
            _prep_params = list(nd.params or []);
            if _prep_idx < len(_prep_params) {
                _prep_e = _prep_params[_prep_idx];
                _prep_e = _prep_e.value if isinstance(_prep_e, uni.KWPair) else _prep_e;
                arg_vals[_prep_idx] = self._nogc_elem_prep(
                    _prep_e, arg_vals[_prep_idx]
                );
            }
            if _prim_emitter == "list" {
                _elem_struct = self.var_list_elem_struct.get(target_name);
                if (
                    _elem_struct is not None
                    and isinstance(_elem_struct, ir.PointerType)
                    and isinstance(_elem_struct.pointee, ir.LiteralStructType)
                ) {
                    arg_vals[_prep_idx] = self._coerce_tuple_to_struct(
                        arg_vals[_prep_idx],
                        _elem_struct.pointee,
                        src_ty=self._expr_type_of(_prep_e)
                    );
                }
            }
        }
        if _prim_emitter == "list" and method_name == "append" {
            self._set_rc_ctx(
                "append",
                f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                    if nd.loc
                    else 0}"
            );
        }
        result = self._dispatch_primitive_method(
            _prim_emitter,
            method_name,
            recv_val,
            arg_vals,
            _prim_key,
            recv_type=_prim_t,
            call=nd
        );
        if _prim_emitter == "list" and method_name == "append" {
            self._clear_rc_ctx();
        }
        if result is not None and _prim_emitter == "list" and method_name == "insert" {
            self._release_owned_args(_orig_args, op="list_method_arg");
        }
        return result;
    }

    type_name: (str | None) = self._receiver_arch_name(trailer.target);
    obj_val: (ir.Value | None) = None;
    if type_name is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{self._tb_class_name(_recv_t) or _recv_kind}.{method_name}",
            help_text=(
                "The receiver of this method call has no native representation, "
                "so the call cannot lower."
            )
        );
        return None;
    }

    func = self._resolve_method(type_name, method_name);
    _is_mono_method = False;
    if func is None {
        _gm_owner: (str | None) = None;
        _gm_hit = self._nearest_slot(type_name, [method_name]);
        _gm_cands = [type_name];
        if _gm_hit is not None and _gm_hit[0] != type_name {
            _gm_cands.append(_gm_hit[0]);
        }
        for _gm_cur in _gm_cands {
            if f"{_gm_cur}.{method_name}" in self._generic_methods {
                _gm_owner = _gm_cur;
                break;
            }
        }
        if _gm_owner is not None {
            _gm_errs = len(self.errors_had);
            func = self._instantiate_generic_method(nd, _gm_owner, method_name);
            if func is None {
                if len(self.errors_had) == _gm_errs {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="method",
                        name=f"{_gm_owner}.{method_name}"
                    );
                }
                return None;
            }
            _is_mono_method = True;
        }
    }
    _demoted = False;
    if func is None {
        if f"{type_name}.{method_name}" in self._native_skipped_methods {
            _demoted = True;
        } else {
            _owner = self._resolve_method_owner(type_name, method_name);
            if _owner is not None
                and f"{_owner}.{method_name}" in self._native_skipped_methods {
                _demoted = True;
            }
        }
    }
    if func is None {
        if _demoted {
            self.emit(
                E5092,
                node_override=nd,
                kind="method",
                name=f"{type_name}.{method_name}",
                help_text=(
                    f"'{method_name}' has no native lowering and was demoted to "
                    f"its Python implementation; it cannot be called from native "
                    f"code. Call it from a Python/@sv context instead."
                )
            );
            return None;
        }
        if self._pyb_base_of(type_name) is not None {
            return self._codegen_pyb_method_call(nd, type_name, method_name);
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{type_name}.{method_name}",
            help_text="This method has no native lowering on its receiver type."
        );
        return None;
    }

    if obj_val is None {
        obj_val = self._codegen_receiver(trailer.target);
    }
    if obj_val is None {
        return None;
    }
    obj_val = self._opt_unwrap_attr(obj_val);

    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.method.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
    }

    args: list[ir.Value] = [obj_val]
        + self._codegen_bound_args(nd, func, self_offset=1);

    if self._arch_has_vtable(type_name) and not _is_mono_method {
        result = self._codegen_virtual_call(
            obj_val, method_name, args, type_name, ret_tb=self._expr_type_of(nd)
        );
        if result is not None {
            if isinstance(func.return_value.type, ir.VoidType) {
                return ir.Constant(ir.IntType(64), 0);
            }

            return result;
        }
    }

    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    result = self.builder.call(func, coerced, name=f"call.{method_name}");

    self._release_owned_args(coerced, op="call_arg");

    if isinstance(func.return_value.type, ir.VoidType) {
        return ir.Constant(ir.IntType(64), 0);
    }

    return result;
}

impl NaIRGenObjects._emit_obj_str(val: ir.Value) -> (ir.Value | None) {
    type_name = self._struct_ptr_pointee_name(val);
    if type_name is None {
        return None;
    }

    func = self._resolve_method(type_name, "__str__");

    i8p = ir.IntType(8).as_pointer();
    is_null = self.builder.icmp_unsigned(
        "==", val, ir.Constant(val.type, None), name="objstr.isnull"
    );
    fn = self.builder.basic_block.function;
    null_bb = fn.append_basic_block(name="objstr.null");
    live_bb = fn.append_basic_block(name="objstr.live");
    cont_bb = fn.append_basic_block(name="objstr.cont");
    self.builder.cbranch(is_null, null_bb, live_bb);

    self.builder.position_at_end(null_bb);
    none_s = self._make_global_string("None", name_prefix=".objstr.none");
    null_end = self.builder.basic_block;
    self.builder.branch(cont_bb);

    self.builder.position_at_end(live_bb);
    if func is None {
        live_res = self._emit_default_obj_repr(val, type_name);
    } else {
        was_owned = self._is_owned(val);
        if was_owned {
            val.is_owned = False;
        }
        result = None;
        if self._arch_has_vtable(type_name) {
            result = self._codegen_virtual_call(
                val,
                "__str__",
                [val],
                type_name,
                ret_tb=convert_to_instance(self._tb_builtin("str"))
            );
        }
        if result is None {
            coerced = [self._coerce_type(val, func.args[0].type)];
            result = self.builder.call(func, coerced, name="call.__str__");
        }
        if was_owned {
            val.is_owned = True;
        }
        live_res = result;
    }
    live_res = self._coerce_type(live_res, i8p);
    live_end = self.builder.basic_block;
    self.builder.branch(cont_bb);

    self.builder.position_at_end(cont_bb);
    phi = self.builder.phi(i8p, name="objstr.result");
    phi.add_incoming(none_s, null_end);
    phi.add_incoming(live_res, live_end);

    return self._mark_owned(phi);
}

impl NaIRGenObjects._emit_default_obj_repr(val: ir.Value, type_name: str) -> ir.Value {
    b = self.builder;
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);

    buf_len = len(type_name) + 48;
    buf = self._rc_call_with_ctx(
        self.rc_alloc_fn,
        [ir.Constant(i64, buf_len)],
        op="obj_repr",
        loc="",
        name="obj.repr.buf"
    );
    self._emit_set_type_tag(b, buf, "str");
    snprintf = self._get_or_declare_extern(
        "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
    );
    fmt = self._make_global_string(
        "<%s object at 0x%llx>", name_prefix=".obj.repr.fmt"
    );
    name_g = self._make_global_string(type_name, name_prefix=".obj.repr.name");
    addr = b.ptrtoint(val, i64, name="obj.repr.addr");
    b.call(
        snprintf,
        [buf, ir.Constant(i64, buf_len), fmt, name_g, addr],
        name="obj.repr.snprintf"
    );
    return self._mark_owned(buf);
}

impl NaIRGenObjects._opt_unwrap_attr(obj_val: ir.Value) -> ir.Value {
    _ua_opt = self._opt_payload_of(obj_val.type);
    if _ua_opt is None {
        return obj_val;
    }
    _ua_tag = self.builder.extract_value(obj_val, 0, name="attr.opt.tag");
    _ua_none = self.builder.icmp_signed(
        "==", _ua_tag, ir.Constant(ir.IntType(8), 0), name="attr.opt.none"
    );
    self._emit_runtime_raise(
        _ua_none, "AttributeError", "'NoneType' object has no attribute"
    );
    return self.builder.extract_value(obj_val, 1, name="attr.opt.val");
}

impl NaIRGenObjects._opt_unwrap_guarded(
    val: (ir.Value | None), what: str, msg: str
) -> (ir.Value | None) {
    """Payload of an optional container, guarded by the absence CPython raises on.

    `has parts: (list[Item] | None)` lowers to a `JacOpt` -- a presence tag
    beside the container pointer -- so a loop, comprehension or slice reading
    the slot receives the wrapper, not a list. Handing that wrapper to the
    container helpers is what used to raise `Type of #1 arg mismatch` out of
    the builder and cost the whole function an ICE. Unwrapping here restores
    the container the rest of the lowering expects; the `None` arm raises
    rather than reading a null, so the two pathways agree on the absent case
    as well as the present one.
    """;
    if val is None {
        return None;
    }
    if self._opt_payload_of(val.type) is None {
        return val;
    }
    _uw_tag = self.builder.extract_value(val, 0, name=f"{what}.opt.tag");
    _uw_none = self.builder.icmp_signed(
        "==", _uw_tag, ir.Constant(ir.IntType(8), 0), name=f"{what}.opt.none"
    );
    self._emit_runtime_raise(_uw_none, "TypeError", msg);
    return self.builder.extract_value(val, 1, name=f"{what}.opt.val");
}

impl NaIRGenObjects._opt_unwrap_iterable(
    coll_val: (ir.Value | None)
) -> (ir.Value | None) {
    return self._opt_unwrap_guarded(
        coll_val, "iter", "'NoneType' object is not iterable"
    );
}

impl NaIRGenObjects._opt_unwrap_subscript(val: (ir.Value | None)) -> (ir.Value | None) {
    return self._opt_unwrap_guarded(
        val, "sub", "'NoneType' object is not subscriptable"
    );
}

impl NaIRGenObjects._accessor_slot_of(
    type_name: str, field_name: str, kind: str, member: (uni.UniNode | None) = None
) -> (str | None) {
    _slot = f"{field_name}.{ACCESSOR_SLOT_SUFFIX[kind]}";
    _hv = self._member_field_of(member);
    if _hv is not None {
        _has_kind = False;
        for _acc in (_hv.accessors or []) {
            if _acc.accessor_kind == kind {
                _has_kind = True;
            }
        }
        if not _has_kind {
            return None;
        }
    }
    _lay = self._arch_layout(type_name);
    if _lay is not None and _slot in _lay.method_index {
        return _slot;
    }
    return _slot if self._resolve_method(type_name, _slot) is not None else None;
}

impl NaIRGenObjects._codegen_accessor_call(
    obj_val: ir.Value,
    type_name: str,
    slot: str,
    args: list[ir.Value],
    ret_tb: any = None
) -> (ir.Value | None) {
    func = self._resolve_method(type_name, slot);
    if func is None {
        return None;
    }
    _all_args: list[ir.Value] = [obj_val] + args;
    if self._arch_has_vtable(type_name) {
        result = self._codegen_virtual_call(
            obj_val, slot, _all_args, type_name, ret_tb=ret_tb
        );
        if result is not None {
            return result;
        }
    }
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(_all_args) {
        coerced.append(
            self._coerce_type(arg, func.args[i].type) if i < len(func.args) else arg
        );
    }
    return self.builder.call(func, coerced, name=f"acc.{slot}");
}

impl NaIRGenObjects._receiver_union_parts(
    nd: (uni.UniNode | None)
) -> (list[str] | None) {
    if not isinstance(nd, uni.AtomTrailer) {
        return None;
    }
    return self._expr_struct_parts(nd.target);
}

impl NaIRGenObjects._expr_struct_parts(
    expr: (uni.UniNode | None)
) -> (list[str] | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    _rt = self._flow_narrowed_type_of(expr);
    if len(self._tb_non_none(_rt)) < 2 {
        return None;
    }
    _rp: list[str] = [];
    for _m in self._tb_non_none(_rt) {
        _nm = self._tb_class_name(_m) if self._tb_kind(_m) == "struct" else None;
        if _nm is not None and _nm in self.struct_types and _nm not in _rp {
            _rp.append(_nm);
        }
    }
    return _rp if len(_rp) >= 2 else None;
}

impl NaIRGenObjects._emit_dispatched_field_ptr(
    obj_val: ir.Value,
    type_name: str,
    field_name: str,
    ftype: (ir.Type | None),
    parts: (list[str] | None) = None
) -> (ir.Value | None) {
    reg = self._registry();
    _base_lay = reg.get_layout(type_name);
    if _base_lay is None {
        return None;
    }
    _base_has_vt = _base_lay.has_vtable;
    _vt_root: str = type_name;
    if not _base_has_vt {
        if not parts {
            return None;
        }
        for _part in parts {
            _plt = reg.get_layout(_part);
            if _plt is None or not _plt.has_vtable or _part not in self.struct_types {
                return None;
            }
        }
        _vt_root = parts[0];
    }
    _base_idx = _base_lay.field_index.get(field_name) if _base_has_vt else None;
    if _base_has_vt and _base_idx is None and ftype is not None {
        return None;
    }
    _cands: list[str] = [];
    for _root in (parts or [type_name]) {
        if _root not in _cands {
            _cands.append(_root);
        }
        for _kid in (reg.subclasses.get(_root) or []) {
            if _kid not in _cands {
                _cands.append(_kid);
            }
        }
    }
    _variants: list[tuple] = [];
    _uniform = True;
    for _cls in _cands {
        _lay = reg.get_layout(_cls);
        if _lay is None or _cls not in self.struct_types {
            continue;
        }
        _ci = _lay.field_index.get(field_name);
        if _ci is None {
            continue;
        }
        _vt = self._vtable_global_for(_cls) if _lay.has_vtable else None;
        if _vt is None {
            continue;
        }
        _cls_elems = self.struct_types[_cls].elements;
        if _ci >= len(_cls_elems) {
            continue;
        }
        if ftype is None {
            if field_name in self.struct_field_inline.get(_cls, set()) {
                return None;
            }
            _vf = _cls_elems[_ci];
            if _variants and _vf != _variants[0][3] {
                return None;
            }
            _variants.append((_cls, _vt, _ci, _vf));
        } else {
            _variants.append((_cls, _vt, _ci, ftype));
        }
        if _base_idx is None or _ci != _base_idx {
            _uniform = False;
        }
    }
    if ftype is None {
        if not _variants {
            return None;
        }
        ftype = _variants[0][3];
    }
    if _uniform or not _variants {
        return None;
    }
    i32 = ir.IntType(32);
    _fp_t = ftype.as_pointer();
    b = self.builder;
    _df_vt_recv = obj_val;
    if _vt_root != type_name {
        _df_vt_recv = b.bitcast(
            obj_val, self.struct_types[_vt_root].as_pointer(), name="df.vt.root"
        );
    }
    _df_vpp = b.gep(
        _df_vt_recv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="df.vt.pp"
    );
    _df_vtp = b.load(_df_vpp, name="df.vt");
    _df_fnc = b.block.function;
    _df_done = _df_fnc.append_basic_block(name=f"df.{field_name}.done");
    _df_incoming: list[tuple] = [];
    for (_vc, _vt, _ci, _vft) in _variants {
        _df_hit = _df_fnc.append_basic_block(name=f"df.{field_name}.{_vc}");
        _df_nxt = _df_fnc.append_basic_block(name=f"df.{field_name}.n.{_vc}");
        _df_eq = b.icmp_unsigned(
            "==",
            _df_vtp,
            b.bitcast(_vt, _df_vtp.type, name="df.cand"),
            name=f"df.eq.{_vc}"
        );
        b.cbranch(_df_eq, _df_hit, _df_nxt);
        b.position_at_end(_df_hit);
        _df_typed = b.bitcast(
            obj_val, self.struct_types[_vc].as_pointer(), name=f"df.self.{_vc}"
        );
        _df_p = b.gep(
            _df_typed, [ir.Constant(i32, 0), ir.Constant(i32, _ci)], name=f"df.p.{_vc}"
        );
        _df_pc = b.bitcast(_df_p, _fp_t, name=f"df.pc.{_vc}");
        _df_incoming.append((_df_pc, b.block));
        b.branch(_df_done);
        b.position_at_end(_df_nxt);
    }

    if _base_idx is not None {
        _df_fb_recv = obj_val;
        if type_name in self.struct_types {
            _df_fb_recv = b.bitcast(
                obj_val, self.struct_types[type_name].as_pointer(), name="df.self.fb"
            );
        }
        _df_fb = b.gep(
            _df_fb_recv,
            [ir.Constant(i32, 0), ir.Constant(i32, _base_idx)],
            name="df.p.fb"
        );
        _df_fbc = b.bitcast(_df_fb, _fp_t, name="df.pc.fb");
        _df_incoming.append((_df_fbc, b.block));
    } else {
        self._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1),
            "AttributeError",
            f"object has no attribute '{field_name}'"
        );
        _df_incoming.append((ir.Constant(_fp_t, None), b.block));
    }
    b.branch(_df_done);
    b.position_at_end(_df_done);
    _df_phi = b.phi(_fp_t, name=f"df.{field_name}.ptr");
    for (_pv, _pb) in _df_incoming {
        _df_phi.add_incoming(_pv, _pb);
    }
    return _df_phi;
}

impl NaIRGenObjects._refuse_unshared_union_slot(
    nd: (uni.UniNode | None),
    type_name: str,
    field_name: str,
    idx: int,
    parts: (list[str] | None)
) -> bool {
    if not parts or self._arch_has_vtable(type_name) {
        return False;
    }
    _off: list[str] = [];
    for _part in parts {
        _plt = self._arch_layout(_part);
        if _plt is None or _plt.field_index.get(field_name) != idx {
            _off.append(_part);
        }
    }
    if not _off {
        return False;
    }
    self.emit(
        E5092,
        node_override=nd,
        kind="inherited field access",
        name=field_name,
        help_text=(
            f"'{field_name}' is read through '{type_name}', whose slot for it "
            f"is not shared by every narrowed member: {', '.join(_off)} lay it "
            f"out elsewhere or not at all, and '{type_name}' carries no vtable "
            f"to tell the members apart at runtime. Read it through a "
            f"single-class value, or move this code to a @sv/Python context."
        )
    );
    return True;
}

impl NaIRGenObjects._narrow_receiver_ptr(
    obj_val: ir.Value, type_name: str
) -> (ir.Value | None) {
    obj_val = self._opt_unwrap_attr(obj_val);

    if (
        self?.jacval_type
        and obj_val.type == self.jacval_type
        and type_name in self.struct_types
    ) {
        obj_val = self._unbox_from_jacval(
            obj_val, self.struct_types[type_name].as_pointer()
        );
    }
    if isinstance(obj_val.type, ir.IntType) and (type_name in self.struct_types) {
        obj_val = self.builder.inttoptr(
            obj_val, self.struct_types[type_name].as_pointer(), name="osp.handle.ptr"
        );
    }

    target_struct = self.struct_types.get(type_name);
    if target_struct is not None
        and isinstance(obj_val.type, ir.PointerType)
        and obj_val.type.pointee is not target_struct {
        obj_val = self.builder.bitcast(
            obj_val, target_struct.as_pointer(), name=f"narrow.{type_name}"
        );
    }

    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.field.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
        return obj_val;
    }
    return None;
}

impl NaIRGenObjects._class_const_global(
    arch_name: str, field_name: str
) -> (ir.GlobalVariable | None) {
    lay = self._arch_layout(arch_name);
    for _cn in (lay.mro if lay is not None else [arch_name]) {
        _clay = self._arch_layout(_cn);
        if _clay is None {
            continue;
        }
        _declares = any(s.name == field_name for s in _clay.statics)
            or any(c.name == field_name for c in _clay.class_consts);
        if _declares {
            return self.static_fields.get(f"{_cn}.{field_name}");
        }
    }
    return None;
}

impl NaIRGenObjects._class_const_variants(arch_name: str, field_name: str) -> tuple {
    reg = self._registry();
    out: list[tuple] = [];
    _whole = True;
    for _cls in (reg.subclasses.get(arch_name) or []) {
        _gv = self._class_const_global(_cls, field_name);
        if _gv is None {
            continue;
        }
        _vt = self._vtable_global_for(_cls);
        if _vt is None {
            _whole = False;
            continue;
        }
        out.append((_cls, _vt, _gv));
    }
    return (out, _whole, );
}

impl NaIRGenObjects._codegen_class_const_read(
    obj_val: ir.Value, type_name: str, field_name: str
) -> (ir.Value | None) {
    _own = self._class_const_global(type_name, field_name);
    (_variants, _whole) = self._class_const_variants(type_name, field_name);
    if not _whole or (_own is None and not _variants) {
        return None;
    }
    _ty = _own.type.pointee if _own is not None else _variants[0][2].type.pointee;
    _uniform = True;
    for (_vc, _vt, _gv) in _variants {
        if _gv.type.pointee != _ty {
            return None;
        }
        if _gv is not _own {
            _uniform = False;
        }
    }
    if _uniform and _own is not None {
        return self.builder.load(_own, name=f"cconst.{field_name}");
    }
    if not self._arch_has_vtable(type_name) {
        return None;
    }
    _recv = self._narrow_receiver_ptr(obj_val, type_name);
    if _recv is None {
        return None;
    }

    i32 = ir.IntType(32);
    b = self.builder;
    _cc_vpp = b.gep(_recv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="cc.vt.pp");
    _cc_vtp = b.load(_cc_vpp, name="cc.vt");
    _cc_fn = b.block.function;
    _cc_done = _cc_fn.append_basic_block(name=f"cc.{field_name}.done");
    _cc_incoming: list[tuple] = [];
    for (_vc, _vt, _gv) in _variants {
        _cc_hit = _cc_fn.append_basic_block(name=f"cc.{field_name}.{_vc}");
        _cc_nxt = _cc_fn.append_basic_block(name=f"cc.{field_name}.n.{_vc}");
        _cc_eq = b.icmp_unsigned(
            "==",
            _cc_vtp,
            b.bitcast(_vt, _cc_vtp.type, name="cc.cand"),
            name=f"cc.eq.{_vc}"
        );
        b.cbranch(_cc_eq, _cc_hit, _cc_nxt);
        b.position_at_end(_cc_hit);
        _cc_incoming.append((b.load(_gv, name=f"cc.{field_name}.{_vc}.v"), b.block));
        b.branch(_cc_done);
        b.position_at_end(_cc_nxt);
    }
    if _own is not None {
        _cc_incoming.append((b.load(_own, name=f"cc.{field_name}.fb"), b.block));
    } else {
        self._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1),
            "AttributeError",
            f"class has no attribute '{field_name}'"
        );
        _cc_incoming.append((self._zero_const(_ty), b.block));
    }
    b.branch(_cc_done);
    b.position_at_end(_cc_done);
    _cc_phi = b.phi(_ty, name=f"cc.{field_name}");
    for (_pv, _pb) in _cc_incoming {
        _cc_phi.add_incoming(_pv, _pb);
    }
    return _cc_phi;
}

impl NaIRGenObjects._codegen_field_access(
    obj_val: ir.Value, field_name: str, type_name: str, nd: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    lay = self._arch_layout(type_name);
    field_indices = lay.field_index if lay is not None else None;
    _getter = self._accessor_slot_of(type_name, field_name, "property", member=nd);
    if _getter is None and (field_indices is None or field_name not in field_indices) {
        _uf_recv = self._narrow_receiver_ptr(obj_val, type_name);
        if _uf_recv is not None {
            _uf_ptr = self._emit_dispatched_field_ptr(
                _uf_recv,
                type_name,
                field_name,
                None,
                parts=self._receiver_union_parts(nd)
            );
            if _uf_ptr is not None {
                return self.builder.load(_uf_ptr, name=f"field.{field_name}");
            }
        }
        return None;
    }
    if _getter is None and self._refuse_opaque_field(nd, type_name, field_name) {
        return None;
    }
    _recv = self._narrow_receiver_ptr(obj_val, type_name);
    if _recv is None {
        return None;
    }
    obj_val = _recv;
    if _getter is not None {
        return self._codegen_accessor_call(
            obj_val, type_name, _getter, [], ret_tb=self._expr_type_of(nd)
        );
    }
    idx = field_indices[field_name];
    field_ptr: (ir.Value | None) = None;
    _fa_struct_t = self.struct_types.get(type_name);
    _fa_parts = self._receiver_union_parts(nd);
    if (
        _fa_struct_t is not None
        and idx < len(_fa_struct_t.elements)
        and field_name not in self.struct_field_inline.get(type_name, set())
    ) {
        field_ptr = self._emit_dispatched_field_ptr(
            obj_val, type_name, field_name, _fa_struct_t.elements[idx], parts=_fa_parts
        );
    }
    if field_ptr is None
        and self._refuse_unshared_union_slot(
            nd, type_name, field_name, idx, _fa_parts
        ) {
        return None;
    }
    if field_ptr is None {
        field_ptr = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
    }
    if field_name in self.struct_field_inline.get(type_name, set()) {
        return field_ptr;
    }
    return self.builder.load(field_ptr, name=f"field.{field_name}");
}

impl NaIRGenObjects._hasvar_is_own(var: uni.UniNode) -> bool {
    sym = var.sym if isinstance(var, uni.AstSymbolNode) else None;
    if sym is not None and sym.ownership == OwnershipKind.OWN {
        return True;
    }
    _tt = var?.type_tag;
    if _tt is None {
        return False;
    }
    if _tt.ownership == OwnershipKind.OWN {
        return True;
    }
    _inner = _tt.tag;
    return isinstance(_inner, uni.UnaryExpr) and _inner.ownership == OwnershipKind.OWN;
}

impl NaIRGenObjects._store_inline_field(
    type_name: str,
    fname: str,
    field_ptr: ir.Value,
    value: (ir.Value | None),
    drop_old: bool
) -> None {
    i8p = ir.IntType(8).as_pointer();
    _ftype = self.struct_field_types.get(type_name, {}).get(fname);
    _pname = getattr(_ftype, "name", "") or "";
    if drop_old and _pname {
        _dropf = self._emit_struct_drop_fields_fn(_pname);
        if _dropf is not None {
            self.builder.call(
                _dropf, [self.builder.bitcast(field_ptr, i8p, name=f"inl.{fname}.old")]
            );
        }
    }
    if value is None {
        return;
    }
    if isinstance(value.type, ir.PointerType) {
        _src = self.builder.load(value, name=f"inl.{fname}.src");
        self.builder.store(_src, field_ptr);
        _free = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        self.builder.call(
            _free, [self.builder.bitcast(value, i8p, name=f"inl.{fname}.shell")]
        );
    } else {
        self.builder.store(value, field_ptr);
    }
}

impl NaIRGenObjects._codegen_field_aug_assign(
    target: uni.AtomTrailer,
    rhs: ir.Value,
    aug_op: str,
    rhs_node: (uni.Expr | None) = None
) -> (ir.Value | None) {
    field_name = self._get_name(target.right);
    if field_name is None {
        return None;
    }
    type_name = self._receiver_arch_name(target.target);
    if type_name is None {
        return None;
    }
    obj_val = self._codegen_expr(target.target);
    if obj_val is None {
        return None;
    }

    current = self._read_field_or_refuse(target, obj_val, field_name, type_name);
    if current is None {
        return None;
    }

    scalar = self._apply_scalar_aug_op(
        current, rhs, aug_op, rhs_node, cur_ty=self._expr_type_of(target)
    );
    if scalar is not None {
        return scalar;
    }

    coerced = self._coerce_type(rhs, current.type);

    if aug_op == "+=" and isinstance(current.type, ir.PointerType) {
        _fa_lay = self._arch_layout(type_name);
        _fld_tb = (
            _fa_lay.fields[_fa_lay.field_index[field_name]].type
                if _fa_lay is not None and field_name in _fa_lay.field_index
                else self._flow_narrowed_type_of(target)
        );
        _rhs_tb = (
            self._flow_narrowed_type_of(rhs_node) if rhs_node is not None else _fld_tb
        );
        _asgn = target.find_parent_of_type(uni.Assignment);
        result = self._emit_binary_op(
            Tok.PLUS,
            current,
            coerced,
            _fld_tb,
            _rhs_tb,
            resolved=(_asgn.resolved_op if _asgn is not None else None)
        );
        return result if result is not None else current;
    }

    return coerced;
}

impl NaIRGenObjects._codegen_field_assign(
    target: uni.AtomTrailer,
    value: ir.Value,
    skip_narrow_coerce: bool = False,
    value_ty: any = None
) -> None {
    _fa_errs = len(self.errors_had);
    field_name = self._get_name(target.right);
    _recv_t = self._flow_narrowed_type_of(target.target);
    if self._tb_is_class_ref(_recv_t) and field_name is not None {
        _sa_target = self._tb_class_name(_recv_t);
        if _sa_target is not None and _sa_target in self.struct_types {
            _sa_gv = self._class_const_global(_sa_target, field_name);
            if _sa_gv is not None {
                _sa_val = self._coerce_type(value, _sa_gv.type.pointee);
                self.builder.store(_sa_val, _sa_gv);
                return;
            }
        }
    }
    obj_val = self._codegen_expr(target.target);
    if obj_val is not None {
        obj_val = self._opt_unwrap_attr(obj_val);
    }
    type_name: (str | None) = self._receiver_arch_name(target.target);
    if (
        obj_val is not None
        and self?.jacval_type
        and obj_val.type == self.jacval_type
        and type_name is not None
        and type_name in self.struct_types
    ) {
        obj_val = self._unbox_from_jacval(
            obj_val, self.struct_types[type_name].as_pointer()
        );
    }
    lay = self._arch_layout(type_name) if type_name is not None else None;
    field_indices = lay.field_index if lay is not None else None;
    _setter = self._accessor_slot_of(type_name, field_name, "setter", member=target)
        if (type_name is not None and field_name is not None)
        else None;
    if (
        field_name is None
        or obj_val is None
        or type_name is None
        or (
            _setter is None
            and (field_indices is None or field_name not in field_indices)
        )
    ) {
        if (
            field_name is not None
            and obj_val is not None
            and type_name is not None
            and _setter is None
            and self._pyb_base_of(type_name) is not None
        ) {
            self._codegen_pyb_field_assign(target, value, obj_val);
            return;
        }
        if len(self.errors_had) == _fa_errs {
            self.emit(
                E5092,
                node_override=target,
                kind="field assignment",
                name=(field_name or "<field>")
            );
        }
        return;
    }

    if _setter is None and self._refuse_opaque_field(target, type_name, field_name) {
        return;
    }

    if _setter is not None {
        _fs_struct = self.struct_types.get(type_name);
        if _fs_struct is not None
            and isinstance(obj_val.type, ir.PointerType)
            and obj_val.type.pointee != _fs_struct {
            obj_val = self.builder.bitcast(
                obj_val, _fs_struct.as_pointer(), name="acc.recv.cast"
            );
        }
        if self._codegen_accessor_call(obj_val, type_name, _setter, [value]) is None {
            self.emit(
                E5092,
                node_override=target,
                kind="field assignment",
                name=field_name,
                help_text=f"'{type_name}.{field_name}' is a property whose "
                f"setter has no native lowering."
            );
        }
        return;
    }
    field_types = self.struct_field_types.get(type_name);
    idx = field_indices[field_name];
    ftype = field_types[field_name];

    _fa_struct = self.struct_types.get(type_name);
    if (
        _fa_struct is not None
        and isinstance(obj_val.type, ir.PointerType)
        and obj_val.type.pointee != _fa_struct
    ) {
        obj_val = self.builder.bitcast(
            obj_val, _fa_struct.as_pointer(), name="fa.recv.cast"
        );
    }

    _slot_struct = self.struct_types.get(type_name);
    _slot_elems = _slot_struct?.elements if _slot_struct is not None else None;
    if _slot_elems is not None
        and idx < len(_slot_elems)
        and _slot_elems[idx] != ftype {
        ftype = _slot_elems[idx];
    }

    if field_name in self.struct_field_inline.get(type_name, set()) {
        _inl_fp = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
        self._store_inline_field(type_name, field_name, _inl_fp, value, True);
        return;
    }

    _vt_struct = type_name in self.clib_vtable_structs;
    _is_clib_cb = (
        _vt_struct
        and isinstance(ftype, ir.PointerType)
        and isinstance(ftype.pointee, ir.FunctionType)
    );
    if _is_clib_cb {
        value = self._clib_coerce_callback(value, ftype);
    } elif not (skip_narrow_coerce and value.type != ftype) {
        value = self._coerce_typed(value, ftype, value_ty);
    }
    field_ptr: (ir.Value | None) = None;
    _fs_parts = self._receiver_union_parts(target);
    if not _vt_struct {
        field_ptr = self._emit_dispatched_field_ptr(
            obj_val, type_name, field_name, ftype, parts=_fs_parts
        );
    }
    if field_ptr is None
        and self._refuse_unshared_union_slot(
            target, type_name, field_name, idx, _fs_parts
        ) {
        return;
    }
    if field_ptr is None {
        field_ptr = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
    }

    if isinstance(ftype, ir.PointerType) and not _vt_struct {
        self._emit_take_ref(
            value,
            op="field_set",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{target.loc.first_line
                if target.loc
                else 0}"
        );
        old_field_val = self.builder.load(field_ptr, name=f"field.{field_name}.old");
        self._emit_rc_release_simple(
            old_field_val,
            op="field_set",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{target.loc.first_line
                if target.loc
                else 0}"
        );
    }
    _fs_opt = self._opt_payload_of(ftype);
    if _fs_opt is not None and isinstance(_fs_opt, ir.PointerType) and not _vt_struct {
        _fs_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{target.loc.first_line
            if target.loc
            else 0}";
        _fs_new_pv = self.builder.extract_value(
            value, 1, name=f"field.{field_name}.newpv"
        );
        self._emit_take_ref(_fs_new_pv, op="field_set", loc=_fs_loc);
        _fs_old = self.builder.load(field_ptr, name=f"field.{field_name}.old");
        _fs_old_pv = self.builder.extract_value(
            _fs_old, 1, name=f"field.{field_name}.oldpv"
        );
        self._emit_rc_release_simple(_fs_old_pv, op="field_set", loc=_fs_loc);
    }
    self.builder.store(value, field_ptr);
}

impl NaIRGenObjects._receiver_routed_method_fn(
    nd: uni.UniNode, owner: str, slot: str, _recv_cls: (str | None)
) -> (ir.Function | None) {
    _sfull = f"{owner}.{slot}";
    _sfunc = self.method_funcs[_sfull];

    _owner_cls = owner;
    _owner_lay = self._arch_layout(_owner_cls);
    _anc_meth: (uni.Ability | None) = None;
    if _owner_lay is not None {
        _mi = _owner_lay.method_index.get(slot);
        if _mi is not None and _owner_lay.methods[_mi].owner == _owner_cls {
            _anc_meth = _owner_lay.methods[_mi].ability;
        }
    }
    _is_static = _anc_meth is not None
        and (_anc_meth.is_static or _anc_meth.is_classmethod);
    if (
        _recv_cls is not None
        and _recv_cls != _owner_cls
        and _recv_cls in self.struct_types
        and not _is_static
    ) {
        _sc_reg = self._registry();
        if not _sc_reg.is_primary_ancestor(_recv_cls, _owner_cls) {
            _spec_key = f"{_recv_cls}.{slot}${_owner_cls}";
            if _spec_key not in self.method_funcs
                and _spec_key not in self._native_skipped_methods {
                if _anc_meth is None or _anc_meth.signature is None {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="call",
                        name=_sfull,
                        help_text=(
                            "An unbound ancestor call runs the "
                            "ancestor's body on this receiver, whose "
                            "field layout differs; specializing it "
                            "needs the ancestor's source, which is "
                            "not visible to this unit."
                        )
                    );
                    return None;
                }
                _spec_arg_tys: list[ir.Type] = [
                    self.struct_types[_recv_cls].as_pointer()
                ];
                for _at in _sfunc.function_type.args[1:] {
                    _spec_arg_tys.append(_at);
                }
                _spec_fnty = ir.FunctionType(
                    _sfunc.function_type.return_type, _spec_arg_tys
                );
                _spec_fn = ir.Function(self.llvm_module, _spec_fnty, name=_spec_key);
                for (_sai, _sa) in enumerate(_sfunc.args) {
                    if _sai < len(_spec_fn.args) {
                        _spec_fn.args[_sai].name = _sa.name;
                    }
                }
                self.method_funcs[_spec_key] = _spec_fn;
                self._codegen_method(_recv_cls, _anc_meth, symbol_override=_spec_key);
            }
            _spec_ready = self.method_funcs.get(_spec_key);
            if _spec_ready is None {
                self.emit(E5092, node_override=nd, kind="call", name=_spec_key);
                return None;
            }
            _sfunc = _spec_ready;
        }
    }
    return _sfunc;
}

impl NaIRGenObjects._emit_class_routed_call(
    nd: uni.FuncCall,
    owner: str,
    slot: str,
    _given_recv: (ir.Value | None),
    _given_recv_cls: (str | None)
) -> (ir.Value | None) {
    method_name = slot;
    _recv_cls: (str | None) = _given_recv_cls;
    if _recv_cls is None {
        _recv_first = (nd.params or [None])[0];
        _recv_cls = (
            self._receiver_arch_name(_recv_first)
                if _recv_first is not None and not isinstance(_recv_first, uni.KWPair)
                else None
        );
    }
    _sfunc = self._receiver_routed_method_fn(nd, owner, slot, _recv_cls);
    if _sfunc is None {
        return None;
    }

    _sargs: list[ir.Value] = [];
    if _given_recv is not None {
        _sargs.append(_given_recv);
    }
    _sargs.extend(
        self._codegen_bound_args(
            nd, _sfunc, self_offset=(1 if _given_recv is not None else 0)
        )
    );
    for (_i, _sv) in enumerate(_sargs) {
        if _i < len(_sfunc.args) {
            _sargs[_i] = self._coerce_type(_sv, _sfunc.args[_i].type);
        }
    }
    _sr = self.builder.call(_sfunc, _sargs, name=f"scall.{method_name}");
    if isinstance(_sfunc.return_value.type, ir.VoidType) {
        return None;
    }
    return _sr;
}
