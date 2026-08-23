import os;

impl NaIRGenExpr._codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    if nd is None {
        return None;
    }
    _jac_loc: str = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if isinstance(nd, uni.Int) {
        tok_name = nd?.name;
        if tok_name == Tok.HEX {
            _lit = ir.Constant(ir.IntType(64), int(nd.value, 16));
        } elif tok_name == Tok.OCT {
            _lit = ir.Constant(ir.IntType(64), int(nd.value, 8));
        } elif tok_name == Tok.BIN {
            _lit = ir.Constant(ir.IntType(64), int(nd.value, 2));
        } else {
            _lit = ir.Constant(ir.IntType(64), int(nd.value, 0));
        }
        return self._lower_coercion(nd, _lit) if nd.coerce_to is not None else _lit;
    }
    if isinstance(nd, uni.Float) {
        _flit = ir.Constant(ir.DoubleType(), float(nd.value));
        return self._lower_coercion(nd, _flit) if nd.coerce_to is not None else _flit;
    }
    if isinstance(nd, uni.Bool) {
        val = 1 if nd.value.lower() in ("true", "1") else 0;
        _blit = ir.Constant(ir.IntType(1), val);
        return self._lower_coercion(nd, _blit) if nd.coerce_to is not None else _blit;
    }
    if isinstance(nd, uni.Null) {
        return ir.Constant(ir.IntType(8).as_pointer(), None);
    }

    if isinstance(nd, uni.CfgExpr) {
        return self._codegen_expr(nd.expr);
    }
    _result: (ir.Value | None) = None;
    if isinstance(nd, uni.Name) {
        _result = self._codegen_name(nd);
    } elif isinstance(nd, uni.BinaryExpr) {
        _result = self._codegen_binary(nd);
    } elif isinstance(nd, uni.CompareExpr) {
        _result = self._codegen_compare(nd);
    } elif isinstance(nd, uni.UnaryExpr) {
        _result = self._codegen_unary(nd);
    } elif isinstance(nd, uni.FuncCall) {
        _result = self._codegen_call(nd);
    } elif isinstance(nd, uni.AtomTrailer) {
        _result = self._codegen_atom_trailer(nd);
    } elif isinstance(nd, uni.BoolExpr) {
        _result = self._codegen_bool_expr(nd);
    } elif isinstance(nd, uni.IfElseExpr) {
        _result = self._codegen_if_else_expr(nd);
    } elif isinstance(nd, uni.MultiString) {
        _result = self._codegen_multistring(nd);
    } elif isinstance(nd, uni.String) {
        _result = self._codegen_string(nd);
    } elif isinstance(nd, uni.FString) {
        _result = self._codegen_fstring(nd);
    } elif isinstance(nd, uni.ListVal) {
        _result = self._codegen_list_val(nd);
    } elif isinstance(nd, uni.DictCompr) {
        _result = self._codegen_dict_compr(nd);
    } elif isinstance(nd, uni.SetCompr) {
        _result = self._codegen_set_compr(nd);
    } elif isinstance(nd, uni.ListCompr) {
        _result = self._codegen_list_compr(nd);
    } elif isinstance(nd, uni.TupleVal) {
        _result = self._codegen_tuple_val(nd);
    } elif isinstance(nd, uni.DictVal) {
        _result = self._codegen_dict_val(nd);
    } elif isinstance(nd, uni.SetVal) {
        _result = self._codegen_set_val(nd);
    } elif isinstance(nd, uni.AtomUnit) {
        _result = self._codegen_expr(nd.value);
    } elif isinstance(nd, uni.CastExpr) {
        _result = self._codegen_expr(nd.value);
    } elif isinstance(nd, uni.LambdaExpr) {
        _result = self._codegen_lambda(nd);
    } elif isinstance(nd, uni.YieldExpr) {
        _result = self._codegen_yield(nd);
    } elif isinstance(nd, uni.AwaitExpr) {
        _result = self._codegen_expr(nd.target);
    } elif isinstance(nd, uni.ConcurrentExpr) {
        _result = self._try_flow_future(nd);
        if _result is None {
            _result = self._codegen_expr(nd.target);
        }
    } elif isinstance(nd, uni.EdgeRefTrailer) {
        _result = self._codegen_edge_ref_trailer(nd);
    } elif (
        isinstance(nd, uni.Slice)
        or isinstance(nd, uni.IndexSlice)
        or isinstance(nd, uni.KVPair)
        or isinstance(nd, uni.KWPair)
        or isinstance(nd, uni.InnerCompr)
        or isinstance(nd, uni.FormattedValue)
    ) { } else {
        self.emit(E5092, node_override=nd, kind="expression", name=type(nd).__name__);
    }

    if _result is not None and isinstance(nd, uni.Expr) and nd.coerce_to is not None {
        _result = self._lower_coercion(nd, _result);
    }
    if _result is not None {
        _result.jac_loc = _jac_loc;
        if self?.jacval_type
            and _result.type == self.jacval_type
            and isinstance(nd, uni.Expr)
            and nd.type is not None {
            _jv_want = self._lower_type(nd.type);
            if _jv_want is not None and self._opt_payload_of(_jv_want) is not None {
                _result = self._coerce_type(_result, _jv_want, nd.type);
                _result.jac_loc = _jac_loc;
            }
        }

        if isinstance(_result.type, ir.PointerType) {
            import from jaclang.compiler.passes.main.rc_facts_pass {
                Ownership,
                result_ownership
            }
            if result_ownership(nd) == Ownership.OWNED {
                self._mark_owned(_result);
            }
        }

        _narrowed = self._apply_flow_narrowing(nd, _result);
        if _narrowed is not _result {
            _narrowed.jac_loc = _jac_loc;
            _result = _narrowed;
        }
    }
    return _result;
}

impl NaIRGenExpr._codegen_required(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    if nd is None {
        return None;
    }
    _errs_before = len(self.errors_had);
    val = self._codegen_expr(nd);
    if val is None
        and len(self.errors_had) == _errs_before
        and not self._reads_unlowered_local(nd) {
        self.emit(E5092, node_override=nd, kind="expression", name=type(nd).__name__);
    }
    return val;
}

impl NaIRGenExpr._current_fn_key -> (str | None) {
    _bb = self._builder.block if self._builder is not None else None;
    _fn = _bb.parent if _bb is not None else None;
    return _fn.name if _fn is not None else None;
}

impl NaIRGenExpr._mark_local_unlowered(name: str) -> None {
    _key = self._current_fn_key();
    if _key is None {
        return;
    }
    _names = self._unlowered_locals.get(_key);
    if _names is None {
        _names = set();
        self._unlowered_locals[_key] = _names;
    }
    _names.add(name);
}

impl NaIRGenExpr._reads_unlowered_local(nd: uni.UniNode) -> bool {
    if not self._unlowered_locals {
        return False;
    }
    _key = self._current_fn_key();
    _names = self._unlowered_locals.get(_key) if _key is not None else None;
    if not _names {
        return False;
    }
    _reads = [nd] if isinstance(nd, uni.Name) else nd.get_all_sub_nodes(uni.Name);
    for _sub in _reads {
        if _sub.value in _names
            and _sub.value not in self.local_vars
            and _sub.value not in self.func_symtab
            and _sub.value not in self.global_vars {
            return True;
        }
    }
    return False;
}

impl NaIRGenExpr._codegen_yield(nd: uni.YieldExpr) -> (ir.Value | None) {
    gc = self._gen_ctx;
    i64 = ir.IntType(64);
    if gc is None or self.builder.function is not gc["resume_fn"] {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="YieldExpr",
            help_text="A generator nested in another function (or a lambda) has no native lowering; hoist it to module level."
        );
        return None;
    }
    if nd.with_from {
        return self._codegen_yield_from(nd);
    }
    if nd.expr is None {
        self._emit_yield_suspend(self._zero_const(gc["elem_type"]));
        return ir.Constant(i64, 0);
    }
    v = self._codegen_expr(nd.expr);
    if v is None {
        return None;
    }
    self._emit_yield_suspend(
        self._coerce_type(v, gc["elem_type"], self._expr_type_of(nd.expr))
    );
    return ir.Constant(i64, 0);
}

impl NaIRGenExpr._emit_yield_suspend(v: ir.Value) -> None {
    gc = self._gen_ctx;
    i1 = ir.IntType(1);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    out_typed = self.builder.bitcast(
        gc["out_i8"], gc["elem_type"].as_pointer(), name="yield.out"
    );
    self.builder.store(v, out_typed);
    for _entry in self._gen_try_stack {
        self.builder.call(self._exc_pop_fn, []);
    }
    k = len(gc["resume_blocks"]) + 1;
    ip_slot = self.builder.bitcast(gc["frame_i8"], i64.as_pointer(), name="yield.ip");
    self.builder.store(ir.Constant(i64, k), ip_slot);
    self.builder.ret(ir.Constant(i1, 1));

    rbb = gc["resume_fn"].append_basic_block(f"resume{k}");
    gc["resume_blocks"].append(rbb);
    self.builder.position_at_end(rbb);
    for _entry in self._gen_try_stack {
        exc_state = _entry["state"];
        self.builder.call(self._exc_push_fn, [exc_state]);
        env_ptr = self.builder.gep(
            exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name=f"rearm.env.{k}"
        );
        env_i8p = self.builder.bitcast(env_ptr, i8p, name=f"rearm.envp.{k}");
        sj = self.builder.call(
            self.extern_funcs["setjmp"], [env_i8p], name=f"rearm.sj.{k}"
        );
        is_exc = self.builder.icmp_signed(
            "!=", sj, ir.Constant(i32, 0), name=f"rearm.isexc.{k}"
        );
        cont_bb = gc["resume_fn"].append_basic_block(f"resume{k}.armed");
        self.builder.cbranch(is_exc, _entry["dispatch"], cont_bb);
        self.builder.position_at_end(cont_bb);
    }
}

