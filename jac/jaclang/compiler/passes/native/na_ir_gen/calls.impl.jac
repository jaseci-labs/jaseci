import from jaclang.jac0core.constant { OwnershipKind }

glob _NA_ABC_REDUCTIONS: dict[str, tuple] = {
         "Sequence": ("list", "tuple", "str", "bytes", "bytearray"),
         "MutableSequence": ("list", "bytearray"),
         "Mapping": ("dict", ),
         "MutableMapping": ("dict", ),
         "Set": ("set", "frozenset"),
         "AbstractSet": ("set", "frozenset"),
         "MutableSet": ("set", ),
         "ByteString": ("bytes", "bytearray")
     },
     _NA_ABC_OPAQUE: tuple = (
         "Iterable",
         "Iterator",
         "Reversible",
         "Generator",
         "Container",
         "Collection",
         "Sized",
         "Hashable",
         "Callable",
         "Awaitable",
         "Coroutine",
         "AsyncIterable",
         "AsyncIterator",
         "AsyncGenerator",
         "MappingView",
         "KeysView",
         "ItemsView",
         "ValuesView",
         "Buffer"
     ),
     _NA_NARY_BUILTINS: tuple = (
         "abs",
         "min",
         "max",
         "pow",
         "divmod",
         "sum",
         "any",
         "all",
         "format"
     ),
     _NA_UNARY_BUILTINS: tuple = (
         "ord",
         "int",
         "chr",
         "str",
         "hex",
         "oct",
         "bin",
         "round",
         "float",
         "bool",
         "sorted",
         "reversed",
         "list",
         "set",
         "frozenset",
         "dict",
         "bytes",
         "bytearray",
         "id",
         "hash",
         "repr",
         "ascii"
     );

impl NaIRGenCalls._arch_alias_target(nd: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(nd, uni.NameAtom) {
        return None;
    }
    sym = nd.sym;
    if sym is None {
        return None;
    }
    d = sym.decl;
    if d is None {
        return None;
    }
    nof = d.name_of;
    if isinstance(nof, uni.Archetype) and nof.name.value != self._get_name(nd) {
        return nof.name.value;
    }
    par = d.parent;
    if isinstance(par, uni.ModuleItem) and par.alias is d {
        return self._get_name(par.name);
    }
    return None;
}

impl NaIRGenCalls._codegen_bound_args(
    nd: uni.FuncCall, func: ir.Function, self_offset: int = 0
) -> list {
    import from jaclang.compiler.type_system.types { ParamKind }
    callee = nd.resolved_callee;
    arg_params = nd.arg_params or {};
    raw = nd.params or [];
    args: list = [];
    positional: list = [];
    kw_named: dict = {};
    kw_spreads: list = [];
    kw_order: list = [];
    for param in raw {
        if isinstance(param, uni.KWPair) {
            key = param.key.sym_name if param.key is not None else None;
            if key is not None {
                kw_named[key] = param;
                kw_order.append(("lit", key));
            } else {
                kw_spreads.append(param.value);
                kw_order.append(("spread", param.value));
            }
            continue;
        }
        if (
            isinstance(param, uni.UnaryExpr)
            and isinstance(param.op, uni.Token)
            and param.op.name in (Tok.STAR_MUL, Tok.STAR_POW)
        ) {
            if param.op.name == Tok.STAR_POW {
                kw_spreads.append(param.operand);
                kw_order.append(("spread", param.operand));
                continue;
            }
            _sp_t = self._flow_narrowed_type_of(param.operand);
            _sp_kind = self._tb_kind(_sp_t);
            _tv = self._codegen_expr(param.operand);
            if _tv is None {
                return self._abandoned_args(func, self_offset, args);
            }
            if _sp_kind == "tuple" {
                positional.extend(self._spread_tuple_values(_tv, _sp_t));
            } elif _sp_kind == "list" {
                positional.append(("spread.list.val", _tv, param.operand));
            } else {
                self.emit(
                    E5092,
                    node_override=param,
                    kind="call argument unpacking",
                    name=f"*{_sp_kind}",
                    help_text="Only tuple spreads (static arity) and list spreads into a variadic callee lower natively; spread a tuple or a list, or pass the elements explicitly."
                );
            }
            continue;
        }
        positional.append(param);
    }

    if callee is None
        or callee.parameters is None
        or callee.is_gradual_callable_form() {
        if kw_named or kw_spreads {
            raise AssertionError(
                f"keyword arguments at {nd.loc} but the checker stamped no callee parameters"
            );
        }
        for p in positional {
            if isinstance(p, tuple) {
                if p[0] == "spread.list.val" {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="call argument unpacking",
                        name="*",
                        help_text="A list spread has no static arity, so it cannot fill fixed parameters; spread a tuple instead, or make the callee variadic."
                    );
                    continue;
                }
                args.append(
                    self._bind_arg_slot(func, self_offset + len(args), p[1], p[2])
                );
                continue;
            }
            v = self._codegen_expr(p);
            if v is not None {
                args.append(
                    self._bind_arg_slot(
                        func, self_offset + len(args), v, self._expr_type_of(p)
                    )
                );
            }
        }
        return self._finish_bound_args(nd, func, self_offset, args);
    }

    params = list(callee.parameters);
    _bound_ids: set = set();
    for (_a, _p) in arg_params.items() {
        if _p is not None {
            _bound_ids.add(id(_p));
        }
    }
    if params
        and (params[0].is_self or params[0].is_cls)
        and id(params[0]) not in _bound_ids {
        params = params[1:];
    }
    _param_ids: set = {id(_q) for _q in params};
    for (_ra, _rp) in arg_params.items() {
        if (
            _rp is not None
            and (_rp.is_self or _rp.is_cls)
            and id(_rp) not in _param_ids
            and _ra in positional
        ) {
            positional.remove(_ra);
            _rv = self._codegen_expr(_ra);
            if _rv is None {
                return self._abandoned_args(func, self_offset, args);
            }
            _rslot = self_offset + len(args);
            if _rslot < len(func.args) {
                _rv = self._coerce_type(
                    _rv, func.args[_rslot].type, self._expr_type_of(_ra)
                );
            }
            args.append(_rv);
        }
    }
    if kw_spreads and not any(p.param_kind == ParamKind.KWARG for p in params) {
        self.emit(
            E5092,
            node_override=nd,
            kind="call argument unpacking",
            name="**",
            help_text="A `**` spread carries keys known only at runtime, so the callee needs a `**kwargs` sink to receive keys that match no declared parameter. Give the callee a `**kwargs` parameter, or pass the arguments explicitly."
        );
        kw_spreads = [];
        kw_order = [];
    }
    _has_vararg = any(p.param_kind == ParamKind.VARARG for p in params);
    _has_kwarg = any(p.param_kind == ParamKind.KWARG for p in params);
    _pack_slots = (
        (_has_vararg or _has_kwarg)
        and not func.function_type.var_arg
        and len(func.args) == self_offset + len(params)
    );
    _kw_by_param: dict = {};
    for (_a, _p) in arg_params.items() {
        if isinstance(_a, uni.KWPair) and _a.key is not None and _p is not None {
            _kw_by_param.setdefault(id(_p), []).append(_a);
        }
    }
    _bind_records: list = [];
    _pos_i = 0;
    for p in params {
        slot = self_offset + len(args);
        expected_type = func.args[slot].type if slot < len(func.args) else None;
        if p.param_kind == ParamKind.VARARG {
            extras = positional[_pos_i:];
            _pos_i = len(positional);
            if not _pack_slots {
                for e in extras {
                    if isinstance(e, tuple) {
                        if e[0] == "spread.list.val" {
                            self.emit(
                                E5092,
                                node_override=nd,
                                kind="call argument unpacking",
                                name="*",
                                help_text="A list spread has no static arity, so it cannot fill fixed parameters; spread a tuple instead, or make the callee variadic."
                            );
                            continue;
                        }
                        args.append(
                            self._bind_arg_slot(
                                func, self_offset + len(args), e[1], e[2]
                            )
                        );
                        continue;
                    }
                    v = self._codegen_expr(e);
                    if v is not None {
                        args.append(
                            self._bind_arg_slot(
                                func, self_offset + len(args), v, self._expr_type_of(e)
                            )
                        );
                    }
                }
                continue;
            }
            _lv = self._codegen_varargs_list(nd, extras, expected_type, p.param_type);
            if _lv is None {
                return self._abandoned_args(func, self_offset, args);
            }
            args.append(_lv);
            continue;
        }
        if p.param_kind == ParamKind.KWARG {
            if not _pack_slots {
                if _kw_by_param.get(id(p)) or kw_spreads {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="variadic call",
                        name="**",
                        help_text="The callee declares a `**` pack, but its native implementation has no `**kwargs` slot, so the keyword arguments this site would pack have nowhere to go."
                    );
                    return self._abandoned_args(func, self_offset, args);
                }
                continue;
            }
            leftover: dict = {};
            for _kwn in _kw_by_param.get(id(p), []) {
                leftover[_kwn.key.sym_name] = _kwn.value;
            }
            _dv = self._codegen_kwargs_dict(
                nd, leftover, expected_type, kw_order, _bind_records, p.param_type
            );
            if _dv is None {
                return self._abandoned_args(func, self_offset, args);
            }
            args.append(_dv);
            continue;
        }
        chosen: any = None;
        _from_pos = False;
        _from_kw = False;
        _stub_default = False;
        if p.param_kind != ParamKind.KWONLY and _pos_i < len(positional) {
            chosen = positional[_pos_i];
            _pos_i += 1;
            _from_pos = True;
        } elif _kw_by_param.get(id(p)) {
            chosen = _kw_by_param[id(p)][0].value;
            _from_kw = True;
        } elif p.default_value is not None {
            chosen = p.default_value;
            if isinstance(chosen, (uni.Null, uni.Ellipsis))
                and str(chosen.loc.mod_path).endswith(".pyi") {
                chosen = None;
                _stub_default = True;
            }
        }
        val: (ir.Value | None) = None;
        if isinstance(chosen, tuple) {
            if chosen[0] == "spread.list.val" {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="call argument unpacking",
                    name="*",
                    help_text="A list spread has no static arity, so it cannot fill fixed parameters; spread a tuple instead, or make the callee variadic."
                );
                return self._abandoned_args(func, self_offset, args);
            }
            val = self._bind_arg_slot(func, slot, chosen[1], chosen[2]);
        } elif chosen is not None {
            val = self._codegen_expr(chosen);
            if val is None {
                return self._abandoned_args(func, self_offset, args);
            }
            val = self._bind_arg_slot(func, slot, val, self._expr_type_of(chosen));
        } elif _stub_default or (kw_spreads and p.param_kind != ParamKind.POSONLY) {
            val = self._stub_default_value(nd, p, expected_type);
        } elif self._checker_flagged(nd) {
            return self._abandoned_args(func, self_offset, args);
        } else {
            raise AssertionError(
                f"no argument bound to parameter '{p.name}' at {nd.loc}; the checker owns the missing-argument diagnostic (E1050)"
            );
        }
        args.append(val);
        if kw_spreads and p.param_kind != ParamKind.POSONLY {
            if expected_type is None {
                raise AssertionError(
                    f"parameter '{p.name}' of {nd.loc} has no native slot to bind a `**` spread key into"
                );
            }
            _required: (str | None) = None;
            if chosen is None and not p.is_optional {
                _required = (
                    "keyword-only" if p.param_kind == ParamKind.KWONLY else "positional"
                );
            }
            _bind_records.append(
                self._prep_kwbind_record(
                    p.name,
                    expected_type,
                    len(args) - 1,
                    args[-1],
                    "pos" if _from_pos else ("kw" if _from_kw else None),
                    _required
                )
            );
        }
    }
    for _rec in _bind_records {
        if _rec["alloca"] is None {
            continue;
        }
        if _rec["missing_msg"] is not None {
            _flv = self.builder.load(_rec["flag"], name="kwbind.flag");
            self._emit_runtime_raise(
                self.builder.not_(_flv, name="kwbind.unbound"),
                "TypeError",
                _rec["missing_msg"]
            );
        }
        _bv = self.builder.load(_rec["alloca"], name="kwbind.final");
        if isinstance(_bv.type, ir.PointerType) {
            self._mark_owned(_bv);
        }
        args[_rec["args_idx"]] = _bv;
    }
    if _pos_i < len(positional) {
        for e in positional[_pos_i:] {
            if isinstance(e, tuple) {
                if e[0] != "spread.list.val" {
                    args.append(
                        self._bind_arg_slot(func, self_offset + len(args), e[1], e[2])
                    );
                }
                continue;
            }
            v = self._codegen_expr(e);
            if v is not None {
                args.append(
                    self._bind_arg_slot(
                        func, self_offset + len(args), v, self._expr_type_of(e)
                    )
                );
            }
        }
    }
    return self._finish_bound_args(nd, func, self_offset, args);
}

impl NaIRGenCalls._bind_arg_slot(
    func: ir.Function, slot: int, val: ir.Value, src_ty: any
) -> ir.Value {
    """Coerce one bound argument into the callee's native slot, typed.

    The argument's checker type drives the coercion (an `any` slot boxes by
    the argument's kind, an optional slot wraps, a narrowed optional unwraps).
    A foreign callee keeps its raw values: the clib membrane and the by-value
    struct plan decide those conversions at the call.
    """;
    if func.name in self.clib_fn_abi or func.name in self.clib_extern_names {
        return val;
    }
    if slot >= len(func.args) {
        return val;
    }
    return self._coerce_type(val, func.args[slot].type, src_ty);
}

