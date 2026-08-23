impl NaIRGenGenerics._mangled_of(t: any) -> (str | None) {
    t = self._tb_solve(t);
    if t is None or not t?.mangle {
        return None;
    }
    if self._mono_solution {
        t = apply_solved_type_vars(t, self._mono_solution);
    }
    return t.mangle();
}

impl NaIRGenGenerics._mono_solution_of(
    ability: uni.Ability, bindings: (dict | None)
) -> (dict | None) {
    solution: dict = {};
    for tp in (ability.type_params or []) {
        tp_name = tp.name.value if tp?.name and tp.name is not None else None;
        if tp_name is None {
            continue;
        }
        _bound = (bindings or {}).get(tp_name);
        if _bound is None {
            return None;
        }
        _bound = self._tb_solve(_bound);
        if isinstance(_bound, TypeVarType) {
            return None;
        }
        solution[tp_name] = _bound;
    }
    return solution;
}

impl NaIRGenGenerics._mono_spec_of(base: str, solution: dict) -> tuple {
    import re;
    import hashlib as _mono_hash;
    parts = sorted(
        [f"{k}={self._mangled_of(v) or 'any'}" for (k, v) in solution.items()]
    );
    key = base + "|" + ",".join(parts);
    safe = re.sub(r"[^0-9A-Za-z_]", "_", "_".join(parts));
    _kd = _mono_hash.sha256(key.encode()).hexdigest()[:8];
    spec_name = f"__jac_mono_{re.sub(r'[^0-9A-Za-z_]', '_', base)}_{safe}_{_kd}";
    return (key, spec_name);
}

impl NaIRGenGenerics._lower_mono_signature(
    ability: uni.Ability, spec_name: str
) -> (ir.FunctionType | None) {
    name = ability.name_ref.sym_name if ability.name_ref else "unnamed";
    sig = ability.signature;
    _ft = ability.name_spec.type;
    if not isinstance(sig, uni.FuncSignature) or not isinstance(_ft, FunctionType) {
        raise AssertionError(
            f"native codegen: generic '{name}' at {ability.loc.mod_path}:"
            f"{ability.loc.first_line} carries no FunctionType"
        );
    }
    _spec = _ft.specialize_func_type_vars(self._mono_solution or {});
    _declared = list(_spec.parameters or []);
    if _declared and (_declared[0].is_self or _declared[0].is_cls) {
        _declared = _declared[1:];
    }
    _params = list(sig.get_parameters());
    _mark = len(self.errors_had);
    _saved_kind = self._sig_decl_kind;
    self._sig_decl_kind = f"signature type (instantiation {spec_name})";
    param_types: list = [];
    try {
        for (i, _dp) in enumerate(_declared) {
            _pv = _params[i] if i < len(_params) else None;
            param_types.append(self._lower_sig_param(ability, _dp, _pv));
        }
        _rt = self._lower_sig_return(ability, _spec);
    } finally {
        self._sig_decl_kind = _saved_kind;
    }
    if len(self.errors_had) > _mark {
        return None;
    }
    return ir.FunctionType(_rt, param_types);
}

impl NaIRGenGenerics._instantiate_generic(
    nd: uni.FuncCall, func_name: str
) -> (ir.Function | None) {
    ability = self.generic_fns[func_name];
    solution = self._mono_solution_of(ability, nd.type_var_bindings);
    if not solution {
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=func_name,
            help_text="The checker did not bind every type parameter of this call, so it cannot be monomorphized; annotate the arguments with concrete types."
        );
        return None;
    }
    (key, spec_name) = self._mono_spec_of(func_name, solution);
    _hit = self._mono_fns.get(key);
    if _hit is not None {
        return _hit;
    }
    saved_sol = self._mono_solution;
    self._mono_solution = solution;
    try {
        fn = self._stamp_mono_fn(ability, spec_name, key);
    } finally {
        self._mono_solution = saved_sol;
    }
    return fn;
}

