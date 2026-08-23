impl NaIRGenComprehensions._codegen_list_compr(nd: uni.ListCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }
    _elem_tb = self._tb_elem(self._expr_type_of(nd));
    _elem_llvm = self._elem_slot_llvm(_elem_tb) if _elem_tb is not None else None;
    if _elem_llvm is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="list comprehension element type",
            help_text="The checker stamped no lowerable element type on this comprehension, so there is no native list layout to build it in. Give the produced expression a concrete native type."
        );
        return None;
    }
    elem_type_name = self._list_spec_for_elem_llvm(_elem_llvm);
    helpers = self.list_helpers[elem_type_name];
    _lcompr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    list_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_lcompr_loc, name="compr.list"
    );
    self._nogc_stamp_elem_drops(list_val, [_elem_tb]);
    self._codegen_compr_walk(
        nd.compr, 0, "list", list_val, nd.out_expr, None, elem_type_name
    );
    return list_val;
}

impl NaIRGenComprehensions._codegen_dict_compr(nd: uni.DictCompr) -> (ir.Value | None) {
    if not nd.compr or nd.kv_pair is None {
        return None;
    }
    key_expr = nd.kv_pair.key;
    val_expr = nd.kv_pair.value;
    if key_expr is None or val_expr is None {
        return None;
    }
    _dty = self._expr_type_of(nd);
    _kt = self._tb_elem(_dty, 0);
    _vt = self._tb_elem(_dty, 1);
    _kl = self._elem_slot_llvm(_kt) if _kt is not None else None;
    _vl = self._elem_slot_llvm(_vt) if _vt is not None else None;
    if _kl is None or _vl is None or (self?.jacval_type and _kl == self.jacval_type) {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="dict comprehension key/value types",
            help_text="The checker stamped no lowerable key and value types on this comprehension, so there is no native dict layout to build it in. Give the key and value expressions concrete native types (one concrete key type)."
        );
        return None;
    }
    (key_type_name, key_size) = self._dict_key_spec(_kl);
    val_type_name = self._dict_val_spec(_vl);
    self._emit_dict_helpers(key_type_name, val_type_name, _kl, _vl, key_size);
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers[dict_key];
    _dcompr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_dcompr_loc, name="dcompr.dict"
    );
    self._nogc_stamp_elem_drops(dict_val, [_kt, _vt]);
    self._codegen_compr_walk(
        nd.compr, 0, "dict", dict_val, key_expr, val_expr, dict_key
    );
    return dict_val;
}

impl NaIRGenComprehensions._codegen_set_compr(nd: uni.SetCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }
    _sty = self._expr_type_of(nd);
    _elem_tb = self._tb_elem(_sty);
    elem_type_name = self._set_spec_for_type(_sty) if _elem_tb is not None else None;
    if elem_type_name is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="set comprehension element type",
            help_text="The checker stamped no lowerable element type on this comprehension, so there is no native set layout to build it in. Give the produced expression one concrete hashable native type."
        );
        return None;
    }
    helpers = self.set_helpers[elem_type_name];
    _scompr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    set_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_scompr_loc, name="scompr.set"
    );
    self._nogc_stamp_elem_drops(set_val, [_elem_tb]);
    self._codegen_compr_walk(
        nd.compr, 0, "set", set_val, nd.out_expr, None, elem_type_name
    );
    return set_val;
}