impl NaIRGenExpr._codegen_yield_from(nd: uni.YieldExpr) -> (ir.Value | None) {
    gc = self._gen_ctx;
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    _errs0 = len(self.errors_had);
    built = self._build_iter_from_expr(nd.expr) if nd.expr is not None else None;
    if built is None {
        if len(self.errors_had) == _errs0 {
            self.emit(
                E5092,
                node_override=nd,
                kind="expression",
                name="yield from",
                help_text="The inner iterable of `yield from` could not lower natively; supported sources are generators, iterator values, lists, dicts, sets, strings, ranges, and the lazy adapters."
            );
        }
        return None;
    }
    (iter_val, _elem_name, elem_type) = built;

    it_spill = self._entry_alloca(iter_val.type, "yf.it");
    self.builder.store(iter_val, it_spill);
    _elem_is_ptr = isinstance(elem_type, ir.PointerType);
    elem_slot = self._entry_alloca(i64 if _elem_is_ptr else elem_type, "yf.elem");

    func = gc["resume_fn"];
    cond_bb = func.append_basic_block("yf.cond");
    body_bb = func.append_basic_block("yf.body");
    end_bb = func.append_basic_block("yf.end");
    self.builder.branch(cond_bb);

    self.builder.position_at_end(cond_bb);
    it_cur = self.builder.load(it_spill, name="yf.it.cur");
    out_i8 = self.builder.bitcast(elem_slot, i8p, name="yf.out");
    got = self._emit_iter_advance(self.builder, it_cur, out_i8);
    self.builder.cbranch(got, body_bb, end_bb);

    self.builder.position_at_end(body_bb);
    v = self.builder.load(elem_slot, name="yf.v");
    if _elem_is_ptr {
        v = self.builder.inttoptr(v, elem_type, name="yf.v.ptr");
    }
    self._emit_yield_suspend(
        self._coerce_type(
            v, gc["elem_type"], self._tb_elem(self._flow_narrowed_type_of(nd.expr))
        )
    );
    self.builder.branch(cond_bb);

    self.builder.position_at_end(end_bb);
    it_end = self.builder.load(it_spill, name="yf.it.end");
    self._emit_rc_release_simple(it_end, op="yf_end", loc="yield_from");
    self.builder.store(ir.Constant(it_end.type, None), it_spill);
    return ir.Constant(i64, 0);
}

impl NaIRGenExpr._codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None) {
    _fn_t = nd.type;
    if not isinstance(_fn_t, FunctionType) {
        raise AssertionError(
            f"lambda at {nd.loc} is not typed as a function (got {nd.type})"
        );
    }
    param_types: list[ir.Type] = [];
    param_names: list[str] = [];
    for p in (_fn_t.parameters or []) {
        _pt = self._lower_type(p.param_type);
        if _pt is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="lambda parameter",
                name=f"{p.name}: {p.param_type}",
                help_text="Every lambda parameter needs a type with a native layout; annotate it (e.g. `lambda x: int : ...`) or let the call site fix it."
            );
            return None;
        }
        param_types.append(_pt);
        param_names.append(p.name);
    }
    ret_type = self._lower_type(_fn_t.return_type);
    if ret_type is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="lambda return type",
            name=f"{_fn_t.return_type}",
            help_text="The lambda's result type has no native layout."
        );
        return None;
    }

    captures: list[tuple] = [];
    free_var_names: list[str] = [];
    for cap_sym in nd.captures {
        if cap_sym.sym_name in free_var_names {
            continue;
        }
        free_var_names.append(cap_sym.sym_name);
        if cap_sym.sym_name not in self.local_vars {
            continue;
        }
        alloca = self.local_vars[cap_sym.sym_name];
        val = self.builder.load(alloca, name=f"cap.{cap_sym.sym_name}");
        captures.append((cap_sym.sym_name, val, val.type));
    }

    all_param_types = list(param_types);
    all_param_names = list(param_names);
    for (cap_name, _cap_val, cap_type) in captures {
        all_param_types.append(cap_type);
        all_param_names.append(cap_name);
    }

    self._str_count += 1;
    anon_name = f"__jac_lambda_{self._str_count}";
    fn_type = ir.FunctionType(ret_type, all_param_types);
    anon_fn = ir.Function(self.llvm_module, fn_type, name=anon_name);
    anon_fn.linkage = "private";
    for (i, arg) in enumerate(anon_fn.args) {
        if i < len(all_param_names) {
            arg.name = all_param_names[i];
        }
    }

    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_func_symtab = dict(self.func_symtab);
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    entry_bb = anon_fn.append_basic_block("entry");
    self._builder = ir.IRBuilder(entry_bb);
    self.local_vars = {};
    self.nogc_no_free_vars = set();
    self.nogc_owned_str_vars = set();
    self.region_handle_vars = set();
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    for (i, arg) in enumerate(anon_fn.args) {
        alloca = self._entry_alloca(arg.type, all_param_names[i]);
        self.builder.store(arg, alloca);
        self.local_vars[all_param_names[i]] = alloca;
    }

    body = nd.body;
    _lam_errs0 = len(self.errors_had);
    if isinstance(body, list) {
        tail = nd.tail_return_expr();
        if tail is not None {
            val = self._codegen_expr(tail);
            if val is not None {
                self.builder.ret(
                    self._coerce_type(val, ret_type, self._expr_type_of(tail))
                );
            } else {
                if len(self.errors_had) == _lam_errs0 {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="expression",
                        name="lambda body",
                        help_text="An expression in this lambda body could not lower natively; an unresolvable name here usually means the lambda reads a variable its enclosing frame cannot expose (e.g. a module-entry local)."
                    );
                }
                self.builder.ret(self._zero_const(ret_type));
            }
        } else {
            self._codegen_body(body);
        }
    } else {
        val = self._codegen_expr(body);
        if val is not None {
            self.builder.ret(
                self._coerce_type(val, ret_type, self._expr_type_of(body))
            );
        } else {
            if len(self.errors_had) == _lam_errs0 {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="expression",
                    name="lambda body",
                    help_text="An expression in this lambda body could not lower natively; an unresolvable name here usually means the lambda reads a variable its enclosing frame cannot expose (e.g. a module-entry local)."
                );
            }
            self.builder.ret(self._zero_const(ret_type));
        }
    }

    for bb in anon_fn.basic_blocks {
        if not bb.is_terminated {
            term_builder = ir.IRBuilder(bb);
            if ret_type == ir.VoidType() {
                term_builder.ret_void();
            } else {
                term_builder.ret(self._zero_const(ret_type));
            }
        }
    }

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.func_symtab = saved_func_symtab;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;

    if captures {
        _all_cells = True;
        for (cap_name, _cap_val, _cap_type) in captures {
            if cap_name not in self.closure_cell_handles {
                _all_cells = False;
                break;
            }
        }
        if _all_cells {
            cap_info: list = [];
            for (cap_name, _cap_val, cap_type) in captures {
                cap_info.append((cap_name, "val", cap_type));
            }
            declared_fnty = ir.FunctionType(ret_type, param_types);
            _clos_val = self._emit_closure_pair(anon_fn, declared_fnty, cap_info);
            if _clos_val is not None {
                self._pending_lambda_captures = None;
                return _clos_val;
            }
        }
        capture_info: list[tuple] = [];
        for (cap_name, _cap_val, _cap_type) in captures {
            capture_info.append((cap_name, self.local_vars[cap_name]));
        }
        self._pending_lambda_captures = capture_info;
    } else {
        self._pending_lambda_captures = None;
    }
    return anon_fn;
}

impl NaIRGenExpr._codegen_name(nd: uni.Name) -> (ir.Value | None) {
    import from jaclang.jac0core.constant { SymbolType }
    var_name = nd.value;
    sym = nd.sym;
    if sym is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name=f"unresolved name '{var_name}'",
            help_text="The symbol table resolved no declaration for this name, so the native backend has no storage to read it from."
        );
        return None;
    }
    _has_caps = var_name in self.lambda_captures or var_name in self.nested_captures;
    if _has_caps {
        _np = nd.parent;
        _is_call_target = isinstance(_np, uni.FuncCall) and _np.target is nd;
        if not _is_call_target {
            _clos_val = self._emit_closure_value(var_name, nd);
            if _clos_val is not None {
                return _clos_val;
            }
            self._emit_closure_escape_error(var_name, nd);
            return None;
        }
    }
    _kind = sym.sym_type;
    _decl_of = sym.decl.name_of if sym.decl is not None else None;
    if _kind
        in (
            SymbolType.OBJECT_ARCH,
            SymbolType.NODE_ARCH,
            SymbolType.EDGE_ARCH,
            SymbolType.WALKER_ARCH,
            SymbolType.ENUM_ARCH
        )
        or isinstance(_decl_of, (uni.Archetype, uni.Enum)) {
        if var_name in self.local_vars {
            return self.builder.load(self.local_vars[var_name], name=var_name);
        }
        return self._codegen_class_ref(nd);
    }
    if _kind in (SymbolType.ABILITY, SymbolType.METHOD, SymbolType.TEST)
        or isinstance(_decl_of, uni.Ability) {
        if var_name in self.local_vars {
            return self.builder.load(self.local_vars[var_name], name=var_name);
        }
        if var_name in self.func_symtab {
            return self.func_symtab[var_name];
        }
        if var_name in self.global_vars {
            return self.builder.load(
                self.global_vars[var_name], name=f"glob.{var_name}"
            );
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="function value",
            name=var_name,
            help_text="This function has no native definition in this unit, so it cannot be used as a value here."
        );
        return None;
    }
    if _kind == SymbolType.MODULE {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name=f"module '{var_name}' as a value",
            help_text="Modules are not first-class values in native code; call or read their members directly."
        );
        return None;
    }
    if var_name in self.local_vars {
        return self.builder.load(self.local_vars[var_name], name=var_name);
    }
    if var_name in self.global_vars {
        return self.builder.load(self.global_vars[var_name], name=f"glob.{var_name}");
    }
    if var_name in self.func_symtab {
        return self.func_symtab[var_name];
    }
    return self._codegen_class_ref(nd);
}