impl NaIRGenGenerics._stamp_mono_fn(
    ability: uni.Ability, spec_name: str, memo_key: str
) -> (ir.Function | None) {
    name = ability.name_ref.sym_name if ability.name_ref else "unnamed";
    sig = ability.signature;
    fnty = self._lower_mono_signature(ability, spec_name);
    if fnty is None {
        return None;
    }
    fn = ir.Function(self.llvm_module, fnty, name=spec_name);
    fn.linkage = "private";
    for (i, p) in enumerate(sig.get_parameters()) {
        fn.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self._mono_fns[memo_key] = fn;

    saved_builder = self._builder;
    saved_locals = self.local_vars if self?.local_vars else {};
    saved_param_vars = self.param_vars;
    saved_nogc = self.nogc_no_free_vars;
    saved_nogc_owned = self.nogc_owned_str_vars;
    saved_region = self.region_handle_vars;
    saved_list_struct = self.var_list_elem_struct;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    saved_symtab = dict(self.func_symtab);
    saved_gen_ctx = self._gen_ctx;
    self._gen_ctx = None;
    self.func_symtab[name] = fn;
    try {
        self._codegen_ability(ability);
    } finally {
        self._builder = saved_builder;
        self.local_vars = saved_locals;
        self.param_vars = saved_param_vars;
        self.nogc_no_free_vars = saved_nogc;
        self.nogc_owned_str_vars = saved_nogc_owned;
        self.region_handle_vars = saved_region;
        self.var_list_elem_struct = saved_list_struct;
        self.closure_cell_vars = saved_cell_vars;
        self.closure_cell_handles = saved_cell_handles;
        self.func_symtab = saved_symtab;
        self._gen_ctx = saved_gen_ctx;
    }
    return fn;
}

impl NaIRGenGenerics._instantiate_generic_for_target(
    func_name: str, tag_node: uni.UniNode
) -> (ir.Function | None) {
    tag_t = self._annotation_type_of(tag_node);
    if not isinstance(tag_t, FunctionType) {
        raise AssertionError(
            f"native codegen: generic '{func_name}' bound to a target whose "
            f"checker type is {tag_t}, not a FunctionType, at "
            f"{tag_node.loc.mod_path}:{tag_node.loc.first_line}"
        );
    }
    ability = self.generic_fns[func_name];
    _ft = ability.name_spec.type;
    if not isinstance(_ft, FunctionType) {
        raise AssertionError(
            f"native codegen: generic '{func_name}' at {ability.loc.mod_path}:"
            f"{ability.loc.first_line} carries no FunctionType"
        );
    }
    bindings: dict = {};
    _ev = self.prog.get_type_evaluator();
    _tgt_params = tag_t.parameters or [];
    for (i, p) in enumerate(_ft.parameters or []) {
        if i < len(_tgt_params) and p.param_type is not None {
            _sol_t = _tgt_params[i].param_type;
            if _sol_t is not None {
                _ev.assign_type_to_type_var(p.param_type, _sol_t, bindings);
            }
        }
    }
    if _ft.return_type is not None and tag_t.return_type is not None {
        _ev.assign_type_to_type_var(_ft.return_type, tag_t.return_type, bindings);
    }
    solution = self._mono_solution_of(ability, bindings);
    if not solution {
        self.emit(
            E5092,
            node_override=tag_node,
            kind="function",
            name=func_name,
            help_text="The target's function type does not bind every type parameter of this generic def, so it cannot be monomorphized; annotate the target with concrete parameter and return types."
        );
        return None;
    }
    (key, spec_name) = self._mono_spec_of(func_name, solution);
    _hit = self._mono_fns.get(key);
    if _hit is not None {
        return _hit;
    }
    saved_sol = self._mono_solution;
    self._mono_solution = solution;
    try {
        fn = self._stamp_mono_fn(ability, spec_name, key);
    } finally {
        self._mono_solution = saved_sol;
    }
    return fn;
}

impl NaIRGenGenerics._instantiate_generic_method(
    nd: uni.FuncCall, owner_arch: str, method_name: str
) -> (ir.Function | None) {
    ability = self._generic_methods[f"{owner_arch}.{method_name}"];
    solution = self._mono_solution_of(ability, nd.type_var_bindings);
    if not solution {
        self.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{owner_arch}.{method_name}",
            help_text="The checker did not bind every type parameter of this call, so it cannot be monomorphized; annotate the arguments with concrete types."
        );
        return None;
    }
    (key, spec_name) = self._mono_spec_of(f"{owner_arch}.{method_name}", solution);
    _hit = self._mono_fns.get(key);
    if _hit is not None {
        return _hit;
    }
    saved_sol = self._mono_solution;
    self._mono_solution = solution;
    try {
        fn = self._stamp_mono_method(ability, owner_arch, method_name, spec_name, key);
    } finally {
        self._mono_solution = saved_sol;
    }
    return fn;
}

impl NaIRGenGenerics._stamp_mono_method(
    ability: uni.Ability,
    arch_name: str,
    method_name: str,
    spec_name: str,
    memo_key: str
) -> (ir.Function | None) {
    full_name = f"{arch_name}.{method_name}";
    if full_name in self._native_skipped_methods {
        return None;
    }
    struct_type = self.struct_types.get(arch_name);
    sig = ability.signature;
    if struct_type is None
        or sig is None
        or ability.is_static
        or ability.is_classmethod {
        self.emit(E5092, node_override=ability, kind="method", name=full_name);
        return None;
    }
    _raw = self._lower_mono_signature(ability, spec_name);
    if _raw is None {
        return None;
    }
    fnty = ir.FunctionType(
        _raw.return_type, [struct_type.as_pointer()] + list(_raw.args)
    );
    fn = ir.Function(self.llvm_module, fnty, name=spec_name);
    fn.linkage = "private";
    fn.args[0].name = "self";
    for (i, p) in enumerate(sig.get_parameters()) {
        fn.args[i + 1].name = p.name.value if p.name else f"arg{i}";
    }
    self._mono_fns[memo_key] = fn;

    saved_gen_ctx = self._gen_ctx;
    self._gen_ctx = None;
    _saved_mf = self.method_funcs.get(full_name);
    self.method_funcs[full_name] = fn;
    try {
        self._codegen_method(arch_name, ability);
    } finally {
        if _saved_mf is not None {
            self.method_funcs[full_name] = _saved_mf;
        } else {
            self.method_funcs.pop(full_name, None);
        }
        self._gen_ctx = saved_gen_ctx;
    }
    if full_name in self._native_skipped_methods {
        self._mono_fns.pop(memo_key, None);
        self.llvm_module.globals.pop(fn.name, None);
        return None;
    }
    return fn;
}
