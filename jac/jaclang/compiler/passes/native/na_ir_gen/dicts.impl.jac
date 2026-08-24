impl NaIRGenDicts._dict_key_spec(key_type: ir.Type) -> tuple {
    if isinstance(key_type, ir.DoubleType) {
        return ("f64", 0);
    }
    if self._is_bytes_type(key_type) {
        return ("bytes", 0);
    }
    if isinstance(key_type, ir.PointerType) {
        if isinstance(key_type.pointee, ir.LiteralStructType) {
            _sz = self._get_struct_size(key_type.pointee);
            return (self._tuple_spec_name(key_type.pointee), _sz);
        }
        return ("ptr", 0);
    }
    return ("i64", 0);
}

impl NaIRGenDicts._unwrap_opt_container(val: ir.Value) -> ir.Value {
    _pay = self._opt_payload_of(val.type);
    if _pay is None or not isinstance(_pay, ir.PointerType) {
        return val;
    }
    return self._coerce_type(val, _pay);
}

impl NaIRGenDicts._dict_val_spec(val_type: ir.Type) -> str {
    if isinstance(val_type, ir.DoubleType) {
        return "f64";
    }
    if self?.jacval_type and val_type == self.jacval_type {
        return "jacval";
    }
    if isinstance(val_type, ir.PointerType) {
        _pointee = val_type.pointee;
        if isinstance(_pointee, ir.IdentifiedStructType) and _pointee.name {
            return "ptr_" + str(_pointee.name).replace(".", "_");
        }
        return "ptr";
    }
    if isinstance(val_type, ir.IntType) and val_type.width != 64 {
        return f"i{val_type.width}";
    }
    return "i64";
}

impl NaIRGenDicts._emit_dict_order_compact(
    b: ir.IRBuilder,
    fn: ir.Function,
    d_ptr: ir.Value,
    removed_slot: ir.Value,
    new_len: ir.Value,
    i32: ir.Type,
    i64: ir.Type,
    order_idx: int
) -> ir.IRBuilder {
    ord_a = b.load(
        b.gep(d_ptr, [ir.Constant(i32, 0), ir.Constant(i32, order_idx)], name="oc.orp"),
        name="oc.ord"
    );
    _idx = b.alloca(i64, name="oc.i");
    b.store(ir.Constant(i64, 0), _idx);
    _scan = fn.append_basic_block("oc.scan");
    _body = fn.append_basic_block("oc.body");
    _shift = fn.append_basic_block("oc.shift");
    _sbody = fn.append_basic_block("oc.sbody");
    _cont = fn.append_basic_block("oc.cont");
    b.branch(_scan);

    bs = ir.IRBuilder(_scan);
    _i = bs.load(_idx, name="oc.iv");

    bs.cbranch(bs.icmp_unsigned(">=", _i, new_len, name="oc.end"), _cont, _body);
    bb = ir.IRBuilder(_body);
    _cur = bb.load(bb.gep(ord_a, [_i], name="oc.cp"), name="oc.cur");
    _hit = bb.icmp_signed("==", _cur, removed_slot, name="oc.hit");
    bb.cbranch(
        _hit, _shift, self._emit_order_scan_incr_block(bb, _idx, _i, i64, fn, _scan)
    );

    bh = ir.IRBuilder(_shift);
    _j = bh.alloca(i64, name="oc.j");
    bh.store(_i, _j);
    bh.branch(_sbody);
    bsb = ir.IRBuilder(_sbody);
    _jv = bsb.load(_j, name="oc.jv");
    _more = bsb.icmp_unsigned("<", _jv, new_len, name="oc.smore");
    _do = fn.append_basic_block("oc.do");
    bsb.cbranch(_more, _do, _cont);
    bd = ir.IRBuilder(_do);
    _nx = bd.add(_jv, ir.Constant(i64, 1), name="oc.jn");
    _nv = bd.load(bd.gep(ord_a, [_nx], name="oc.srcp"), name="oc.src");
    bd.store(_nv, bd.gep(ord_a, [_jv], name="oc.dstp"));
    bd.store(_nx, _j);
    bd.branch(_sbody);
    return ir.IRBuilder(_cont);
}

