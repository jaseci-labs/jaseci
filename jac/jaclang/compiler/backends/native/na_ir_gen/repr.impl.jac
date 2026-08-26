impl NaIRGenRepr._repr_const_str(text: str) -> ir.Value {
    g = self._make_global_string(text, name_prefix=".repr.c");
    if self._nogc_headerless() {
        return self._call_str_dup(self.builder, g, name="rp.c.dup");
    }
    return g;
}

impl NaIRGenRepr._repr_acc_concat(
    acc_slot: ir.Value, piece: ir.Value, own_piece: bool
) -> None {
    b = self.builder;
    cur: any = b.load(acc_slot, name="rp.cur");
    res = self._emit_str_concat(cur, piece);
    self._emit_rc_release_simple(cur, op="mstr_old", loc="");
    if own_piece {
        self._emit_rc_release_simple(piece, op="mstr_val", loc="");
    }
    b.store(res, acc_slot);
}

impl NaIRGenRepr._repr_maybe_sep(
    fn: ir.Function, i_val: ir.Value, acc_slot: ir.Value, sep_g: ir.Value
) -> None {
    b = self.builder;
    i64 = ir.IntType(64);
    need = b.icmp_signed(">", i_val, ir.Constant(i64, 0), name="rp.sep.need");
    sep_bb = fn.append_basic_block("rp.sep");
    cont_bb = fn.append_basic_block("rp.sep.cont");
    b.cbranch(need, sep_bb, cont_bb);
    b.position_at_end(sep_bb);
    self._repr_acc_concat(acc_slot, sep_g, False);
    b.branch(cont_bb);
    b.position_at_end(cont_bb);
}

impl NaIRGenRepr._repr_call_elem_fn(elem_fn: ir.Function, elem: ir.Value) -> ir.Value {
    _pty: any = elem_fn.args[0].type;
    v = elem if elem.type == _pty else self._coerce_type(elem, _pty);
    res: any = self.builder.call(elem_fn, [v], name="rp.piece");
    return self._mark_owned(res);
}

impl NaIRGenRepr._repr_cache_key(t: any) -> (str | None) {
    t = self._tb_solve(t);
    _m = t?.mangle if t is not None else None;
    if not callable(_m) {
        return None;
    }
    return "t:" + str(_m());
}

impl NaIRGenRepr._repr_fn_for_type(t: any) -> (ir.Function | None) {
    t = self._tb_solve(t);
    _kind = self._tb_kind(t);
    if _kind == "int" {
        return self._repr_leaf_fn("int");
    }
    if _kind == "bool" {
        return self._repr_leaf_fn("bool");
    }
    if _kind == "float" {
        return self._float_repr_fn();
    }
    if _kind == "str" {
        return self._repr_str_fn();
    }
    if _kind in ("any", "union") {
        return self._repr_jacval_fn();
    }
    if _kind == "optional" {
        _pfn = self._repr_fn_for_type(self._tb_opt_payload(t));
        if _pfn is not None and isinstance(_pfn.args[0].type, ir.PointerType) {
            return _pfn;
        }
        return self._repr_jacval_fn();
    }
    if _kind == "struct" {
        _name = self._tb_class_name(t);
        if _name is not None and _name in self.struct_types {
            return self._repr_obj_fn(_name);
        }
        return None;
    }
    if _kind == "tuple" and self._tuple_has_variadic_arg(self._tb_args(t)) {
        _kind = "list";
    }
    if _kind not in ("list", "dict", "set", "tuple") {
        return None;
    }
    _key = self._repr_cache_key(t);
    if _key is None {
        return None;
    }
    _cached = self._repr_fns.get(_key);
    if _cached is not None {
        return _cached;
    }
    fn: (ir.Function | None) = None;
    if _kind == "list" {
        fn = self._repr_list_fn(t, _key);
    } elif _kind == "dict" {
        fn = self._repr_dict_fn(t, _key);
    } elif _kind == "set" {
        fn = self._repr_set_fn(t, _key);
    } else {
        fn = self._repr_tuple_fn(t, _key);
    }
    if fn is not None {
        self._repr_fns[_key] = fn;
    }
    return fn;
}

