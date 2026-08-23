impl NaIRGenLists._emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None {
    if elem_type_name in self.list_helpers {
        return;
    }

    if elem_type_name == "ptr" {
        elem_type = ir.IntType(8).as_pointer();
    }
    if elem_type_name == "i64" and isinstance(elem_type, ir.IntType) {
        elem_type = ir.IntType(64);
    }

    _list_layout = self._container_layout_dense([elem_type]);
    list_struct = self.llvm_module.context.get_identified_type(
        f"List.{elem_type_name}"
    );
    if not list_struct.elements {
        list_struct.set_body(*self._container_struct_fields(_list_layout));
    }
    self.list_types[elem_type_name] = list_struct;
    self.container_layouts[f"List.{elem_type_name}"] = _list_layout;
    list_ptr_type = list_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);

    _rel_fn_decl = None;
    if not self._nogc_headerless() {
        _rel_fn_name = f"__rc_release_list_{elem_type_name}";
        _rel_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type]);
        try {
            _rel_fn_decl = self.llvm_module.get_global(_rel_fn_name);
        } except KeyError {
            _rel_fn_decl = ir.Function(self.llvm_module, _rel_fnty, name=_rel_fn_name);
            _rel_fn_decl.linkage = "private";
        }
    }

    new_fn = self._emit_container_new_fn(
        f"__list_new_{elem_type_name}",
        list_ptr_type,
        _list_layout,
        dtor_fn=_rel_fn_decl,
        type_name=f"list_{elem_type_name}"
    );

    append_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type, elem_type]);
    append_fn = ir.Function(
        self.llvm_module, append_fnty, name=f"__list_append_{elem_type_name}"
    );
    append_fn.linkage = "private";
    append_fn.args[0].name = "list";
    append_fn.args[1].name = "val";
    entry_bb = append_fn.append_basic_block("entry");
    grow_bb = append_fn.append_basic_block("grow");
    store_bb = append_fn.append_basic_block("store");
    b = ir.IRBuilder(entry_bb);
    l_arg = append_fn.args[0];
    v_arg = append_fn.args[1];
    len_p2 = b.gep(l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    cap_p2 = b.gep(l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    cur_len = b.load(len_p2, name="len");
    cur_cap = b.load(cap_p2, name="cap");
    need_grow = b.icmp_unsigned(">=", cur_len, cur_cap, name="need.grow");
    b.cbranch(need_grow, grow_bb, store_bb);

    b.position_at_end(grow_bb);
    data_p_g = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.g"
    );
    self._emit_grow_array(b, data_p_g, elem_type, cur_len, cap_p2, cur_cap);
    b.branch(store_bb);

    b.position_at_end(store_bb);
    data_p_s = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.s"
    );
    cur_data = b.load(data_p_s, name="data");
    slot = b.gep(cur_data, [cur_len], name="slot");

    self._emit_elem_retain(b, elem_type, v_arg);
    b.store(v_arg, slot);
    new_len = b.add(cur_len, ir.Constant(i64, 1), name="new.len");
    b.store(new_len, len_p2);
    b.ret_void();

    get_fn = self._emit_array_get_fn(
        f"__list_get_{elem_type_name}", list_ptr_type, elem_type, 2
    );

    set_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type, i64, elem_type]);
    set_fn = ir.Function(
        self.llvm_module, set_fnty, name=f"__list_set_{elem_type_name}"
    );
    set_fn.linkage = "private";
    set_fn.args[0].name = "list";
    set_fn.args[1].name = "index";
    set_fn.args[2].name = "val";
    bb_s = set_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_s);
    dp2 = b.gep(
        set_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr"
    );
    d2 = b.load(dp2, name="data");
    ep2 = b.gep(d2, [set_fn.args[1]], name="elem.ptr");

    if self._elem_kind(elem_type) != "raw" and not self._nogc_headerless() {
        self._emit_elem_retain(b, elem_type, set_fn.args[2]);
        _old_v_s = b.load(ep2, name="lset_old_val");
        b.store(set_fn.args[2], ep2);
        self._emit_elem_release(b, elem_type, _old_v_s);
    } else {
        b.store(set_fn.args[2], ep2);
    }
    b.ret_void();

    len_fn = self._emit_container_len_fn(f"__list_len_{elem_type_name}", list_ptr_type);

    if self._nogc_headerless() {
        self._emit_container_drop_fn(f"List.{elem_type_name}");
    } else {
        release_fn = self._emit_container_release_fn(
            f"__rc_release_list_{elem_type_name}", list_ptr_type, _list_layout
        );
        self.list_release_fns[elem_type_name] = release_fn;
    }

    self.list_helpers[elem_type_name] = {
        "new": new_fn,
        "append": append_fn,
        "get": get_fn,
        "set": set_fn,
        "len": len_fn,
        "elem_type": elem_type
    };
}