impl NaIRGenDicts._emit_order_scan_incr_block(
    b: ir.IRBuilder,
    idx_slot: ir.Value,
    i_cur: ir.Value,
    i64: ir.Type,
    fn: ir.Function,
    scan_bb: ir.Block
) -> ir.Block {
    _blk = fn.append_basic_block("oc.incr");
    _bi = ir.IRBuilder(_blk);
    _bi.store(_bi.add(i_cur, ir.Constant(i64, 1), name="oc.in"), idx_slot);
    _bi.branch(scan_bb);
    return _blk;
}

impl NaIRGenDicts._emit_dict_helpers(
    key_type_name: str,
    val_type_name: str,
    key_type: ir.Type,
    val_type: ir.Type,
    key_size: int = 0
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";

    if dict_key in self.dict_helpers {
        return;
    }

    _key_sz: int = int(key_size);
    if _key_sz == 0 and isinstance(key_type, ir.PointerType) {
        _pointee = key_type?.pointee;
        if _pointee is not None and isinstance(_pointee, ir.LiteralStructType) {
            _key_sz = self._get_struct_size(_pointee);
        }
    }

    _safe = dict_key.replace(":", "_");
    _struct_name = f"Dict.{key_type_name}.{val_type_name}";
    layout = self._container_layout_hash(key_type, val_type);
    dict_struct = self.llvm_module.context.get_identified_type(_struct_name);
    if not dict_struct.elements {
        dict_struct.set_body(*self._container_struct_fields(layout));
    }
    self.dict_types[dict_key] = dict_struct;
    self.container_layouts[_struct_name] = layout;
    dict_ptr_type = dict_struct.as_pointer();

    _rel_fn_decl = None;
    _rel_fn_name = f"__rc_release_dict_{_safe}";
    if not self._nogc_headerless() {
        _rel_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
        try {
            _rel_fn_decl = self.llvm_module.get_global(_rel_fn_name);
        } except KeyError {
            _rel_fn_decl = ir.Function(self.llvm_module, _rel_fnty, name=_rel_fn_name);
            _rel_fn_decl.linkage = "private";
        }
    }

    new_fn = self._emit_container_new_fn(
        f"__dict_new_{_safe}",
        dict_ptr_type,
        layout,
        dtor_fn=_rel_fn_decl,
        type_name=f"dict_{_safe}"
    );

    core = self._emit_hash_core_helpers(
        "dict",
        dict_key,
        dict_ptr_type,
        key_type,
        val_type,
        key_type_name,
        _key_sz,
        layout
    );

    len_fn = self._emit_container_len_fn(f"__dict_len_{_safe}", dict_ptr_type);

    if self._nogc_headerless() {
        self._emit_container_drop_fn(_struct_name);
    } else {
        release_fn = self._emit_container_release_fn(
            _rel_fn_name, dict_ptr_type, layout
        );
        self.dict_release_fns[dict_key] = release_fn;
    }

    self.dict_helpers[dict_key] = {
        "new": new_fn,
        "set": core["insert"],
        "set_ph": core["insert_ph"],
        "get": core["get"],
        "get_ph": core["get_ph"],
        "len": len_fn,
        "contains": core["contains"],
        "contains_ph": core["contains_ph"],
        "get_key": core["get_key"],
        "get_val": core["get_val"],
        "remove": core["remove"],
        "remove_ph": core["remove_ph"],
        "pop": core["pop"],
        "pop_ph": core["pop_ph"],
        "find": core["find"],
        "clear": core["clear"],
        "key_type": key_type,
        "val_type": val_type
    };
}