impl NaIRGenRepr._repr_leaf_fn(kind: str) -> (ir.Function | None) {
    if kind not in ("int", "bool") {
        return None;
    }
    _cached = self._repr_fns.get(kind);
    if _cached is not None {
        return _cached;
    }
    import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
    i8p: any = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fnty = ir.FunctionType(i8p, [i64]);
    fn: any = ir.Function(
        self.llvm_module, fnty, name=f"__jac_repr_{native_safe_sym(kind)}"
    );
    fn.linkage = "private";
    fn.args[0].name = "v";
    v = fn.args[0];
    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;
    if kind == "bool" {
        t_g = self._make_global_string("True", name_prefix=".repr.true");
        f_g = self._make_global_string("False", name_prefix=".repr.false");
        nz = b.icmp_signed("!=", v, ir.Constant(i64, 0), name="rp.b.nz");
        sel: any = b.select(nz, t_g, f_g, name="rp.b.sel");
        if self._nogc_headerless() {
            sel = self._call_str_dup(b, sel, name="rp.b.dup");
        }
        b.ret(sel);
    } else {
        snprintf = self._get_or_declare_extern(
            "snprintf", i32, [i8p, i64, i8p], var_arg=True
        );
        fmt_g = self._make_global_string("%lld", name_prefix=".repr.fmt.int");
        cap = ir.Constant(i64, 24);
        buf: any = b.call(self.rc_alloc_fn, [cap], name="rp.i.buf");
        b.call(snprintf, [buf, cap, fmt_g, v]);
        self._emit_set_type_tag(b, buf, "str");
        b.ret(buf);
    }
    self._builder = saved_builder;
    self._repr_fns[kind] = fn;
    return fn;
}

impl NaIRGenRepr._repr_str_fn -> ir.Function {
    _cached = self._repr_fns.get("str");
    if _cached is not None {
        return _cached;
    }
    import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i8p: any = i8.as_pointer();
    i64 = ir.IntType(64);
    fnty = ir.FunctionType(i8p, [i8p]);
    fn: any = ir.Function(
        self.llvm_module, fnty, name=f"__jac_repr_{native_safe_sym('str')}"
    );
    fn.linkage = "private";
    fn.args[0].name = "s";
    s = fn.args[0];
    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;
    SQ = ir.Constant(i8, 0x27);
    DQ = ir.Constant(i8, 0x22);
    BSL = ir.Constant(i8, 0x5C);

    null_bb = fn.append_basic_block("rp.s.null");
    scan_bb = fn.append_basic_block("rp.s.scan");
    is_null = b.icmp_unsigned("==", s, ir.Constant(i8p, None), name="rp.s.isnull");
    b.cbranch(is_null, null_bb, scan_bb);
    b.position_at_end(null_bb);
    b.ret(self._repr_const_str("None"));

    b.position_at_end(scan_bb);
    slen = self._call_str_len(b, s, name="rp.s.len");
    has_sq = b.alloca(i1, name="rp.has.sq");
    has_dq = b.alloca(i1, name="rp.has.dq");
    si = b.alloca(i64, name="rp.si");
    b.store(ir.Constant(i1, 0), has_sq);
    b.store(ir.Constant(i1, 0), has_dq);
    b.store(ir.Constant(i64, 0), si);
    sc_cond = fn.append_basic_block("rp.sc.cond");
    sc_body = fn.append_basic_block("rp.sc.body");
    sc_done = fn.append_basic_block("rp.sc.done");
    b.branch(sc_cond);
    b.position_at_end(sc_cond);
    sidx = b.load(si, name="rp.sidx");
    b.cbranch(b.icmp_signed("<", sidx, slen, name="rp.sc.go"), sc_body, sc_done);
    b.position_at_end(sc_body);
    sc = b.load(b.gep(s, [sidx], name="rp.sc.ptr"), name="rp.sc.ch");
    b.store(
        b.or_(b.load(has_sq), b.icmp_unsigned("==", sc, SQ, name="rp.sc.isq")), has_sq
    );
    b.store(
        b.or_(b.load(has_dq), b.icmp_unsigned("==", sc, DQ, name="rp.sc.idq")), has_dq
    );
    b.store(b.add(sidx, ir.Constant(i64, 1)), si);
    b.branch(sc_cond);
    b.position_at_end(sc_done);
    use_dq = b.and_(
        b.load(has_sq), b.not_(b.load(has_dq), name="rp.no.dq"), name="rp.use.dq"
    );
    quote = b.select(use_dq, DQ, SQ, name="rp.quote");