impl NaIRGenExpr._codegen_walrus(nd: uni.BinaryExpr) -> (ir.Value | None) {
    if not isinstance(nd.left, uni.Name) {
        return self._codegen_expr(nd.right);
    }
    var_name = self._get_name(nd.left);
    if var_name is None {
        self.emit(E5092, node_override=nd, kind="binary operator", name="WALRUS_EQ");
        return None;
    }
    value = self._codegen_expr(nd.right);
    if value is None {
        return None;
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    _rhs_t = self._expr_type_of(nd.right);
    if var_name in self.local_vars {
        alloca = self.local_vars[var_name];
        slot_type = alloca.type.pointee;
        value = self._coerce_type(value, slot_type, _rhs_t);
        if isinstance(slot_type, ir.PointerType) {
            if not self._is_owned(value) {
                self._emit_rc_retain(value, op="walrus", loc=_loc);
            }
            old_val = self.builder.load(alloca, name=f"{var_name}.old");
            self._emit_rc_release_typed(old_val, op="overwrite", loc=_loc);
        }
        self.builder.store(value, alloca);
    } else {
        var_type = self._lower_type(nd.left.type);
        if var_type is None {
            raise AssertionError(
                f"walrus target '{var_name}' at {nd.loc} has no lowerable type ({nd.left.type})"
            );
        }
        value = self._coerce_type(value, var_type, _rhs_t);
        alloca = self._entry_alloca(var_type, var_name);
        if isinstance(var_type, ir.PointerType) and not self._is_owned(value) {
            self._emit_rc_retain(value, op="walrus", loc=_loc);
        }
        self.builder.store(value, alloca);
        self.local_vars[var_name] = alloca;
    }

    return self.builder.load(alloca, name=var_name);
}

impl NaIRGenExpr._codegen_binary(nd: uni.BinaryExpr) -> (ir.Value | None) {
    if isinstance(nd.op, uni.ConnectOp) {
        return self._codegen_connect(nd);
    }
    if isinstance(nd.op, uni.DisconnectOp) {
        return self._codegen_disconnect(nd);
    }
    op = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);

    if op == Tok.WALRUS_EQ {
        return self._codegen_walrus(nd);
    }
    if op == Tok.PIPE_FWD {
        return self._codegen_pipe_fwd(nd);
    }
    if op == Tok.KW_SPAWN {
        return self._codegen_spawn(nd);
    }
    left = self._codegen_expr(nd.left);
    right = self._codegen_expr(nd.right);
    if left is None or right is None {
        return None;
    }
    _lty = self._flow_narrowed_type_of(nd.left);
    _rty = self._flow_narrowed_type_of(nd.right);
    result: (ir.Value | None);
    if op == Tok.STAR_POW {
        result = self._codegen_pow(left, right, nd.right, _lty, _rty);
    } else {
        result = self._emit_binary_op(
            op, left, right, _lty, _rty, resolved=nd.resolved_op
        );
    }

    if result is not None {
        _l_str = self._tb_kind(_lty) == "str";
        _r_str = self._tb_kind(_rty) == "str";
        if op == Tok.PLUS and _l_str and _r_str {
            if self._is_owned(left) {
                self._emit_rc_release_typed(
                    left, op="binop_lhs", loc=getattr(left, 'jac_loc', '')
                );
            }
            if self._is_owned(right) {
                self._emit_rc_release_typed(
                    right, op="binop_rhs", loc=getattr(right, 'jac_loc', '')
                );
            }
        } elif op in (Tok.PLUS, Tok.STAR_MUL)
            and self._is_owned(result)
            and self._tb_kind(nd.type) == "list" {
            self._release_owned_operands(left, right, op="binop_list");
        }
    }
    return result;
}

impl NaIRGenExpr._codegen_unary(nd: uni.UnaryExpr) -> (ir.Value | None) {
    operand = self._codegen_expr(nd.operand);
    if operand is None {
        return None;
    }
    import from jaclang.jac0core.constant { is_borrow_kind, OwnershipKind }
    if is_borrow_kind(nd.ownership) {
        return operand;
    }
    if nd.ownership == OwnershipKind.IMM {
        return operand;
    }
    _operand_t = self._expr_type_of(nd.operand);
    _kind = self._tb_kind(_operand_t);
    if nd.ownership == OwnershipKind.OWN {
        if _kind == "str" and operand.type == ir.IntType(8).as_pointer() {
            _rb = self._rc_strdup(operand, name="rebox.str");
            return self._mark_owned(_rb);
        }
        return operand;
    }
    op = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    if op == Tok.MINUS {
        if _kind == "float" {
            return self.builder.fneg(operand, name="fneg");
        } elif _kind in ("int", "bool") {
            if operand.type.width > 1
                and (self._tb_sized(_operand_t) or self._tb_sized(nd.type)) {
                return self._emit_checked_neg(operand);
            }
            return self.builder.neg(operand, name="neg");
        } elif _kind == "complex" {
            f64 = ir.DoubleType();
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            z1 = ir.Constant(i32, 1);
            r = self.builder.load(
                self.builder.gep(operand, [z0, z0], name="cneg.rp"), name="cneg.r"
            );
            im = self.builder.load(
                self.builder.gep(operand, [z0, z1], name="cneg.ip"), name="cneg.i"
            );
            nr = self.builder.fneg(r, name="cneg.nr");
            ni = self.builder.fneg(im, name="cneg.ni");
            raw = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(i64, 16)], name="cneg.raw"
            );
            ptr = self.builder.bitcast(
                raw, self.complex_struct_type.as_pointer(), name="cneg.ptr"
            );
            self.builder.store(nr, self.builder.gep(ptr, [z0, z0], name="cneg.srp"));
            self.builder.store(ni, self.builder.gep(ptr, [z0, z1], name="cneg.sip"));
            return ptr;
        }
    } elif op == Tok.NOT {
        return self.builder.not_(self._to_bool(operand, _operand_t), name="not");
    } elif op == Tok.BW_NOT {
        if _kind in ("int", "bool")
            or (_kind == "enum" and self._enum_value_kind(_operand_t) == "int") {
            all_ones = ir.Constant(operand.type, -1);
            return self.builder.xor(operand, all_ones, name="bwnot");
        }
    } elif op == Tok.PLUS {
        if _kind in ("int", "bool", "float", "complex") {
            return operand;
        }
    }
    self.emit(
        E5092,
        node_override=nd,
        kind="unary operator",
        name=f"{op} on {_kind}",
        help_text="This unary operator has no native lowering for the operand's type."
    );
    return None;
}

impl NaIRGenExpr._codegen_pipe_fwd(nd: uni.BinaryExpr) -> (ir.Value | None) {
    if isinstance(nd.left, uni.TupleVal) and nd.left.values {
        call_params = list(nd.left.values);
    } else {
        call_params = [nd.left];
    }
    call = uni.FuncCall(
        target=nd.right,
        params=call_params,
        genai_call=None,
        kid=[nd.right, *call_params]
    );
    call.parent = nd.parent;
    return self._codegen_expr(call);
}

impl NaIRGenExpr._codegen_spawn(nd: uni.BinaryExpr) -> (ir.Value | None) {
    left_val = self._codegen_expr(nd.left);
    right_val = self._codegen_expr(nd.right);
    if left_val is None or right_val is None {
        return None;
    }

    left_name = self._spawn_operand_name(nd.left);
    right_name = self._spawn_operand_name(nd.right);
    left_is_walker = left_name is not None and self._is_walker_arch(left_name);
    right_is_walker = right_name is not None and self._is_walker_arch(right_name);
    (walker_name, walker_val, loc_val) = (None, None, None);
    if left_is_walker {
        (walker_name, walker_val, loc_val) = (left_name, left_val, right_val);
    } elif right_is_walker {
        (walker_name, walker_val, loc_val) = (right_name, right_val, left_val);
    } else {
        self.emit(
            E5092,
            node_override=nd,
            kind="binary operator",
            name="KW_SPAWN",
            help_text=self._xmod_osp_help([left_name, right_name])
        );
        return left_val;
    }

    _loc_name = right_name if left_is_walker else left_name;
    _xhelp = self._xmod_osp_help([_loc_name]);
    if _xhelp is not None {
        self.emit(
            E5092,
            node_override=nd,
            kind="binary operator",
            name="KW_SPAWN",
            help_text=_xhelp
        );
        return walker_val;
    }

    _spawn_model = self.ir_in.gen.osp_model;
    if (_spawn_model is not None)
        and (walker_name in _spawn_model.tags)
        and (self._osp_rt_global is not None)
        and ("osp_spawn" in self.func_symtab) {
        return self._codegen_kernel_spawn(walker_name, walker_val, loc_val);
    }

    self.emit(E5092, node_override=nd, kind="binary operator", name="KW_SPAWN");
    return walker_val;
}