impl NaIRGenDicts._jacval_tag_for_type(ty: any) -> (int | None) {
    _t = self._tb_solve(ty);
    if self._tb_is_class_ref(_t) {
        return 6;
    }
    _kind = self._tb_kind(_t);
    if _kind in ("optional", "union") {
        _tags = {self._jacval_tag_for_type(_m) for _m in self._tb_non_none(_t)};
        return _tags.pop() if len(_tags) == 1 else None;
    }
    _by_kind = {
        "int": 0,
        "float": 1,
        "str": 2,
        "list": 3,
        "bytearray": 3,
        "dict": 4,
        "set": 5,
        "struct": 6,
        "object": 6,
        "class": 6,
        "tuple": 6,
        "bool": 7,
        "none": 8,
        "bytes": 2,
        "fn": 2,
        "file": 2,
        "binary_file": 2,
        "region": 2,
        "iterator": 2,
        "range": 2,
        "slice": 2,
        "complex": 2,
        "enum": 2
    };
    return _by_kind.get(_kind);
}

impl NaIRGenDicts._enum_value_kind(ty: any) -> str {
    _t = self._tb_solve(self._tb_opt_payload(ty) or ty);
    _name = self._tb_class_name(_t);
    _lay = self._registry().get_enum_layout(_name) if _name is not None else None;
    if _lay is None {
        raise AssertionError(
            f"native: enum `{_t}` has no layout to decide its tagged `any` representation"
        );
    }
    return "str" if _lay.is_string_enum else "int";
}

impl NaIRGenDicts._jacval_scalar_bits(value: ir.Value, payload_ty: any) -> tuple {
    b = self.builder;
    i64 = ir.IntType(64);
    _kind = self._tb_kind(payload_ty);
    if _kind == "enum" {
        _kind = "int";
    }
    if _kind == "bool" {
        _bv = value;
        if isinstance(_bv.type, ir.IntType) and _bv.type.width != 64 {
            _bv = b.zext(_bv, i64, name="jv.bext");
        }
        return (7, _bv);
    }
    if _kind == "int" {
        if not isinstance(value.type, ir.IntType) {
            raise AssertionError(
                f"native: int-typed value lowered as `{value.type}` cannot box into `any`"
            );
        }
        if value.type.width == 64 {
            return (0, value);
        }
        if value.type.width > 64 {
            return (0, b.trunc(value, i64, name="jv.itrunc"));
        }
        _unsigned = self._tb_unsigned(payload_ty) or value.type.width == 1;
        return (
            0,
            b.zext(value, i64, name="jv.iext")
                if _unsigned
                else b.sext(value, i64, name="jv.isext")
        );
    }
    if _kind == "float" {
        _fv = value;
        if isinstance(_fv.type, ir.IntType) {
            _fv = b.sitofp(_fv, ir.DoubleType(), name="jv.i2f");
        } elif isinstance(_fv.type, ir.FloatType) {
            _fv = b.fpext(_fv, ir.DoubleType(), name="jv.f32ext");
        }
        return (1, b.bitcast(_fv, i64, name="jv.f2i"));
    }
    raise AssertionError(
        f"native: `{payload_ty}` ({_kind}) is not a scalar that boxes into `any` (llvm={value.type})"
    );
}

impl NaIRGenDicts._jacval_none -> ir.Value {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    jv_alloca = self._entry_alloca(self.jacval_type, "jv.none");
    self.builder.store(
        ir.Constant(i8, 8),
        self.builder.gep(
            jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="jv.none.tag"
        )
    );
    self.builder.store(
        ir.Constant(i64, 0),
        self.builder.gep(
            jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="jv.none.pay"
        )
    );
    return self.builder.load(jv_alloca, name="jacval.none");
}

