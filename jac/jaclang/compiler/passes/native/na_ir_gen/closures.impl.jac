import from jaclang.jac0core.constant { Tokens as Tok }
impl NaIRGenClosures._scan_closure_escapes(
    nd: uni.UniNode, body: (list | tuple)
) -> None {
    def nearest_scope(n: uni.UniNode) -> (uni.UniNode | None) {
        p = n.parent;
        while p is not None {
            if isinstance(
                p,
                (
                    uni.Ability,
                    uni.ImplDef,
                    uni.LambdaExpr,
                    uni.Test,
                    uni.ModuleCode,
                    uni.Module
                )
            ) {
                return p;
            }
            p = p.parent;
        }
        return None;
    }
    if not body {
        return;
    }
    direct_names: list = [];
    for nm in nd.get_all_sub_nodes(typ=uni.Name) {
        if nearest_scope(nm) is nd {
            direct_names.append(nm);
        }
    }
    for sub in nd.get_all_sub_nodes(typ=uni.Ability) {
        if nearest_scope(sub) is not nd or self._ability_is_generator(sub) {
            continue;
        }
        sname = sub.name_ref.sym_name if sub.name_ref else None;
        if sname is None {
            continue;
        }
        escapes = False;
        for nm in direct_names {
            if nm.value != sname {
                continue;
            }
            _np = nm.parent;
            if not (isinstance(_np, uni.FuncCall) and _np.target is nm) {
                escapes = True;
                break;
            }
        }
        if not escapes {
            continue;
        }
        for cap_sym in sub.get_enclosing_captures() {
            if cap_sym.parent_tab is nd {
                self.closure_cell_vars.add(cap_sym.sym_name);
            }
        }
    }
    for lam in nd.get_all_sub_nodes(typ=uni.LambdaExpr) {
        if nearest_scope(lam) is not nd {
            continue;
        }
        for cap_sym in lam.captures {
            if cap_sym.parent_tab is nd {
                self.closure_cell_vars.add(cap_sym.sym_name);
            }
        }
    }
}

impl NaIRGenClosures._closure_sig_struct(fnty: ir.FunctionType) -> tuple {
    key = str(fnty);
    _existing = self._closure_sig_keys.get(key);
    if _existing is not None {
        (st, fnty_env) = self.closure_sig_registry[_existing];
        return (_existing, st, fnty_env);
    }
    self._closure_uid += 1;
    name = f"JacClosure.{self._closure_uid}";
    i64 = ir.IntType(64);
    i8p: any = ir.IntType(8).as_pointer();
    self._register_iter_struct(name, ["fn", "env"], [i64, i8p]);
    fnty_env = ir.FunctionType(fnty.return_type, list(fnty.args) + [i8p]);
    st = self.struct_types[name];
    self.closure_sig_registry[name] = (st, fnty_env);
    self._closure_sig_keys[key] = name;
    return (name, st, fnty_env);
}

impl NaIRGenClosures._closure_struct_of(val_type: ir.Type) -> (str | None) {
    if not isinstance(val_type, ir.PointerType) {
        return None;
    }
    pname: any = val_type.pointee?.name;
    if pname is not None and pname in self.closure_sig_registry {
        return pname;
    }
    return None;
}

impl NaIRGenClosures._closure_cell_struct(slot_type: ir.Type) -> str {
    key = str(slot_type);
    _existing = self._closure_cell_structs.get(key);
    if _existing is not None {
        return _existing;
    }
    self._closure_uid += 1;
    name = f"JacCell.{self._closure_uid}";
    self._register_iter_struct(name, ["val"], [slot_type]);
    self._closure_cell_structs[key] = name;
    return name;
}