impl NaIRGenExpr._codegen_kernel_spawn(
    walker_name: str, walker_val: ir.Value, loc_val: ir.Value
) -> (ir.Value | None) {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    if self._osp_ensure_fn is not None {
        self.builder.call(self._osp_ensure_fn, []);
    }
    osp_spawn_fn = self.func_symtab.get("osp_spawn");
    if osp_spawn_fn is None {
        return walker_val;
    }
    _argtys = osp_spawn_fn.function_type.args;

    _h = self.list_helpers.get("i64");
    _starts = self._rc_call_with_ctx(
        _h["new"], [], op="new", loc="", name="spawn.starts"
    );
    self._rc_call_with_ctx(
        _h["append"], [_starts, self._coerce_type(loc_val, i64)], op="append", loc=""
    );

    _ks_model = self.ir_in.gen.osp_model;
    _wtag = _ks_model.local_index(walker_name) if (_ks_model is not None) else -1;
    if _wtag < 0 {
        _wtag = 0;
    }
    _descp = self.builder.load(
        self.builder.gep(
            self._osp_desc_global,
            [ir.Constant(i32, 0), ir.Constant(i32, _wtag)],
            name="spawn.descp"
        ),
        name="spawn.desc.i8"
    );
    _rt = self.builder.load(self._osp_rt_global, name="spawn.rt");
    self.builder.call(
        osp_spawn_fn,
        [
            self._coerce_type(_rt, _argtys[0]),
            self._coerce_type(
                walker_val, _argtys[1], self._arch_instance_type(walker_name)
            ),
            self._coerce_type(_descp, _argtys[2]),
            self._coerce_type(_starts, _argtys[3])
        ]
    );
    self._emit_rc_release_simple(_starts, op="spawn_starts", loc="");
    return walker_val;
}

impl NaIRGenExpr._arch_instance_type(arch_name: str) -> any {
    _lay = self._arch_layout(arch_name);
    _ct = _lay.class_type if _lay is not None else None;
    if _ct is not None
        and hasattr(_ct, "clone_as_instance")
        and not _ct.is_instance() {
        return _ct.clone_as_instance();
    }
    return _ct;
}

impl NaIRGenExpr._spawn_operand_name(nd: uni.UniNode) -> (str | None) {
    _t = self._tb_solve(self._flow_narrowed_type_of(nd));
    _payload = self._tb_opt_payload(_t);
    return self._tb_class_name(_payload if _payload is not None else _t);
}

impl NaIRGenExpr._is_walker_arch(name: str) -> bool {
    _model = self.ir_in.gen.osp_model;
    return (_model is not None) and (_model.arch_kind.get(name) == "walker");
}

impl NaIRGenExpr._codegen_compare(nd: uni.CompareExpr) -> (ir.Value | None) {
    left = self._codegen_expr(nd.left);
    if left is None or not nd.rights or not nd.ops {
        return None;
    }
    if len(nd.ops) > 1 and len(nd.rights) == len(nd.ops) {
        return self._codegen_compare_chain(nd, left);
    }
    right = self._codegen_expr(nd.rights[0]);
    if right is None {
        return None;
    }
    op = nd.ops[0].name if isinstance(nd.ops[0], uni.Token) else str(nd.ops[0]);
    return self._codegen_compare_link(op, left, right, nd.left, nd.rights[0]);
}

impl NaIRGenExpr._codegen_compare_link(
    op: str,
    left: ir.Value,
    right: ir.Value,
    left_node: uni.UniNode,
    right_node: uni.UniNode,
    release_operands: bool = True
) -> (ir.Value | None) {
    _cmp_left_orig = left;
    _cmp_right_orig = right;
    _o_right = right_node.expr if isinstance(right_node, uni.CfgExpr) else right_node;
    _o_left = left_node.expr if isinstance(left_node, uni.CfgExpr) else left_node;
    _lty = self._flow_narrowed_type_of(_o_left);
    _rty = self._flow_narrowed_type_of(_o_right);
    _lk = self._tb_kind(_lty);
    _rk = self._tb_kind(_rty);

    if self?.jacval_type and op in (Tok.KW_IS, Tok.KW_ISN, Tok.EE, Tok.NE) {
        _none_negate = op in (Tok.KW_ISN, Tok.NE);
        if left.type == self.jacval_type and isinstance(_o_right, uni.Null) {
            return self._jacval_is_none(left, _none_negate);
        }
        if right.type == self.jacval_type and isinstance(_o_left, uni.Null) {
            return self._jacval_is_none(right, _none_negate);
        }
    }

    if op in (Tok.KW_IS, Tok.KW_ISN, Tok.EE, Tok.NE) {
        _on_negate = op in (Tok.KW_ISN, Tok.NE);
        _opt_side: (ir.Value | None) = None;
        if self._opt_payload_of(left.type) is not None
            and isinstance(_o_right, uni.Null) {
            _opt_side = left;
        } elif self._opt_payload_of(right.type) is not None
            and isinstance(_o_left, uni.Null) {
            _opt_side = right;
        }
        if _opt_side is not None {
            _otag = self.builder.extract_value(_opt_side, 0, name="opt.cmp.tag");
            _ocmp = self.builder.icmp_signed(
                "!=" if _on_negate else "==",
                _otag,
                ir.Constant(ir.IntType(8), 0),
                name="opt.cmp.none"
            );
            return self.builder.zext(_ocmp, ir.IntType(64), name="opt.cmp.i64");
        }
    }

    if op == Tok.KW_IN or op == Tok.KW_NIN {
        return self._codegen_membership(
            op == Tok.KW_NIN,
            left,
            right,
            _o_left,
            _o_right,
            _cmp_right_orig,
            release_operands
        );
    }

    if op == Tok.KW_IS or op == Tok.KW_ISN {
        return self._codegen_identity(
            op == Tok.KW_ISN, left, right, _lty, _rty, _o_left, release_operands
        );
    }
    is_float = _lk == "float" or _rk == "float";
    if is_float {
        (left, right) = self._promote_to_float(left, right, _lty, _rty);
    }
    _cmp_result = self._emit_comparison(op, left, right, is_float, _lty, _rty);
    if release_operands {
        self._release_owned_operands(_cmp_left_orig, _cmp_right_orig, op="cmp_op");
    }
    return _cmp_result;
}

impl NaIRGenExpr._codegen_identity(
    negate: bool,
    left: ir.Value,
    right: ir.Value,
    lty: any,
    rty: any,
    at: uni.UniNode,
    release_operands: bool
) -> (ir.Value | None) {
    """`x is y` / `x is not y` over native representations, decided by kind.

    Options compare by presence and payload; two unboxed scalars compare by
    value (a native int has no identity apart from its value); a scalar
    against a reference is never the same object; a dynamically typed operand
    boxes its peer and compares as JacVals; two references compare by address.
    Truthiness is never an answer here.
    """;
    _orig_l = left;
    _orig_r = right;
    _scalar = ("int", "bool", "enum", "float");
    lk = self._tb_kind(lty);
    rk = self._tb_kind(rty);
    _res: (ir.Value | None) = self._identity_over_optional(left, right, negate);
    if _res is None {
        if lk == "any" or rk == "any" {
            _lj = self._box_to_jacval(left, ty=lty);
            _rj = self._box_to_jacval(right, ty=rty);
            _eq = self._emit_jacval_eq(_lj, _rj);
            _res = self.builder.not_(_eq, name="is.jv.ne") if negate else _eq;
        } elif lk in _scalar and rk in _scalar {
            if lk == "float" or rk == "float" {
                (_lf, _rf) = self._promote_to_float(left, right, lty, rty);
                _res = self.builder.fcmp_ordered(
                    "!=" if negate else "==", _lf, _rf, name="is.fval"
                );
            } else {
                _i64 = ir.IntType(64);
                _res = self.builder.icmp_signed(
                    "!=" if negate else "==",
                    self._coerce_type(left, _i64, lty),
                    self._coerce_type(right, _i64, rty),
                    name="is.val"
                );
            }
        } elif lk in _scalar or rk in _scalar {
            _res = ir.Constant(ir.IntType(1), 1 if negate else 0);
        } else {
            left = self._str_norm(left);
            right = self._str_norm(right);
            if isinstance(left.type, ir.PointerType)
                and isinstance(right.type, ir.PointerType) {
                if left.type != right.type {
                    right = self.builder.bitcast(right, left.type);
                }
                _res = self.builder.icmp_unsigned(
                    "!=" if negate else "==",
                    left,
                    right,
                    name="is.ne" if negate else "is.eq"
                );
            } elif isinstance(left.type, ir.IntType) and left.type == right.type {
                _res = self.builder.icmp_signed(
                    "!=" if negate else "==", left, right, name="is.handle"
                );
            } else {
                self.emit(
                    E5092,
                    node_override=at,
                    kind="identity comparison",
                    name=f"{lk} is {rk}",
                    help_text=f"Identity over these operand types has no native lowering: `{lty}` and `{rty}` do not lower to references, so there is no address to compare."
                );
                return None;
            }
        }
    }
    if release_operands {
        self._release_owned_operands(_orig_l, _orig_r, op="cmp_is");
    }
    return _res;
}

impl NaIRGenExpr._membership_result(
    found: ir.Value, is_not_in: bool, gate: (ir.Value | None) = None
) -> ir.Value {
    i64 = ir.IntType(64);
    result = found
        if found.type == i64
        else self.builder.zext(found, i64, name="in.i64");
    if gate is not None {
        result = self.builder.select(gate, result, ir.Constant(i64, 0), name="in.opt");
    }
    if is_not_in {
        result = self.builder.icmp_signed(
            "==", result, ir.Constant(i64, 0), name="not.in"
        );
        result = self.builder.zext(result, i64, name="notin.i64");
    }
    return result;
}