impl NaIRGenDicts._box_to_jacval(value: ir.Value, ty: any) -> ir.Value {
    value = self._str_norm(value);
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    if self?.jacval_type and value.type == self.jacval_type {
        return value;
    }
    _ty = self._tb_solve(ty);
    _kind = self._tb_kind(_ty);
    _dyn_kind = _kind in ("any", "unknown", "typevar", "never");
    if _dyn_kind and not isinstance(value.type, (ir.IntType, ir.DoubleType)) {
        raise AssertionError(
            f"native: boxing `{value.type}` into `any` without a concrete checker type (ty={ty}) at {self._na_loc()}"
        );
    }
    _pty = self._tb_opt_payload(_ty);
    _pty = _pty if _pty is not None else _ty;
    _pkind = self._tb_kind(_pty);
    jv_alloca = self._entry_alloca(self.jacval_type, "jacval");
    tag_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="jv.tag.ptr"
    );
    payload_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="jv.payload.ptr"
    );
    if _kind == "none" or isinstance(value.type, ir.VoidType) {
        b.store(ir.Constant(i8, 8), tag_ptr);
        b.store(ir.Constant(i64, 0), payload_ptr);
        return b.load(jv_alloca, name="jacval");
    }
    if _dyn_kind {
        if isinstance(value.type, ir.DoubleType) {
            b.store(ir.Constant(i8, 1), tag_ptr);
            b.store(b.bitcast(value, i64, name="jv.dyn.f64"), payload_ptr);
        } elif value.type.width == 1 {
            b.store(ir.Constant(i8, 7), tag_ptr);
            b.store(b.zext(value, i64, name="jv.dyn.bool"), payload_ptr);
        } else {
            b.store(ir.Constant(i8, 0), tag_ptr);
            _wide = value
                if value.type.width == 64
                else b.sext(value, i64, name="jv.dyn.int");
            b.store(_wide, payload_ptr);
        }
        return b.load(jv_alloca, name="jacval");
    }
    if isinstance(value.type, ir.LiteralStructType) {
        _tup_ptr = self._box_value_tuple(value);
        b.store(ir.Constant(i8, 6), tag_ptr);
        b.store(b.ptrtoint(_tup_ptr, i64, name="jv.tup.p2i"), payload_ptr);
        return b.load(jv_alloca, name="jacval");
    }
    _opt_pl = self._opt_payload_of(value.type);
    if _opt_pl is not None and not isinstance(_opt_pl, ir.PointerType) {
        _has = b.extract_value(value, 0, name="jv.opt.has");
        _pv = b.extract_value(value, 1, name="jv.opt.pv");
        (_stag, _sbits) = self._jacval_scalar_bits(_pv, _pty);
        _live = b.icmp_unsigned("!=", _has, ir.Constant(i8, 0), name="jv.opt.live");
        b.store(
            b.select(
                _live, ir.Constant(i8, _stag), ir.Constant(i8, 8), name="jv.opt.tag"
            ),
            tag_ptr
        );
        b.store(
            b.select(_live, _sbits, ir.Constant(i64, 0), name="jv.opt.bits"),
            payload_ptr
        );
        return b.load(jv_alloca, name="jacval");
    }
    if isinstance(value.type, ir.PointerType) {
        _tag = self._jacval_tag_for_type(_ty);
        if _tag is None {
            raise AssertionError(
                f"native: no `any` tag for a `{_ty}` value (llvm={value.type})"
            );
        }
        payload = b.ptrtoint(value, i64, name="jv.p2i");
        if self._tb_has_none(_ty) {
            is_null = b.icmp_unsigned(
                "==", payload, ir.Constant(i64, 0), name="jv.isnone"
            );
            none_or_tag = b.select(
                is_null, ir.Constant(i8, 8), ir.Constant(i8, _tag), name="jv.nonetag"
            );
            b.store(none_or_tag, tag_ptr);
        } else {
            b.store(ir.Constant(i8, _tag), tag_ptr);
        }
        b.store(payload, payload_ptr);
        return b.load(jv_alloca, name="jacval");
    }
    if _pkind in ("bool", "int", "float", "enum") {
        (_stag, _sbits) = self._jacval_scalar_bits(value, _pty);
        b.store(ir.Constant(i8, _stag), tag_ptr);
        b.store(_sbits, payload_ptr);
        return b.load(jv_alloca, name="jacval");
    }
    self.emit(
        E5092,
        kind="expression",
        name=f"`any` box of {value.type}",
        help_text=f"A `{_ty}` value lowered as `{value.type}` has no tagged `any` representation natively."
    );
    b.store(ir.Constant(i8, 0), tag_ptr);
    b.store(ir.Constant(i64, 0), payload_ptr);
    return b.load(jv_alloca, name="jacval");
}