impl NaIRGenCalls._spread_tuple_values(tv: ir.Value, tuple_t: any) -> list {
    _tt = tv.type;
    _tup_ptr = isinstance(_tt, ir.PointerType)
        and isinstance(_tt.pointee, ir.LiteralStructType);
    _elems = _tt.pointee.elements if _tup_ptr else _tt.elements;
    _elem_tbs = self._tb_args(tuple_t);
    _i32 = ir.IntType(32);
    out: list = [];
    for (_ei, _et) in enumerate(_elems) {
        if _tup_ptr {
            _ep = self.builder.gep(
                tv, [ir.Constant(_i32, 0), ir.Constant(_i32, _ei)], name=f"spread.{_ei}"
            );
            _ev = self.builder.load(_ep, name=f"spread.v.{_ei}");
        } else {
            _ev = self.builder.extract_value(tv, _ei, name=f"spread.v.{_ei}");
        }
        if isinstance(_ev.type, ir.PointerType) {
            self._emit_rc_retain(_ev, op="spread_elem", loc="");
            self._mark_owned(_ev);
        }
        out.append(
            ("spread.val", _ev, _elem_tbs[_ei] if _ei < len(_elem_tbs) else None)
        );
    }
    if _tup_ptr and self._is_owned(tv) {
        self._emit_rc_release_simple(tv, op="spread_tuple", loc="");
    }
    return out;
}

impl NaIRGenCalls._finish_bound_args(
    nd: uni.FuncCall, func: ir.Function, self_offset: int, args: list
) -> list {
    _nc_name = nd.target.sym_name if isinstance(nd.target, uni.Name) else None;
    _nc_entry = self.nested_captures.get(_nc_name) if _nc_name is not None else None;
    if _nc_entry is not None and _nc_entry[0] is func {
        for (_cname, _cmode) in _nc_entry[1] {
            _c_slot = self.local_vars.get(_cname);
            if _c_slot is None {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="function",
                    name=f"{_nc_name} (captured '{_cname}' not in the calling frame)",
                    help_text="A capturing nested function can only be called from a frame that defines or forwards its captures. Pass the value as an explicit parameter instead."
                );
                return self._abandoned_args(func, self_offset, args);
            }
            if _cmode == "ptr" {
                args.append(_c_slot);
            } else {
                args.append(self.builder.load(_c_slot, name=f"cap.{_cname}"));
            }
        }
    }
    if func.function_type.var_arg {
        return args;
    }
    expected_argc = self._callee_jac_arity(func, self_offset);
    if len(args) > expected_argc {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name=f"call with {len(args)} arguments (native accepts {expected_argc})",
            help_text="The resolved (frontend) signature allows more arguments than the native implementation declares (a variadic stub over a bounded native function). Pass fewer arguments or fold the extras before the call."
        );
        return args[:expected_argc];
    }
    if len(args) < expected_argc {
        if self._checker_flagged(nd) {
            return self._abandoned_args(func, self_offset, args);
        }
        raise AssertionError(
            f"call at {nd.loc} bound {len(args)} arguments but '{func.name}' takes {expected_argc}; the checker owns the missing-argument diagnostic (E1050)"
        );
    }
    return args;
}

impl NaIRGenCalls._abandoned_args(
    func: ir.Function, self_offset: int, args: list
) -> list {
    """Pad a binding that already reported its diagnostic to the slot count.

    Reached only after an E5092 named the shape gap; the padded values keep the
    call structurally well-formed so the enclosing function demotes cleanly
    instead of tripping the IR builder.
    """;
    out = list(args);
    if func.function_type.var_arg {
        return out;
    }
    if func.name in self.clib_fn_abi {
        return out;
    }
    while self_offset + len(out) < len(func.args) {
        out.append(self._zero_const(func.args[self_offset + len(out)].type));
    }
    return out;
}

impl NaIRGenCalls._callee_jac_arity(func: ir.Function, self_offset: int) -> int {
    """How many Jac arguments the callee's native symbol takes.

    A foreign function with a by-value struct plan has an IR arity the SysV /
    AAPCS classification decided (a struct may occupy several register
    pieces, a large return adds an sret slot), so its Jac arity is the plan's
    parameter count; every other native function takes one IR argument per
    Jac parameter.
    """;
    _plan = self.clib_fn_abi.get(func.name);
    if _plan is not None {
        return len(_plan["params"]);
    }
    return len(func.args) - self_offset;
}

impl NaIRGenCalls._checker_flagged(nd: uni.UniNode) -> bool {
    """Whether an earlier pass already reported an error on this node's line.""";
    for e in self.errors_had {
        if (
            e.loc is not None
            and nd.loc is not None
            and e.loc.mod_path == nd.loc.mod_path
            and e.loc.first_line == nd.loc.first_line
        ) {
            return True;
        }
    }
    return False;
}

impl NaIRGenCalls._codegen_varargs_list(
    nd: uni.FuncCall, extras: list, expected: (ir.Type | None), elem_tb: any
) -> (ir.Value | None) {
    _elem_llvm = self._elem_storage_llvm(elem_tb);
    if _elem_llvm is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="variadic parameter",
            name="*",
            help_text=f"The callee's `*args` element type ({elem_tb}) has no native layout; annotate the variadic parameter with a lowerable element type."
        );
        return None;
    }
    spec = self._list_spec_for_elem_llvm(_elem_llvm);
    helpers = self.list_helpers.get(spec);
    if helpers is None {
        raise AssertionError(
            f"list helpers for `*args` element {elem_tb} were not registered at {nd.loc}"
        );
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    lv = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="varargs.new"
    );
    for e in extras {
        if isinstance(e, tuple) and e and e[0] == "spread.list.val" {
            _src = e[1];
            _src_spec = self._list_spec_of(e[2]);
            _src_h = self.list_helpers.get(_src_spec)
                if _src_spec is not None
                else None;
            if _src_h is None {
                self.emit(
                    E5092,
                    node_override=e[2],
                    kind="call argument unpacking",
                    name="*",
                    help_text="The spread list's element type did not resolve to a registered native list; annotate it with a lowerable element type."
                );
                continue;
            }
            i64 = ir.IntType(64);
            _cp_fn = self.builder.function;
            _cp_loop = _cp_fn.append_basic_block("spread.loop");
            _cp_body = _cp_fn.append_basic_block("spread.body");
            _cp_done = _cp_fn.append_basic_block("spread.done");
            _cp_len = self.builder.call(_src_h["len"], [_src], name="spread.len");
            _cp_pre = self.builder.block;
            self.builder.branch(_cp_loop);
            self._builder = ir.IRBuilder(_cp_loop);
            _cp_i = self.builder.phi(i64, name="spread.i");
            _cp_i.add_incoming(ir.Constant(i64, 0), _cp_pre);
            self.builder.cbranch(
                self.builder.icmp_unsigned(">=", _cp_i, _cp_len, name="spread.atend"),
                _cp_done,
                _cp_body
            );
            self._builder = ir.IRBuilder(_cp_body);
            _cp_e = self.builder.call(_src_h["get"], [_src, _cp_i], name="spread.elem");
            _cp_e2 = self._coerce_type(
                _cp_e,
                helpers["elem_type"],
                self._tb_elem(self._flow_narrowed_type_of(e[2]))
            );
            self._rc_call_with_ctx(
                helpers["append"], [lv, _cp_e2], op="list_init", loc=_loc
            );
            _cp_i1 = self.builder.add(_cp_i, ir.Constant(i64, 1), name="spread.i1");
            _cp_i.add_incoming(_cp_i1, self.builder.block);
            self.builder.branch(_cp_loop);
            self._builder = ir.IRBuilder(_cp_done);
            self._release_owned_args([_src], op="spread_list");
            continue;
        }
        _e_ty: any = None;
        if isinstance(e, tuple) and e and e[0] == "spread.val" {
            v = e[1];
            _e_ty = e[2];
        } else {
            v = self._codegen_expr(e);
            if v is None {
                return None;
            }
            _e_ty = self._expr_type_of(e);
        }
        _orig = v;
        v2 = self._coerce_type(v, helpers["elem_type"], _e_ty);
        self._rc_call_with_ctx(helpers["append"], [lv, v2], op="list_init", loc=_loc);
        self._release_owned_args([_orig], op="list_init");
    }
    _lv = self._mark_owned(lv);
    if expected is not None and _lv.type != expected {
        _lv = self._coerce_type(_lv, expected);
    }
    return _lv;
}

impl NaIRGenCalls._codegen_kwargs_dict(
    nd: uni.FuncCall,
    leftover: dict,
    expected: (ir.Type | None),
    order: (list | None) = None,
    bind_records: (list | None) = None,
    val_tb: any = None
) -> (ir.Value | None) {
    _i8p = ir.IntType(8).as_pointer();
    _v_llvm = self._elem_storage_llvm(val_tb);
    if _v_llvm is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="variadic parameter",
            name="**",
            help_text=f"The callee's `**kwargs` value type ({val_tb}) has no native layout; annotate the variadic parameter with a lowerable value type."
        );
        return None;
    }
    if self._str_desc_ty is not None and _v_llvm == self._str_desc_ty {
        _v_llvm = _i8p;
    }
    (_k_spec, _k_size) = self._dict_key_spec(_i8p);
    _v_spec = self._dict_val_spec(_v_llvm);
    self._emit_dict_helpers(_k_spec, _v_spec, _i8p, _v_llvm, _k_size);
    dict_key = f"{_k_spec}:{_v_spec}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        raise AssertionError(
            f"dict helpers for `**kwargs` value {val_tb} were not registered at {nd.loc}"
        );
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dv = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="kwargs.new"
    );

    _skip_dv: (ir.Value | None) = None;
    _unbound: list = [];
    for _br in (bind_records or []) {
        if _br["alloca"] is not None {
            _unbound.append(_br);
        }
    }
    if _unbound {
        _skip_dv = self._rc_call_with_ctx(
            helpers["new"], [], op="new", loc=_loc, name="kwbind.names"
        );
        for _br in _unbound {
            self._rc_call_with_ctx(
                helpers["set_ph"],
                [
                    _skip_dv,
                    self._make_global_string(_br["name"], name_prefix=".kwname"),
                    self._zero_const(helpers["val_type"]),
                    ir.Constant(ir.IntType(64), self._static_str_hash(_br["name"]))
                ],
                op="dict_init",
                loc=_loc
            );
        }
    }
    _seen_spread = False;
    for _entry in (order or []) {
        (_kind, _payload) = _entry;
        if _kind == "lit" {
            kname: str = _payload;
            if kname not in leftover {
                continue;
            }
            v = self._codegen_expr(leftover[kname]);
            if v is None {
                return None;
            }
            k = self._make_global_string(kname, name_prefix=".kwname");
            _lkh = ir.Constant(ir.IntType(64), self._static_str_hash(kname));
            if _seen_spread {
                self._emit_runtime_raise(
                    self.builder.call(
                        helpers["contains_ph"], [dv, k, _lkh], name="kwargs.dup"
                    ),
                    "TypeError",
                    f"got multiple values for keyword argument '{kname}'"
                );
            }
            _orig = v;
            v2 = self._coerce_type(
                v, helpers["val_type"], self._expr_type_of(leftover[kname])
            );
            self._rc_call_with_ctx(
                helpers["set_ph"], [dv, k, v2, _lkh], op="dict_init", loc=_loc
            );
            self._release_owned_args([_orig], op="dict_init");
            continue;
        }
        _seen_spread = True;
        sp_expr = _payload;
        sv = self._codegen_expr(sp_expr);
        if sv is None {
            return None;
        }

        for _rec in (bind_records or []) {
            _kg = self._make_global_string(_rec["name"], name_prefix=".kwname");
            _rkh = ir.Constant(ir.IntType(64), self._static_str_hash(_rec["name"]));
            _has = self.builder.call(
                helpers["contains_ph"], [sv, _kg, _rkh], name="kwbind.has"
            );
            if _rec["alloca"] is None {
                self._emit_runtime_raise(_has, "TypeError", _rec["dup_msg"]);
                continue;
            }
            _flv = self.builder.load(_rec["flag"], name="kwbind.flag");
            self._emit_runtime_raise(
                self.builder.and_(_has, _flv, name="kwbind.dup"),
                "TypeError",
                _rec["dup_msg"]
            );
            _do = self.builder.and_(
                _has, self.builder.not_(_flv, name="kwbind.unset"), name="kwbind.do"
            );
            _bfn = self.builder.block.function;
            _bind_bb = _bfn.append_basic_block("kwbind.set");
            _cont_bb = _bfn.append_basic_block("kwbind.cont");
            self.builder.cbranch(_do, _bind_bb, _cont_bb);
            self.builder.position_at_end(_bind_bb);
            _bv = self.builder.call(
                helpers["get_ph"], [sv, _kg, _rkh], name="kwbind.get"
            );
            _bv = self._coerce_type(_bv, _rec["slot_type"]);
            if isinstance(_rec["slot_type"], ir.PointerType) {
                self._emit_rc_retain(_bv, op="kwbind", loc=_loc);
                _old = self.builder.load(_rec["alloca"], name="kwbind.old");
                self._emit_rc_release_simple(_old, op="kwbind", loc=_loc);
            }
            self.builder.store(_bv, _rec["alloca"]);
            self.builder.store(ir.Constant(ir.IntType(1), 1), _rec["flag"]);
            self.builder.branch(_cont_bb);
            self.builder.position_at_end(_cont_bb);
        }
        _sp_key = self._dict_key_of(sp_expr);
        if _sp_key != dict_key
            or not self._merge_dict_into(
                dv, sv, helpers, dict_key, _loc, skip_keys=_skip_dv
            ) {
            self.emit(
                E5092,
                node_override=sp_expr,
                kind="call argument unpacking",
                name="**",
                help_text="A `**` spread must be a dict of the same key/value types as the callee's `**kwargs` sink."
            );
            continue;
        }
        self._release_owned_args([sv], op="dict_init");
    }
    if _skip_dv is not None {
        self._emit_rc_release_simple(_skip_dv, op="dict_init", loc=_loc);
    }
    _dv = self._mark_owned(dv);
    if expected is not None and _dv.type != expected {
        _dv = self._coerce_type(_dv, expected);
    }
    return _dv;
}