impl NaIRGenLists._cast_to_list_elem(
    b: any, val: ir.Value, elem_type: ir.Type, name: str
) -> ir.Value {
    if val.type == elem_type {
        return val;
    }
    if isinstance(val.type, ir.PointerType) and isinstance(elem_type, ir.PointerType) {
        return b.bitcast(val, elem_type, name=f"{name}.cast");
    }
    return val;
}

impl NaIRGenLists._reflavor_list(
    val: ir.Value, src_spec: str, dst_spec: str, src_elem_ty: any = None
) -> (ir.Value | None) {
    if self._builder is None or self.builder.function is None {
        return None;
    }
    _src_h = self.list_helpers.get(src_spec);
    _dst_h = self.list_helpers.get(dst_spec);
    if _src_h is None or _dst_h is None {
        return None;
    }
    _out = self.builder.call(_dst_h["new"], [], name=f"list.{dst_spec}.reflavor");
    self._emit_spread_copy(
        val, _src_h, _out, _dst_h, "list", "list_reflavor", src_elem_ty=src_elem_ty
    );
    return self._mark_owned(_out);
}

impl NaIRGenLists._spec_from_list_slot_type(t: (ir.Type | None)) -> (str | None) {
    if t is None {
        return None;
    }

    _pl = self._opt_payload_of(t);
    if _pl is not None {
        return self._spec_from_list_slot_type(_pl);
    }
    if not isinstance(t, ir.PointerType) {
        return None;
    }
    for (spec, lt) in self.list_types.items() {
        if lt.as_pointer() == t {
            return spec;
        }
    }
    return None;
}

impl NaIRGenLists._list_elem_ready(
    val: ir.Value, expr: (uni.UniNode | None), spec: str, elem_llvm: ir.Type, loc: str
) -> tuple {
    _vty = self._expr_type_of(expr);
    if isinstance(elem_llvm, ir.PointerType)
        and isinstance(elem_llvm.pointee, ir.LiteralStructType)
        and isinstance(val.type, ir.LiteralStructType) {
        val = self._coerce_tuple_to_struct(val, elem_llvm.pointee);
    }
    val = self._box_value_tuple(val, loc=loc);
    val = self._nogc_elem_prep(expr, val);
    _boxed = val;
    if spec == "jacval" {
        return (self._box_to_jacval(val, ty=_vty), _boxed);
    }
    if val.type != elem_llvm {
        val = self._coerce_typed(val, elem_llvm, _vty);
    }
    if spec == "ptr" and isinstance(val.type, ir.PointerType) {
        val = self.builder.bitcast(val, ir.IntType(8).as_pointer(), name="elem.cast");
    } else {
        val = self._coerce_typed(val, self.list_helpers[spec]["elem_type"], _vty);
    }
    return (val, _boxed);
}