    cap = b.add(b.mul(slen, ir.Constant(i64, 4)), ir.Constant(i64, 3), name="rp.cap");
    buf: any = b.call(self.rc_alloc_fn, [cap], name="rp.s.buf");
    b.store(quote, buf);
    oi = b.alloca(i64, name="rp.oi");
    wi = b.alloca(i64, name="rp.wi");
    b.store(ir.Constant(i64, 1), oi);
    b.store(ir.Constant(i64, 0), wi);

    w_cond = fn.append_basic_block("rp.w.cond");
    w_body = fn.append_basic_block("rp.w.body");
    w_done = fn.append_basic_block("rp.w.done");
    b.branch(w_cond);
    b.position_at_end(w_cond);
    widx = b.load(wi, name="rp.widx");
    b.cbranch(b.icmp_signed("<", widx, slen, name="rp.w.go"), w_body, w_done);
    b.position_at_end(w_body);
    c = b.load(b.gep(s, [widx], name="rp.c.ptr"), name="rp.c");
    is_bsl = b.icmp_unsigned("==", c, BSL, name="rp.is.bsl");
    is_q = b.icmp_unsigned("==", c, quote, name="rp.is.q");
    is_tab = b.icmp_unsigned("==", c, ir.Constant(i8, 0x09), name="rp.is.tab");
    is_nl = b.icmp_unsigned("==", c, ir.Constant(i8, 0x0A), name="rp.is.nl");
    is_cr = b.icmp_unsigned("==", c, ir.Constant(i8, 0x0D), name="rp.is.cr");
    ge_sp = b.icmp_unsigned(">=", c, ir.Constant(i8, 0x20), name="rp.ge.sp");
    not_del = b.icmp_unsigned("!=", c, ir.Constant(i8, 0x7F), name="rp.not.del");
    in_rng = b.and_(ge_sp, not_del, name="rp.in.rng");
    is_special = b.or_(is_bsl, is_q, name="rp.is.special");
    is_ctrl = b.or_(b.or_(is_tab, is_nl, name="rp.tn"), is_cr, name="rp.is.ctrl");
    is_plain = b.and_(in_rng, b.not_(is_special, name="rp.not.sp"), name="rp.is.plain");
    is_hex = b.not_(
        b.or_(b.or_(is_special, is_ctrl, name="rp.sc1"), is_plain, name="rp.sc2"),
        name="rp.is.hex"
    );

    hi = b.lshr(c, ir.Constant(i8, 4), name="rp.hi");
    lo = b.and_(c, ir.Constant(i8, 0x0F), name="rp.lo");
    hi_lt = b.icmp_unsigned("<", hi, ir.Constant(i8, 10), name="rp.hi.lt");
    lo_lt = b.icmp_unsigned("<", lo, ir.Constant(i8, 10), name="rp.lo.lt");
    hi_hex = b.select(
        hi_lt,
        b.add(hi, ir.Constant(i8, 48)),
        b.add(hi, ir.Constant(i8, 87)),
        name="rp.hi.x"
    );
    lo_hex = b.select(
        lo_lt,
        b.add(lo, ir.Constant(i8, 48)),
        b.add(lo, ir.Constant(i8, 87)),
        name="rp.lo.x"
    );

    o0 = b.select(is_plain, c, BSL, name="rp.o0");
    ctrl_ch = b.select(
        is_tab,
        ir.Constant(i8, 0x74),
        b.select(is_nl, ir.Constant(i8, 0x6E), ir.Constant(i8, 0x72), name="rp.nr"),
        name="rp.ctrl.ch"
    );
    special_ch = b.select(is_bsl, BSL, quote, name="rp.special.ch");
    o1 = b.select(
        is_special,
        special_ch,
        b.select(is_ctrl, ctrl_ch, ir.Constant(i8, 0x78), name="rp.o1.x"),
        name="rp.o1"
    );
    klen = b.select(
        is_plain,
        ir.Constant(i64, 1),
        b.select(is_hex, ir.Constant(i64, 4), ir.Constant(i64, 2), name="rp.k0"),
        name="rp.klen"
    );

    oi_cur = b.load(oi, name="rp.oi.cur");
    b.store(o0, b.gep(buf, [oi_cur], name="rp.s0"));
    b.store(o1, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 1))], name="rp.s1"));
    b.store(hi_hex, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 2))], name="rp.s2"));
    b.store(lo_hex, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 3))], name="rp.s3"));
    b.store(b.add(oi_cur, klen), oi);
    b.store(b.add(widx, ir.Constant(i64, 1)), wi);
    b.branch(w_cond);
    b.position_at_end(w_done);
    oi_end = b.load(oi, name="rp.oi.end");
    b.store(quote, b.gep(buf, [oi_end], name="rp.qc"));
    b.store(
        ir.Constant(i8, 0),
        b.gep(buf, [b.add(oi_end, ir.Constant(i64, 1))], name="rp.nul")
    );
    self._emit_set_type_tag(b, buf, "str");
    b.ret(buf);
    self._builder = saved_builder;
    self._repr_fns["str"] = fn;
    return fn;
}