impl NaIRGenExpr._codegen_membership(
    is_not_in: bool,
    left: ir.Value,
    right: ir.Value,
    left_node: uni.UniNode,
    right_node: uni.UniNode,
    right_orig: ir.Value,
    release_operands: bool
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    _hay_t = self._tb_solve(self._flow_narrowed_type_of(right_node));
    _hay_payload = self._tb_opt_payload(_hay_t);
    if _hay_payload is not None {
        _hay_t = _hay_payload;
    }
    _hk = self._tb_kind(_hay_t);
    left = self._str_norm(left);
    right = self._str_norm(right);
    right = self._unwrap_opt_container(right);

    if _hk == "dict" {
        _dk = self._dict_key_of(right_node);
        helpers = self.dict_helpers.get(_dk) if _dk is not None else None;
        if helpers is not None {
            key_type = helpers["key_type"];
            (left_coerced, _din_gate) = self._opt_membership_operand(left, key_type);
            (_has_fn, _kh) = self._static_key_op(helpers, "contains", left_node);
            _has_args = [right, left_coerced];
            if _kh is not None {
                _has_args.append(_kh);
            }
            found = self.builder.call(_has_fn, _has_args, name="dict.contains");
            result = self._membership_result(found, is_not_in, _din_gate);
            if release_operands {
                self._release_owned_operands(
                    left_coerced, right_orig, op="cmp_in_dict"
                );
            }
            return result;
        }
    } elif _hk == "set" {
        _sk = self._set_spec_of(right_node);
        helpers = self.set_helpers.get(_sk) if _sk is not None else None;
        if helpers is not None {
            elem_type = helpers["elem_type"];
            (left_coerced, _sin_gate) = self._opt_membership_operand(left, elem_type);
            (_has_fn, _kh) = self._static_key_op(helpers, "contains", left_node);
            _has_args = [right, left_coerced];
            if _kh is not None {
                _has_args.append(_kh);
            }
            found = self.builder.call(_has_fn, _has_args, name="set.contains");
            result = self._membership_result(found, is_not_in, _sin_gate);
            if release_operands {
                self._release_owned_operands(left_coerced, right_orig, op="cmp_in_set");
            }
            return result;
        }
    } elif _hk in ("list", "bytearray") {
        _lk = self._list_spec_of(right_node);
        helpers = self.list_helpers.get(_lk) if _lk is not None else None;
        if helpers is not None {
            elem_type = helpers["elem_type"];
            (left_coerced, _lin_gate) = self._opt_membership_operand(left, elem_type);
            list_len = self.builder.call(helpers["len"], [right], name="list.in.len");
            func = self.builder.basic_block.function;
            entry_bb = self.builder.basic_block;
            loop_bb = func.append_basic_block(name="list.in.loop");
            check_bb = func.append_basic_block(name="list.in.check");
            found_bb = func.append_basic_block(name="list.in.found");
            done_bb = func.append_basic_block(name="list.in.done");
            self.builder.branch(loop_bb);
            self.builder.position_at_start(loop_bb);
            idx = self.builder.phi(i64, name="list.in.idx");
            idx.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = self.builder.icmp_unsigned(
                ">=", idx, list_len, name="list.in.atend"
            );
            self.builder.cbranch(at_end, done_bb, check_bb);
            self.builder.position_at_start(check_bb);
            elem = self.builder.call(helpers["get"], [right, idx], name="list.in.elem");
            _elem_kind = self._tb_kind(self._tb_elem(_hay_t));
            if _elem_kind == "str" {
                _lin_i8p = ir.IntType(8).as_pointer();
                _lin_cmp = self._call_str_cmp(
                    self.builder,
                    self.builder.bitcast(left_coerced, _lin_i8p, name="list.in.l.i8"),
                    self.builder.bitcast(elem, _lin_i8p, name="list.in.e.i8"),
                    name="list.in.strcmp"
                );
                eq = self.builder.icmp_signed(
                    "==", _lin_cmp, ir.Constant(ir.IntType(32), 0), name="list.in.eq"
                );
            } elif _elem_kind == "any" {
                eq = self._emit_jacval_eq(left_coerced, elem);
            } elif _elem_kind == "float" {
                eq = self.builder.fcmp_ordered(
                    "==", elem, left_coerced, name="list.in.eq"
                );
            } elif _elem_kind in ("int", "bool", "enum") {
                eq = self.builder.icmp_signed(
                    "==", elem, left_coerced, name="list.in.eq"
                );
            } else {
                eq = self.builder.icmp_unsigned(
                    "==", elem, left_coerced, name="list.in.eq"
                );
            }
            _lin_end_bb = self.builder.basic_block;
            next_idx = self.builder.add(idx, ir.Constant(i64, 1), name="list.in.next");
            idx.add_incoming(next_idx, _lin_end_bb);
            self.builder.cbranch(eq, found_bb, loop_bb);
            self.builder.position_at_start(found_bb);
            self.builder.branch(done_bb);
            self.builder.position_at_start(done_bb);
            found = self.builder.phi(i64, name="list.in.result");
            found.add_incoming(ir.Constant(i64, 0), loop_bb);
            found.add_incoming(ir.Constant(i64, 1), found_bb);
            result = self._membership_result(found, is_not_in, _lin_gate);
            if release_operands {
                self._release_owned_operands(
                    left_coerced, right_orig, op="cmp_in_list"
                );
            }
            return result;
        }
    } elif _hk == "tuple" {
        tin_struct = self._tuple_struct_of_value(right);
        if tin_struct is not None {
            tin_val = (
                self.builder.load(right, name="tuple.in.val")
                    if isinstance(right.type, ir.PointerType)
                    else right
            );
            n = len(tin_struct.elements);
            i1_t = ir.IntType(1);
            found: ir.Value = ir.Constant(i1_t, 0);
            _needle_t = self._flow_narrowed_type_of(left_node);
            _elem_kinds = [self._tb_kind(a) for a in self._tb_args(_hay_t)];
            _ref_kinds = (
                "list",
                "dict",
                "set",
                "struct",
                "object",
                "bytes",
                "bytearray",
                "range",
                "slice",
                "complex",
                "fn",
                "file",
                "binary_file",
                "iterator",
                "region",
                "class",
                "none"
            );
            for i in range(n) {
                elem = self.builder.extract_value(tin_val, i, name=f"tuple.in.{i}");
                left_c = self._coerce_type(left, elem.type, _needle_t);
                _ek = _elem_kinds[i] if i < len(_elem_kinds) else "unknown";
                if _ek == "str" {
                    cmp = self._call_str_cmp(
                        self.builder, left_c, elem, name=f"tuple.in.{i}.cmp"
                    );
                    eq = self.builder.icmp_signed(
                        "==",
                        cmp,
                        ir.Constant(ir.IntType(32), 0),
                        name=f"tuple.in.{i}.eq"
                    );
                } elif _ek == "float" {
                    eq = self.builder.fcmp_ordered(
                        "==", left_c, elem, name=f"tuple.in.{i}.eq"
                    );
                } elif _ek in ("int", "bool", "enum") {
                    eq = self.builder.icmp_signed(
                        "==", left_c, elem, name=f"tuple.in.{i}.eq"
                    );
                } elif _ek == "any" {
                    eq = self._emit_jacval_eq(left_c, elem);
                } elif _ek in _ref_kinds and isinstance(elem.type, ir.PointerType) {
                    eq = self.builder.icmp_unsigned(
                        "==", left_c, elem, name=f"tuple.in.{i}.eq"
                    );
                } else {
                    self.emit(
                        E5092,
                        node_override=right_node,
                        kind="expression",
                        name=f"membership over tuple element {_ek}",
                        help_text="This tuple element type has no native equality for membership tests."
                    );
                    return None;
                }
                found = self.builder.or_(found, eq, name=f"tuple.in.{i}.found");
            }
            return self._membership_result(found, is_not_in);
        }
    } elif _hk == "range" {
        i32 = ir.IntType(32);
        z0 = ir.Constant(i32, 0);
        val = self._coerce_type(left, i64, self._flow_narrowed_type_of(left_node));
        start = self.builder.load(
            self.builder.gep(right, [z0, ir.Constant(i32, 0)], name="rin.sp"),
            name="rin.start"
        );
        stop = self.builder.load(
            self.builder.gep(right, [z0, ir.Constant(i32, 1)], name="rin.ep"),
            name="rin.stop"
        );
        step = self.builder.load(
            self.builder.gep(right, [z0, ir.Constant(i32, 2)], name="rin.tp"),
            name="rin.step"
        );
        diff = self.builder.sub(val, start, name="rin.diff");
        rem = self.builder.srem(diff, step, name="rin.rem");
        rem_zero = self.builder.icmp_signed(
            "==", rem, ir.Constant(i64, 0), name="rin.remz"
        );
        step_pos = self.builder.icmp_signed(
            ">", step, ir.Constant(i64, 0), name="rin.spos"
        );
        ge_start = self.builder.icmp_signed(">=", val, start, name="rin.ges");
        lt_stop = self.builder.icmp_signed("<", val, stop, name="rin.lts");
        pos_ok = self.builder.and_(ge_start, lt_stop, name="rin.pok");
        le_start = self.builder.icmp_signed("<=", val, start, name="rin.les");
        gt_stop = self.builder.icmp_signed(">", val, stop, name="rin.gts");
        neg_ok = self.builder.and_(le_start, gt_stop, name="rin.nok");
        bounds = self.builder.select(step_pos, pos_ok, neg_ok, name="rin.bounds");
        found = self.builder.and_(rem_zero, bounds, name="rin.found");
        return self._membership_result(found, is_not_in);
    } elif _hk == "bytes" {
        if self._tb_kind(self._flow_narrowed_type_of(left_node)) == "bytes" {
            found = self._emit_bytes_contains(left, right);
            return self._membership_result(found, is_not_in);
        }
    } elif _hk == "str" {
        _needle_t = self._flow_narrowed_type_of(left_node);
        if self._tb_payload_kind(_needle_t) == "str" {
            i8p = ir.IntType(8).as_pointer();
            _hay_s = self._coerce_type(right, i8p, _hay_t);
            _needle_s = self._coerce_type(left, i8p, _needle_t);
            strstr_fn = self._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
            hit = self.builder.call(strstr_fn, [_hay_s, _needle_s], name="str.in.ptr");
            found = self.builder.icmp_unsigned(
                "!=", hit, ir.Constant(i8p, None), name="str.in.found"
            );
            return self._membership_result(found, is_not_in);
        }
    }
    self.emit(
        E5092,
        node_override=right_node,
        kind="expression",
        name=f"membership over {_hay_t} ({_hk})",
        help_text="Membership lowers natively over lists, dicts, sets, tuples, ranges, bytes and strings whose element types have a native layout; this right-hand side has none."
    );
    return None;
}