impl NaIRGenCalls._merge_dict_into(
    dst: ir.Value,
    src: ir.Value,
    helpers: dict,
    dict_key: str,
    loc: str,
    skip_keys: (ir.Value | None) = None
) -> bool {
    src_t = self.dict_types.get(dict_key);
    if src_t is None or src.type != src_t.as_pointer() {
        return False;
    }
    i64 = ir.IntType(64);
    fn = self.builder.block.function;
    head_bb = fn.append_basic_block("kwsp.head");
    body_bb = fn.append_basic_block("kwsp.body");
    step_bb = fn.append_basic_block("kwsp.step");
    end_bb = fn.append_basic_block("kwsp.end");
    idx_slot = self._entry_alloca(i64, "kwsp.idx");
    self.builder.store(ir.Constant(i64, 0), idx_slot);
    self.builder.branch(head_bb);

    self.builder.position_at_end(head_bb);
    idx = self.builder.load(idx_slot, name="kwsp.i");
    n = self.builder.call(helpers["len"], [src], name="kwsp.n");
    self.builder.cbranch(
        self.builder.icmp_signed("<", idx, n, name="kwsp.ok"), body_bb, end_bb
    );

    self.builder.position_at_end(body_bb);
    k = self.builder.call(helpers["get_key"], [src, idx], name="kwsp.k");
    if skip_keys is not None {
        merge_bb = fn.append_basic_block("kwsp.merge");
        self.builder.cbranch(
            self.builder.call(helpers["contains"], [skip_keys, k], name="kwsp.bound"),
            step_bb,
            merge_bb
        );
        self.builder.position_at_end(merge_bb);
    }
    v = self.builder.call(helpers["get_val"], [src, idx], name="kwsp.v");
    self._emit_runtime_raise(
        self.builder.call(helpers["contains"], [dst, k], name="kwsp.dup"),
        "TypeError",
        "got multiple values for a keyword argument"
    );
    self._rc_call_with_ctx(
        helpers["set"],
        [
            dst,
            self._coerce_type(k, helpers["key_type"]),
            self._coerce_type(v, helpers["val_type"])
        ],
        op="dict_init",
        loc=loc
    );
    self.builder.branch(step_bb);

    self.builder.position_at_end(step_bb);
    self.builder.store(
        self.builder.add(idx, ir.Constant(i64, 1), name="kwsp.i.next"), idx_slot
    );
    self.builder.branch(head_bb);

    self.builder.position_at_end(end_bb);
    return True;
}

impl NaIRGenCalls._codegen_call_args(nd: uni.FuncCall) -> list {
    arg_vals: list[ir.Value] = [];
    for param in (nd.params or []) {
        v = self._coerce_narrowed_arg(param, self._codegen_expr(param));
        if v is not None {
            arg_vals.append(v);
        }
    }
    return arg_vals;
}

impl NaIRGenCalls._coerce_narrowed_arg(
    nd: (uni.UniNode | None), val: (ir.Value | None)
) -> (ir.Value | None) {
    if val is None or self._opt_payload_of(val.type) is None {
        return val;
    }
    _arg_nd = nd.value if isinstance(nd, uni.KWPair) else nd;
    if not isinstance(_arg_nd, uni.Expr) or _arg_nd.type is None {
        return val;
    }
    _want = self._lower_type(_arg_nd.type);
    if _want is None
        or isinstance(_want, ir.VoidType)
        or self._opt_payload_of(_want) is not None {
        return val;
    }
    return self._coerce_type(val, _want, self._flow_narrowed_type_of(_arg_nd));
}

impl NaIRGenCalls._codegen_receiver(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    _rv = self._codegen_expr(nd);
    return self._opt_unwrap_attr(_rv) if _rv is not None else None;
}

impl NaIRGenCalls._emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None {
    if isinstance(value.type, ir.PointerType) and not self._is_owned(value) {
        self._emit_rc_retain(value, op=op, loc=loc);
        return;
    }
    if self._opt_ptr_payload_of(value.type) is not None and not self._is_owned(value) {
        _tr_pv = self.builder.extract_value(value, 1, name="takeref.opt.pv");
        self._emit_rc_retain(_tr_pv, op=op, loc=loc);
    }
}

impl NaIRGenCalls._emit_new(nd: uni.FuncCall) -> (ir.Value | None) {
    params_l = nd.params or [];
    if not params_l or any([isinstance(p, uni.KWPair) for p in params_l]) {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="new",
            help_text="new() takes a class followed by positional constructor arguments only."
        );
        return None;
    }
    _cls_t = self._tb_solve(params_l[0].type);
    cls_name = (
        self._tb_class_name(_cls_t)
            if isinstance(_cls_t, ClassType) and not _cls_t.is_instance()
            else None
    );
    if cls_name is None or cls_name not in self.struct_types {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="new",
            help_text="new() lowers natively only when the first argument statically names an archetype whose native layout is visible to this module; dynamic class values are not supported in native code."
        );
        return None;
    }
    return self._codegen_instantiation(
        nd, type_name_override=cls_name, ctor_params=list(params_l[1:])
    );
}

impl NaIRGenCalls._codegen_decorated_call(
    nd: uni.FuncCall, func_name: str
) -> (ir.Value | None) {
    (raw_fn, slot_gv, _dec_names, fnty, _decl) = self.decorated_fns[func_name];
    args: list[ir.Value] = self._codegen_bound_args(nd, raw_fn, self_offset=0);
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(fnty.args) {
            coerced.append(self._coerce_type(arg, fnty.args[i]));
        } else {
            coerced.append(arg);
        }
    }
    fptr = self.builder.load(slot_gv, name=f"decslot.{func_name}");
    result = self.builder.call(fptr, coerced, name=f"call.{func_name}");
    self._release_owned_args(coerced, op="call_arg");
    return result;
}

impl NaIRGenCalls._emit_unsupported_builtin_call(
    nd: uni.FuncCall, func_name: str
) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="builtin call",
        name=func_name,
        help_text="This builtin is implemented for some argument types but could not be lowered for the argument(s) at this call site (for example `sum`/`min`/`max` over a `range` rather than a list). Restructure to a supported form, or move the code to a @sv/Python context."
    );
}

impl NaIRGenCalls._module_call_qualifier(nd: uni.FuncCall) -> (str | None) {
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }
    _recv = trailer.target;
    _sym = _recv.sym if isinstance(_recv, uni.AstSymbolNode) else None;
    if _sym is None {
        return None;
    }
    import from jaclang.jac0core.constant { SymbolType }
    if _sym.sym_type != SymbolType.MODULE {
        return None;
    }
    _decl = _sym.decl;
    _path = _decl if isinstance(_decl, uni.ModulePath) else _decl?.parent;
    if isinstance(_path, uni.ModulePath) {
        return _path.dot_path_str.lstrip(".");
    }
    return _sym.sym_name;
}

impl NaIRGenCalls._callee_function(
    nd: uni.FuncCall, func_name: str
) -> (ir.Function | None) {
    func = self.func_symtab.get(func_name);
    _decl = nd.callee_decl;
    if func is None or _decl is None {
        return func;
    }
    _dm = self._func_def_mod.get(func_name);
    _decl_mod = _decl.find_parent_of_type(uni.Module);
    if _dm is not None and _decl_mod is not None and _dm != _decl_mod.name {
        return None;
    }
    return func;
}

impl NaIRGenCalls._stub_default_value(
    nd: uni.FuncCall, param: any, expected_type: (ir.Type | None)
) -> ir.Value {
    if expected_type is None {
        raise AssertionError(
            f"parameter '{param.name}' of the call at {nd.loc} has a stub default but no native slot"
        );
    }
    return self._zero_const(expected_type);
}

impl NaIRGenCalls._codegen_intrinsic(
    nd: uni.FuncCall, intr: object
) -> (ir.Value | None) {
    import from jaclang.compiler.intrinsic_registry { IntrinsicDispatch }

    positional: list = [
        p
        for p in (nd.params or [])
        if not isinstance(p, uni.KWPair)
    ];
    if len(positional) != intr.arity()
        or any(isinstance(p, uni.KWPair) for p in (nd.params or [])) {
        if self._checker_flagged(nd) {
            return None;
        }
        raise AssertionError(
            f"intrinsic '{intr.name}' at {nd.loc} reached lowering with a mismatched argument list; the checker owns the E5095 diagnostic"
        );
    }
    handler = {
        IntrinsicDispatch.RC_RUNTIME: self._emit_intrinsic_rc_runtime,
        IntrinsicDispatch.FLOAT_BITS: self._emit_intrinsic_float_bits,
        IntrinsicDispatch.BITS_FLOAT: self._emit_intrinsic_bits_float
    }.get(
        intr.dispatch
    );
    if handler is None {
        self.emit(
            E9001,
            node_override=nd,
            pass_name="NaIRGenPass",
            details=f"intrinsic '{intr.name}' registers dispatch key {intr.dispatch.value} with no mapped emitter"
        );
        return None;
    }
    return handler(nd, intr, positional);
}

impl NaIRGenCalls._intrinsic_operand(
    nd: uni.FuncCall, intr: object, arg: uni.Expr, spec: str
) -> (ir.Value | None) {
    _kind = self._tb_kind(self._flow_narrowed_type_of(arg));
    if _kind not in ("int", "bool", "float") {
        self._emit_intrinsic_misuse(
            nd,
            intr,
            f"operand of type {self._flow_narrowed_type_of(
                arg
            )} does not fit registered parameter type {spec}"
        );
        return None;
    }
    arg_val = self._codegen_expr(arg);
    if arg_val is None {
        return None;
    }
    _arg_t = self._flow_narrowed_type_of(arg);
    if spec == "f64" {
        return self._coerce_type(arg_val, ir.DoubleType(), _arg_t);
    }
    return self._coerce_type(arg_val, ir.IntType(64), _arg_t);
}

impl NaIRGenCalls._emit_intrinsic_misuse(
    nd: uni.FuncCall, intr: object, reason: str
) -> None {
    for e in self.errors_had {
        if (
            e.code is E5095
            and e.loc.mod_path == nd.loc.mod_path
            and e.loc.first_line == nd.loc.first_line
            and e.loc.col_start == nd.loc.col_start
        ) {
            return;
        }
    }
    self.emit(E5095, node_override=nd, name=intr.name, reason=reason);
}