impl NaIRGenComprehensions._emit_compr_element(
    kind: str,
    acc: ir.Value,
    key_expr: uni.UniNode,
    val_expr: (uni.UniNode | None),
    spec: str
) -> None {
    if kind == "dict" {
        key_val = self._str_norm(self._codegen_expr(key_expr));
        value_val = self._str_norm(self._codegen_expr(val_expr));
        value_val = self._nogc_elem_prep(val_expr, value_val);
        if key_val is not None and value_val is not None {
            helpers = self.dict_helpers.get(spec);
            if helpers is not None {
                expected_key_type = helpers["key_type"];
                expected_val_type = helpers["val_type"];
                key_val = self._box_value_tuple(key_val);
                _boxed_key = key_val;
                key_val = self._coerce_typed(
                    key_val, expected_key_type, self._expr_type_of(key_expr)
                );
                value_val = self._box_value_tuple(value_val);
                _boxed_val_compr = value_val;
                if self?.jacval_type and expected_val_type == self.jacval_type {
                    value_val = self._box_to_jacval(
                        value_val, ty=self._expr_type_of(val_expr)
                    );
                } else {
                    value_val = self._coerce_typed(
                        value_val, expected_val_type, self._expr_type_of(val_expr)
                    );
                }
                self.builder.call(helpers["set"], [acc, key_val, value_val]);

                if isinstance(_boxed_key.type, ir.PointerType)
                    and self._is_owned(_boxed_key) {
                    self._emit_rc_release_simple(_boxed_key, op="dcompr_key", loc="");
                }
                if isinstance(_boxed_val_compr.type, ir.PointerType)
                    and self._is_owned(_boxed_val_compr) {
                    self._emit_rc_release_simple(
                        _boxed_val_compr, op="dcompr_val", loc=""
                    );
                }
            }
        }
        return;
    }
    if kind == "set" {
        val = self._str_norm(self._codegen_expr(key_expr));
        val = self._nogc_elem_prep(key_expr, val);
        if val is not None {
            helpers = self.set_helpers.get(spec);
            if helpers is not None {
                expected_type = helpers["elem_type"];
                if isinstance(expected_type, ir.PointerType)
                    and isinstance(expected_type.pointee, ir.LiteralStructType)
                    and isinstance(val.type, ir.LiteralStructType) {
                    val = self._coerce_tuple_to_struct(val, expected_type.pointee);
                }
                val = self._box_value_tuple(val);
                _scompr_boxed = val;
                if val.type != expected_type {
                    val = self._coerce_typed(
                        val, expected_type, self._expr_type_of(key_expr)
                    );
                }
                self.builder.call(helpers["add"], [acc, val]);

                if isinstance(_scompr_boxed.type, ir.PointerType)
                    and self._is_owned(_scompr_boxed) {
                    self._emit_rc_release_simple(
                        _scompr_boxed, op="scompr_elem", loc=""
                    );
                }
            }
        }
        return;
    }

    val = self._str_norm(self._codegen_expr(key_expr));
    if val is not None {
        helpers = self.list_helpers.get(spec);
        if helpers is not None {
            _compr_append_orig = val;
            _elem_llvm: (ir.Type | None) = None;
            if isinstance(key_expr.parent, uni.ListCompr) {
                _elem_llvm = self._elem_slot_llvm(
                    self._tb_elem(self._expr_type_of(key_expr.parent))
                );
            }
            (val, _compr_boxed_val) = self._list_elem_ready(
                val, key_expr, spec, _elem_llvm or helpers["elem_type"], ""
            );
            _compr_loc_raw = getattr(_compr_append_orig, 'jac_loc', key_expr?.loc);
            _compr_loc: str = "";
            if isinstance(_compr_loc_raw, str) {
                _compr_loc = _compr_loc_raw;
            } elif _compr_loc_raw is not None {
                _compr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{_compr_loc_raw.first_line}";
            }
            if not _compr_loc {
                _compr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:0";
            }
            self._rc_call_with_ctx(
                helpers["append"], [acc, val], op="compr_elem", loc=_compr_loc
            );

            if isinstance(_compr_boxed_val.type, ir.PointerType)
                and self._is_owned(_compr_boxed_val) {
                self._emit_rc_release_simple(
                    _compr_boxed_val, op="compr_elem", loc=_compr_loc
                );
            }
        }
    }
}