impl NaIRGenDicts._unbox_from_jacval(jv: ir.Value, target_type: ir.Type) -> ir.Value {
    b = self.builder;
    i64 = ir.IntType(64);
    payload = b.extract_value(jv, 1, name="jv.unbox.payload");
    if isinstance(target_type, ir.IntType) {
        if target_type.width == 64 {
            return payload;
        }
        if target_type.width == 1 {
            return b.icmp_unsigned(
                "!=", payload, ir.Constant(i64, 0), name="jv.unbox.bool"
            );
        }
        return b.trunc(payload, target_type, name="jv.unbox.itrunc");
    }
    if isinstance(target_type, ir.DoubleType) {
        return b.bitcast(payload, target_type, name="jv.unbox.f");
    }
    if isinstance(target_type, ir.FloatType) {
        _d = b.bitcast(payload, ir.DoubleType(), name="jv.unbox.f64");
        return b.fptrunc(_d, target_type, name="jv.unbox.f32");
    }
    if isinstance(target_type, ir.PointerType) {
        return b.inttoptr(payload, target_type, name="jv.unbox.p");
    }

    self.emit(E5092, kind="expression", name=f"`any` unbox to {target_type}");
    return ir.Constant(target_type, None);
}

impl NaIRGenDicts._dict_key_reconcile(
    dk: (str | None), val: (ir.Value | None)
) -> (str | None) {
    return dk;
}

impl NaIRGenDicts._codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None) {
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    _dty = self._expr_type_of(nd);
    _kt = self._tb_elem(_dty, 0);
    _vt = self._tb_elem(_dty, 1);
    if _kt is None or _vt is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="dict display without key/value types",
            help_text="The checker stamped no key or value type on this dict display, so there is no native layout to build it in. Annotate the binding (for example `d: dict[str, int] = {}`), or give the display an entry."
        );
        return None;
    }
    _kl = self._elem_slot_llvm(_kt);
    _vl = self._elem_slot_llvm(_vt);
    if _kl is not None and self?.jacval_type and _kl == self.jacval_type {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="dict with mixed key types",
            help_text="Native dicts hash a single concrete key type; a dict whose keys mix representations has no native storage. Use one key type (for example str) and keep the mixing on the value side."
        );
        return None;
    }
    if _kl is None or _vl is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name=f"dict of {_kt} to {_vt}",
            help_text="The key or value type has no native lowering, so the dict has no native layout. Use lowerable key and value types, or move this code to a @sv/Python context."
        );
        return None;
    }
    (key_type_name, key_size) = self._dict_key_spec(_kl);
    val_type_name = self._dict_val_spec(_vl);
    self._emit_dict_helpers(key_type_name, val_type_name, _kl, _vl, key_size);
    helpers = self.dict_helpers[f"{key_type_name}:{val_type_name}"];
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];
    use_jacval = val_type_name == "jacval";

    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="dict.new"
    );
    self._nogc_stamp_elem_drops(dict_val, [_kt, _vt]);

    for pair in (nd.kv_pairs or []) {
        k = self._codegen_expr(pair.key);
        v = self._str_norm(self._codegen_expr(pair.value));
        if k is None or v is None {
            self.emit(
                E5092,
                node_override=pair,
                kind="expression",
                name="dict entry",
                help_text="This entry of the dict display did not lower, so the dict would have been built without it. Move the expression out of the display, or move the enclosing code to a @sv/Python context."
            );
            return None;
        }
        v = self._nogc_elem_prep(pair.value, v);
        _orig_k = k;
        _orig_v = v;
        k = self._coerce_typed(k, key_type, self._expr_type_of(pair.key));
        if use_jacval {
            v = self._box_to_jacval(v, ty=self._expr_type_of(pair.value));
        } else {
            v = self._coerce_typed(v, val_type, self._expr_type_of(pair.value));
        }
        (_set_fn, _kh) = self._static_key_op(helpers, "set", pair.key);
        _set_args = [dict_val, k, v];
        if _kh is not None {
            _set_args.append(_kh);
        }
        self._rc_call_with_ctx(_set_fn, _set_args, op="dict_init", loc=_loc);

        if isinstance(_orig_k.type, ir.PointerType) and self._is_owned(_orig_k) {
            self._emit_rc_release_simple(_orig_k, op="dict_init", loc=_loc);
        }
        if isinstance(_orig_v.type, ir.PointerType) and self._is_owned(_orig_v) {
            self._emit_rc_release_simple(_orig_v, op="dict_init", loc=_loc);
        }
    }
    return dict_val;
}