impl NaIRGenExpr._identity_over_optional(
    left: ir.Value, right: ir.Value, negate: bool
) -> (ir.Value | None) {
    """`x is y` where at least one operand is an option and neither is `None`.

    A `T | None` value lowers to a `JacOpt` -- a presence tag beside the
    payload -- which is not a pointer, so the pointer path cannot answer this
    and the fallback below answers a different question entirely: the
    truthiness of the left operand, with the right operand discarded. Two
    options are identical when both are absent, or both present with the same
    payload; an option against a plain reference is identical when the option
    is present and the payloads match. A comparison against a literal `None`
    never reaches here -- it is answered as a tag test further up.
    """;
    _lp = self._opt_payload_of(left.type);
    _rp = self._opt_payload_of(right.type);
    if _lp is None and _rp is None {
        return None;
    }
    _zero_tag = ir.Constant(ir.IntType(8), 0);
    _l_set: any = ir.Constant(ir.IntType(1), 1);
    _l_val: any = left;
    if _lp is not None {
        _l_tag = self.builder.extract_value(left, 0, name="is.l.tag");
        _l_set = self.builder.icmp_signed("!=", _l_tag, _zero_tag, name="is.l.set");
        _l_val = self.builder.extract_value(left, 1, name="is.l.pv");
    }
    _r_set: any = ir.Constant(ir.IntType(1), 1);
    _r_val: any = right;
    if _rp is not None {
        _r_tag = self.builder.extract_value(right, 0, name="is.r.tag");
        _r_set = self.builder.icmp_signed("!=", _r_tag, _zero_tag, name="is.r.set");
        _r_val = self.builder.extract_value(right, 1, name="is.r.pv");
    }
    if not isinstance(_l_val.type, ir.PointerType)
        or not isinstance(_r_val.type, ir.PointerType) {
        return None;
    }
    if _l_val.type != _r_val.type {
        _r_val = self.builder.bitcast(_r_val, _l_val.type, name="is.r.cast");
    }
    _same_pv = self.builder.icmp_unsigned("==", _l_val, _r_val, name="is.pv.eq");
    _both_set = self.builder.and_(_l_set, _r_set, name="is.both.set");
    _hit = self.builder.and_(_both_set, _same_pv, name="is.opt.hit");
    _l_none = self.builder.not_(_l_set, name="is.l.none");
    _r_none = self.builder.not_(_r_set, name="is.r.none");
    _both_none = self.builder.and_(_l_none, _r_none, name="is.both.none");
    _res: any = self.builder.or_(_hit, _both_none, name="is.opt");
    if negate {
        _res = self.builder.not_(_res, name="isn.opt");
    }
    return _res;
}

impl NaIRGenExpr._codegen_compare_chain(
    nd: uni.CompareExpr, left: ir.Value
) -> (ir.Value | None) {
    op_names: list[str] = [];
    for _o in nd.ops {
        _name = _o.name if isinstance(_o, uni.Token) else str(_o);
        op_names.append(_name);
    }
    operands: list = [left];
    result: (ir.Value | None) = None;
    cur = left;
    for (i, op_name) in enumerate(op_names) {
        right = self._codegen_required(nd.rights[i]);
        if right is None {
            return None;
        }
        operands.append(right);
        left_node = nd.left if i == 0 else nd.rights[i - 1];
        _errs_before = len(self.errors_had);
        link = self._codegen_compare_link(
            op_name, cur, right, left_node, nd.rights[i], release_operands=False
        );
        if link is None {
            if len(self.errors_had) == _errs_before {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="chained comparison operator",
                    name=op_name
                );
            }
            return None;
        }
        link = self._to_bool(link, nd.type);
        result = link
            if result is None
            else self.builder.and_(result, link, name=f"chain.and.{i}");
        cur = right;
    }
    self._release_owned_args(operands, op="cmp_chain");
    return result;
}

impl NaIRGenExpr._truth_only_context(nd: uni.UniNode) -> bool {
    """Whether an expression's value is consumed only for its truth.

    A condition of `if` / `elif` / `while` / `assert` / a conditional
    expression / a comprehension filter, the operand of `not`, or an operand
    of another truth-only boolean chain never has its value read, so the chain
    may carry an `i1` instead of a representation shared by its operands.
    """;
    _child: uni.UniNode = nd;
    _p = nd.parent;
    while isinstance(_p, (uni.AtomUnit, uni.CfgExpr)) {
        _child = _p;
        _p = _p.parent;
    }
    if isinstance(_p, (uni.IfStmt, uni.WhileStmt, uni.AssertStmt, uni.IfElseExpr)) {
        return _p.condition is _child;
    }
    if isinstance(_p, uni.UnaryExpr) {
        return isinstance(_p.op, uni.Token) and _p.op.name == Tok.NOT;
    }
    if isinstance(_p, uni.BoolExpr) {
        return self._truth_only_context(_p);
    }
    if isinstance(_p, uni.InnerCompr) {
        return _child in (_p.conditional or []);
    }
    if isinstance(_p, uni.MatchCase) {
        return _p.guard is _child;
    }
    return False;
}

impl NaIRGenExpr._join_value_type(
    nd: uni.Expr, part_types: list, part_values: list
) -> (ir.Type | None) {
    """The native representation a value-selecting expression carries.

    `a or b`, `a and b` and `x if c else y` yield one of their operands, so the
    result needs one representation every operand can reach: operands that
    already agree keep their representation; a numeric mix widens to the
    native float (bool/int mixes to the native int); anything else lowers the
    checker's type of the whole expression, and a chain whose value nobody
    reads carries its truth as an `i1`.
    """;
    _kinds = [self._tb_kind(t) for t in part_types];
    _reprs = [
        v.type
        for v in part_values
        if v is not None
    ];
    if _reprs
        and len(part_values) == len(part_types)
        and all(r == _reprs[0] for r in _reprs) {
        return _reprs[0];
    }
    if _kinds and all(k == "bool" for k in _kinds) {
        return ir.IntType(1);
    }
    if _kinds and all(k in ("int", "bool") for k in _kinds) {
        return ir.IntType(64);
    }
    if _kinds and all(k in ("int", "bool", "float") for k in _kinds) {
        return ir.DoubleType();
    }
    if isinstance(nd, uni.BoolExpr) and self._truth_only_context(nd) {
        return ir.IntType(1);
    }
    return self._lower_type(nd.type);
}

impl NaIRGenExpr._codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None) {
    if not nd.values {
        return None;
    }
    op_name = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    is_and = op_name == Tok.KW_AND;
    i1 = ir.IntType(1);
    _part_types = [self._expr_type_of(v) for v in nd.values];
    target_t = self._join_value_type(nd, _part_types, []);
    if target_t is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="boolean expression",
            name=f"{nd.type}",
            help_text="The value of this `and`/`or` chain has no native layout: its operands' types share no native representation. Give the operands one type, or test them separately."
        );
        return None;
    }
    func = self.builder.function;
    merge_bb = func.append_basic_block(name="bool.merge");
    incomings: list = [];
    n = len(nd.values);
    for (i, v_nd) in enumerate(nd.values) {
        v_ty = _part_types[i];
        v = self._str_norm(self._codegen_expr(v_nd));
        if v is None {
            return None;
        }
        if i == n - 1 {
            _last = (
                self._to_bool(v, v_ty)
                    if target_t == i1
                    else self._coerce_type(v, target_t, v_ty)
            );
            incomings.append((_last, self.builder.block));
            self.builder.branch(merge_bb);
            break;
        }
        cond = self._to_bool(v, v_ty);
        _val = cond if target_t == i1 else self._coerce_type(v, target_t, v_ty);
        next_bb = func.append_basic_block(name=f"bool.next.{i + 1}");
        incomings.append((_val, self.builder.block));
        if is_and {
            self.builder.cbranch(cond, next_bb, merge_bb);
        } else {
            self.builder.cbranch(cond, merge_bb, next_bb);
        }
        self.builder.position_at_end(next_bb);
    }
    self.builder.position_at_end(merge_bb);
    phi = self.builder.phi(target_t, name="bool.result");
    for (_iv, _ib) in incomings {
        phi.add_incoming(_iv, _ib);
    }
    return phi;
}

impl NaIRGenExpr._codegen_if_else_expr(nd: uni.IfElseExpr) -> (ir.Value | None) {
    cond = self._codegen_expr(nd.condition);
    if cond is None {
        return None;
    }
    cond = self._to_bool(cond, self._expr_type_of(nd.condition));
    func = self.builder.function;
    then_bb = func.append_basic_block(name="ternary.then");
    else_bb = func.append_basic_block(name="ternary.else");
    merge_bb = func.append_basic_block(name="ternary.end");
    self.builder.cbranch(cond, then_bb, else_bb);