impl NaIRGenComprehensions._codegen_compr_walk(
    comprs: list,
    idx: int,
    kind: str,
    acc: ir.Value,
    key_expr: uni.UniNode,
    val_expr: (uni.UniNode | None),
    spec: str
) -> None {
    if idx >= len(comprs) {
        self._emit_compr_element(kind, acc, key_expr, val_expr, spec);
        return;
    }
    inner = comprs[idx];
    loop_target = inner.target;
    collection = inner.collection;
    conditionals = inner.conditional or [];

    if isinstance(collection, uni.FuncCall) {
        if self._builtin_call_is(collection, "range") {
            self._codegen_compr_range_walk(
                inner, comprs, idx, kind, acc, key_expr, val_expr, spec, conditionals
            );
            return;
        }
    }

    coll_val = self._opt_unwrap_iterable(self._codegen_expr(collection));
    if coll_val is None {
        return;
    }
    _coll_ty = self._expr_type_of(collection);
    _coll_kind = self._tb_kind(self._tb_opt_payload(_coll_ty) or _coll_ty);
    coll_elem_type_name = self._list_spec_for_expr(collection)
        if _coll_kind in ("list", "bytearray", "tuple")
        else None;
    if coll_elem_type_name is None {
        self.emit(
            E5092,
            node_override=collection,
            kind="expression",
            name=f"comprehension over {_coll_ty}",
            help_text="A native comprehension walks a list; this collection's checker type is not a list with a lowerable element type. Iterate a list here, or move this code to a @sv/Python context."
        );
        return;
    }
    coll_helpers = self.list_helpers[coll_elem_type_name];
    _coll_want = coll_helpers["len"].function_type.args[0];
    if coll_val.type != _coll_want {
        coll_val = self.builder.bitcast(coll_val, _coll_want, name="compr.coll.cast");
    }
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    i64 = ir.IntType(64);
    len_val = self.builder.call(coll_helpers["len"], [coll_val], name="compr.len");
    idx_alloca = self._entry_alloca(i64, "compr.idx");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);

    actual_elem_type = self._for_target_slot_llvm(
        loop_target, coll_helpers["elem_type"]
    );
    _elem_cast: (ir.Type | None) = (
        actual_elem_type if actual_elem_type != coll_helpers["elem_type"] else None
    );
    loop_alloca = self._entry_alloca(actual_elem_type, loop_var_name);

    if isinstance(actual_elem_type, ir.PointerType) {
        _compr_saved_block = self.builder.block;
        self.builder.position_after(loop_alloca);
        self.builder.store(ir.Constant(actual_elem_type, None), loop_alloca);
        self.builder.position_at_end(_compr_saved_block);
    }
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="compr.cond");
    body_bb = func.append_basic_block(name="compr.body");
    incr_bb = func.append_basic_block(name="compr.incr");
    end_bb = func.append_basic_block(name="compr.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur_idx = self.builder.load(idx_alloca, name="compr.cur.idx");
    cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="compr.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
    body_idx = self.builder.load(idx_alloca, name="compr.body.idx");
    elem_val = self.builder.call(
        coll_helpers["get"], [coll_val, body_idx], name="compr.elem"
    );

    if _elem_cast is not None {
        elem_val = self.builder.bitcast(elem_val, _elem_cast, name="compr.elem.cast");
    }

    if isinstance(actual_elem_type, ir.PointerType) {
        _compr_old = self.builder.load(loop_alloca, name="compr.old");
        self._emit_rc_release_simple(_compr_old, op="compr_elem", loc="");
        self._emit_rc_retain(elem_val, op="compr_elem", loc="");
    }
    self.builder.store(elem_val, loop_alloca);
    if conditionals {
        filter_bb = func.append_basic_block(name="compr.filter");
        skip_bb = func.append_basic_block(name="compr.skip");
        all_cond = self._codegen_expr(conditionals[0]);
        if all_cond is not None {
            all_cond = self._to_bool_of(all_cond, conditionals[0]);
            for i in range(1, len(conditionals)) {
                next_cond = self._codegen_expr(conditionals[i]);
                if next_cond is not None {
                    next_cond = self._to_bool_of(next_cond, conditionals[i]);
                    all_cond = self.builder.and_(all_cond, next_cond, name="compr.and");
                }
            }
            self.builder.cbranch(all_cond, filter_bb, skip_bb);
        } else {
            self.builder.branch(filter_bb);
        }
        self.builder.position_at_end(filter_bb);
        self._codegen_compr_walk(comprs, idx + 1, kind, acc, key_expr, val_expr, spec);
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_compr_walk(comprs, idx + 1, kind, acc, key_expr, val_expr, spec);
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="compr.inc.idx");
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="compr.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);

    if isinstance(coll_val.type, ir.PointerType) and self._is_owned(coll_val) {
        _coll_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:0";
        self._emit_rc_release_simple(coll_val, op="compr_coll", loc=_coll_loc);
    }
}