impl NaIRGenRepr._repr_obj_fn(arch_name: str) -> ir.Function {
    _cached = self._repr_fns.get(arch_name);
    if _cached is not None {
        return _cached;
    }
    import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
    i8p: any = ir.IntType(8).as_pointer();
    _pst: any = self.struct_types[arch_name];
    pty = _pst.as_pointer();
    fnty = ir.FunctionType(i8p, [pty]);
    fn: any = ir.Function(
        self.llvm_module, fnty, name=f"__jac_repr_{native_safe_sym(arch_name)}"
    );
    fn.linkage = "private";
    fn.args[0].name = "obj";
    o = fn.args[0];
    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;
    null_bb = fn.append_basic_block("rp.o.null");
    live_bb = fn.append_basic_block("rp.o.live");
    is_null = b.icmp_unsigned("==", o, ir.Constant(pty, None), name="rp.o.isnull");
    b.cbranch(is_null, null_bb, live_bb);
    b.position_at_end(null_bb);
    b.ret(self._repr_const_str("None"));
    b.position_at_end(live_bb);
    _m: any = self._resolve_method(arch_name, "__repr__");
    _res: any = None;
    if _m is None {
        _res = self._emit_default_obj_repr(o, arch_name);
    } else {
        if self._arch_has_vtable(arch_name) {
            _res = self._codegen_virtual_call(o, "__repr__", [o], arch_name);
        }
        if _res is None {
            _co = [self._coerce_type(o, _m.args[0].type)];
            _res = self.builder.call(_m, _co, name="call.__repr__");
        }
    }
    b.ret(self._coerce_type(_res, i8p));
    self._builder = saved_builder;
    self._repr_fns[arch_name] = fn;
    return fn;
}

impl NaIRGenRepr._repr_seq_fn(
    fn_name: str,
    cont_ptr_ty: ir.Type,
    elem_fn: ir.Function,
    open_text: str,
    close_text: str,
    empty_text: (str | None),
    get_fn: (ir.Function | None) = None
) -> ir.Function {
    i8p: any = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fnty = ir.FunctionType(i8p, [cont_ptr_ty]);
    fn: any = ir.Function(self.llvm_module, fnty, name=fn_name);
    fn.linkage = "private";
    fn.args[0].name = "cont";
    c_arg = fn.args[0];
    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;
    null_bb = fn.append_basic_block("rp.null");
    init_bb = fn.append_basic_block("rp.init");
    is_null = b.icmp_unsigned(
        "==", c_arg, ir.Constant(cont_ptr_ty, None), name="rp.isnull"
    );
    b.cbranch(is_null, null_bb, init_bb);
    b.position_at_end(null_bb);
    b.ret(self._repr_const_str("None"));
    b.position_at_end(init_bb);
    open_g = self._make_global_string(open_text, name_prefix=".repr.open");
    close_g = self._make_global_string(close_text, name_prefix=".repr.close");
    sep_g = self._make_global_string(", ", name_prefix=".repr.sep");
    z32 = ir.Constant(i32, 0);
    len_v = b.load(b.gep(c_arg, [z32, z32], name="rp.len.p"), name="rp.len");
    if empty_text is not None {
        empty_bb = fn.append_basic_block("rp.empty");
        main_bb = fn.append_basic_block("rp.main");
        is_empty = b.icmp_signed("==", len_v, ir.Constant(i64, 0), name="rp.isempty");
        b.cbranch(is_empty, empty_bb, main_bb);
        b.position_at_end(empty_bb);
        b.ret(self._repr_const_str(empty_text));
        b.position_at_end(main_bb);
    }
    data = None;
    if get_fn is None {
        data = b.load(
            b.gep(c_arg, [z32, ir.Constant(i32, 2)], name="rp.data.p"), name="rp.data"
        );
    }
    acc: any = b.alloca(i8p, name="rp.acc");
    iv = b.alloca(i64, name="rp.i");
    b.store(self._rc_strdup(open_g, name="rp.acc0"), acc);
    b.store(ir.Constant(i64, 0), iv);
    cond_bb = fn.append_basic_block("rp.cond");
    body_bb = fn.append_basic_block("rp.body");
    done_bb = fn.append_basic_block("rp.done");
    b.branch(cond_bb);
    b.position_at_end(cond_bb);
    i_cur: any = b.load(iv, name="rp.iv");
    b.cbranch(b.icmp_signed("<", i_cur, len_v, name="rp.more"), body_bb, done_bb);
    b.position_at_end(body_bb);
    self._repr_maybe_sep(fn, i_cur, acc, sep_g);
    if get_fn is None {
        elem: any = b.load(b.gep(data, [i_cur], name="rp.elem.p"), name="rp.elem");
    } else {
        elem: any = b.call(get_fn, [c_arg, i_cur], name="rp.elem");
    }
    piece = self._repr_call_elem_fn(elem_fn, elem);
    self._repr_acc_concat(acc, piece, True);
    b.store(b.add(i_cur, ir.Constant(i64, 1), name="rp.inc"), iv);
    b.branch(cond_bb);
    b.position_at_end(done_bb);
    _fin: any = b.load(acc, name="rp.fin");
    res: any = self._emit_str_concat(_fin, close_g);
    self._emit_rc_release_simple(_fin, op="mstr_old", loc="");
    self._emit_set_type_tag(b, res, "str");
    b.ret(res);
    self._builder = saved_builder;
    return fn;
}