impl NaIRGenCalls._emit_intrinsic_rc_runtime(
    nd: uni.FuncCall, intr: object, args: list
) -> (ir.Value | None) {
    if intr.gc_mode_gate is not None and self._gc_mode() != intr.gc_mode_gate {
        return None;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    self.builder.call(self.llvm_module.get_global(intr.name), []);
    return None;
}

impl NaIRGenCalls._emit_intrinsic_float_bits(
    nd: uni.FuncCall, intr: object, args: list
) -> (ir.Value | None) {
    arg_val = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    if arg_val is None {
        return None;
    }
    return self.builder.bitcast(arg_val, ir.IntType(64), name="float_bits");
}

impl NaIRGenCalls._emit_intrinsic_bits_float(
    nd: uni.FuncCall, intr: object, args: list
) -> (ir.Value | None) {
    arg_val = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    if arg_val is None {
        return None;
    }
    return self.builder.bitcast(arg_val, ir.DoubleType(), name="bits_float");
}

impl NaIRGenCalls._codegen_call(nd: uni.FuncCall) -> (ir.Value | None) {
    import from jaclang.compiler.symbol_utils {
        erased_field_marker_default,
        erased_field_marker_factory,
        erased_identity_call_arg,
        is_erased_field_marker
    }

    _identity_arg = erased_identity_call_arg(nd);
    if _identity_arg is not None {
        return self._codegen_expr(_identity_arg);
    }

    if is_erased_field_marker(nd) {
        _marker_default = erased_field_marker_default(nd);
        _factory_expr = erased_field_marker_factory(nd);
        _factory = (
            _factory_expr.value
                if isinstance(_factory_expr, (uni.Name, uni.BuiltinType))
                else None
        );
        if _factory in ("list", "set", "dict") {
            _hv = nd.parent;
            _ctype = (
                _hv.type
                    if isinstance(_hv, uni.HasVar) and _hv.type is not None
                    else nd.type
            );
            return self._empty_container_of_type(_ctype, _factory, nd);
        }
        if _marker_default is not None {
            return self._codegen_expr(_marker_default);
        }
        if _factory_expr is not None {
            return self._codegen_expr(_factory_expr);
        }
        return None;
    }

    _call_kind = nd.call_kind;
    _mod_qual: (str | None) = None;
    func_name: (str | None) = None;
    if _call_kind == "method" {
        return self._codegen_method_call(nd);
    }
    if _call_kind == "module_function" {
        _mod_qual = self._module_call_qualifier(nd);
        if (
            _mod_qual is None
            or _mod_qual not in self._native_module_imports
            or _mod_qual in self.local_vars
            or _mod_qual in self.struct_types
        ) {
            return self._codegen_method_call(nd);
        }
        func_name = self._get_name(nd.target.right);
        if func_name is None {
            raise AssertionError(
                f"module function call at {nd.loc} has no member name"
            );
        }
    } else {
        func_name = self._get_name(nd.target);
    }

    if _call_kind == "intrinsic" {
        import from jaclang.compiler.intrinsic_registry { INTRINSIC_REGISTRY }
        _intrinsic_entry = INTRINSIC_REGISTRY.get(func_name);
        if _intrinsic_entry is None {
            raise AssertionError(
                f"call at {nd.loc} is classified intrinsic but '{func_name}' is not registered"
            );
        }
        return self._codegen_intrinsic(nd, _intrinsic_entry);
    }

    _tt = self._tb_solve(nd.target.type);
    _cls_form = (
        isinstance(_tt, ClassType) and _tt._shared is not None and not _tt.is_instance()
    );
    if _cls_form and _tt.shared.is_enum_class {
        _ec_name = self._tb_class_name(_tt);
        if _ec_name is not None and self._enum_ctor_layout(_ec_name) is not None {
            return self._codegen_enum_ctor(nd, _ec_name);
        }
    }

    _callee_t = nd.target.type;
    if isinstance(_callee_t, ClassType)
        and _callee_t.private.distinct_key is not None {
        _cast_params = nd.params or [];
        if len(_cast_params) == 1 {
            _cast_arg = self._codegen_expr(_cast_params[0]);
            if _cast_arg is not None {
                _cast_res = self._dispatch_builtin(
                    _callee_t.shared.class_name,
                    [_cast_arg],
                    kwargs=self._split_call_kwargs(nd),
                    kw_node=nd,
                    type_key=(
                        self._mangled_of(self._flow_narrowed_type_of(_cast_params[0]))
                        or ""
                    )
                );
                self._release_owned_args([_cast_arg], op="distinct_cast_arg");
                if _cast_res is not None {
                    return _cast_res;
                }
            }
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="distinct cast",
            name=func_name or _callee_t.shared.class_name
        );
        return None;
    }

    if _call_kind == "builtin" {
        return self._codegen_builtin_call(nd);
    }

    if _cls_form and not _tt.shared.is_enum_class {
        _cls = self._tb_class_name(_tt);
        if _cls is not None and _cls in self.struct_types {
            return self._codegen_instantiation(nd, type_name_override=_cls);
        }
        if _call_kind == "instantiation" {
            self.emit(
                E5092,
                node_override=nd,
                kind="constructor",
                name=_cls or func_name,
                help_text="This class has no native layout visible to this module, so its constructor cannot lower here."
            );
            return None;
        }
    }
    if (
        func_name in self._native_skipped_methods and func_name not in self.generic_fns
    ) {
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=func_name,
            help_text=f"'{func_name}' demoted to its Python-only implementation "
            f"(native seam), so a native caller cannot reach it; hoist the "
            f"blocking construct out of '{func_name}' or move this caller off "
            f"the native pathway."
        );
        return None;
    }
    _dec_entry = self.decorated_fns.get(func_name);
    if _dec_entry is not None and _dec_entry[4] is nd.callee_decl {
        return self._codegen_decorated_call(nd, func_name);
    }
    func = self._callee_function(nd, func_name);
    if func is None {
        manifest = self.ir_in.gen.interop_manifest;
        binding = manifest.bindings.get(func_name);
        _src_ab: (uni.Ability | None) = nd.callee_decl;
        if _src_ab is None
            and binding is not None
            and isinstance(binding.ast_node, uni.Ability) {
            _src_ab = binding.ast_node;
        }
        if binding is not None
            and _src_ab is not None
            and _src_ab.type_params
            and func_name not in self.generic_fns {
            self.generic_fns[func_name] = _src_ab;
        }
        if binding is not None
            and func_name not in self.generic_fns
            and (
                binding.source_context.value == "server"
                or (
                    binding.source_context.value == "native"
                    and binding.source_module is not None
                )
            ) {
            _ext_fn = nd.resolved_callee;
            if _ext_fn is None or _ext_fn.parameters is None {
                self.emit(
                    E5092, node_override=nd, kind="function signature", name=func_name
                );
                return None;
            }
            import from jaclang.compiler.type_system.types { ParamKind }
            for _ep in _ext_fn.parameters {
                if _ep.param_kind in (ParamKind.VARARG, ParamKind.KWARG) {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="function",
                        name=func_name,
                        help_text="A variadic function cannot be called across the native interop boundary yet; wrap it in a fixed-arity function on the defining side."
                    );
                    return None;
                }
            }
            param_ir_types: list = [];
            for _ep in _ext_fn.parameters {
                _ept = self._lower_type(_ep.param_type);
                if _ept is None {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="function signature",
                        name=f"{func_name} parameter '{_ep.name}' ({_ep.param_type})"
                    );
                    return None;
                }
                param_ir_types.append(_ept);
            }
            ret_ir_type = self._lower_type(_ext_fn.return_type);
            if ret_ir_type is None {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="function signature",
                    name=f"{func_name} return type ({_ext_fn.return_type})"
                );
                return None;
            }
            func = self._get_or_declare_extern(func_name, ret_ir_type, param_ir_types);
        }
    }
    if func is None and func_name in self.generic_fns {
        func = self._instantiate_generic(nd, func_name);
        if func is None {
            return None;
        }
    }
    if func is None {
        if func_name in self.local_vars {
            _alloca = self.local_vars[func_name];
            _loaded = self.builder.load(_alloca, name=f"fptr.{func_name}");
            _clos_name = self._closure_struct_of(_loaded.type);
            if _clos_name is not None {
                return self._codegen_closure_call(nd, _loaded, _clos_name);
            }
            if (
                isinstance(_loaded.type, ir.PointerType)
                and isinstance(_loaded.type.pointee, ir.FunctionType)
            ) {
                _fn_type = _loaded.type.pointee;
                _iargs: list[ir.Value] = [];
                _iarg_tys: list = [];
                _iparams = nd.params or [];
                for _ip in _iparams {
                    _iv = self._codegen_expr(_ip);
                    if _iv is not None {
                        _iargs.append(_iv);
                        _iarg_tys.append(
                            self._expr_type_of(
                                _ip.value if isinstance(_ip, uni.KWPair) else _ip
                            )
                        );
                    }
                }
                _icoerced: list[ir.Value] = [];
                for (_ii, _ia) in enumerate(_iargs) {
                    if _ii < len(_fn_type.args) {
                        _icoerced.append(
                            self._coerce_type(_ia, _fn_type.args[_ii], _iarg_tys[_ii])
                        );
                    } else {
                        _icoerced.append(_ia);
                    }
                }

                if func_name in self.lambda_captures {
                    for (_cname, _c_alloca) in self.lambda_captures[func_name] {
                        _cval = self.builder.load(_c_alloca, name=f"cap.{_cname}");
                        _icoerced.append(_cval);
                    }
                }
                _icall_result = self.builder.call(
                    _loaded, _icoerced, name=f"icall.{func_name}"
                );
                self._release_owned_args(_iargs, op="icall_arg");
                return _icall_result;
            }
        }

        if func_name in self.global_vars {
            _gvar = self.global_vars[func_name];
            _gloaded = self.builder.load(_gvar, name=f"fptr.{func_name}");
            _gclos_name = self._closure_struct_of(_gloaded.type);
            if _gclos_name is not None {
                return self._codegen_closure_call(nd, _gloaded, _gclos_name);
            }
        }

        self.emit(E5092, node_override=nd, kind="function", name=func_name);
        return None;
    }

    args: list[ir.Value] = self._codegen_bound_args(nd, func, self_offset=0);

    if _call_kind == "clib" and func_name in self.clib_fn_abi {
        return self._codegen_clib_call(func, func_name, args);
    }

    _is_foreign = _call_kind == "clib" and func_name in self.clib_extern_names;
    coerced: list[ir.Value] = [];

    _clib_str_args: set = set();
    _clib_str_ret = False;
    _clib_ret_struct: (str | None) = None;
    if _is_foreign {
        import from jaclang.compiler.targets.foreign { declared_type_name }
        _clib_decl = nd.callee_decl;
        _clib_sig = _clib_decl.signature if _clib_decl is not None else None;
        if isinstance(_clib_sig, uni.FuncSignature) {
            for (_ci, _cp) in enumerate(_clib_sig.get_parameters()) {
                if _cp.type_tag is not None
                    and declared_type_name(_cp.type_tag.tag) == "str" {
                    _clib_str_args.add(_ci);
                }
            }
            _clib_ret_name = declared_type_name(_clib_sig.return_type);
            _clib_str_ret = _clib_ret_name == "str";
            if _clib_ret_name in self.clib_struct_names {
                _clib_ret_struct = _clib_ret_name;
            }
        }
    }
    release_args: list[ir.Value] = [];
    _i8ptr = ir.IntType(8).as_pointer();
    for (i, arg) in enumerate(args) {
        if (
            _is_foreign
            and self._is_bytes_value(arg)
            and i < len(func.args)
            and (func.args[i].type == _i8ptr or self._is_bytes_type(func.args[i].type))
        ) {
            coerced.append(
                self._bytes_data_ptr(arg) if func.args[i].type == _i8ptr else arg
            );
            release_args.append(arg);
        } elif (
            _is_foreign
            and i in _clib_str_args
            and i < len(func.args)
            and func.args[i].type == _i8ptr
            and isinstance(arg.type, ir.PointerType)
        ) {
            coerced.append(self._membrane_str_out(self.builder, arg));
            release_args.append(arg);
        } elif i < len(func.args) {
            _c = self._coerce_type(arg, func.args[i].type);
            coerced.append(_c);
            release_args.append(_c);
        } else {
            coerced.append(arg);
            release_args.append(arg);
        }
    }
    if self._nogc_headerless() {
        release_args = self._nogc_owned_release_args(nd, release_args);
    }
    if not self._call_args_lowered(nd, func, func_name, coerced) {
        return None;
    }
    result = self.builder.call(func, coerced, name=f"call.{func_name}");
    if _is_foreign {
        result = self._clib_sext_ret(func_name, result);
        if _clib_str_ret and isinstance(result.type, ir.PointerType) {
            result = self._membrane_str_in(self.builder, result);
        }
    }

    self._release_owned_args(release_args, op="call_arg");

    if _is_foreign and _clib_ret_struct is not None {
        _abi_type = self.clib_struct_abi_types.get(_clib_ret_struct);
        _struct_ptr = self.struct_types[_clib_ret_struct].as_pointer();
        if _abi_type is not None and result.type == _abi_type {
            result = self._coerce_type(result, _struct_ptr);
        } elif not isinstance(result.type, ir.PointerType)
            and result.type == self.struct_types[_clib_ret_struct] {
            result = self._coerce_type(result, _struct_ptr);
        }
    }

    return result;
}

impl NaIRGenCalls._nogc_owned_release_args(
    nd: uni.FuncCall, release_args: list
) -> list {
    _skip_own: set = set();
    _is_ctor = nd.call_kind == "instantiation";
    _callee = nd.resolved_callee;
    _params = list(_callee.parameters or []) if _callee is not None else [];
    if _is_ctor {
        for _oi in range(len(release_args)) {
            _skip_own.add(_oi);
        }
    } elif _params and len(_params) == len(release_args) {
        for (_oi, _op) in enumerate(_params) {
            if _op.ownership == OwnershipKind.OWN {
                _skip_own.add(_oi);
            }
        }
    }
    if not _skip_own {
        return release_args;
    }
    _kept: list = [];
    for (_ri, _rv) in enumerate(release_args) {
        if _ri not in _skip_own {
            _kept.append(_rv);
        }
    }
    _param_idx: dict = {};
    for (_pi2, _p2) in enumerate(_params) {
        _param_idx[id(_p2)] = _pi2;
    }
    for _pa in (nd.params or []) {
        _bound = (nd.arg_params or {}).get(_pa);
        _aidx = _param_idx.get(id(_bound), -1) if _bound is not None else -1;
        _anode = _pa.value if isinstance(_pa, uni.KWPair) else _pa;
        if not (_is_ctor or _aidx in _skip_own) {
            continue;
        }
        if not isinstance(_anode, uni.Name) {
            continue;
        }
        _salloca = self.local_vars.get(_anode.sym_name);
        if _salloca is not None
            and isinstance(_salloca.type, ir.PointerType)
            and isinstance(_salloca.type.pointee, ir.PointerType) {
            self.builder.store(ir.Constant(_salloca.type.pointee, None), _salloca);
        }
    }
    return _kept;
}

impl NaIRGenCalls._jacval_tags_for_kind(kind: str) -> list[int] {
    _tags: dict = {
        "int": [0, 7],
        "bool": [7],
        "float": [1],
        "str": [2],
        "list": [3],
        "dict": [4],
        "set": [5],
        "none": [8]
    };
    return list(_tags.get(kind, []));
}