impl NaIRGenClosures._emit_closure_cell(var_name: str, slot_type: ir.Type) -> ir.Value {
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    cell_name = self._closure_cell_struct(slot_type);
    i32 = ir.IntType(32);
    func: any = self.builder.function;
    _gc = self._gen_ctx;
    if _gc is not None and func is _gc["resume_fn"] {
        _cell_st: any = self.struct_types[cell_name];
        cell_ptr_ty: ir.Type = _cell_st.as_pointer();
        handle_slot = self._entry_alloca(cell_ptr_ty, f"__cell_{var_name}");
        (_sn, _soff, _st) = _gc["slots"][-1];
        _gc["cell_inits"].append(
            {
                "name": var_name,
                "cell_name": cell_name,
                "slot_off": _soff,
                "val_type": slot_type,
                "param_index": None
            }
        );
        entry_block = func.entry_basic_block;
        cur_block = self.builder.block;
        self.builder.position_at_end(entry_block);
        cell: any = self.builder.load(handle_slot, name=f"cellh.{var_name}");
        slot: any = self.builder.gep(
            cell, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name=f"cell.{var_name}"
        );
        self.builder.position_at_end(cur_block);
        self.closure_cell_handles[var_name] = cell;
        return slot;
    }
    entry_block = func.entry_basic_block;
    cur_block = self.builder.block;
    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    cell = self._alloc_iter_struct(cell_name);
    slot: any = self.builder.gep(
        cell, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name=f"cell.{var_name}"
    );
    if isinstance(slot_type, ir.IntType) {
        self.builder.store(ir.Constant(slot_type, 0), slot);
    } elif isinstance(slot_type, (ir.DoubleType, ir.FloatType)) {
        self.builder.store(ir.Constant(slot_type, 0.0), slot);
    } else {
        self.builder.store(ir.Constant(slot_type, None), slot);
    }
    self.builder.position_at_end(cur_block);
    self.closure_cell_handles[var_name] = cell;
    return slot;
}

impl NaIRGenClosures._emit_closure_thunk(
    target_fn: ir.Function, declared_count: int, cap_info: list
) -> ir.Function {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    self._closure_uid += 1;
    env_name = f"JacClosureEnv.{self._closure_uid}";
    field_names: list = [];
    field_types: list = [];
    for (cname, cmode, hidden_ty) in cap_info {
        _ht: any = hidden_ty;
        slot_ty = _ht.pointee if cmode == "ptr" else _ht;
        cell_struct: any = self.struct_types[self._closure_cell_struct(slot_ty)];
        field_names.append(cname);
        field_types.append(cell_struct.as_pointer());
    }
    self._register_iter_struct(env_name, field_names, field_types);

    fnty: any = target_fn.function_type;
    declared = list(fnty.args)[:declared_count];
    thunk_ty = ir.FunctionType(fnty.return_type, declared + [i8p]);
    thunk: any = ir.Function(
        self.llvm_module, thunk_ty, name=f"__jac_closure_{target_fn.name}"
    );
    thunk.linkage = "private";
    thunk.args[-1].name = "env";

    saved_builder = self._builder;
    self._builder = ir.IRBuilder(thunk.append_basic_block("entry"));
    _env_st: any = self.struct_types[env_name];
    envp = self.builder.bitcast(thunk.args[-1], _env_st.as_pointer(), name="env.typed");
    call_args = list(thunk.args)[:-1];
    for (i, (cname, cmode, _hidden_ty)) in enumerate(cap_info) {
        fslot = self.builder.gep(
            envp, [ir.Constant(i32, 0), ir.Constant(i32, i)], name=f"env.{cname}"
        );
        cell = self.builder.load(fslot, name=f"cell.{cname}");
        vslot = self.builder.gep(
            cell, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name=f"cellv.{cname}"
        );
        if cmode == "ptr" {
            call_args.append(vslot);
        } else {
            call_args.append(self.builder.load(vslot, name=f"capv.{cname}"));
        }
    }
    if isinstance(thunk_ty.return_type, ir.VoidType) {
        self.builder.call(target_fn, call_args);
        self.builder.ret_void();
    } else {
        res = self.builder.call(target_fn, call_args, name="clos.inner");
        self.builder.ret(res);
    }
    self._builder = saved_builder;
    thunk.jac_env_struct = env_name;
    return thunk;
}