impl NaIRGenDicts._codegen_dict_access(
    target_val: ir.Value,
    key_val: ir.Value,
    key_type_name: str,
    val_type_name: str,
    key_node: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return None;
    }
    target_val = self._unwrap_opt_container(target_val);
    key_type = helpers["key_type"];
    key_val = self._coerce_typed(key_val, key_type, self._expr_type_of(key_node));

    (_has_fn, _kh) = self._static_key_op(helpers, "contains", key_node);
    _has_args = [target_val, key_val];
    if _kh is not None {
        _has_args.append(_kh);
    }
    key_exists = self.builder.call(_has_fn, _has_args, name="dict.has");
    not_exists = self.builder.not_(key_exists, name="dict.nokey");
    self._emit_runtime_raise(not_exists, "KeyError", "key not found");
    (_get_fn, _gh) = self._static_key_op(helpers, "get", key_node);
    _get_args = [target_val, key_val];
    if _gh is not None {
        _get_args.append(_gh);
    }
    return self.builder.call(_get_fn, _get_args, name="dict.get");
}

impl NaIRGenDicts._codegen_dict_set(
    target_val: ir.Value,
    key_val: ir.Value,
    value: ir.Value,
    key_type_name: str,
    val_type_name: str,
    key_node: (uni.UniNode | None) = None
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return;
    }
    target_val = self._unwrap_opt_container(target_val);
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];
    _orig_key = key_val;
    _orig_value = value;
    key_val = self._coerce_typed(key_val, key_type, self._expr_type_of(key_node));
    value = self._coerce_type(value, val_type);
    _dset_ctx_loc = getattr(
        _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
    );
    (_set_fn, _kh) = self._static_key_op(helpers, "set", key_node);
    _set_args = [target_val, key_val, value];
    if _kh is not None {
        _set_args.append(_kh);
    }
    self._rc_call_with_ctx(_set_fn, _set_args, op="dict_set", loc=_dset_ctx_loc);

    if (
        isinstance(_orig_key.type, ir.PointerType)
        and isinstance(key_type, ir.PointerType)
        and self._is_owned(_orig_key)
    ) {
        self._emit_rc_release_simple(_orig_key, op="dict_set", loc=_dset_ctx_loc);
    }

    if (
        isinstance(_orig_value.type, ir.PointerType)
        and self._elem_kind(val_type) != "raw"
        and self._is_owned(_orig_value)
    ) {
        _dset_loc = getattr(
            _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
        );
        self._emit_rc_release_simple(_orig_value, op="dict_set", loc=_dset_loc);
    }
}