impl NaIRGenRepr._repr_list_fn(t: any, key: str) -> (ir.Function | None) {
    import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
    _elem = self._tb_elem(t);
    if _elem is None {
        return None;
    }
    elem_fn = self._repr_fn_for_type(_elem);
    if elem_fn is None {
        return None;
    }
    _spec = self._list_spec_for_type(t);
    _st: any = self.list_types.get(_spec) if _spec is not None else None;
    if _st is None {
        return None;
    }
    return self._repr_seq_fn(
        f"__jac_repr_{native_safe_sym(key)}", _st.as_pointer(), elem_fn, "[", "]", None
    );
}

impl NaIRGenRepr._repr_set_fn(t: any, key: str) -> (ir.Function | None) {
    import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
    _elem = self._tb_elem(t);
    if _elem is None {
        return None;
    }
    elem_fn = self._repr_fn_for_type(_elem);
    if elem_fn is None {
        return None;
    }
    _spec = self._set_spec_for_type(t);
    _st: any = self.set_types.get(_spec) if _spec is not None else None;
    _sh = self.set_helpers.get(_spec) if _spec is not None else None;
    if _st is None or _sh is None {
        return None;
    }
    return self._repr_seq_fn(
        f"__jac_repr_{native_safe_sym(key)}",
        _st.as_pointer(),
        elem_fn,
        "{",
        "}",
        "set()",
        get_fn=_sh["get"]
    );
}