impl NaIRGenClosures._emit_closure_pair(
    target_fn: ir.Function, declared_fnty: ir.FunctionType, cap_info: list
) -> (ir.Value | None) {
    for (cname, _cmode, _ht) in cap_info {
        if cname not in self.closure_cell_handles {
            return None;
        }
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    (sig_name, _sig_st, _fnty_env) = self._closure_sig_struct(declared_fnty);
    _tname: any = target_fn.name;
    thunk: any = self.closure_thunks.get(_tname);
    if thunk is None {
        thunk = self._emit_closure_thunk(target_fn, len(declared_fnty.args), cap_info);
        self.closure_thunks[_tname] = thunk;
    }
    env_name: any = thunk.jac_env_struct;
    env_field_types = self.struct_field_types[env_name];
    env = self._alloc_iter_struct(env_name);
    for (i, (cname, _cmode, _ht)) in enumerate(cap_info) {
        cell: any = self.closure_cell_handles[cname];
        fty = env_field_types[cname];
        cellv = cell
            if cell.type == fty
            else self.builder.bitcast(cell, fty, name=f"cellc.{cname}");
        fslot = self.builder.gep(
            env, [ir.Constant(i32, 0), ir.Constant(i32, i)], name=f"envf.{cname}"
        );
        self.builder.store(cellv, fslot);
        self._emit_rc_retain(cell, op="closure_env", loc="");
    }
    clos = self._alloc_iter_struct(sig_name);
    fn_slot = self.builder.gep(
        clos, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="clos.fn.slot"
    );
    self.builder.store(self.builder.ptrtoint(thunk, i64, name="clos.fn"), fn_slot);
    env_slot = self.builder.gep(
        clos, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="clos.env.slot"
    );
    self.builder.store(self.builder.bitcast(env, i8p, name="clos.env.i8"), env_slot);
    self._mark_owned(clos);
    return clos;
}

impl NaIRGenClosures._emit_closure_value(
    var_name: str, nd: uni.UniNode
) -> (ir.Value | None) {
    cap_entry = self.nested_captures.get(var_name);
    if cap_entry is None {
        return None;
    }
    fn: any = cap_entry[0];
    caps: any = cap_entry[1];
    declared_count = len(fn.args) - len(caps);
    if declared_count < 0 {
        return None;
    }
    fnty = fn.function_type;
    declared_fnty = ir.FunctionType(fnty.return_type, list(fnty.args)[:declared_count]);
    cap_info: list = [];
    for (i, (cname, cmode)) in enumerate(caps) {
        cap_info.append((cname, cmode, fnty.args[declared_count + i]));
    }
    return self._emit_closure_pair(fn, declared_fnty, cap_info);
}

impl NaIRGenClosures._emit_closure_escape_error(
    var_name: str, nd: uni.UniNode
) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="expression",
        name=f"'{var_name}' (capturing closure used as a value)",
        help_text="This closure's captured variables could not be promoted to shared heap cells in this frame (e.g. the capture is itself borrowed from an outer function, or the closure is a generator), so it can only be called directly here. Move the captured state into this frame, or use an object holding the state."
    );
}

impl NaIRGenClosures._codegen_closure_call(
    nd: uni.FuncCall, clos_val: ir.Value, struct_name: str
) -> (ir.Value | None) {
    (_st, fnty_env) = self.closure_sig_registry[struct_name];
    if struct_name == self._bare_callable_sname {
        return self._emit_bare_callable_call(nd, clos_val);
    }
    i32 = ir.IntType(32);
    declared = list(fnty_env.args)[:-1];
    raw_args: list = [];
    for p in (nd.params or []) {
        v = self._codegen_expr(p);
        if v is not None {
            raw_args.append(v);
        }
    }
    coerced: list = [];
    for (i, a) in enumerate(raw_args) {
        if i < len(declared) {
            coerced.append(self._coerce_type(a, declared[i]));
        } else {
            coerced.append(a);
        }
    }
    while len(coerced) < len(declared) {
        coerced.append(self._default_arg_fallback(declared[len(coerced)]));
    }
    fn_slot = self.builder.gep(
        clos_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ccall.fn.slot"
    );
    fn_i64 = self.builder.load(fn_slot, name="ccall.fn.i64");
    fn_ptr = self.builder.inttoptr(fn_i64, fnty_env.as_pointer(), name="ccall.fn");
    env_slot = self.builder.gep(
        clos_val, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="ccall.env.slot"
    );
    env = self.builder.load(env_slot, name="ccall.env");
    result: any = None;
    if isinstance(fnty_env.return_type, ir.VoidType) {
        result = self.builder.call(fn_ptr, coerced + [env]);
    } else {
        result = self.builder.call(fn_ptr, coerced + [env], name="ccall");
    }
    for a in raw_args {
        if isinstance(a.type, ir.PointerType) and self._is_owned(a) {
            self._emit_rc_release_simple(a, op="ccall_arg", loc="");
        }
    }
    if isinstance(clos_val.type, ir.PointerType) and self._is_owned(clos_val) {
        self._emit_rc_release_simple(clos_val, op="ccall_target", loc="");
    }
    return result;
}