impl NaIRGenLists._codegen_list_val(nd: uni.ListVal) -> (ir.Value | None) {
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    _lty = self._expr_type_of(nd);
    _elem_tb = self._tb_elem(_lty);
    if _elem_tb is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="list display without an element type",
            help_text="The checker stamped no element type on this list display, so there is no native layout to build it in. Annotate the binding (for example `xs: list[int] = []`), or give the display an element."
        );
        return None;
    }
    _elem_llvm = self._elem_slot_llvm(_elem_tb);
    if _elem_llvm is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name=f"list of {_elem_tb}",
            help_text="The element type has no native lowering, so the list has no native layout. Use a lowerable element type, or move this code to a @sv/Python context."
        );
        return None;
    }
    spec = self._list_spec_for_elem_llvm(_elem_llvm);
    helpers = self.list_helpers[spec];
    list_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="list.new"
    );
    self._nogc_stamp_elem_drops(list_val, [_elem_tb]);

    for v_nd in (nd.values or []) {
        _spread_op = self._spread_operand(v_nd);
        if _spread_op is not None {
            _src_info = self._container_src_info(
                self._str_norm(self._codegen_expr(_spread_op)), _spread_op
            );
            if _src_info is None {
                self.emit(
                    E5092,
                    node_override=v_nd,
                    kind="expression",
                    name="spread in a list display",
                    help_text="A `*` spread is copied element by element out of a native list or set; this operand lowered to neither. Give it a lowerable list or set type, or write the elements out."
                );
                return None;
            }
            self._emit_spread_copy(
                _src_info["value"],
                _src_info["helpers"],
                list_val,
                helpers,
                "list",
                _loc,
                src_elem_ty=self._tb_elem(self._expr_type_of(_spread_op))
            );
            continue;
        }
        val = self._str_norm(self._codegen_expr(v_nd));
        if val is None {
            self.emit(
                E5092,
                node_override=v_nd,
                kind="expression",
                name="list element",
                help_text="This element of the list display did not lower, so the list would have been built without it. Move the expression out of the display, or move the enclosing code to a @sv/Python context."
            );
            return None;
        }
        (append_val, _boxed_val) = self._list_elem_ready(
            val, v_nd, spec, _elem_llvm, _loc
        );
        self._rc_call_with_ctx(
            helpers["append"], [list_val, append_val], op="list_init", loc=_loc
        );
        if isinstance(_boxed_val.type, ir.PointerType)
            and self._is_owned(_boxed_val)
            and self._gc_mode() != "none" {
            self._emit_rc_release_simple(_boxed_val, op="list_init", loc=_loc);
        }
    }
    return list_val;
}

impl NaIRGenLists._codegen_index(
    target_val: ir.Value, index_val: ir.Value, elem_type_name: str
) -> (ir.Value | None) {
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    i64 = ir.IntType(64);
    index_val = self._coerce_type(index_val, i64);

    len_val = self.builder.call(helpers["len"], [target_val], name="list.len.chk");
    is_neg = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="idx.neg.chk"
    );
    adjusted = self.builder.add(index_val, len_val, name="idx.adj");
    index_val = self.builder.select(is_neg, adjusted, index_val, name="idx.norm");
    below = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="idx.below"
    );
    above = self.builder.icmp_signed(">=", index_val, len_val, name="idx.oob.chk");
    is_oob = self.builder.or_(below, above, name="idx.range.chk");
    self._emit_runtime_raise(is_oob, "IndexError", "list index out of range");
    _got = self.builder.call(helpers["get"], [target_val, index_val], name="list.get");
    if elem_type_name == "u8" {
        return self.builder.zext(_got, i64, name="ba.get.zext");
    }
    return _got;
}

impl NaIRGenLists._codegen_any_subscript(
    jacval: ir.Value, key_val: ir.Value, key_ty: any = None
) -> (ir.Value | None) {
    if not self?.jacval_type {
        return None;
    }
    if key_ty is None {
        raise AssertionError(
            f"native: subscript on an `any` receiver reached codegen without the key's type (key llvm={key_val.type})"
        );
    }
    i8p = ir.IntType(8).as_pointer();
    _kkind = self._tb_kind(self._tb_opt_payload(key_ty) or key_ty);
    if _kkind == "str" {
        self._emit_dict_helpers("ptr", "jacval", i8p, self.jacval_type);
        d = self._unbox_from_jacval(jacval, self.dict_types["ptr:jacval"].as_pointer());
        return self._codegen_dict_access(
            d, self._coerce_typed(key_val, i8p, key_ty), "ptr", "jacval"
        );
    }
    if _kkind in ("int", "bool") {
        self._emit_list_helpers("jacval", self.jacval_type);
        l = self._unbox_from_jacval(jacval, self.list_types["jacval"].as_pointer());
        return self._codegen_index(l, key_val, "jacval");
    }
    return None;
}