impl NaIRGenRepr._repr_dict_fn(t: any, key: str) -> (ir.Function | None) {
    import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
    _kt = self._tb_elem(t, 0);
    _vt = self._tb_elem(t, 1);
    if _kt is None or _vt is None {
        return None;
    }
    kfn = self._repr_fn_for_type(_kt);
    vfn = self._repr_fn_for_type(_vt);
    if kfn is None or vfn is None {
        return None;
    }
    _spec = self._dict_spec_for_type(t);
    _st: any = self.dict_types.get(_spec) if _spec is not None else None;
    if _st is None {
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    pty = _st.as_pointer();
    fnty = ir.FunctionType(i8p, [pty]);
    fn: any = ir.Function(
        self.llvm_module, fnty, name=f"__jac_repr_{native_safe_sym(key)}"
    );
    fn.linkage = "private";
    fn.args[0].name = "d";
    d_arg = fn.args[0];
    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;
    null_bb = fn.append_basic_block("rp.d.null");
    init_bb = fn.append_basic_block("rp.d.init");
    is_null = b.icmp_unsigned("==", d_arg, ir.Constant(pty, None), name="rp.d.isnull");
    b.cbranch(is_null, null_bb, init_bb);
    b.position_at_end(null_bb);
    b.ret(self._repr_const_str("None"));
    b.position_at_end(init_bb);
    open_g = self._make_global_string("{", name_prefix=".repr.open");
    close_g = self._make_global_string("}", name_prefix=".repr.close");
    sep_g = self._make_global_string(", ", name_prefix=".repr.sep");
    colon_g = self._make_global_string(": ", name_prefix=".repr.colon");
    z32 = ir.Constant(i32, 0);
    len_v = b.load(b.gep(d_arg, [z32, z32], name="rp.d.len.p"), name="rp.d.len");
    keys = b.load(
        b.gep(d_arg, [z32, ir.Constant(i32, 2)], name="rp.d.keys.p"), name="rp.d.keys"
    );
    vals = b.load(
        b.gep(d_arg, [z32, ir.Constant(i32, 3)], name="rp.d.vals.p"), name="rp.d.vals"
    );
    order = b.load(
        b.gep(d_arg, [z32, ir.Constant(i32, 6)], name="rp.d.ord.p"), name="rp.d.order"
    );
    acc: any = b.alloca(i8p, name="rp.acc");
    iv = b.alloca(i64, name="rp.i");
    b.store(self._rc_strdup(open_g, name="rp.acc0"), acc);
    b.store(ir.Constant(i64, 0), iv);
    cond_bb = fn.append_basic_block("rp.cond");
    body_bb = fn.append_basic_block("rp.body");
    done_bb = fn.append_basic_block("rp.done");
    b.branch(cond_bb);
    b.position_at_end(cond_bb);
    i_cur: any = b.load(iv, name="rp.iv");
    b.cbranch(b.icmp_signed("<", i_cur, len_v, name="rp.more"), body_bb, done_bb);
    b.position_at_end(body_bb);
    _slot: any = b.load(b.gep(order, [i_cur], name="rp.slp"), name="rp.slot");
    self._repr_maybe_sep(fn, i_cur, acc, sep_g);
    k_el: any = b.load(b.gep(keys, [_slot], name="rp.k.p"), name="rp.k");
    self._repr_acc_concat(acc, self._repr_call_elem_fn(kfn, k_el), True);
    self._repr_acc_concat(acc, colon_g, False);
    v_el: any = b.load(b.gep(vals, [_slot], name="rp.v.p"), name="rp.v");
    self._repr_acc_concat(acc, self._repr_call_elem_fn(vfn, v_el), True);
    b.store(b.add(i_cur, ir.Constant(i64, 1), name="rp.inc"), iv);
    b.branch(cond_bb);
    b.position_at_end(done_bb);
    _fin: any = b.load(acc, name="rp.fin");
    res: any = self._emit_str_concat(_fin, close_g);
    self._emit_rc_release_simple(_fin, op="mstr_old", loc="");
    self._emit_set_type_tag(b, res, "str");
    b.ret(res);
    self._builder = saved_builder;
    return fn;
}

impl NaIRGenRepr._repr_tuple_fn(t: any, key: str) -> (ir.Function | None) {
    import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
    _fields = self._tb_args(t);
    if not _fields {
        return None;
    }
    _lowered = self._lower_type(t);
    if (
        _lowered is None
        or not isinstance(_lowered, ir.PointerType)
        or not isinstance(_lowered.pointee, ir.LiteralStructType)
        or len(_lowered.pointee.elements) != len(_fields)
    ) {
        return None;
    }
    _ffns: list = [];
    for _ft in _fields {
        _f = self._repr_fn_for_type(_ft);
        if _f is None {
            return None;
        }
        _ffns.append(_f);
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    pty = _lowered;
    fnty = ir.FunctionType(i8p, [pty]);
    fn: any = ir.Function(
        self.llvm_module, fnty, name=f"__jac_repr_{native_safe_sym(key)}"
    );
    fn.linkage = "private";
    fn.args[0].name = "t";
    t_arg = fn.args[0];
    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;
    null_bb = fn.append_basic_block("rp.t.null");
    live_bb = fn.append_basic_block("rp.t.live");
    is_null = b.icmp_unsigned("==", t_arg, ir.Constant(pty, None), name="rp.t.isnull");
    b.cbranch(is_null, null_bb, live_bb);
    b.position_at_end(null_bb);
    b.ret(self._repr_const_str("None"));
    b.position_at_end(live_bb);
    open_g = self._make_global_string("(", name_prefix=".repr.open");
    sep_g = self._make_global_string(", ", name_prefix=".repr.sep");
    close_g = self._make_global_string(
        ",)" if len(_ffns) == 1 else ")", name_prefix=".repr.close"
    );
    z32 = ir.Constant(i32, 0);
    cur: any = self._rc_strdup(open_g, name="rp.t.acc0");
    for (idx, ffn) in enumerate(_ffns) {
        if idx > 0 {
            nxt = self._emit_str_concat(cur, sep_g);
            self._emit_rc_release_simple(cur, op="mstr_old", loc="");
            cur = nxt;
        }
        fld: any = b.load(
            b.gep(t_arg, [z32, ir.Constant(i32, idx)], name=f"rp.t.{idx}.p"),
            name=f"rp.t.{idx}"
        );
        piece = self._repr_call_elem_fn(ffn, fld);
        nxt = self._emit_str_concat(cur, piece);
        self._emit_rc_release_simple(cur, op="mstr_old", loc="");
        self._emit_rc_release_simple(piece, op="mstr_val", loc="");
        cur = nxt;
    }
    res: any = self._emit_str_concat(cur, close_g);
    self._emit_rc_release_simple(cur, op="mstr_old", loc="");
    self._emit_set_type_tag(b, res, "str");
    b.ret(res);
    self._builder = saved_builder;
    return fn;
}

impl NaIRGenRepr._emit_container_repr(val: ir.Value, t: any) -> (ir.Value | None) {
    if t is None {
        return None;
    }
    _t = self._tb_opt_payload(t) if self._tb_kind(t) == "optional" else t;
    _kind = self._tb_kind(_t);
    if _kind not in ("list", "dict", "set", "tuple") {
        return None;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    fn = self._repr_fn_for_type(_t);
    if fn is None {
        return None;
    }
    if isinstance(val.type, ir.LiteralStructType) {
        if _kind != "tuple" {
            return None;
        }
        boxed = self._box_value_tuple(val);
        arg = (
            boxed
                if boxed.type == fn.args[0].type
                else self.builder.bitcast(boxed, fn.args[0].type, name="tup.repr.arg")
        );
        res: any = self.builder.call(fn, [arg], name="tup.repr");
        self._mark_owned(res);
        self._emit_rc_release_simple(boxed, op="mstr_val", loc="");
        return res;
    }
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    arg = (
        val
            if val.type == fn.args[0].type
            else self.builder.bitcast(val, fn.args[0].type, name="cont.repr.arg")
    );
    res: any = self.builder.call(fn, [arg], name="cont.repr");
    return self._mark_owned(res);
}

impl NaIRGenRepr._repr_jacval_fn -> (ir.Function | None) {
    if not self?.jacval_type {
        return None;
    }
    _cached = self._repr_fns.get("jacval");
    if _cached is not None {
        return _cached;
    }
    _int_fn = self._repr_leaf_fn("int");
    _bool_fn = self._repr_leaf_fn("bool");
    _float_fn = self._float_repr_fn();
    _str_fn = self._repr_str_fn();
    if _int_fn is None or _bool_fn is None {
        return None;
    }
    i8 = ir.IntType(8);
    i8p: any = i8.as_pointer();
    i64 = ir.IntType(64);
    f64 = ir.DoubleType();
    fnty = ir.FunctionType(i8p, [self.jacval_type]);
    fn: any = ir.Function(self.llvm_module, fnty, name="__jac_repr_jacval");
    fn.linkage = "private";
    fn.args[0].name = "jv";
    self._repr_fns["jacval"] = fn;
    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;
    tag = b.extract_value(fn.args[0], 0, name="rp.jv.tag");
    payload = b.extract_value(fn.args[0], 1, name="rp.jv.payload");
    _strdup = self._get_or_declare_extern("strdup", i8p, [i8p]);