impl NaIRGenClosures._emit_callable_trampoline(real_fn: ir.Function, bound: bool) -> ir.Function {
    """Emit (once per callee) the uniform dynamic entry of a bare `Callable`.

    Signature: `%JacVal (ptr args_list, ptr env)`. Arguments arrive as a
    jacval list; each is unboxed into the callee's declared parameter type.
    A bound trampoline passes `env` as the receiver (`self`) first. The
    result is boxed back into a jacval (void returns box as none).
    """;
    _key = f"{real_fn.name}::{bound}";
    _hit = self._callable_trampolines.get(_key);
    if _hit is not None {
        return _hit;
    }
    if not self._bare_callable_sname {
        self._bare_callable_type();
    }
    if self?.jacval_type is None or "jacval" not in self.list_helpers {
        return real_fn;
    }
    _argsl = self.list_types["jacval"].as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fnty = ir.FunctionType(self.jacval_type, [_argsl, ir.IntType(8).as_pointer()]);
    _safe = real_fn.name.replace(".", "_").replace("-", "_");
    _tname = f"__ucl_{_safe}";
    if bound {
        _tname += "_b";
    }
    tf = ir.Function(self.llvm_module, fnty, name=_tname);
    tf.linkage = "private";
    bb = tf.append_basic_block("entry");
    _saved_builder = self._builder;
    self._builder = ir.IRBuilder(bb);
    b = self.builder;
    argsl = tf.args[0];
    env = tf.args[1];
    sig_args = list(real_fn.function_type.args);
    start: int = 0;
    if bound {
        start = 1;
    }
    call_args: list[ir.Value] = [];
    if bound and sig_args {
        _self_ty = sig_args[0];
        if env.type != _self_ty {
            call_args.append(b.bitcast(env, _self_ty, name="recv.cast"));
        } else {
            call_args.append(env);
        }
    }
    for (i, P) in enumerate(sig_args[start:]) {
        jv = b.call(
            self.list_helpers["jacval"]["get"],
            [argsl, ir.Constant(i64, i)],
            name=f"uarg.{i}"
        );
        call_args.append(self._unbox_from_jacval(jv, P));
    }
    r = b.call(real_fn, call_args);
    if isinstance(real_fn.function_type.return_type, ir.VoidType) {
        b.ret(ir.Constant(self.jacval_type, None));
    } else {
        jv = self._box_to_jacval(r);
        b.ret(jv);
    }
    self._builder = _saved_builder;
    self._callable_trampolines[_key] = tf;
    return tf;
}