impl NaIRGenComprehensions._codegen_compr_range_walk(
    inner: uni.InnerCompr,
    comprs: list,
    idx: int,
    kind: str,
    acc: ir.Value,
    key_expr: uni.UniNode,
    val_expr: (uni.UniNode | None),
    spec: str,
    conditionals: list
) -> None {
    collection = inner.collection;
    loop_target = inner.target;
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    params = collection.params or [];
    start_val: (ir.Value | None) = None;
    stop_val: (ir.Value | None) = None;
    _start_nd: (uni.UniNode | None) = None;
    _stop_nd: (uni.UniNode | None) = None;
    if len(params) == 1 {
        start_val = ir.Constant(ir.IntType(64), 0);
        _stop_nd = params[0];
        stop_val = self._codegen_expr(params[0]);
    } elif len(params) >= 2 {
        _start_nd = params[0];
        _stop_nd = params[1];
        start_val = self._codegen_expr(params[0]);
        stop_val = self._codegen_expr(params[1]);
    }
    if start_val is None or stop_val is None {
        return;
    }
    i64 = ir.IntType(64);
    start_val = self._coerce_typed(start_val, i64, self._expr_type_of(_start_nd));
    stop_val = self._coerce_typed(stop_val, i64, self._expr_type_of(_stop_nd));
    loop_alloca = self._entry_alloca(i64, loop_var_name);
    self.builder.store(start_val, loop_alloca);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="compr.range.cond");
    body_bb = func.append_basic_block(name="compr.range.body");
    incr_bb = func.append_basic_block(name="compr.range.incr");
    end_bb = func.append_basic_block(name="compr.range.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    i_val = self.builder.load(loop_alloca, name=loop_var_name);
    cmp = self.builder.icmp_signed("<", i_val, stop_val, name="compr.range.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
    if conditionals {
        filter_bb = func.append_basic_block(name="compr.range.filter");
        skip_bb = func.append_basic_block(name="compr.range.skip");
        all_cond = self._codegen_expr(conditionals[0]);
        if all_cond is not None {
            all_cond = self._to_bool_of(all_cond, conditionals[0]);
            for i in range(1, len(conditionals)) {
                next_cond = self._codegen_expr(conditionals[i]);
                if next_cond is not None {
                    next_cond = self._to_bool_of(next_cond, conditionals[i]);
                    all_cond = self.builder.and_(all_cond, next_cond, name="compr.and");
                }
            }
            self.builder.cbranch(all_cond, filter_bb, skip_bb);
        } else {
            self.builder.branch(filter_bb);
        }
        self.builder.position_at_end(filter_bb);
        self._codegen_compr_walk(comprs, idx + 1, kind, acc, key_expr, val_expr, spec);
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_compr_walk(comprs, idx + 1, kind, acc, key_expr, val_expr, spec);
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    self.builder.position_at_end(incr_bb);
    i_cur = self.builder.load(loop_alloca, name="compr.range.cur");
    i_next = self.builder.add(i_cur, ir.Constant(i64, 1), name="compr.range.next");
    self.builder.store(i_next, loop_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);
}