    self.builder.position_at_end(then_bb);
    then_val = self._codegen_expr(nd.value);
    then_end_bb = self.builder.block;
    then_open = not self.builder.block.is_terminated;

    self.builder.position_at_end(else_bb);
    else_val = self._codegen_expr(nd.else_value);
    else_end_bb = self.builder.block;
    else_open = not self.builder.block.is_terminated;

    target_t: (ir.Type | None) = None;
    if then_val is not None and else_val is not None {
        _then_ty = self._expr_type_of(nd.value);
        _else_ty = self._expr_type_of(nd.else_value);
        target_t = self._join_value_type(
            nd, [_then_ty, _else_ty], [then_val, else_val]
        );
        if target_t is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="conditional expression",
                name=f"{nd.type}",
                help_text="The two branches' types share no native representation, so the conditional expression has no native value layout. Give both branches one type."
            );
        } else {
            if then_open and then_val.type != target_t {
                self.builder.position_at_end(then_end_bb);
                then_val = self._coerce_type(then_val, target_t, _then_ty);
                then_end_bb = self.builder.block;
            }
            if else_open and else_val.type != target_t {
                self.builder.position_at_end(else_end_bb);
                else_val = self._coerce_type(else_val, target_t, _else_ty);
                else_end_bb = self.builder.block;
            }
        }
    }
    if then_open {
        self.builder.position_at_end(then_end_bb);
        self.builder.branch(merge_bb);
    }
    if else_open {
        self.builder.position_at_end(else_end_bb);
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(merge_bb);
    if then_val is None or else_val is None or target_t is None {
        return None;
    }
    phi = self.builder.phi(target_t, name="ternary.result");
    phi.add_incoming(then_val, then_end_bb);
    phi.add_incoming(else_val, else_end_bb);
    return phi;
}

impl NaIRGenExpr._codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None) {
    if isinstance(nd.right, uni.FilterCompr) {
        return self._codegen_chained_filter(nd);
    }
    if nd.is_attr {
        return self._codegen_attr_access(nd);
    }
    if nd.right?.slices {
        return self._codegen_subscript(nd);
    }
    self.emit(
        E5092,
        node_override=nd,
        kind="subscript/index access",
        name=(self._get_name(nd.target) or "<expr>"),
        help_text="This trailer has neither a member name nor an index; it has no native lowering."
    );
    return None;
}

impl NaIRGenExpr._enum_member_value(enum_t: any, member: str) -> (ir.Value | None) {
    enum_name = self._tb_class_name(enum_t);
    if enum_name is None {
        return None;
    }
    _key = f"{enum_name}.{member}";
    if _key not in self.enum_values {
        self._ensure_enum_lowered(enum_t);
    }
    return self.enum_values.get(_key);
}

impl NaIRGenExpr._codegen_enum_member_attr(
    nd: uni.AtomTrailer, right_name: str
) -> (ir.Value | None) {
    """`.value` / `.name` on an enum member, static or runtime.

    A target typed `EnumMemberType` is a member spelled out in source, so the
    answer is a constant; an enum-typed target is a runtime member and reads
    through the enum's value/name tables.
    """;
    import from jaclang.compiler.passes.main.layout_pass {
        class_form_enum_member,
        class_form_enum_scalar
    }
    _tt = self._tb_solve(nd.target.type);
    _cf_owner = class_form_enum_member(_tt);
    if _cf_owner is not None {
        if right_name == "value" {
            return self._codegen_class_form_enum_member(nd.target);
        }
        return self._make_global_string(_cf_owner[2], name_prefix=".cfenum.name");
    }
    if right_name == "value" and class_form_enum_scalar(_tt) is not None {
        return self._codegen_expr(nd.target);
    }
    if isinstance(_tt, EnumMemberType) {
        mem_enum = self._tb_class_name(_tt);
        mem_name = _tt.member_info.member_name if _tt.member_info is not None else None;
        if mem_enum is None or mem_name is None {
            raise AssertionError(
                f"enum member at {nd.target.loc} has no class or member name"
            );
        }
        member_val = self._enum_member_value(_tt, mem_name);
        if member_val is None {
            raise AssertionError(
                f"enum member {mem_enum}.{mem_name} at {nd.target.loc} has no lowered constant"
            );
        }
        if mem_enum in self.enum_string_values {
            return self._wrap_enum_str(
                self._codegen_enum_value_lookup(
                    mem_enum, member_val, use_name=(right_name == "name")
                )
            );
        }
        if right_name == "value" {
            return member_val;
        }
        ordinal = self.enum_member_ordinal.get(f"{mem_enum}.{mem_name}");
        if ordinal is None {
            raise AssertionError(
                f"enum member {mem_enum}.{mem_name} at {nd.target.loc} has no ordinal"
            );
        }
        return self._wrap_enum_str(
            self._codegen_enum_value_lookup(
                mem_enum, ir.Constant(ir.IntType(64), ordinal), use_name=True
            )
        );
    }
    enum_name = self._tb_class_name(_tt);
    if enum_name is None {
        raise AssertionError(
            f"enum-typed receiver at {nd.target.loc} has no class name"
        );
    }
    if enum_name not in self.enum_types {
        self._ensure_enum_lowered(_tt);
    }
    member_val = self._codegen_expr(nd.target);
    if member_val is None {
        return None;
    }
    if enum_name in self.enum_string_values {
        return self._wrap_enum_str(
            self._codegen_enum_value_lookup(
                enum_name, member_val, use_name=(right_name == "name")
            )
        );
    }
    if right_name == "value" and enum_name in self.enum_name_arrays {
        return member_val;
    }
    return self._codegen_enum_attr_runtime(enum_name, member_val, right_name == "name");
}

impl NaIRGenExpr._codegen_module_attr(
    nd: uni.AtomTrailer, mod_sym: any, right_name: str
) -> (ir.Value | None) {
    _decl = mod_sym.decl;
    _path = _decl if isinstance(_decl, uni.ModulePath) else _decl?.parent;
    mod_name = (
        _path.dot_path_str.lstrip(".")
            if isinstance(_path, uni.ModulePath)
            else mod_sym.sym_name
    );
    if mod_name in self._native_stdlib_modules {
        if mod_name == "sys" {
            if right_name == "argv" {
                return self._emit_sys_argv();
            }
            if right_name == "platform" {
                import platform as _plat;
                return self._make_global_string(_plat.system().lower());
            }
            if right_name == "maxsize" {
                return ir.Constant(ir.IntType(64), 0x7FFFFFFFFFFFFFFF);
            }
            if right_name == "byteorder" {
                import sys as _sys;
                return self._make_global_string(_sys.byteorder);
            }
            if right_name == "stdout" or right_name == "stderr" {
                return self._emit_sys_stream(right_name);
            }
        }
        if mod_name == "math" {
            _mc = self._emit_math_const(right_name);
            if _mc is not None {
                return _mc;
            }
        }
        if mod_name == "os" {
            _oc = self._emit_os_const(right_name);
            if _oc is not None {
                return _oc;
            }
        }
    }
    if mod_name in self._native_module_imports and right_name in self.global_vars {
        return self.builder.load(
            self.global_vars[right_name], name=f"modglob.{right_name}"
        );
    }
    _rt = nd.type;
    if isinstance(_rt, EnumMemberType) {
        _mv = self._enum_member_value(_rt.enum_class, right_name);
        if _mv is not None {
            return _mv;
        }
    }
    self.emit(
        E5092,
        node_override=nd,
        kind="attribute access",
        name=f"{mod_name}.{right_name}",
        help_text="This module attribute has no native lowering in this unit."
    );
    return None;
}

impl NaIRGenExpr._codegen_attr_access(nd: uni.AtomTrailer) -> (ir.Value | None) {
    import from jaclang.jac0core.constant { SymbolType }
    right_name = self._get_name(nd.right);
    if right_name is None {
        raise AssertionError(f"attribute access at {nd.loc} has no member name");
    }

    _cls_name = self._codegen_class_name(nd);
    if _cls_name is not None {
        return _cls_name;
    }
    _bound_owner = self._tb_solve(nd.target.type);
    if self._tb_is_class_ref(_bound_owner)
        and JAC_TYPE_REGISTRY.is_sized(self._tb_class_name(_bound_owner) or "") {
        _bound = self._codegen_sized_bound(
            self._tb_class_name(_bound_owner) or "", right_name
        );
        if _bound is not None {
            return _bound;
        }
    }

    _cf_member = self._codegen_class_form_enum_member(nd);
    if _cf_member is not None {
        return _cf_member;
    }

    _rt = self._tb_solve(nd.type);
    _tt = self._tb_solve(self._flow_narrowed_type_of(nd.target));
    _tt_payload = self._tb_opt_payload(_tt);
    if _tt_payload is not None {
        _tt = _tt_payload;
    }
    _t_kind = self._tb_kind(_tt);
    _recv_sym = nd.target.sym if isinstance(nd.target, uni.AstSymbolNode) else None;

    if _recv_sym is not None and _recv_sym.sym_type == SymbolType.MODULE {
        return self._codegen_module_attr(nd, _recv_sym, right_name);
    }

    if isinstance(_rt, EnumMemberType) and _t_kind in ("enum", "class") {
        _mv = self._enum_member_value(_rt.enum_class, right_name);
        if _mv is not None {
            return _mv;
        }
    }
    if (
        _t_kind == "enum"
        and isinstance(_tt, ClassType)
        and not _tt.is_instance()
        and right_name not in ("value", "name")
    ) {
        _mv = self._enum_member_const(_tt, right_name);
        if _mv is not None {
            return _mv;
        }
    }