impl NaIRGenLists._codegen_any_len(jacval: ir.Value) -> ir.Value {
    b = self.builder;
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    tag = b.extract_value(jacval, 0, name="anylen.tag");
    payload = b.extract_value(jacval, 1, name="anylen.payload");
    is_str = b.icmp_unsigned("==", tag, ir.Constant(i8, 2), name="anylen.isstr");
    func = b.function;
    str_bb = func.append_basic_block(name="anylen.str");
    cont_bb = func.append_basic_block(name="anylen.cont");
    merge_bb = func.append_basic_block(name="anylen.end");
    b.cbranch(is_str, str_bb, cont_bb);
    b.position_at_end(str_bb);
    sp = b.inttoptr(payload, i8p, name="anylen.sp");
    sl = self._call_str_len(b, sp, name="anylen.strlen");
    b.branch(merge_bb);
    b.position_at_end(cont_bb);
    lp = b.inttoptr(payload, i64.as_pointer(), name="anylen.lp");
    cl = b.load(lp, name="anylen.contlen");
    b.branch(merge_bb);
    b.position_at_end(merge_bb);
    phi = b.phi(i64, name="anylen");
    phi.add_incoming(sl, str_bb);
    phi.add_incoming(cl, cont_bb);
    return phi;
}

impl NaIRGenLists._codegen_index_set(
    target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
) -> None {
    value = self._str_norm(value);
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return;
    }
    i64 = ir.IntType(64);
    index_val = self._coerce_type(index_val, i64);

    len_val = self.builder.call(helpers["len"], [target_val], name="list.setlen.chk");
    is_neg = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="setidx.neg.chk"
    );
    adjusted = self.builder.add(index_val, len_val, name="setidx.adj");
    index_val = self.builder.select(is_neg, adjusted, index_val, name="setidx.norm");
    below = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="setidx.below"
    );
    above = self.builder.icmp_signed(">=", index_val, len_val, name="setidx.oob.chk");
    is_oob = self.builder.or_(below, above, name="setidx.range.chk");
    self._emit_runtime_raise(
        is_oob, "IndexError", "list assignment index out of range"
    );
    elem_type = helpers["elem_type"];

    _lset_ctx_loc = getattr(
        value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
    );

    _orig_value = value;
    _val_was_owned = self._is_owned(value);
    value = self._coerce_type(value, elem_type);
    self._rc_call_with_ctx(
        helpers["set"], [target_val, index_val, value], op="list_set", loc=_lset_ctx_loc
    );

    if (
        isinstance(_orig_value.type, ir.PointerType)
        and _val_was_owned
        and self._elem_kind(elem_type) != "raw"
    ) {
        self._emit_rc_release_simple(_orig_value, op="list_set", loc=_lset_ctx_loc);
    }
}