    def _ret_const(bl: ir.IRBuilder, text: str, label: str) {
        _prev = self._builder;
        self._builder = bl;
        _g: any = self._make_global_string(text, name_prefix=f".repr.jv.{label}");
        if self._nogc_headerless() {
            _g = bl.call(_strdup, [_g], name=f"rp.jv.{label}.dup");
        }
        self._builder = _prev;
        bl.ret(_g);
    }
    _cases = [
        (1, "float"),
        (2, "str"),
        (3, "list"),
        (4, "dict"),
        (5, "set"),
        (6, "obj"),
        (7, "bool"),
        (8, "none")
    ];
    for (_t, _label) in _cases {
        _hit_bb = fn.append_basic_block(f"jv.{_label}");
        _next_bb = fn.append_basic_block(f"jv.chk.{_label}");
        b.cbranch(
            b.icmp_unsigned("==", tag, ir.Constant(i8, _t), name=f"rp.is.{_label}"),
            _hit_bb,
            _next_bb
        );
        bh = ir.IRBuilder(_hit_bb);
        if _label == "float" {
            bh.ret(
                bh.call(
                    _float_fn,
                    [bh.bitcast(payload, f64, name="rp.jv.f64")],
                    name="rp.jv.float"
                )
            );
        } elif _label == "str" {
            bh.ret(
                bh.call(
                    _str_fn,
                    [bh.inttoptr(payload, i8p, name="rp.jv.sp")],
                    name="rp.jv.str"
                )
            );
        } elif _label == "bool" {
            bh.ret(bh.call(_bool_fn, [payload], name="rp.jv.bool"));
        } elif _label == "none" {
            _ret_const(bh, "None", "none");
        } elif _label == "list" {
            _ret_const(bh, "[...]", "list");
        } elif _label in ("dict", "set") {
            _ret_const(bh, "{...}", _label);
        } else {
            _ret_const(bh, "<object>", "obj");
        }
        b = ir.IRBuilder(_next_bb);
    }
    b.ret(b.call(_int_fn, [payload], name="rp.jv.int"));
    self._builder = saved_builder;
    return fn;
}

impl NaIRGenRepr._str_jacval_fn -> (ir.Function | None) {
    if not self?.jacval_type {
        return None;
    }
    _cached = self._repr_fns.get("jacval_str");
    if _cached is not None {
        return _cached;
    }
    _int_fn = self._repr_leaf_fn("int");
    _bool_fn = self._repr_leaf_fn("bool");
    _float_fn = self._float_repr_fn();
    if _int_fn is None or _bool_fn is None {
        return None;
    }
    i8 = ir.IntType(8);
    i8p: any = i8.as_pointer();
    f64 = ir.DoubleType();
    fnty = ir.FunctionType(i8p, [self.jacval_type]);
    fn: any = ir.Function(self.llvm_module, fnty, name="__jac_str_jacval");
    fn.linkage = "private";
    fn.args[0].name = "jv";
    self._repr_fns["jacval_str"] = fn;
    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;
    tag = b.extract_value(fn.args[0], 0, name="sj.tag");
    payload = b.extract_value(fn.args[0], 1, name="sj.payload");
    _strdup = self._get_or_declare_extern("strdup", i8p, [i8p]);