impl NaIRGenClosures._make_bound_callable(real_fn: ir.Function, recv: ir.Value) -> ir.Value {
    """Heap-allocate a callable pair binding `real_fn` to receiver `recv`.""";
    if not self._bare_callable_sname {
        self._bare_callable_type();
    }
    tramp = self._emit_callable_trampoline(real_fn, True);
    i8p = ir.IntType(8).as_pointer();
    recv_i8 = recv;
    if recv.type != i8p {
        recv_i8 = self.builder.bitcast(recv, i8p, name="bind.recv");
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    self._emit_rc_retain(recv_i8, op="bind.env", loc="");
    pair = self._alloc_iter_struct(self._bare_callable_sname);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fn_slot = self.builder.gep(pair, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="bind.fn.slot");
    self.builder.store(self.builder.ptrtoint(tramp, i64, name="bind.fn.i64"), fn_slot);
    env_slot = self.builder.gep(pair, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="bind.env.slot");
    self.builder.store(recv_i8, env_slot);
    return pair;
}

impl NaIRGenClosures._emit_bare_callable_call(nd: uni.FuncCall, pair: ir.Value) -> ir.Value {
    """Call through a bare-`Callable` value.

    Null pair raises AttributeError. Arguments (fixed expressions and/or one
    `*list` spread) are boxed into a jacval list; the trampoline does the
    rest. Returns the callee's boxed result.
    """;
    (_st, fnty_env) = self.closure_sig_registry[self._bare_callable_sname];
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    b = self.builder;
    _is_null = b.icmp_unsigned(
        "==", pair, ir.Constant(pair.type, None), name="call.null"
    );
    self._emit_runtime_raise(
        _is_null, "AttributeError", "'None' Callable object is not callable"
    );
    if self?.jacval_type is None or "jacval" not in self.list_helpers {
        self._emit_list_helpers("jacval", self.jacval_type);
    }
    _h = self.list_helpers["jacval"];
    fn_i64 = b.load(
        b.gep(pair, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="call.fn.slot"),
        name="call.fn.i64"
    );
    fnp = b.inttoptr(fn_i64, fnty_env.as_pointer(), name="call.tramp");
    env = b.load(
        b.gep(pair, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="call.env.slot"),
        name="call.env"
    );
    dst = self._rc_call_with_ctx(_h["new"], [], op="new", loc="", name="call.args");
    for p in (nd.params or []) {
        if isinstance(p, uni.KWPair) {
            self.emit(
                E5092,
                node_override=nd,
                kind="call argument",
                name="keyword argument through a bare Callable",
                help_text=(
                    "A bare `Callable` value carries no parameter names, so "
                    "keyword arguments cannot be matched at the call site. "
                    "Pass positionally, or type the slot `Callable[[P], R]`."
                )
            );
            continue;
        }
        if (
            isinstance(p, uni.UnaryExpr)
            and isinstance(p.op, uni.Token)
            and p.op.name in (Tok.STAR_MUL, Tok.STAR_POW)
        ) {
            src = self._codegen_expr(p.operand);
            if src is None {
                continue;
            }
            _src_spec: (str | None) = None;
            for (_nm, _lt) in self.list_types.items() {
                if _lt.as_pointer() == src.type {
                    _src_spec = _nm;
                    break;
                }
            }
            if _src_spec is None {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="call argument unpacking",
                    name="*",
                    help_text=(
                        "Only `*list` spreads lower through a bare `Callable`;"
                        " spread a tuple explicitly instead."
                    )
                );
                continue;
            }
            _sh = self.list_helpers[_src_spec];
            n = b.call(_sh["len"], [src], name="spread.len");
            loop_bb = b.function.append_basic_block("spread.loop");
            body_bb = b.function.append_basic_block("spread.body");
            done_bb = b.function.append_basic_block("spread.done");
            i_slot = self._entry_alloca(i64, "spread.i");
            b.store(ir.Constant(i64, 0), i_slot);
            b.branch(loop_bb);
            b.position_at_end(loop_bb);
            i_v = b.load(i_slot, name="spread.i.v");
            more = b.icmp_signed("<", i_v, n, name="spread.more");
            b.cbranch(more, body_bb, done_bb);
            b.position_at_end(body_bb);
            e = b.call(_sh["get"], [src, i_v], name="spread.e");
            jv = self._box_to_jacval(e);
            b.call(_h["append"], [dst, jv]);
            i_n = b.add(i_v, ir.Constant(i64, 1), name="spread.next");
            b.store(i_n, i_slot);
            b.branch(loop_bb);
            b.position_at_end(done_bb);
            continue;
        }
        v = self._codegen_expr(p);
        if v is None {
            self.emit(E5092, node_override=nd, kind="call argument", name="?");
            continue;
        }
        jv = self._box_to_jacval(v);
        b.call(_h["append"], [dst, jv]);
    }
    res = b.call(fnp, [dst, env], name="callable.call");
    _rel = self.list_release_fns.get("jacval");
    if _rel is not None {
        b.call(_rel, [dst]);
    }
    return res;
}

impl NaIRGenClosures._codegen_method_reference_value(
    nd: uni.UniNode, target_name: (str | None), right_name: (str | None)
) -> (ir.Value | None) {
    """Lower `instance.method` used as a VALUE into a bound callable pair.

    Only fires when the attribute names a natively-lowered method of a
    struct-typed receiver and is not shadowed by a field or property; every
    other read falls through to the field-access paths.
    """;
    if right_name is None or target_name is None {
        return None;
    }
    if right_name in ("init", "__init__", "postinit", "__post_init__") {
        return None;
    }
    _recv_ty = self._struct_name_of(nd.target);
    if _recv_ty is None or _recv_ty not in self.struct_types {
        return None;
    }
    if right_name in self.struct_field_indices.get(_recv_ty, {}) {
        return None;
    }
    if self._accessor_slot_of(_recv_ty, right_name, "property") is not None {
        return None;
    }
    _hit: (ir.Function | None) = None;
    for _cn in self._mro_of(_recv_ty) {
        _cand = f"{_cn}.{right_name}";
        if (
            _cand in self.method_funcs
            and _cand not in self._native_skipped_methods
        ) {
            _hit = self.method_funcs[_cand];
            break;
        }
    }
    if _hit is None {
        return None;
    }
    _recv = self._codegen_expr(nd.target);
    if _recv is None {
        return None;
    }
    return self._make_bound_callable(_hit, _recv);
}