impl NaIRGenCalls._isinstance_static_verdict(
    kind: str, operand_t: any
) -> (bool | None) {
    """Answer the arms whose native representation carries no JacVal tag.

    A native tuple is an unboxed literal struct and a `bytes` / `bytearray` is
    a pointer to its own runtime struct, so none of the three is reachable
    through a tag compare -- but each is fully decided by the operand's
    declared type. Returning `True`/`False` settles that arm at compile time;
    `None` means the arm is not one of these (or the operand is a union that
    only partly inhabits it) and falls through to the tag and vtable machinery.
    """;
    if kind not in ("tuple", "bytes", "bytearray") {
        return None;
    }
    _kinds = {self._tb_kind(m) for m in self._tb_non_none(operand_t)};
    if not _kinds {
        return None;
    }
    if kind not in _kinds {
        return False;
    }
    return True if len(_kinds) == 1 else None;
}

impl NaIRGenCalls._isinstance_abc_reduction(t: any, name: str) -> (list[str] | None) {
    """The native shapes an `isinstance` arm naming a stdlib ABC reduces to.

    A `collections.abc` class is a Python object no native unit can host, so a
    check against one is only answerable by reducing it to the finite set of
    native runtime shapes that inhabit it. `_NA_ABC_REDUCTIONS` holds the
    reductions that are exact rather than approximate: every entry is a
    container ABC whose members, among values a native unit can hold, are
    precisely the listed builtins. Protocol-shaped ABCs are deliberately absent
    -- an archetype with `__iter__` inhabits `Iterable` too, so a builtin-only
    answer there would be silently wrong. Those sit in `_NA_ABC_OPAQUE`.

    `None` means the arm is not a stdlib ABC and the caller should treat it as
    it always has. An empty list means it is one this backend refuses to guess
    at, and the caller turns that into a diagnostic rather than an answer.
    """;
    if name in self.struct_types or name in self.enum_types {
        return None;
    }
    if not isinstance(t, ClassType) or t._shared is None {
        return None;
    }
    if not t.shared.is_from_stdlib_stub {
        return None;
    }
    cn = t.shared.class_name;
    if cn in _NA_ABC_REDUCTIONS {
        return list(_NA_ABC_REDUCTIONS[cn]);
    }
    if cn in _NA_ABC_OPAQUE {
        return [];
    }
    return None;
}

impl NaIRGenCalls._isinstance_arm_class(v: uni.UniNode) -> any {
    """The class an `isinstance` arm names, as the instance-form ClassType.

    The arm's expression is typed `type[X]` by the checker (a class-form
    ClassType, or the builtin `type` specialised on X); a `type[T]` over a
    generic parameter resolves through the active mono solution.
    """;
    if (
        isinstance(v, uni.FuncCall)
        and v.call_kind == "builtin"
        and self._get_name(v.target) == "type"
        and v.params
        and len(v.params) == 1
        and isinstance(v.params[0], uni.Null)
    ) {
        return self._tb_solve(v.params[0].type);
    }
    t = v.type if isinstance(v, uni.Expr) else None;
    t = self._tb_solve(t);
    if isinstance(t, ClassType) and t._shared is not None and t.is_builtin("type") {
        _targs = t.private.type_args or [];
        t = self._tb_solve(_targs[0]) if _targs else None;
    }
    if isinstance(t, EnumMemberType) {
        t = t.enum_class;
    }
    if isinstance(t, ClassType) and t._shared is not None and not t.is_instance() {
        return t.clone_as_instance();
    }
    return t;
}