    def _ret_const(bl: ir.IRBuilder, text: str, label: str) {
        _prev = self._builder;
        self._builder = bl;
        _g: any = self._make_global_string(text, name_prefix=f".str.jv.{label}");
        if self._nogc_headerless() {
            _g = bl.call(_strdup, [_g], name=f"sj.{label}.dup");
        }
        self._builder = _prev;
        bl.ret(_g);
    }
    _cases = [
        (1, "float"),
        (2, "str"),
        (3, "list"),
        (4, "dict"),
        (5, "set"),
        (6, "obj"),
        (7, "bool"),
        (8, "none")
    ];
    for (_t, _label) in _cases {
        _hit_bb = fn.append_basic_block(f"sjv.{_label}");
        _next_bb = fn.append_basic_block(f"sjv.chk.{_label}");
        b.cbranch(
            b.icmp_unsigned("==", tag, ir.Constant(i8, _t), name=f"sj.is.{_label}"),
            _hit_bb,
            _next_bb
        );
        bh = ir.IRBuilder(_hit_bb);
        if _label == "float" {
            bh.ret(
                bh.call(
                    _float_fn,
                    [bh.bitcast(payload, f64, name="sj.f64")],
                    name="sj.float"
                )
            );
        } elif _label == "str" {
            _sp: any = bh.inttoptr(payload, i8p, name="sj.sp");
            _prev_b = self._builder;
            self._builder = bh;
            self._emit_rc_retain(_sp, op="str_jacval");
            self._builder = _prev_b;
            bh.ret(_sp);
        } elif _label == "bool" {
            bh.ret(bh.call(_bool_fn, [payload], name="sj.bool"));
        } elif _label == "none" {
            _ret_const(bh, "None", "none");
        } elif _label == "list" {
            _ret_const(bh, "[...]", "list");
        } elif _label in ("dict", "set") {
            _ret_const(bh, "{...}", _label);
        } else {
            _ret_const(bh, "<object>", "obj");
        }
        b = ir.IRBuilder(_next_bb);
    }
    b.ret(b.call(_int_fn, [payload], name="sj.int"));
    self._builder = saved_builder;
    return fn;
}