impl NaIRGenLists._emit_aos_list_helpers(tname: str) -> ir.Type {
    _spec = f"aos.{tname}";
    if _spec in self.list_types {
        return self.list_types[_spec];
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    _t_struct = self.struct_types[tname];
    _tp = _t_struct.as_pointer();
    st = self.llvm_module.context.get_identified_type(f"List.aos.{tname}");
    st.set_body(i64, i64, _tp);
    self.list_types[_spec] = st;
    self.container_layouts[f"List.aos.{tname}"] = {
        "kind": "aos",
        "data_fields": [(2, _t_struct)],
        "elem_kinds": ["raw"],
        "ctrl_idx": -1,
        "used_idx": -1,
        "order_idx": -1,
        "drop_base": 3
    };
    _stp = st.as_pointer();
    _malloc = self._get_or_declare_extern("malloc", i8p, [i64]);
    _free = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    _memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    _z = ir.Constant(i32, 0);

    new_fn = self._define_function(
        f"__list_new_aos_{tname}", ir.FunctionType(_stp, [])
    );
    new_fn.linkage = "private";
    b = ir.IRBuilder(new_fn.append_basic_block("entry"));
    _szT = b.ptrtoint(
        b.gep(ir.Constant(_tp, None), [ir.Constant(i32, 1)], name="szT.p"),
        i64,
        name="szT"
    );
    _szSelf = b.ptrtoint(
        b.gep(ir.Constant(_stp, None), [ir.Constant(i32, 1)], name="szS.p"),
        i64,
        name="szS"
    );
    _selfp = b.bitcast(
        b.call(_malloc, [_szSelf], name="aos.self8"), _stp, name="aos.self"
    );
    b.store(
        ir.Constant(i64, 0), b.gep(_selfp, [_z, ir.Constant(i32, 0)], name="aos.len")
    );
    b.store(
        ir.Constant(i64, 8), b.gep(_selfp, [_z, ir.Constant(i32, 1)], name="aos.cap")
    );
    _buf0 = b.call(
        _malloc, [b.mul(ir.Constant(i64, 8), _szT, name="aos.b0.sz")], name="aos.b0"
    );
    b.store(
        b.bitcast(_buf0, _tp, name="aos.b0.t"),
        b.gep(_selfp, [_z, ir.Constant(i32, 2)], name="aos.data")
    );
    b.ret(_selfp);

    append_fn = self._define_function(
        f"__list_append_aos_{tname}", ir.FunctionType(ir.VoidType(), [_stp, _tp])
    );
    append_fn.linkage = "private";
    _a_entry = append_fn.append_basic_block("entry");
    _a_grow = append_fn.append_basic_block("grow");
    _a_store = append_fn.append_basic_block("store");
    b = ir.IRBuilder(_a_entry);
    _a_szT = b.ptrtoint(
        b.gep(ir.Constant(_tp, None), [ir.Constant(i32, 1)], name="a.szT.p"),
        i64,
        name="a.szT"
    );
    _a_len_p = b.gep(append_fn.args[0], [_z, ir.Constant(i32, 0)], name="a.len.p");
    _a_cap_p = b.gep(append_fn.args[0], [_z, ir.Constant(i32, 1)], name="a.cap.p");
    _a_data_p = b.gep(append_fn.args[0], [_z, ir.Constant(i32, 2)], name="a.data.p");
    _a_len = b.load(_a_len_p, name="a.len");
    _a_cap = b.load(_a_cap_p, name="a.cap");
    b.cbranch(b.icmp_signed(">=", _a_len, _a_cap, name="a.full"), _a_grow, _a_store);
    b = ir.IRBuilder(_a_grow);
    _g_ncap = b.mul(_a_cap, ir.Constant(i64, 2), name="a.ncap");
    _g_new = b.call(_malloc, [b.mul(_g_ncap, _a_szT, name="a.nsz")], name="a.nbuf");
    _g_old = b.load(_a_data_p, name="a.old");
    b.call(
        _memcpy,
        [
            _g_new,
            b.bitcast(_g_old, i8p, name="a.old8"),
            b.mul(_a_len, _a_szT, name="a.copysz")
        ]
    );
    b.call(_free, [b.bitcast(_g_old, i8p, name="a.old8f")]);
    b.store(b.bitcast(_g_new, _tp, name="a.nbuf.t"), _a_data_p);
    b.store(_g_ncap, _a_cap_p);
    b.branch(_a_store);
    b = ir.IRBuilder(_a_store);
    _s_data = b.load(_a_data_p, name="a.data");
    _s_dst = b.gep(_s_data, [_a_len], name="a.dst");
    b.call(
        _memcpy,
        [
            b.bitcast(_s_dst, i8p, name="a.dst8"),
            b.bitcast(append_fn.args[1], i8p, name="a.src8"),
            _a_szT
        ]
    );
    b.call(_free, [b.bitcast(append_fn.args[1], i8p, name="a.shell8")]);
    b.store(b.add(_a_len, ir.Constant(i64, 1), name="a.len1"), _a_len_p);
    b.ret_void();

    get_fn = self._define_function(
        f"__list_get_aos_{tname}", ir.FunctionType(_tp, [_stp, i64])
    );
    get_fn.linkage = "private";
    b = ir.IRBuilder(get_fn.append_basic_block("entry"));
    _g_data = b.load(
        b.gep(get_fn.args[0], [_z, ir.Constant(i32, 2)], name="g.data.p"), name="g.data"
    );
    b.ret(b.gep(_g_data, [get_fn.args[1]], name="g.elem"));

    set_fn = self._define_function(
        f"__list_set_aos_{tname}", ir.FunctionType(ir.VoidType(), [_stp, i64, _tp])
    );
    set_fn.linkage = "private";
    b = ir.IRBuilder(set_fn.append_basic_block("entry"));
    _st_szT = b.ptrtoint(
        b.gep(ir.Constant(_tp, None), [ir.Constant(i32, 1)], name="s.szT.p"),
        i64,
        name="s.szT"
    );
    _st_data = b.load(
        b.gep(set_fn.args[0], [_z, ir.Constant(i32, 2)], name="s.data.p"), name="s.data"
    );
    _st_slot = b.gep(_st_data, [set_fn.args[1]], name="s.slot");
    _fields_fn = self._emit_struct_drop_fields_fn(tname);
    if _fields_fn is not None {
        b.call(_fields_fn, [b.bitcast(_st_slot, i8p, name="s.slot8")]);
    }
    b.call(
        _memcpy,
        [
            b.bitcast(_st_slot, i8p, name="s.slot8b"),
            b.bitcast(set_fn.args[2], i8p, name="s.src8"),
            _st_szT
        ]
    );
    b.call(_free, [b.bitcast(set_fn.args[2], i8p, name="s.shell8")]);
    b.ret_void();

    len_fn = self._define_function(
        f"__list_len_aos_{tname}", ir.FunctionType(i64, [_stp])
    );
    len_fn.linkage = "private";
    b = ir.IRBuilder(len_fn.append_basic_block("entry"));
    b.ret(
        b.load(
            b.gep(len_fn.args[0], [_z, ir.Constant(i32, 0)], name="l.len.p"),
            name="l.len"
        )
    );

    drop_fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [i8p]),
        name=f"__drop_List_aos_{tname}"
    );
    drop_fn.linkage = "private";
    drop_fn.args[0].name = "self";
    _d_entry = drop_fn.append_basic_block("entry");
    _d_prep = drop_fn.append_basic_block("prep");
    _d_done = drop_fn.append_basic_block("done");
    b = ir.IRBuilder(_d_entry);
    _d_null = b.icmp_unsigned(
        "==", drop_fn.args[0], ir.Constant(i8p, None), name="d.null"
    );
    b.cbranch(_d_null, _d_done, _d_prep);
    b = ir.IRBuilder(_d_prep);
    _d_selfp = b.bitcast(drop_fn.args[0], _stp, name="d.self");
    _d_fields = self._emit_struct_drop_fields_fn(tname);

    def _aos_drop_elem(bl: ir.IRBuilder, i: ir.Value, elem_ptrs: list) -> ir.IRBuilder {
        if _d_fields is not None {
            bl.call(_d_fields, [bl.bitcast(elem_ptrs[0], i8p, name="d.elem8")]);
        }
        return bl;
    }
    b = self._emit_live_slot_loop(
        drop_fn,
        b,
        _d_selfp,
        self.container_layouts[f"List.aos.{tname}"],
        "d",
        _aos_drop_elem
    );
    _d_data = b.load(
        b.gep(_d_selfp, [_z, ir.Constant(i32, 2)], name="d.data.p"), name="d.data"
    );
    b.call(_free, [b.bitcast(_d_data, i8p, name="d.data8")]);
    b.call(_free, [drop_fn.args[0]]);
    b.branch(_d_done);
    b = ir.IRBuilder(_d_done);
    b.ret_void();
    self.container_drop_fns[f"List.aos.{tname}"] = drop_fn;

    self.list_helpers[_spec] = {
        "new": new_fn,
        "append": append_fn,
        "get": get_fn,
        "set": set_fn,
        "len": len_fn,
        "elem_type": _tp
    };
    return st;
}