impl NaIRGenCalls._isinstance_target_names(
    nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
) -> (list[str] | None) {
    """Flatten the type argument into the type names the check has to test.

    A tuple argument contributes each of its arms; a stdlib ABC arm expands to
    the native shapes it reduces to, and keeps its own name too whenever some
    archetype names it in an MRO, so a user type registered under the ABC still
    answers through the vtable arm. `None` means a diagnostic was emitted.
    """;
    raw: list = list(type_arg.values or [])
        if isinstance(type_arg, uni.TupleVal)
        else [type_arg];
    pyb_operand = self._isinstance_operand_is_pyb(nd, operand);
    names: list[str] = [];
    for v in raw {
        _cls = self._isinstance_arm_class(v);
        nm = self._tb_class_name(_cls);
        if nm is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="builtin call",
                name="isinstance against a runtime class value",
                help_text=f"The class arm is typed `{v.type
                    if isinstance(v, uni.Expr)
                    else None}` rather than `type[X]`; only statically named classes (or a runtime class tuple over a pointer operand) lower natively."
            );
            return None;
        }
        reduced = self._isinstance_abc_reduction(_cls, nm);
        if reduced is None {
            if nm not in names {
                names.append(nm);
            }
            continue;
        }
        if not reduced or pyb_operand {
            self.emit(
                E5092,
                node_override=nd,
                kind="builtin call",
                name=f"isinstance against `{nm}`",
                help_text=(
                    "This operand's class inherits a Python-side base, so which abstract base classes it inhabits is decided by an MRO this native unit only holds a shadow handle to. Test the concrete type instead (`list`, `dict`, an archetype), or move the code to a @sv/Python context."
                        if pyb_operand
                        else "This abstract base class has no exact answer over native values -- an archetype can inhabit it without naming it, so a native check would have to guess. Test the concrete type instead (`list`, `dict`, an archetype), or move the code to a @sv/Python context."
                )
            );
            return None;
        }
        for _b in reduced {
            if _b not in names {
                names.append(_b);
            }
        }
        if nm not in names and self._vtable_candidates([nm]) {
            names.append(nm);
        }
    }
    return names;
}

impl NaIRGenCalls._isinstance_name_kinds(
    type_arg: uni.UniNode, names: list[str]
) -> dict {
    """Map each target name to the native kind its class lowers as.

    Names produced by an ABC reduction are builtin container names whose kind
    is the name itself; every other name came from a typed arm.
    """;
    raw: list = list(type_arg.values or [])
        if isinstance(type_arg, uni.TupleVal)
        else [type_arg];
    kinds: dict = {};
    for v in raw {
        _cls = self._isinstance_arm_class(v);
        nm = self._tb_class_name(_cls);
        if nm is not None {
            kinds[nm] = self._tb_kind(_cls);
        }
    }
    _builtin_kinds: dict = {
        "list": "list",
        "tuple": "tuple",
        "str": "str",
        "bytes": "bytes",
        "bytearray": "bytearray",
        "dict": "dict",
        "set": "set",
        "frozenset": "set"
    };
    for nm in names {
        if nm not in kinds {
            kinds[nm] = _builtin_kinds.get(nm, "object");
        }
    }
    return kinds;
}

impl NaIRGenCalls._emit_isinstance(nd: uni.FuncCall) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    params = nd.params or [];
    if len(params) < 2 {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    operand = self._codegen_expr(params[0]);
    if operand is None {
        return None;
    }
    if self._opt_payload_of(operand.type) is None {
        if not isinstance(operand.type, ir.PointerType) {
            return self._emit_isinstance_core(nd, operand);
        }

        _nn_fn = self.builder.block.function;
        _nn_bb = _nn_fn.append_basic_block("isinst.nn");
        _nn_done_bb = _nn_fn.append_basic_block("isinst.nn.done");
        _nn_ok = self.builder.icmp_unsigned(
            "!=", operand, ir.Constant(operand.type, None), name="isinst.nonnull"
        );
        _nn_entry = self.builder.block;
        self.builder.cbranch(_nn_ok, _nn_bb, _nn_done_bb);
        self.builder.position_at_end(_nn_bb);
        _nn_inner = self._emit_isinstance_core(nd, operand);
        _nn_inner_bb = self.builder.block;
        self.builder.branch(_nn_done_bb);
        self.builder.position_at_end(_nn_done_bb);
        if _nn_inner is None {
            return None;
        }
        _nn_res = self.builder.phi(i1, name="isinst.nn.res");
        _nn_res.add_incoming(ir.Constant(i1, 0), _nn_entry);
        _nn_res.add_incoming(_nn_inner, _nn_inner_bb);
        return _nn_res;
    }
    fn = self.builder.block.function;
    some_bb = fn.append_basic_block("isinst.opt.some");
    done_bb = fn.append_basic_block("isinst.opt.done");
    opt_tag = self.builder.extract_value(operand, 0, name="isinst.opt.tag");
    opt_set = self.builder.icmp_signed(
        "!=", opt_tag, ir.Constant(i8, 0), name="isinst.opt.set"
    );
    payload = self.builder.extract_value(operand, 1, name="isinst.opt.val");
    entry_bb = self.builder.block;
    self.builder.cbranch(opt_set, some_bb, done_bb);
    self.builder.position_at_end(some_bb);
    inner = self._emit_isinstance_core(nd, payload);
    inner_bb = self.builder.block;
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
    if inner is None {
        return None;
    }
    res = self.builder.phi(i1, name="isinst.opt.res");
    res.add_incoming(ir.Constant(i1, 0), entry_bb);
    res.add_incoming(inner, inner_bb);
    return res;
}

impl NaIRGenCalls._emit_isinstance_core(
    nd: uni.FuncCall, operand: ir.Value
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    params = nd.params or [];

    type_arg = params[1];
    if not isinstance(type_arg, uni.TupleVal) {
        _rt_res = self._emit_isinstance_runtime(nd, operand, type_arg);
        if _rt_res is not None {
            return _rt_res;
        }
    }
    names = self._isinstance_target_names(nd, operand, type_arg);
    if names is None {
        return None;
    }
    _name_kinds = self._isinstance_name_kinds(type_arg, names);
    _operand_t = self._flow_narrowed_type_of(params[0]);
    _short = self._isinstance_unprovable_class(
        names, self._isinstance_operand_arch(nd, operand)
    );
    if _short is not None {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name=f"isinstance against `{'`, `'.join(names)}`",
            help_text=(
                f"`{_short}` subclasses a class another module defines, so this unit linearized it from a base whose own bases it could not see yet -- its ancestor chain stops one link short of the classes named here, and answering from it is how a check reports `False` for a base the operand genuinely derives from. Test the concrete class instead, or declare `{_short}` in the module that defines its base."
            )
        );
        return None;
    }
    tags: list[int] = [];
    unresolved: list[str] = [];
    static_seen = False;
    static_hit = False;
    for nm in names {
        _nk = _name_kinds.get(nm, "object");
        verdict = self._isinstance_static_verdict(_nk, _operand_t);
        if verdict is not None {
            static_seen = True;
            static_hit = static_hit or verdict;
            continue;
        }
        nm_tags = self._jacval_tags_for_kind(_nk);
        if not nm_tags {
            unresolved.append(nm);
        }
        for t in nm_tags {
            if t not in tags {
                tags.append(t);
            }
        }
    }
    if static_hit {
        self._release_owned_args([operand], op="isinstance_arg");
        return ir.Constant(i1, 1);
    }
    if unresolved {
        (_enum_tags, unresolved) = self._enum_union_tags(params[0], unresolved);
        for _et in _enum_tags {
            if _et not in tags {
                tags.append(_et);
            }
        }
    }
    if unresolved {
        if not tags {
            return self._emit_isinstance_user(nd, operand, unresolved);
        }
        return self._emit_isinstance_mixed(nd, operand, tags, unresolved);
    }
    if not tags {
        if static_seen {
            self._release_owned_args([operand], op="isinstance_arg");
            return ir.Constant(i1, 0);
        }
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    if isinstance(operand.type, ir.PointerType) {
        _pt_res = self._emit_isinstance_ptr_tags(operand, tags);
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return _pt_res;
    }
    boxed = self._box_to_jacval(
        operand, ty=self._expr_type_of(nd.params[0]) if nd.params else None
    );
    tag = self.builder.extract_value(boxed, 0, name="isinst.tag");
    result: (ir.Value | None) = None;
    for t in sorted(tags) {
        cmp = self.builder.icmp_unsigned(
            "==", tag, ir.Constant(i8, t), name="isinst.cmp"
        );
        result = cmp
            if result is None
            else self.builder.or_(result, cmp, name="isinst.or");
    }
    self._release_owned_args([operand], op="isinstance_arg");
    return result;
}

impl NaIRGenCalls._isinstance_operand_is_pyb(
    nd: uni.FuncCall, operand: ir.Value
) -> bool {
    """Does the operand's class reach its bases through the Python bridge?

    A class with a Python-side base carries an MRO this unit never modelled --
    `PyBase(ABC)` in the interop fixtures is exactly that shape -- so which
    abstract base classes such an instance inhabits is not answerable from the
    native layout. Only the reduction cares: an archetype arm still answers
    through the vtable, whose MRO covers the layout-trusted bases.
    """;
    arch = self._isinstance_operand_arch(nd, operand);
    if arch is None {
        return False;
    }
    for cand in self._mro_of(arch) {
        if self._pyb_base_of(cand) is not None {
            return True;
        }
    }
    return False;
}

impl NaIRGenCalls._enum_union_tags(
    operand_expr: uni.UniNode, names: list[str]
) -> tuple {
    t = operand_expr.type if isinstance(operand_expr, uni.Expr) else None;
    members: list = [];
    if isinstance(t, UnionType) {
        members = list(t.types or []);
    } elif t is not None {
        members = [t];
    }
    if not members {
        return ([], names, );
    }
    member_rows: list = [];
    _kind_tags: dict = {
        "none": [8],
        "bool": [7],
        "int": [0, 7],
        "float": [1],
        "str": [2],
        "list": [3, 4, 5],
        "dict": [3, 4, 5],
        "set": [3, 4, 5],
        "tuple": [3, 4, 5]
    };
    for m in members {
        cn = self._tb_class_name(m);
        if cn is None {
            return ([], names, );
        }
        _mk = self._tb_kind(m);
        if _mk == "enum" {
            member_rows.append((cn, True, [0], ));
        } else {
            member_rows.append((cn, False, _kind_tags.get(_mk, [6]), ));
        }
    }
    resolved: list[int] = [];
    still: list[str] = [];
    for nm in names {
        hit = False;
        for row in member_rows {
            if row[0] == nm and row[1] {
                clash = False;
                for other in member_rows {
                    if other[0] != nm and (0 in other[2]) {
                        clash = True;
                        break;
                    }
                }
                hit = not clash;
                break;
            }
        }
        if hit {
            if 0 not in resolved {
                resolved.append(0);
            }
        } else {
            still.append(nm);
        }
    }
    return (resolved, still, );
}

impl NaIRGenCalls._emit_isinstance_ptr_tags(
    operand: ir.Value, tags: list[int]
) -> ir.Value {
    i1 = ir.IntType(1);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();

    _prefixes: dict[int, str] = {3: "list_", 4: "dict_", 5: "set_"};
    if 6 in tags {
        return ir.Constant(i1, 1);
    }
    _want = [
        t
        for t in sorted(tags)
        if t in _prefixes
    ];
    if not _want {
        return ir.Constant(i1, 0);
    }
    b = self.builder;
    raw = b.bitcast(operand, i8p, name="isinst.hdr.raw");
    fn = b.block.function;
    pre_bb = b.block;
    tag_bb = fn.append_basic_block("isinst.hdr.tag");
    cmp_bb = fn.append_basic_block("isinst.hdr.cmp");
    done_bb = fn.append_basic_block("isinst.hdr.done");
    magic_ok = self._emit_magic_check(b, raw, name_prefix="isinst.mc");
    b.cbranch(magic_ok, tag_bb, done_bb);

    b.position_at_end(tag_bb);
    tag_slot = b.gep(raw, [ir.Constant(i64, HDR_TAG_OFF)], name="isinst.tag.slot");
    tag_pp = b.bitcast(tag_slot, i8p.as_pointer(), name="isinst.tag.pp");
    tag_ptr = b.load(tag_pp, name="isinst.tag.name");
    tag_nn = b.icmp_unsigned(
        "!=", tag_ptr, ir.Constant(i8p, None), name="isinst.tag.nn"
    );
    b.cbranch(tag_nn, cmp_bb, done_bb);

    b.position_at_end(cmp_bb);
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    matched: (ir.Value | None) = None;
    for t in _want {
        pfx = _prefixes[t];
        pfx_gv = self._get_snprintf_fmt(pfx);
        pfx_ptr = b.gep(
            pfx_gv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.pfx"
        );
        cmp_res = b.call(
            memcmp_fn,
            [tag_ptr, pfx_ptr, ir.Constant(i64, len(pfx))],
            name="isinst.memcmp"
        );
        eq = b.icmp_signed("==", cmp_res, ir.Constant(i32, 0), name="isinst.pfx.eq");
        matched = eq if matched is None else b.or_(matched, eq, name="isinst.pfx.or");
    }
    cmp_end_bb = b.block;
    b.branch(done_bb);

    b.position_at_end(done_bb);
    res = b.phi(i1, name="isinst.hdr.res");
    res.add_incoming(ir.Constant(i1, 0), pre_bb);
    res.add_incoming(ir.Constant(i1, 0), tag_bb);
    res.add_incoming(matched, cmp_end_bb);
    return res;
}

impl NaIRGenCalls._emit_isinstance_mixed(
    nd: uni.FuncCall, operand: ir.Value, tags: list[int], names: list[str]
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);

    _by_name = self._isinstance_needs_class_name(names);
    if _by_name and self._nogc_headerless() {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    target_vtables = [] if _by_name else self._vtable_candidates(names);
    if not _by_name and not target_vtables {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    boxed = self._box_to_jacval(
        operand, ty=self._expr_type_of(nd.params[0]) if nd.params else None
    );
    tag = self.builder.extract_value(boxed, 0, name="isinst.tag");
    payload = self.builder.extract_value(boxed, 1, name="isinst.payload");

    prim: (ir.Value | None) = None;
    for t in sorted(tags) {
        cmp = self.builder.icmp_unsigned(
            "==", tag, ir.Constant(i8, t), name="isinst.cmp"
        );
        prim = cmp if prim is None else self.builder.or_(prim, cmp, name="isinst.or");
    }
    if prim is None {
        prim = ir.Constant(i1, 0);
    }

    pre_bb = self.builder.block;
    obj_bb = self.builder.append_basic_block(name="isinst.mix.obj");
    load_bb = self.builder.append_basic_block(name="isinst.mix.load");
    merge_bb = self.builder.append_basic_block(name="isinst.mix.merge");
    is_obj = self.builder.icmp_unsigned(
        "==", tag, ir.Constant(i8, 6), name="isinst.isobj"
    );
    self.builder.cbranch(is_obj, obj_bb, merge_bb);

    self.builder.position_at_end(obj_bb);
    is_null = self.builder.icmp_signed(
        "==", payload, ir.Constant(payload.type, 0), name="isinst.mix.null"
    );
    self.builder.cbranch(is_null, merge_bb, load_bb);

    self.builder.position_at_end(load_bb);
    user_or: (ir.Value | None) = None;
    if _by_name {
        user_or = self._isinstance_class_name_hit(
            self.builder.inttoptr(payload, i8.as_pointer(), name="isinst.mix.obj"),
            names
        );
        if user_or is None {
            self._emit_unsupported_builtin_call(nd, "isinstance");
            return None;
        }
    } else {
        i8_pp = i8.as_pointer().as_pointer();
        slot_pp = self.builder.inttoptr(
            payload, i8_pp.as_pointer(), name="isinst.mix.slot"
        );
        vptr = self.builder.load(slot_pp, name="isinst.mix.vptr");
        for vt in target_vtables {
            vt_base = self.builder.gep(
                vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.mix.vt"
            );
            eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="isinst.mix.eq");
            user_or = eq
                if user_or is None
                else self.builder.or_(user_or, eq, name="isinst.mix.uor");
        }
    }
    end_load = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    result = self.builder.phi(i1, name="isinst.mix.result");
    result.add_incoming(prim, pre_bb);
    result.add_incoming(ir.Constant(i1, 0), obj_bb);
    result.add_incoming(user_or, end_load);
    self._release_owned_args([operand], op="isinstance_arg");
    return result;
}

impl NaIRGenCalls._emit_isinstance_user(
    nd: uni.FuncCall, operand: ir.Value, names: list[str]
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);

    if not isinstance(operand.type, ir.PointerType) {
        if self?.jacval_type and operand.type == self.jacval_type {
            return self._emit_isinstance_mixed(nd, operand, [], names);
        }
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    if self._isinstance_needs_class_name(names) {
        _nm_hit = (
            None
                if self._nogc_headerless()
                else self._isinstance_class_name_hit(operand, names)
        );
        if _nm_hit is None {
            self._emit_unsupported_builtin_call(nd, "isinstance");
            return None;
        }
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return _nm_hit;
    }

    target_vtables = self._vtable_candidates(names);
    if not target_vtables {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    struct_name = self._struct_name_of(nd.params[0] if nd.params else None);
    if (
        struct_name is not None
        and struct_name in self.struct_types
        and not self._arch_has_vtable(struct_name)
    ) {
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return ir.Constant(i1, 0);
    }

    pre_bb = self.builder.block;
    null_ptr = ir.Constant(operand.type, None);
    is_null = self.builder.icmp_unsigned(
        "==", operand, null_ptr, name="isinst.null.chk"
    );
    nonnull_bb = self.builder.append_basic_block(name="isinst.nonnull");
    merge_bb = self.builder.append_basic_block(name="isinst.merge");
    self.builder.cbranch(is_null, merge_bb, nonnull_bb);

    self.builder.position_at_end(nonnull_bb);
    i8_pp = i8.as_pointer().as_pointer();
    op_as = self.builder.bitcast(operand, i8_pp.as_pointer(), name="isinst.obj");
    vptr = self.builder.load(op_as, name="isinst.vptr");
    cmp: (ir.Value | None) = None;
    for vt in target_vtables {
        vt_base = self.builder.gep(
            vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.vt.base"
        );
        eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="isinst.eq");
        cmp = eq if cmp is None else self.builder.or_(cmp, eq, name="isinst.or");
    }

    if self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    end_nonnull = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    result = self.builder.phi(i1, name="isinst.result");
    result.add_incoming(ir.Constant(i1, 0), pre_bb);
    result.add_incoming(cmp, end_nonnull);
    return result;
}

impl NaIRGenCalls._flow_future_licensed(nd: uni.ConcurrentExpr) -> (uni.Name | None) {
    import from jaclang.jac0core.constant { Tokens as Tok }
    asgn = nd.parent;
    if not (
        isinstance(asgn, uni.Assignment)
        and asgn.value is nd
        and asgn.aug_op is None
        and len(asgn.target) == 1
        and isinstance(asgn.target[0], uni.Name)
    ) {
        return None;
    }
    h = asgn.target[0];
    if h.sym is None {
        return None;
    }
    _fn = asgn.find_parent_of_type(uni.Ability);
    _scope = _fn if _fn is not None else asgn.find_parent_of_type(uni.ModuleCode);
    if _scope is None {
        return None;
    }
    _spawn_loop = (
        asgn.find_parent_of_type(uni.InForStmt)
        or asgn.find_parent_of_type(uni.WhileStmt)
        or asgn.find_parent_of_type(uni.IterForStmt)
    );
    _waits = 0;
    for use in _scope.get_all_sub_nodes(uni.Name) {
        if use.sym is not h.sym or use is h {
            continue;
        }
        _p = use.parent;
        _use_loop = (
            use.find_parent_of_type(uni.InForStmt)
            or use.find_parent_of_type(uni.WhileStmt)
            or use.find_parent_of_type(uni.IterForStmt)
        );
        if isinstance(_p, uni.ConcurrentExpr)
            and _p.target is use
            and _p.tok is not None
            and _p.tok.name == Tok.KW_WAIT
            and _use_loop is _spawn_loop {
            _waits += 1;
            continue;
        }
        return None;
    }
    if _waits != 1 {
        return None;
    }
    return h;
}

impl NaIRGenCalls._try_flow_future(nd: uni.ConcurrentExpr) -> (ir.Value | None) {
    import from jaclang.jac0core.constant { Tokens as Tok }
    if nd.tok is None {
        return None;
    }
    _par_ok = (self.ir_in.gen.nogc_enforced and self._gc_mode() == "none")
        or (self._gc_mode() == "rc" and not self._rc_debug_codegen);
    if not _par_ok
        or "wasm" in str(self.llvm_module.triple)
        or self._gen_ctx is not None {
        return None;
    }
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8p = ir.IntType(8).as_pointer();
    if nd.tok.name == Tok.KW_WAIT {
        if not isinstance(nd.target, uni.Name) or nd.target.sym is None {
            return None;
        }
        _meta = self.flow_future_meta.get(id(nd.target.sym));
        if _meta is None {
            return None;
        }
        (fut_ty, res_ty) = _meta;
        _slot = self.local_vars.get(nd.target.sym_name);
        if _slot is None {
            _slot = self.global_vars.get(nd.target.sym_name);
        }
        if _slot is None {
            return None;
        }
        _hv = self.builder.load(_slot, name="fut.h");
        if isinstance(_hv.type, ir.DoubleType) {
            _hv = self.builder.bitcast(_hv, i64, name="fut.h.i");
        }
        if isinstance(_hv.type, ir.PointerType) {
            _fut = self.builder.bitcast(_hv, fut_ty.as_pointer(), name="fut.p");
        } else {
            _fut = self.builder.inttoptr(_hv, fut_ty.as_pointer(), name="fut.p");
        }
        _tid = self.builder.load(
            self.builder.gep(
                _fut, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="fut.tid.s"
            ),
            name="fut.tid"
        );
        _join_bb = self.builder.function.append_basic_block("fut.join");
        _done_bb = self.builder.function.append_basic_block("fut.done");
        self.builder.cbranch(
            self.builder.icmp_signed("!=", _tid, ir.Constant(i64, 0), name="fut.live"),
            _join_bb,
            _done_bb
        );
        self.builder.position_at_end(_join_bb);
        _pjoin = self._get_or_declare_extern("pthread_join", i32, [i64, i8p]);
        self.builder.call(_pjoin, [_tid, ir.Constant(i8p, None)]);
        self.builder.branch(_done_bb);
        self.builder.position_at_end(_done_bb);
        _res = self.builder.load(
            self.builder.gep(
                _fut, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="fut.res.s"
            ),
            name="fut.res"
        );
        _free = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        self.builder.call(_free, [self.builder.bitcast(_fut, i8p, name="fut.i8")]);
        if isinstance(res_ty, ir.PointerType) {
            self._mark_owned(_res);
        }
        return _res;
    }
    if nd.tok.name != Tok.KW_FLOW {
        return None;
    }
    call = nd.target;
    if not isinstance(call, uni.FuncCall) or not isinstance(call.target, uni.Name) {
        return None;
    }
    fname = call.target.sym_name;
    callee = self._callee_function(call, fname);
    if callee is None
        or not isinstance(callee, ir.Function)
        or call.call_kind == "clib" {
        return None;
    }
    _rc = call.resolved_callee;
    _res_ty = self._lower_type(_rc.return_type) if _rc is not None else None;
    if _res_ty is None or _res_ty != callee.function_type.return_type {
        return None;
    }
    _res_ok = (isinstance(_res_ty, ir.IntType) and _res_ty.width == 64)
        or isinstance(_res_ty, ir.DoubleType)
        or isinstance(_res_ty, ir.PointerType);
    if not _res_ok {
        return None;
    }
    h = self._flow_future_licensed(nd);
    if h is None {
        return None;
    }
    _argv: list = self._codegen_bound_args(call, callee, self_offset=0);
    if len(_argv) != len(callee.args) {
        return None;
    }
    _cargs: list = [];
    for (i, a) in enumerate(_argv) {
        _cargs.append(self._coerce_type(a, callee.args[i].type));
    }
    fut_ty = ir.LiteralStructType([i64, _res_ty] + [a.type for a in _cargs]);
    self._str_count += 1;
    _fid = self._str_count;
    _task_fn = ir.Function(
        self.llvm_module, ir.FunctionType(i8p, [i8p]), name=f"__jac_flow_task_{_fid}"
    );
    _task_fn.linkage = "private";
    _tb = ir.IRBuilder(_task_fn.append_basic_block("entry"));
    _tf = _tb.bitcast(_task_fn.args[0], fut_ty.as_pointer(), name="t.fut");
    _t_args: list = [];
    for i in range(len(_cargs)) {
        _t_args.append(
            _tb.load(
                _tb.gep(
                    _tf,
                    [ir.Constant(i32, 0), ir.Constant(i32, 2 + i)],
                    name=f"t.a{i}.s"
                ),
                name=f"t.a{i}"
            )
        );
    }
    _t_res = _tb.call(callee, _t_args, name="t.call");
    _tb.store(
        _t_res, _tb.gep(_tf, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="t.res.s")
    );
    if self._gc_mode() != "none" {
        _saved_b = self._builder;
        self._builder = _tb;
        for (i, a) in enumerate(_cargs) {
            if isinstance(a.type, ir.PointerType) {
                self._emit_rc_release_simple(_t_args[i], op="flow_arg", loc="");
            }
        }
        self._builder = _saved_b;
    }
    _tb.ret(ir.Constant(i8p, None));
    _malloc = self._get_or_declare_extern("malloc", i8p, [i64]);
    _sz = self.builder.ptrtoint(
        self.builder.gep(
            ir.Constant(fut_ty.as_pointer(), None),
            [ir.Constant(i32, 1)],
            name="fut.szp"
        ),
        i64,
        name="fut.sz"
    );
    _fut8 = self.builder.call(_malloc, [_sz], name="fut.raw");
    _fut = self.builder.bitcast(_fut8, fut_ty.as_pointer(), name="fut.new");
    for (i, a) in enumerate(_cargs) {
        if isinstance(a.type, ir.PointerType) and self._gc_mode() != "none" {
            self._emit_rc_retain(a, op="flow_arg", loc="");
        }
        self.builder.store(
            a,
            self.builder.gep(
                _fut, [ir.Constant(i32, 0), ir.Constant(i32, 2 + i)], name=f"fut.a{i}.s"
            )
        );
    }
    _tid_slot = self.builder.gep(
        _fut, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="fut.tid.w"
    );
    self.builder.store(ir.Constant(i64, 0), _tid_slot);
    _thr_fnty_p = ir.FunctionType(i8p, [i8p]).as_pointer();
    _pcreate = self._get_or_declare_extern(
        "pthread_create", i32, [i64.as_pointer(), i8p, _thr_fnty_p, i8p]
    );
    _crc = self.builder.call(
        _pcreate, [_tid_slot, ir.Constant(i8p, None), _task_fn, _fut8], name="fut.crc"
    );
    _seq_bb = self.builder.function.append_basic_block("fut.seq");
    _ok_bb = self.builder.function.append_basic_block("fut.spawned");
    self.builder.cbranch(
        self.builder.icmp_signed("!=", _crc, ir.Constant(i32, 0), name="fut.crc.bad"),
        _seq_bb,
        _ok_bb
    );
    self.builder.position_at_end(_seq_bb);
    self.builder.store(ir.Constant(i64, 0), _tid_slot);
    self.builder.call(_task_fn, [_fut8]);
    self.builder.branch(_ok_bb);
    self.builder.position_at_end(_ok_bb);
    self.flow_future_meta[id(h.sym)] = (fut_ty, _res_ty);
    _hraw = self.builder.ptrtoint(_fut8, i64, name="fut.h.raw");
    if isinstance(_res_ty, ir.DoubleType) {
        return self.builder.bitcast(_hraw, ir.DoubleType(), name="fut.h.f");
    }
    if isinstance(_res_ty, ir.PointerType) {
        return self.builder.bitcast(_fut8, _res_ty, name="fut.h.p");
    }
    return _hraw;
}

impl NaIRGenCalls._call_args_lowered(
    nd: uni.UniNode, func: ir.Function, func_name: str, coerced: list
) -> bool {
    """Whether every argument reached the callee's parameter type.

    `_coerce_type` answers with the value unchanged when it has no coercion
    for a pair, so a lowering that lost a type upstream reaches the builder
    with an argument the callee cannot take. The builder's `TypeError` is
    then reported as an internal compiler error, which buries the real
    defect under a crash. Refusing here demotes the one callable and names
    the parameter that did not line up, so the coverage records a fact rather
    than a stack trace.
    """;
    _n = min(len(coerced), len(func.args));
    for _i in range(_n) {
        if coerced[_i].type == func.args[_i].type {
            continue;
        }
        self.emit(
            E5092,
            node_override=nd,
            kind="call argument",
            name=f"{func_name} parameter {_i + 1}",
            help_text=f"The argument lowered to `{coerced[_i].type}` but "
            f"`{func_name}` takes `{func.args[_i].type}` there, and no "
            "coercion connects the two. Some type upstream of this call was "
            "lost -- an unlinked imported archetype, an erased container "
            "element, or a narrow the backend could not follow."
        );
        return False;
    }
    return True;
}

impl NaIRGenCalls._prep_kwbind_record(
    name: str,
    slot_type: ir.Type,
    args_idx: int,
    stored: ir.Value,
    bound_kind: (str | None),
    required_kind: (str | None)
) -> dict {
    rec: dict = {};
    rec["name"] = name;
    rec["slot_type"] = slot_type;
    rec["args_idx"] = args_idx;
    rec["alloca"] = None;
    rec["flag"] = None;
    rec["missing_msg"] = None;
    if bound_kind is not None {
        _noun = "argument" if bound_kind == "pos" else "keyword argument";
        rec["dup_msg"] = f"got multiple values for {_noun} '{name}'";
        return rec;
    }
    rec["dup_msg"] = f"got multiple values for keyword argument '{name}'";
    _al = self._entry_alloca(slot_type, f"kwbind.{name}");
    _init = self._coerce_type(stored, slot_type);
    if isinstance(slot_type, ir.PointerType) and not self._is_owned(stored) {
        self._emit_rc_retain(_init, op="kwbind", loc="");
    }
    self.builder.store(_init, _al);
    _fl = self._entry_alloca(ir.IntType(1), f"kwbind.{name}.bound");
    self.builder.store(ir.Constant(ir.IntType(1), 0), _fl);
    rec["alloca"] = _al;
    rec["flag"] = _fl;
    if required_kind is not None {
        rec["missing_msg"] = f"missing 1 required {required_kind} argument: '{name}'";
    }
    return rec;
}

impl NaIRGenCalls._codegen_builtin_call(nd: uni.FuncCall) -> (ir.Value | None) {
    """Lower a call the checker classified as a builtin.

    Dispatch is by the resolved callee's name, so an aliased import still
    reaches the right emitter. Every path either yields a value or reports
    the one E5092 that names the builtin this unit cannot lower for the call's
    argument shape; nothing returns silently.
    """;
    func_name = self._callee_name_of(nd);
    if func_name is None {
        raise AssertionError(f"builtin call at {nd.loc} resolves to no callee name");
    }
    _errs0 = len(self.errors_had);
    result: (ir.Value | None) = None;
    if func_name in ("range", "slice") {
        result = self._codegen_range_or_slice(nd, func_name);
    } elif func_name in _NA_NARY_BUILTINS {
        result = self._codegen_builtin_nary(nd, func_name);
    } elif func_name in _NA_UNARY_BUILTINS {
        result = self._codegen_builtin_unary(nd, func_name);
    } else {
        _direct: dict = {
            "print": self._emit_print,
            "managed": self._codegen_managed_call,
            "new": self._emit_new,
            "Region": self._codegen_region_call,
            "isinstance": self._emit_isinstance,
            "type": self._codegen_type_call,
            "len": self._codegen_len_call,
            "iter": self._codegen_iter_call,
            "next": self._codegen_next,
            "complex": self._codegen_complex_call,
            "input": self._codegen_input_call,
            "open": self._emit_open
        };
        _handler = _direct.get(func_name);
        if _handler is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="builtin call",
                name=func_name,
                help_text="This builtin has no native lowering in this unit; restructure the call, or move the code to a @sv/Python context."
            );
            return None;
        }
        result = _handler(nd);
    }
    if result is None and len(self.errors_had) == _errs0 {
        self._emit_unsupported_builtin_call(nd, func_name);
    }
    return result;
}

impl NaIRGenCalls._codegen_managed_call(nd: uni.FuncCall) -> (ir.Value | None) {
    params_l = nd.params or [];
    if len(params_l) != 1 or isinstance(params_l[0], uni.KWPair) {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="managed",
            help_text="managed() takes exactly one positional value."
        );
        return None;
    }
    return self._codegen_expr(params_l[0]);
}

impl NaIRGenCalls._codegen_region_call(nd: uni.FuncCall) -> (ir.Value | None) {
    import from jaclang.compiler.expr_keys { is_builtin_region_name }
    if not is_builtin_region_name(nd.target) {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="Region",
            help_text="Only the builtin `Region()` constructor lowers natively."
        );
        return None;
    }
    self._emit_arena_helpers();
    return self.builder.call(self.region_new_fn, [], name="region.new");
}

impl NaIRGenCalls._codegen_type_call(nd: uni.FuncCall) -> (ir.Value | None) {
    _cid_params = nd.params or [];
    if len(_cid_params) != 1 {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="type",
            help_text="Only the one-argument `type(x)` form lowers natively."
        );
        return None;
    }
    return self._codegen_class_id(_cid_params[0]);
}

impl NaIRGenCalls._codegen_iter_call(nd: uni.FuncCall) -> (ir.Value | None) {
    built = self._build_iter_from_expr(nd);
    if built is None {
        return None;
    }
    (iter_val, _ename, _etype) = built;
    return iter_val;
}

impl NaIRGenCalls._codegen_complex_call(nd: uni.FuncCall) -> (ir.Value | None) {
    params_l = nd.params or [];
    if len(params_l) < 2 {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="complex",
            help_text="Only the two-argument `complex(re, im)` form lowers natively."
        );
        return None;
    }
    real_val = self._codegen_expr(params_l[0]);
    imag_val = self._codegen_expr(params_l[1]);
    if real_val is None or imag_val is None {
        return None;
    }
    f64 = ir.DoubleType();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    real_f = self._coerce_type(real_val, f64, self._flow_narrowed_type_of(params_l[0]));
    imag_f = self._coerce_type(imag_val, f64, self._flow_narrowed_type_of(params_l[1]));
    ctype = self.complex_struct_type;
    raw = self.builder.call(
        self.rc_alloc_fn, [ir.Constant(i64, 16)], name="complex.raw"
    );
    ptr = self.builder.bitcast(raw, ctype.as_pointer(), name="complex.ptr");
    rp = self.builder.gep(
        ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="complex.re.ptr"
    );
    ip = self.builder.gep(
        ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="complex.im.ptr"
    );
    self.builder.store(real_f, rp);
    self.builder.store(imag_f, ip);
    return ptr;
}

impl NaIRGenCalls._codegen_builtin_nary(
    nd: uni.FuncCall, func_name: str
) -> (ir.Value | None) {
    params_l = nd.params or [];
    arg_vals: list[ir.Value] = [];
    arg_nodes: list = [];
    for param in params_l {
        v = self._codegen_expr(param);
        if v is None {
            return None;
        }
        arg_vals.append(v);
        arg_nodes.append(param);
    }
    if not arg_vals {
        self._emit_unsupported_builtin_call(nd, func_name);
        return None;
    }
    result = self._dispatch_builtin(func_name, arg_vals, arg_nodes=arg_nodes);
    self._release_owned_args(arg_vals, op="builtin_arg");
    if result is None {
        self._emit_unsupported_builtin_call(nd, func_name);
    }
    return result;
}

impl NaIRGenCalls._codegen_builtin_unary(
    nd: uni.FuncCall, func_name: str
) -> (ir.Value | None) {
    params_l = nd.params or [];
    if not params_l {
        if func_name in ("list", "set") {
            return self._codegen_empty_container_ctor(nd, func_name);
        }
        if func_name == "bytearray" {
            _ba_empty = self._dispatch_builtin(
                "bytearray", [], kwargs=self._split_call_kwargs(nd), kw_node=nd
            );
            if _ba_empty is None {
                self._emit_unsupported_builtin_call(nd, func_name);
            }
            return _ba_empty;
        }
        self._emit_unsupported_builtin_call(nd, func_name);
        return None;
    }
    arg_val = self._codegen_expr(params_l[0]);
    if arg_val is None {
        return None;
    }
    _kwargs = self._split_call_kwargs(nd);
    result = self._dispatch_builtin(
        func_name,
        [arg_val],
        kwargs=_kwargs,
        kw_node=nd,
        type_key=(self._mangled_of(self._flow_narrowed_type_of(params_l[0])) or "")
    );
    self._release_owned_args([arg_val], op="builtin1_arg");
    if result is None and not _kwargs {
        self._emit_unsupported_builtin_call(nd, func_name);
    }
    return result;
}

impl NaIRGenCalls._codegen_len_call(nd: uni.FuncCall) -> (ir.Value | None) {
    params_l = nd.params or [];
    if not params_l {
        return None;
    }
    _arg_nd = params_l[0];
    _arg_t = self._flow_narrowed_type_of(_arg_nd);
    _kind = self._tb_kind(_arg_t);
    if _kind == "optional" {
        _arg_t = self._tb_opt_payload(_arg_t);
        _kind = self._tb_kind(_arg_t);
    }
    arg_val = self._codegen_expr(_arg_nd);
    if arg_val is None {
        return None;
    }
    if self._opt_payload_of(arg_val.type) is not None {
        arg_val = self._coerce_type(
            arg_val,
            self._opt_payload_of(arg_val.type),
            self._flow_narrowed_type_of(_arg_nd)
        );
    }
    _len_result: (ir.Value | None) = None;
    if _kind == "str" {
        if self._str_desc_ty is not None and arg_val.type == self._str_desc_ty {
            _len_result = self.builder.extract_value(
                arg_val, len(list(self._str_desc_ty.elements)) - 1, name="s.len.o1"
            );
        } else {
            _len_result = self._call_str_len(self.builder, arg_val, name="str.len");
        }
    } elif _kind == "any" {
        _len_result = self._codegen_any_len(arg_val);
    } elif _kind == "bytes" {
        _len_result = self._bytes_len_val(arg_val);
    } elif _kind == "dict" {
        _dk = self._dict_key_of(_arg_nd);
        helpers = self.dict_helpers.get(_dk) if _dk is not None else None;
        if helpers is not None {
            _len_result = self.builder.call(helpers["len"], [arg_val], name="dict.len");
        }
    } elif _kind == "set" {
        _sk = self._set_spec_of(_arg_nd);
        helpers = self.set_helpers.get(_sk) if _sk is not None else None;
        if helpers is not None {
            _len_result = self.builder.call(helpers["len"], [arg_val], name="set.len");
        }
    } elif _kind in ("list", "bytearray") {
        _lk = self._list_spec_of(_arg_nd);
        helpers = self.list_helpers.get(_lk) if _lk is not None else None;
        if helpers is not None {
            _len_result = self.builder.call(helpers["len"], [arg_val], name="list.len");
        }
    } elif _kind == "tuple" {
        _tup = self._tuple_struct_of_value(arg_val);
        if _tup is not None {
            _len_result = ir.Constant(ir.IntType(64), len(_tup.elements));
        }
    }
    if _len_result is None {
        self._emit_unsupported_builtin_call(nd, "len");
        return None;
    }
    self._release_owned_args([arg_val], op="len_arg");
    return _len_result;
}

impl NaIRGenCalls._codegen_empty_container_ctor(
    nd: uni.FuncCall, func_name: str
) -> (ir.Value | None) {
    return self._empty_container_of_type(nd.type, func_name, nd);
}

impl NaIRGenCalls._empty_container_of_type(
    t: any, func_name: str, nd: uni.UniNode
) -> (ir.Value | None) {
    self._lower_type(t);
    if func_name == "dict" {
        _dspec = self._dict_spec_for_type(t);
        _dh = self.dict_helpers.get(_dspec) if _dspec is not None else None;
        if _dh is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="builtin call",
                name="dict() without a key and value type",
                help_text="An empty `dict()` only lowers when the checker names its key and value types."
            );
            return None;
        }
        return self.builder.call(_dh["new"], [], name="dict.empty");
    }
    _targs = self._tb_args(t);
    _elem_t = _targs[0] if _targs else None;
    if _elem_t is None or self._tb_kind(_elem_t) in ("unknown", "never") {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name=f"{func_name}() without an element type",
            help_text=f"An empty `{func_name}()` only lowers when the checker gives it an element type (annotate the target, e.g. `xs: {func_name}[int] = {func_name}()`), because the native container layout is fixed per element type."
        );
        return None;
    }
    _ez_spec = (
        self._set_spec_for_type(t)
            if func_name == "set"
            else self._list_spec_for_type(t)
    );
    _ez_h = (
        (self.set_helpers if func_name == "set" else self.list_helpers).get(_ez_spec)
            if _ez_spec is not None
            else None
    );
    if _ez_h is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name=f"{func_name}[{_elem_t}]()",
            help_text="The element type has no native container layout."
        );
        return None;
    }
    return self.builder.call(_ez_h["new"], [], name=f"{func_name}.empty");
}

impl NaIRGenCalls._codegen_range_or_slice(
    nd: uni.FuncCall, func_name: str
) -> (ir.Value | None) {
    params_l = nd.params or [];
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    start_v: (ir.Value | None) = None;
    stop_v: (ir.Value | None) = None;
    step_v: (ir.Value | None) = None;
    if len(params_l) == 1 {
        start_v = ir.Constant(i64, 0);
        stop_v = self._codegen_expr(params_l[0]);
        step_v = ir.Constant(i64, 1);
    } elif len(params_l) == 2 {
        start_v = self._codegen_expr(params_l[0]);
        stop_v = self._codegen_expr(params_l[1]);
        step_v = ir.Constant(i64, 1);
    } elif len(params_l) >= 3 {
        start_v = self._codegen_expr(params_l[0]);
        stop_v = self._codegen_expr(params_l[1]);
        step_v = self._codegen_expr(params_l[2]);
    }
    if start_v is None or stop_v is None or step_v is None {
        return None;
    }
    _rs_types: list = [self._expr_type_of(_p) for _p in params_l];
    (_st_t, _sp_t, _se_t) = (None, None, None);
    if len(params_l) == 1 {
        _sp_t = _rs_types[0];
    } elif len(params_l) == 2 {
        (_st_t, _sp_t) = (_rs_types[0], _rs_types[1]);
    } else {
        (_st_t, _sp_t, _se_t) = (_rs_types[0], _rs_types[1], _rs_types[2]);
    }
    start_v = self._coerce_type(start_v, i64, _st_t);
    stop_v = self._coerce_type(stop_v, i64, _sp_t);
    step_v = self._coerce_type(step_v, i64, _se_t);
    rtype = self.range_struct_type if func_name == "range" else self.slice_struct_type;
    raw = self.builder.call(
        self.rc_alloc_fn, [ir.Constant(i64, 24)], name=f"{func_name}.raw"
    );
    ptr = self.builder.bitcast(raw, rtype.as_pointer(), name=f"{func_name}.ptr");
    z0 = ir.Constant(i32, 0);
    self.builder.store(
        start_v,
        self.builder.gep(ptr, [z0, ir.Constant(i32, 0)], name=f"{func_name}.sp")
    );
    self.builder.store(
        stop_v, self.builder.gep(ptr, [z0, ir.Constant(i32, 1)], name=f"{func_name}.ep")
    );
    self.builder.store(
        step_v, self.builder.gep(ptr, [z0, ir.Constant(i32, 2)], name=f"{func_name}.tp")
    );
    return ptr;
}

impl NaIRGenCalls._codegen_input_call(nd: uni.FuncCall) -> (ir.Value | None) {
    i8p = ir.IntType(8).as_pointer();
    params_l = nd.params or [];

    if params_l {
        prompt_val = self._codegen_expr(params_l[0]);
        if prompt_val is not None {
            _prompt_orig = prompt_val;
            printf = self._get_printf();
            fmt = self._get_fmt_string("%s");
            fmt_ptr = self.builder.bitcast(fmt, i8p, name="fmt.ptr");

            if isinstance(prompt_val.type, ir.PointerType) and prompt_val.type != i8p {
                prompt_val = self.builder.bitcast(prompt_val, i8p, name="prompt.cast");
            }
            self.builder.call(printf, [fmt_ptr, prompt_val]);
            self._release_owned_args([_prompt_orig], op="input_prompt");
        }
    }

    buf_size = 256;
    buf_type = ir.ArrayType(ir.IntType(8), buf_size);
    buf = self.builder.alloca(buf_type, name="input.buf");
    buf_ptr = self.builder.bitcast(buf, i8p, name="input.ptr");

    import platform;
    stdin_name = "__stdinp" if platform.system() == "Darwin" else "stdin";
    if stdin_name not in self.extern_funcs {
        stdin_type = i8p;
        stdin_global = ir.GlobalVariable(self.llvm_module, stdin_type, name=stdin_name);
        stdin_global.linkage = "external";
        if "windows" in str(self.llvm_module.triple or "") {
            stdin_global.storage_class = "dllimport";
        }
        self.extern_funcs[stdin_name] = stdin_global;
    }
    stdin_var = self.extern_funcs[stdin_name];
    stdin_val = self.builder.load(stdin_var, name="stdin.val");
    fgets = self._get_or_declare_extern("fgets", i8p, [i8p, ir.IntType(32), i8p]);
    size_val = ir.Constant(ir.IntType(32), buf_size);
    fgets_ret = self.builder.call(
        fgets, [buf_ptr, size_val, stdin_val], name="fgets.result"
    );

    func = self.builder.function;
    eof_bb = func.append_basic_block(name="input.eof");
    ok_bb = func.append_basic_block(name="input.ok");
    merge_bb = func.append_basic_block(name="input.merge");
    null_ptr = ir.Constant(i8p, None);
    is_eof = self.builder.icmp_signed("==", fgets_ret, null_ptr, name="is.eof");
    self.builder.cbranch(is_eof, eof_bb, ok_bb);

    self.builder.position_at_start(eof_bb);
    eof_str = self._str_alloc(
        self.builder, ir.Constant(ir.IntType(64), 1), name="eof.str"
    );
    self._str_finish(self.builder, eof_str, ir.Constant(ir.IntType(64), 0));
    self.builder.branch(merge_bb);
    eof_bb_end = self.builder.block;

    self.builder.position_at_start(ok_bb);

    slen = self._call_str_len_raw(self.builder, buf_ptr, name="input.len");

    alloc_size = self.builder.add(
        slen, ir.Constant(ir.IntType(64), 1), name="alloc.size"
    );
    result_ptr = self._str_alloc(self.builder, alloc_size, name="input.result");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, ir.IntType(64)]);
    self.builder.call(memcpy, [result_ptr, buf_ptr, alloc_size]);

    has_len = self.builder.icmp_signed(
        ">", slen, ir.Constant(ir.IntType(64), 0), name="has.len"
    );
    strip_bb = func.append_basic_block(name="input.strip");
    nostrip_bb = func.append_basic_block(name="input.nostrip");
    self.builder.cbranch(has_len, strip_bb, nostrip_bb);
    self.builder.position_at_start(strip_bb);
    last_idx = self.builder.sub(slen, ir.Constant(ir.IntType(64), 1), name="last.idx");
    last_ptr = self.builder.gep(result_ptr, [last_idx], name="last.ptr");
    last_byte = self.builder.load(last_ptr, name="last.byte");
    is_newline = self.builder.icmp_signed(
        "==", last_byte, ir.Constant(ir.IntType(8), 10), name="is.nl"
    );

    null_byte = ir.Constant(ir.IntType(8), 0);
    store_val = self.builder.select(is_newline, null_byte, last_byte, name="strip.nl");
    self.builder.store(store_val, last_ptr);

    strip_cr_bb = func.append_basic_block(name="input.strip.cr");
    self.builder.cbranch(is_newline, strip_cr_bb, nostrip_bb);
    self.builder.position_at_start(strip_cr_bb);

    has_cr_len = self.builder.icmp_signed(
        ">=", slen, ir.Constant(ir.IntType(64), 2), name="has.cr.len"
    );
    strip_cr_check_bb = func.append_basic_block(name="input.strip.cr.check");
    self.builder.cbranch(has_cr_len, strip_cr_check_bb, nostrip_bb);
    self.builder.position_at_start(strip_cr_check_bb);

    cr_idx = self.builder.sub(slen, ir.Constant(ir.IntType(64), 2), name="cr.idx");
    cr_ptr = self.builder.gep(result_ptr, [cr_idx], name="cr.ptr");
    cr_byte = self.builder.load(cr_ptr, name="cr.byte");
    is_cr = self.builder.icmp_signed(
        "==", cr_byte, ir.Constant(ir.IntType(8), 13), name="is.cr"
    );

    store_cr_val = self.builder.select(is_cr, null_byte, cr_byte, name="strip.cr");
    self.builder.store(store_cr_val, cr_ptr);
    self.builder.branch(nostrip_bb);
    self.builder.position_at_start(nostrip_bb);
    final_len = self._call_str_len(self.builder, result_ptr, name="input.final.len");
    self._str_finish(self.builder, result_ptr, final_len);
    self.builder.branch(merge_bb);
    ok_bb_end = self.builder.block;

    self.builder.position_at_start(merge_bb);
    phi = self.builder.phi(i8p, name="input.phi");
    phi.add_incoming(eof_str, eof_bb_end);
    phi.add_incoming(result_ptr, ok_bb_end);
    return phi;
}