    if right_name in ("value", "name") and _t_kind == "enum" {
        return self._codegen_enum_member_attr(nd, right_name);
    }

    if _t_kind == "slice" {
        _slice_field_map: dict[(str, int)] = {"start": 0, "stop": 1, "step": 2};
        if right_name in _slice_field_map {
            obj_val = self._codegen_expr(nd.target);
            if obj_val is None {
                return None;
            }
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            fidx = ir.Constant(i32, _slice_field_map[right_name]);
            ptr = self.builder.gep(obj_val, [z0, fidx], name=f"slice.{right_name}.ptr");
            return self.builder.load(ptr, name=f"slice.{right_name}");
        }
    }

    _cls_decl = self._tb_decl(_tt);
    _cls_form = (
        isinstance(_tt, ClassType) and _tt._shared is not None and not _tt.is_instance()
    );
    if _cls_form and isinstance(_cls_decl, uni.Archetype) {
        _cls = self._tb_class_name(_tt);
        if _cls is not None and _cls in self.struct_types {
            _mro_names: list = [_cls];
            for _m in (_tt.shared.mro or []) {
                _mn = self._tb_class_name(_m);
                if _mn is not None and _mn not in _mro_names {
                    _mro_names.append(_mn);
                }
            }
            for _cn in _mro_names {
                _sf = f"{_cn}.{right_name}";
                if _sf in self.static_fields {
                    return self.builder.load(
                        self.static_fields[_sf], name=f"sfld.{right_name}"
                    );
                }
            }
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="attribute access",
            name=f"{_cls}.{right_name}",
            help_text="Only static fields of an archetype with a native layout can be read off the class."
        );
        return None;
    }

    _fa_type_name = self._struct_name_of(nd.target);
    if _fa_type_name is not None {
        type_name = _fa_type_name;
        _fa_idx = self.struct_field_indices.get(type_name);
        _fa_get = self._accessor_slot_of(type_name, right_name, "property");
        obj_val = self._codegen_expr(nd.target);
        if obj_val is None {
            return None;
        }
        if (
            _fa_get is None
            and (_fa_idx is None or right_name not in _fa_idx)
            and self._pyb_base_of(type_name) is not None
        ) {
            return self._codegen_pyb_field_load(
                nd, self._opt_unwrap_attr(obj_val), right_name
            );
        }
        return self._read_field_or_refuse(nd, obj_val, right_name, type_name);
    }

    self.emit(
        E5092,
        node_override=nd,
        kind="attribute access",
        name=right_name,
        help_text=f"The receiver is typed `{_tt}` ({_t_kind}), which has no native layout with a member `{right_name}`. Give the value a concrete native type, or move this code to a @sv/Python context."
    );
    return None;
}

impl NaIRGenExpr._subscript_index_node(nd: uni.AtomTrailer) -> (uni.UniNode | None) {
    slices = nd.right.slices or [];
    if not slices {
        return None;
    }
    idx_node = slices[0];
    return idx_node.start if idx_node?.start else idx_node;
}

impl NaIRGenExpr._subscript_index_value(nd: uni.AtomTrailer) -> (ir.Value | None) {
    slices = nd.right.slices or [];
    if not slices {
        return None;
    }
    idx_node = slices[0];
    idx_val = self._codegen_expr(idx_node);
    if idx_val is None and idx_node?.start {
        idx_val = self._codegen_expr(idx_node.start);
    }
    return idx_val;
}

impl NaIRGenExpr._codegen_subscript(nd: uni.AtomTrailer) -> (ir.Value | None) {
    _tt = self._tb_solve(self._flow_narrowed_type_of(nd.target));
    _tt_payload = self._tb_opt_payload(_tt);
    if _tt_payload is not None {
        _tt = _tt_payload;
    }
    _t_kind = self._tb_kind(_tt);
    slices = nd.right.slices or [];
    is_range = bool(nd.right.is_range) and bool(slices);
    s = slices[0] if slices else None;

    if _t_kind in ("list", "bytearray") {
        spec = self._list_spec_of(nd.target);
        if spec is None {
            self.emit(
                E5092,
                node_override=nd.target,
                kind="subscript/index access",
                name=f"{_tt}",
                help_text="This list's element type has no native layout, so the list cannot be indexed natively."
            );
            return None;
        }
        target_val = self._codegen_expr(nd.target);
        target_val = self._opt_unwrap_subscript(self._str_norm(target_val));
        if target_val is None {
            return None;
        }
        if is_range {
            return self._codegen_list_slice(target_val, s, spec);
        }
        idx_val = self._subscript_index_value(nd);
        if idx_val is None {
            return None;
        }
        result = self._codegen_index(target_val, idx_val, spec);
        if result is not None and spec == "ptr" {
            cast_type = self._lower_type(nd.type);
            if isinstance(cast_type, ir.PointerType) and result.type != cast_type {
                result = self.builder.bitcast(result, cast_type, name="idx.cast");
            }
        }
        return result;
    }

    if _t_kind == "str" {
        target_val = self._codegen_expr(nd.target);
        if target_val is None {
            return None;
        }
        if self._str_desc_ty is not None and target_val.type == self._str_desc_ty {
            if is_range {
                return self._codegen_string_slice(target_val, s, nd.target);
            }
            _didx_val = self._subscript_index_value(nd);
            if _didx_val is None {
                return None;
            }
            _ddata = self.builder.extract_value(
                target_val, 0 if self._nogc_headerless() else 1, name="chr.data"
            );
            _dlen = self.builder.extract_value(
                target_val, 1 if self._nogc_headerless() else 2, name="chr.len"
            );
            return self._codegen_string_index(_ddata, _didx_val, len_val=_dlen);
        }
        target_val = self._opt_unwrap_subscript(self._str_norm(target_val));
        if target_val is None {
            return None;
        }
        if is_range {
            return self._codegen_string_slice(target_val, s, nd.target);
        }
        idx_val = self._subscript_index_value(nd);
        if idx_val is None {
            return None;
        }
        return self._codegen_string_index(
            target_val,
            self._coerce_type(
                idx_val,
                ir.IntType(64),
                self._expr_type_of(self._subscript_index_node(nd))
            ),
            len_val=self._call_str_len(self.builder, target_val, name="chr.len")
        );
    }

    if _t_kind == "bytes" {
        target_val = self._opt_unwrap_subscript(
            self._str_norm(self._codegen_expr(nd.target))
        );
        if target_val is None {
            return None;
        }
        if is_range {
            return self._codegen_bytes_slice(target_val, s);
        }
        idx_val = self._subscript_index_value(nd);
        if idx_val is None {
            return None;
        }
        return self._codegen_bytes_index(target_val, idx_val);
    }

    if is_range {
        self.emit(
            E5092,
            node_override=nd,
            kind="subscript/index access",
            name=f"slice of {_tt}",
            help_text="Only lists, strings, bytes and bytearrays can be sliced natively."
        );
        return None;
    }

    if _t_kind == "any" {
        target_val = self._opt_unwrap_subscript(
            self._str_norm(self._codegen_expr(nd.target))
        );
        _any_key = self._subscript_index_value(nd);
        if target_val is None or _any_key is None {
            return None;
        }
        _any_res = self._codegen_any_subscript(target_val, _any_key);
        if _any_res is not None {
            return _any_res;
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="subscript/index access",
            name="any",
            help_text="A dynamically typed value could not be subscripted natively."
        );
        return None;
    }

    if _t_kind == "tuple" {
        target_val = self._opt_unwrap_subscript(
            self._str_norm(self._codegen_expr(nd.target))
        );
        if target_val is None {
            return None;
        }
        tsub_struct = self._tuple_struct_of_value(target_val);
        if tsub_struct is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="subscript/index access",
                name=f"{_tt}",
                help_text="This tuple did not lower to a native tuple struct."
            );
            return None;
        }
        idx_val = self._subscript_index_value(nd);
        if idx_val is None {
            return None;
        }
        return self._codegen_tuple_index(target_val, idx_val, tsub_struct);
    }

    if _t_kind == "dict" {
        dict_type_key = self._dict_key_of(nd.target);
        parts = dict_type_key.split(":") if dict_type_key is not None else [];
        if len(parts) != 2 {
            self.emit(
                E5092,
                node_override=nd.target,
                kind="subscript/index access",
                name=f"{_tt}",
                help_text="This dict's key or value type has no native layout, so the dict cannot be indexed natively."
            );
            return None;
        }
        (key_type_name, val_type_name) = (parts[0], parts[1]);
        target_val = self._opt_unwrap_subscript(
            self._str_norm(self._codegen_expr(nd.target))
        );
        if target_val is None {
            return None;
        }
        key_val = self._subscript_index_value(nd);
        if key_val is None {
            return None;
        }
        idx_node = slices[0];
        _dk_nd = idx_node.start if idx_node?.start else idx_node;
        return self._codegen_dict_access(
            target_val, key_val, key_type_name, val_type_name, key_node=_dk_nd
        );
    }

    if _t_kind == "struct" {
        target_val = self._opt_unwrap_subscript(
            self._str_norm(self._codegen_expr(nd.target))
        );
        if target_val is None {
            return None;
        }
        if self._struct_ptr_pointee_name(target_val) is not None {
            idx_val = self._subscript_index_value(nd);
            if idx_val is None {
                return None;
            }
            return self._struct_array_elem_ptr(target_val, idx_val);
        }
    }

    self.emit(
        E5092,
        node_override=nd,
        kind="subscript/index access",
        name=(self._get_name(nd.target) or "<expr>"),
        help_text=f"The receiver is typed `{_tt}` ({_t_kind}), which has no native subscript lowering. Give the value a concrete native container type, or move this code to a @sv/Python context."
    );
    return None;
}
