impl NaIRGenPass._codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value {
    i64 = ir.IntType(64);
    func = self.builder.function;

    result_alloca = self._entry_alloca(i64, "pow.result");
    counter_alloca = self._entry_alloca(i64, "pow.counter");
    self.builder.store(ir.Constant(i64, 1), result_alloca);
    self.builder.store(ir.Constant(i64, 0), counter_alloca);

    cond_bb = func.append_basic_block(name="pow.cond");
    body_bb = func.append_basic_block(name="pow.body");
    end_bb = func.append_basic_block(name="pow.end");
    self.builder.branch(cond_bb);

    self.builder.position_at_end(cond_bb);
    counter = self.builder.load(counter_alloca, name="pow.i");
    cmp = self.builder.icmp_signed("<", counter, exp, name="pow.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);

    self.builder.position_at_end(body_bb);
    cur_result = self.builder.load(result_alloca, name="pow.cur");
    new_result = self.builder.mul(cur_result, base, name="pow.mul");
    self.builder.store(new_result, result_alloca);
    cur_counter = self.builder.load(counter_alloca, name="pow.ci");
    next_counter = self.builder.add(cur_counter, ir.Constant(i64, 1), name="pow.inc");
    self.builder.store(next_counter, counter_alloca);
    self.builder.branch(cond_bb);

    self.builder.position_at_end(end_bb);
    return self.builder.load(result_alloca, name="pow.final");
}

impl NaIRGenPass._dict_key_spec(key_type: ir.Type) -> tuple {
    if isinstance(key_type, ir.DoubleType) {
        return ("f64", 0);
    }
    if self._is_bytes_type(key_type) {
        return ("bytes", 0);
    }
    if isinstance(key_type, ir.PointerType) {
        if isinstance(key_type.pointee, ir.LiteralStructType) {
            _sz = self._get_struct_size(key_type.pointee);
            return (f"tuple{_sz}", _sz);
        }
        return ("ptr", 0);
    }
    return ("i64", 0);
}

impl NaIRGenPass._dict_val_spec(val_type: ir.Type) -> str {
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
    return "i64";
}

impl NaIRGenPass._emit_dict_order_compact(
    b: ir.IRBuilder,
    fn: ir.Function,
    d_ptr: ir.Value,
    removed_slot: ir.Value,
    new_len: ir.Value,
    i32: ir.Type,
    i64: ir.Type
) -> ir.IRBuilder {
    ord_a = b.load(
        b.gep(d_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 6)], name="oc.orp"),
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

impl NaIRGenPass._emit_order_scan_incr_block(
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

impl NaIRGenPass._emit_dict_trace_fn(
    trace_fn_name: str, dict_ptr_type: ir.Type, key_type: ir.Type, val_type: ir.Type
) -> ir.Function {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    visitor_ptype = ir.FunctionType(ir.VoidType(), [i8p]).as_pointer();
    trace_fnty = ir.FunctionType(ir.VoidType(), [i8p, i8p]);
    try {
        _existing = self.llvm_module.get_global(trace_fn_name);
        if isinstance(_existing, ir.Function) and not _existing.blocks {
            trace_fn = _existing;
            trace_fn.linkage = "private";
        } else {
            trace_fn = ir.Function(self.llvm_module, trace_fnty, name=trace_fn_name);
            trace_fn.linkage = "private";
        }
    } except KeyError {
        trace_fn = ir.Function(self.llvm_module, trace_fnty, name=trace_fn_name);
        trace_fn.linkage = "private";
    }
    trace_fn.args[0].name = "obj";
    trace_fn.args[1].name = "vis";

    b = ir.IRBuilder(trace_fn.append_basic_block("entry"));
    _vis = b.bitcast(trace_fn.args[1], visitor_ptype, name="vis.fn");
    d_t = b.bitcast(trace_fn.args[0], dict_ptr_type, name="dict.typed");
    cap_t = b.load(
        b.gep(d_t, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp"), name="cap"
    );
    keys_t = b.load(
        b.gep(d_t, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"), name="keys"
    );
    vals_t = b.load(
        b.gep(d_t, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"), name="vals"
    );
    ctrl_t = b.load(
        b.gep(d_t, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"), name="ctrl"
    );
    si_t = b.alloca(i64, name="si");
    b.store(ir.Constant(i64, 0), si_t);

    loop_bb = trace_fn.append_basic_block("loop");
    chk_bb = trace_fn.append_basic_block("chk");
    live_bb = trace_fn.append_basic_block("live");
    next_bb = trace_fn.append_basic_block("next");
    done_bb = trace_fn.append_basic_block("done");
    b.branch(loop_bb);

    bl = ir.IRBuilder(loop_bb);
    si_v = bl.load(si_t, name="si");
    bl.cbranch(bl.icmp_unsigned(">=", si_v, cap_t, name="end"), done_bb, chk_bb);

    bck = ir.IRBuilder(chk_bb);
    cb_t = bck.load(bck.gep(ctrl_t, [si_v], name="cbp"), name="cb");
    bck.cbranch(
        bck.icmp_unsigned(">=", cb_t, ir.Constant(i8, 0x80), name="occ"),
        live_bb,
        next_bb
    );

    blv = ir.IRBuilder(live_bb);
    if isinstance(key_type, ir.PointerType) {
        kv_t = blv.load(blv.gep(keys_t, [si_v], name="kvp"), name="kv");
        blv.call(_vis, [blv.bitcast(kv_t, i8p, name="ki8")]);
    }
    if isinstance(val_type, ir.PointerType) {
        vv_t = blv.load(blv.gep(vals_t, [si_v], name="vvp"), name="vv");
        blv.call(_vis, [blv.bitcast(vv_t, i8p, name="vi8")]);
    }
    blv.branch(next_bb);

    bnx = ir.IRBuilder(next_bb);
    bnx.store(bnx.add(si_v, ir.Constant(i64, 1), name="nsi"), si_t);
    bnx.branch(loop_bb);

    ir.IRBuilder(done_bb).ret_void();
    return trace_fn;
}

impl NaIRGenPass._emit_dict_helpers(
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

    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    i8p = i8.as_pointer();
    is_str_key: bool = key_type == i8p;
    is_int_key: bool = isinstance(key_type, ir.IntType);
    is_bytes_key: bool = key_type_name == "bytes";

    CTRL_EMPTY: int = 0;
    CTRL_TOMBSTONE: int = 1;
    INIT_CAP: int = 8;
    FNV_BASIS: int = -3750763034362895579;
    FNV_PRIME: int = 1099511628211;
    MUL_HASH_K: int = -7046029254386353131;

    dict_struct = self.llvm_module.context.get_identified_type(
        f"Dict.{key_type_name}.{val_type_name}"
    );

    _i64p_ord = i64.as_pointer();
    if not dict_struct.elements {
        if self._gc_mode() == "none" {
            dict_struct.set_body(
                i64,
                i64,
                key_type.as_pointer(),
                val_type.as_pointer(),
                i8p,
                i64,
                _i64p_ord,
                self._nogc_elem_drop_slot_ty(),
                self._nogc_elem_drop_slot_ty()
            );
        } else {
            dict_struct.set_body(
                i64,
                i64,
                key_type.as_pointer(),
                val_type.as_pointer(),
                i8p,
                i64,
                _i64p_ord
            );
        }
    }
    self.dict_types[dict_key] = dict_struct;
    dict_ptr_type = dict_struct.as_pointer();

    malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
    calloc_fn = self._get_or_declare_extern("calloc", i8p, [i64, i64]);
    strcmp_fn = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    if self.rc_safe_free_fn is None {
        self._emit_rc_helpers();
    }
    if self.rc_retain_fn is None {
        self._emit_rc_helpers();
    }

    _rel_fn_decl = None;
    if not self._nogc_headerless() {
        _rel_fn_name = f"__rc_release_dict_{dict_key.replace(':', '_')}";
        _rel_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
        try {
            _rel_fn_decl = self.llvm_module.get_global(_rel_fn_name);
        } except KeyError {
            _rel_fn_decl = ir.Function(self.llvm_module, _rel_fnty, name=_rel_fn_name);
            _rel_fn_decl.linkage = "private";
        }

        _dict_type_name = _rel_fn_name[len("__rc_release_"):];
        _dict_has_ptr_kv = (
            isinstance(key_type, ir.PointerType) or isinstance(val_type, ir.PointerType)
        );
        _dict_has_trace = False;
        if _dict_has_ptr_kv and self._gc_mode() == "cycles" {
            _dict_trace_fn = self._emit_dict_trace_fn(
                f"__rc_trace_{_dict_type_name}", dict_ptr_type, key_type, val_type
            );
            _dict_has_trace = self._register_trace_pair(_rel_fn_decl, _dict_trace_fn);
        }
        self._require_trace_fn(_dict_type_name, _dict_has_ptr_kv, _dict_has_trace);
    }

    hash_fnty = ir.FunctionType(i64, [key_type]);
    hash_fn = ir.Function(
        self.llvm_module, hash_fnty, name=f"__dict_hash_{key_type_name}_{val_type_name}"
    );
    hash_fn.linkage = "private";
    hash_fn.args[0].name = "key";
    bhe = ir.IRBuilder(hash_fn.append_basic_block("entry"));
    if is_bytes_key {
        h_ba = bhe.alloca(i64, name="h");
        idx_ba = bhe.alloca(i64, name="idx");
        bhe.store(ir.Constant(i64, FNV_BASIS), h_ba);
        bhe.store(ir.Constant(i64, 0), idx_ba);
        blen = bhe.load(
            bhe.gep(
                hash_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp"
            ),
            name="blen"
        );
        bdata = bhe.bitcast(
            bhe.gep(
                hash_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="dp"
            ),
            i8p,
            name="bdata"
        );
        hblc = hash_fn.append_basic_block("blc");
        hblb = hash_fn.append_basic_block("blb");
        hbrt = hash_fn.append_basic_block("brt");
        bhe.branch(hblc);
        bblc = ir.IRBuilder(hblc);
        bidx = bblc.load(idx_ba, name="idx");
        bblc.cbranch(bblc.icmp_unsigned("<", bidx, blen, name="more"), hblb, hbrt);
        bblb = ir.IRBuilder(hblb);
        bch = bblb.load(bblb.gep(bdata, [bidx], name="cp"), name="ch");
        bcur = bblb.load(h_ba, name="h");
        bce = bblb.zext(bch, i64, name="ce");
        bxor = bblb.xor(bcur, bce, name="hx");
        bmul = bblb.mul(bxor, ir.Constant(i64, FNV_PRIME), name="hm");
        bblb.store(bmul, h_ba);
        bblb.store(bblb.add(bidx, ir.Constant(i64, 1), name="ni"), idx_ba);
        bblb.branch(hblc);
        bbrt = ir.IRBuilder(hbrt);
        bbrt.ret(bbrt.load(h_ba, name="hf"));
    } elif is_str_key {
        h_a = bhe.alloca(i64, name="h");
        idx_a = bhe.alloca(i64, name="idx");
        bhe.store(ir.Constant(i64, FNV_BASIS), h_a);
        bhe.store(ir.Constant(i64, 0), idx_a);
        hlc = hash_fn.append_basic_block("lc");
        hlb = hash_fn.append_basic_block("lb");
        hrt = hash_fn.append_basic_block("rt");
        bhe.branch(hlc);
        blc = ir.IRBuilder(hlc);
        hidx = blc.load(idx_a, name="idx");
        hcp = blc.gep(hash_fn.args[0], [hidx], name="cp");
        hch = blc.load(hcp, name="ch");
        hend = blc.icmp_signed("==", hch, ir.Constant(i8, 0), name="end");
        blc.cbranch(hend, hrt, hlb);
        blb = ir.IRBuilder(hlb);
        hcur = blb.load(h_a, name="h");
        hce = blb.zext(hch, i64, name="ce");
        hxor = blb.xor(hcur, hce, name="hx");
        hmul = blb.mul(hxor, ir.Constant(i64, FNV_PRIME), name="hm");
        blb.store(hmul, h_a);
        blb.store(blb.add(hidx, ir.Constant(i64, 1), name="ni"), idx_a);
        blb.branch(hlc);
        brt = ir.IRBuilder(hrt);
        brt.ret(brt.load(h_a, name="hf"));
    } else {
        if isinstance(key_type, ir.PointerType) {
            ki = bhe.ptrtoint(hash_fn.args[0], i64, name="ki");
            bhe.ret(bhe.mul(ki, ir.Constant(i64, MUL_HASH_K), name="h"));
        } elif isinstance(key_type, ir.DoubleType) {
            kbits = bhe.bitcast(hash_fn.args[0], i64, name="kbits");
            bhe.ret(bhe.mul(kbits, ir.Constant(i64, MUL_HASH_K), name="h"));
        } else {
            bhe.ret(bhe.mul(hash_fn.args[0], ir.Constant(i64, MUL_HASH_K), name="h"));
        }
    }

    find_fnty = ir.FunctionType(i64, [dict_ptr_type, key_type]);
    find_fn = ir.Function(
        self.llvm_module, find_fnty, name=f"__dict_find_{key_type_name}_{val_type_name}"
    );
    find_fn.linkage = "private";
    find_fn.args[0].name = "dict";
    find_fn.args[1].name = "key";
    bf = ir.IRBuilder(find_fn.append_basic_block("entry"));
    d_f = find_fn.args[0];
    k_f = find_fn.args[1];
    slot_a = bf.alloca(i64, name="slot");
    itomb_a = bf.alloca(i64, name="itomb");

    hf = bf.call(hash_fn, [k_f], name="h");
    h2r = bf.lshr(hf, ir.Constant(i64, 57), name="h2r");
    h27 = bf.and_(h2r, ir.Constant(i64, 0x7F), name="h27");
    h2o = bf.or_(h27, ir.Constant(i64, 0x80), name="h2o");
    h2 = bf.trunc(h2o, i8, name="h2");

    capf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp"), name="cap"
    );
    keysf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"), name="keys"
    );
    ctrlf = bf.load(
        bf.gep(d_f, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"), name="ctrl"
    );
    maskf = bf.sub(capf, ir.Constant(i64, 1), name="mask");
    s0 = bf.and_(hf, maskf, name="s0");
    bf.store(s0, slot_a);
    bf.store(ir.Constant(i64, -1), itomb_a);

    probe_bb = find_fn.append_basic_block("probe");
    empty_bb = find_fn.append_basic_block("empty");
    fp_bb = find_fn.append_basic_block("fp");
    keq_bb = find_fn.append_basic_block("keq");
    tomb_bb = find_fn.append_basic_block("tomb");
    next_bb = find_fn.append_basic_block("next");
    found_bb = find_fn.append_basic_block("found");
    bf.branch(probe_bb);

    bp = ir.IRBuilder(probe_bb);
    sl = bp.load(slot_a, name="sl");
    cbp = bp.gep(ctrlf, [sl], name="cbp");
    cb = bp.load(cbp, name="cb");
    emp = bp.icmp_unsigned("==", cb, ir.Constant(i8, CTRL_EMPTY), name="emp");
    bp.cbranch(emp, empty_bb, fp_bb);

    be = ir.IRBuilder(empty_bb);
    itomb = be.load(itomb_a, name="it");
    notmb = be.icmp_signed("==", itomb, ir.Constant(i64, -1), name="nt");
    ins = be.select(notmb, sl, itomb, name="ins");
    be.ret(be.xor(ins, ir.Constant(i64, -1), name="nfr"));

    bfp = ir.IRBuilder(fp_bb);
    fpm = bfp.icmp_unsigned("==", cb, h2, name="fpm");
    bfp.cbranch(fpm, keq_bb, tomb_bb);

    bke = ir.IRBuilder(keq_bb);
    kpke = bke.gep(keysf, [sl], name="kp");
    kke = bke.load(kpke, name="k");
    if is_int_key {
        keq = bke.icmp_signed("==", kke, k_f, name="keq");
    } elif is_bytes_key {
        memcmp_b = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
        klen_b = bke.load(
            bke.gep(kke, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="klp"),
            name="klen"
        );
        alen_b = bke.load(
            bke.gep(k_f, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="alp"),
            name="alen"
        );
        len_eq = bke.icmp_unsigned("==", klen_b, alen_b, name="leneq");
        kdat_b = bke.bitcast(
            bke.gep(kke, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="kdp"),
            i8p,
            name="kdat"
        );
        adat_b = bke.bitcast(
            bke.gep(k_f, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="adp"),
            i8p,
            name="adat"
        );
        mcr_b = bke.call(memcmp_b, [kdat_b, adat_b, klen_b], name="bmcr");
        dat_eq = bke.icmp_signed("==", mcr_b, ir.Constant(i32, 0), name="dateq");
        keq = bke.and_(len_eq, dat_eq, name="keq");
    } elif is_str_key {
        cmpr = bke.call(strcmp_fn, [kke, k_f], name="scmp");
        keq = bke.icmp_signed("==", cmpr, ir.Constant(i32, 0), name="keq");
    } elif _key_sz > 0 {
        memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
        ki = bke.bitcast(kke, i8p, name="ki");
        ai = bke.bitcast(k_f, i8p, name="ai");
        cr = bke.call(memcmp_fn, [ki, ai, ir.Constant(i64, _key_sz)], name="mcr");
        keq = bke.icmp_signed("==", cr, ir.Constant(i32, 0), name="keq");
    } elif isinstance(key_type, ir.DoubleType) {
        keq = bke.fcmp_ordered("==", kke, k_f, name="keq");
    } else {
        keq = bke.icmp_unsigned("==", kke, k_f, name="keq");
    }
    bke.cbranch(keq, found_bb, next_bb);

    bfnd = ir.IRBuilder(found_bb);
    bfnd.ret(sl);

    btb = ir.IRBuilder(tomb_bb);
    ist = btb.icmp_unsigned("==", cb, ir.Constant(i8, CTRL_TOMBSTONE), name="ist");
    it2 = btb.load(itomb_a, name="it2");
    nt2 = btb.icmp_signed("==", it2, ir.Constant(i64, -1), name="nt2");
    ss = btb.and_(ist, nt2, name="ss");
    nit = btb.select(ss, sl, it2, name="nit");
    btb.store(nit, itomb_a);
    btb.branch(next_bb);

    bnx = ir.IRBuilder(next_bb);
    nsl = bnx.add(sl, ir.Constant(i64, 1), name="nsl");
    nslm = bnx.and_(nsl, maskf, name="nslm");
    bnx.store(nslm, slot_a);
    bnx.branch(probe_bb);

    new_fnty2 = ir.FunctionType(dict_ptr_type, []);
    new_fn = ir.Function(
        self.llvm_module, new_fnty2, name=f"__dict_new_{key_type_name}_{val_type_name}"
    );
    new_fn.linkage = "private";
    bn = ir.IRBuilder(new_fn.append_basic_block("entry"));
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }

    null_p = ir.Constant(dict_ptr_type, None);
    sg = bn.gep(null_p, [ir.Constant(i32, 1)], name="sg");
    ssz = bn.ptrtoint(sg, i64, name="ssz");
    raw = bn.call(self.rc_alloc_fn, [ssz], name="raw");
    dp = bn.bitcast(raw, dict_ptr_type, name="dp");

    if not self._nogc_headerless() {
        if self.rc_set_type_fn is not None {
            _tn = _rel_fn_name[len("__rc_release_"):]
                if _rel_fn_name.startswith("__rc_release_")
                else "dict";
            _dpi8 = bn.bitcast(dp, i8p, name="dp.i8");
            self._emit_set_type_tag(bn, _dpi8, _tn);
        }

        _i64p_n = i64.as_pointer();
        _drn = bn.bitcast(dp, i8p, name="dr");
        _dsln = bn.gep(_drn, [ir.Constant(i64, HDR_DTOR_OFF)], name="dsl");
        _dslip = bn.bitcast(_dsln, _i64p_n, name="dsli");
        _dti64 = bn.ptrtoint(_rel_fn_decl, i64, name="di");
        bn.store(_dti64, _dslip);
    }

    bn.store(
        ir.Constant(i64, 0),
        bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp")
    );

    bn.store(
        ir.Constant(i64, INIT_CAP),
        bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp")
    );

    kn = ir.Constant(key_type.as_pointer(), None);
    kgn = bn.gep(kn, [ir.Constant(i32, 1)], name="ksz");
    ksn = bn.ptrtoint(kgn, i64, name="ksz");
    kbn = bn.mul(ir.Constant(i64, INIT_CAP), ksn, name="kb");
    krn = bn.call(malloc_fn, [kbn], name="kr");
    kpn = bn.bitcast(krn, key_type.as_pointer(), name="kp");
    bn.store(kpn, bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kf"));

    vn = ir.Constant(val_type.as_pointer(), None);
    vgn = bn.gep(vn, [ir.Constant(i32, 1)], name="vsz");
    vsn = bn.ptrtoint(vgn, i64, name="vsz");
    vbn = bn.mul(ir.Constant(i64, INIT_CAP), vsn, name="vb");
    vrn = bn.call(malloc_fn, [vbn], name="vr");
    vpn = bn.bitcast(vrn, val_type.as_pointer(), name="vp");
    bn.store(vpn, bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vf"));

    cbn = ir.Constant(i64, INIT_CAP);
    crn = bn.call(calloc_fn, [cbn, ir.Constant(i64, 1)], name="cr");
    bn.store(crn, bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="cf"));

    bn.store(
        ir.Constant(i64, 0),
        bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 5)], name="uf")
    );

    _ord_bytes = ir.Constant(i64, INIT_CAP * 8);
    orn = bn.call(malloc_fn, [_ord_bytes], name="ordr");
    orpn = bn.bitcast(orn, i64.as_pointer(), name="ordp");
    bn.store(orpn, bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 6)], name="ordf"));

    if self._gc_mode() == "none" {
        _drop_slot_ty = self._nogc_elem_drop_slot_ty();
        _drop_null = ir.Constant(_drop_slot_ty, None);
        bn.store(
            _drop_null,
            bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 7)], name="kdrop")
        );
        bn.store(
            _drop_null,
            bn.gep(dp, [ir.Constant(i32, 0), ir.Constant(i32, 8)], name="vdrop")
        );
    }
    bn.ret(dp);

    rehash_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
    rehash_fn = ir.Function(
        self.llvm_module,
        rehash_fnty,
        name=f"__dict_rehash_{key_type_name}_{val_type_name}"
    );
    rehash_fn.linkage = "private";
    rehash_fn.args[0].name = "dict";
    brh = ir.IRBuilder(rehash_fn.append_basic_block("entry"));
    d_rh = rehash_fn.args[0];

    ok_a = brh.alloca(key_type, name="ok");
    ov_a = brh.alloca(val_type, name="ov");
    nh2_a = brh.alloca(i8, name="nh2");
    rslot_a = brh.alloca(i64, name="rsl");
    si_a = brh.alloca(i64, name="si");

    cap_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp");
    keys_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp");
    vals_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp");
    ctrl_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp");
    len_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp");
    used_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 5)], name="up");
    ord_prh = brh.gep(d_rh, [ir.Constant(i32, 0), ir.Constant(i32, 6)], name="orp");
    old_cap = brh.load(cap_prh, name="ocap");
    old_len = brh.load(len_prh, name="olen");
    old_keys = brh.load(keys_prh, name="okeys");
    old_vals = brh.load(vals_prh, name="ovals");
    old_ctrl = brh.load(ctrl_prh, name="octrl");
    old_order = brh.load(ord_prh, name="oorder");
    new_cap = brh.mul(old_cap, ir.Constant(i64, 2), name="ncap");
    new_mask = brh.sub(new_cap, ir.Constant(i64, 1), name="nmask");

    kgnr = brh.gep(
        ir.Constant(key_type.as_pointer(), None), [ir.Constant(i32, 1)], name="ksz"
    );
    kszr = brh.ptrtoint(kgnr, i64, name="ksz");
    kbrh = brh.mul(new_cap, kszr, name="kb");
    nkr = brh.call(malloc_fn, [kbrh], name="nkr");
    new_keys = brh.bitcast(nkr, key_type.as_pointer(), name="nk");
    vgnr = brh.gep(
        ir.Constant(val_type.as_pointer(), None), [ir.Constant(i32, 1)], name="vsz"
    );
    vszr = brh.ptrtoint(vgnr, i64, name="vsz");
    vbrh = brh.mul(new_cap, vszr, name="vb");
    nvr = brh.call(malloc_fn, [vbrh], name="nvr");
    new_vals = brh.bitcast(nvr, val_type.as_pointer(), name="nv");
    ncr = brh.call(calloc_fn, [new_cap, ir.Constant(i64, 1)], name="ncr");

    _nord_bytes = brh.mul(new_cap, ir.Constant(i64, 8), name="nordb");
    nordr = brh.call(malloc_fn, [_nord_bytes], name="nordr");
    new_order = brh.bitcast(nordr, i64.as_pointer(), name="norder");

    brh.store(new_cap, cap_prh);
    brh.store(new_keys, keys_prh);
    brh.store(new_vals, vals_prh);
    brh.store(ncr, ctrl_prh);
    brh.store(new_order, ord_prh);
    brh.store(ir.Constant(i64, 0), len_prh);
    brh.store(ir.Constant(i64, 0), used_prh);
    brh.store(ir.Constant(i64, 0), si_a);

    rl_bb = rehash_fn.append_basic_block("rl");
    ri_bb = rehash_fn.append_basic_block("ri");
    rp_bb = rehash_fn.append_basic_block("rp");
    ra_bb = rehash_fn.append_basic_block("ra");
    rd_bb = rehash_fn.append_basic_block("rd");
    rf_bb = rehash_fn.append_basic_block("rf");
    brh.branch(rl_bb);

    brl = ir.IRBuilder(rl_bb);
    si_rh = brl.load(si_a, name="j");
    rend = brl.icmp_unsigned(">=", si_rh, old_len, name="rend");
    brl.cbranch(rend, rf_bb, ri_bb);

    bri = ir.IRBuilder(ri_bb);
    _osl = bri.load(bri.gep(old_order, [si_rh], name="osl.p"), name="osl");
    okp = bri.gep(old_keys, [_osl], name="okp");
    ovp = bri.gep(old_vals, [_osl], name="ovp");
    ok_v = bri.load(okp, name="ok");
    ov_v = bri.load(ovp, name="ov");
    bri.store(ok_v, ok_a);
    bri.store(ov_v, ov_a);
    nhr = bri.call(hash_fn, [ok_v], name="nh");
    nh2r0 = bri.lshr(nhr, ir.Constant(i64, 57), name="nh2r");
    nh2r7 = bri.and_(nh2r0, ir.Constant(i64, 0x7F), name="nh27");
    nh2ro = bri.or_(nh2r7, ir.Constant(i64, 0x80), name="nh2o");
    nh2 = bri.trunc(nh2ro, i8, name="nh2");
    bri.store(nh2, nh2_a);
    bri.store(bri.and_(nhr, new_mask, name="rs0"), rslot_a);
    bri.branch(rp_bb);

    brp = ir.IRBuilder(rp_bb);
    rsl = brp.load(rslot_a, name="rsl");
    ncp = brp.gep(ncr, [rsl], name="ncp");
    nc = brp.load(ncp, name="nc");
    rse = brp.icmp_unsigned("==", nc, ir.Constant(i8, CTRL_EMPTY), name="rse");
    brp.cbranch(rse, rd_bb, ra_bb);

    bra = ir.IRBuilder(ra_bb);
    nrsl = bra.add(rsl, ir.Constant(i64, 1), name="nrsl");
    bra.store(bra.and_(nrsl, new_mask, name="nrslm"), rslot_a);
    bra.branch(rp_bb);

    brd = ir.IRBuilder(rd_bb);
    ok_d = brd.load(ok_a, name="ok");
    ov_d = brd.load(ov_a, name="ov");
    nh2_d = brd.load(nh2_a, name="nh2");
    brd.store(ok_d, brd.gep(new_keys, [rsl], name="nkp"));
    brd.store(ov_d, brd.gep(new_vals, [rsl], name="nvp"));
    brd.store(nh2_d, brd.gep(ncr, [rsl], name="ncp2"));
    cl_d = brd.load(len_prh, name="cl");

    brd.store(rsl, brd.gep(new_order, [cl_d], name="nordp"));
    brd.store(brd.add(cl_d, ir.Constant(i64, 1), name="nl"), len_prh);
    cu_d = brd.load(used_prh, name="cu");
    brd.store(brd.add(cu_d, ir.Constant(i64, 1), name="nu"), used_prh);
    brd.store(brd.add(brd.load(si_a, name="j2"), ir.Constant(i64, 1), name="nj"), si_a);
    brd.branch(rl_bb);

    brf = ir.IRBuilder(rf_bb);
    if self._nogc_headerless() {
        _free_rh = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        brf.call(_free_rh, [brf.bitcast(old_keys, i8p, name="oki8")]);
        brf.call(_free_rh, [brf.bitcast(old_vals, i8p, name="ovi8")]);
        brf.call(_free_rh, [old_ctrl]);
        brf.call(_free_rh, [brf.bitcast(old_order, i8p, name="ordi8")]);
    } else {
        brf.call(self.rc_safe_free_fn, [brf.bitcast(old_keys, i8p, name="oki8")]);
        brf.call(self.rc_safe_free_fn, [brf.bitcast(old_vals, i8p, name="ovi8")]);
        brf.call(self.rc_safe_free_fn, [old_ctrl]);
        brf.call(self.rc_safe_free_fn, [brf.bitcast(old_order, i8p, name="ordi8")]);
    }
    brf.ret_void();

    set_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type, key_type, val_type]);
    set_fn = ir.Function(
        self.llvm_module, set_fnty, name=f"__dict_set_{key_type_name}_{val_type_name}"
    );
    set_fn.linkage = "private";
    set_fn.args[0].name = "dict";
    set_fn.args[1].name = "key";
    set_fn.args[2].name = "val";
    bs = ir.IRBuilder(set_fn.append_basic_block("entry"));
    d_s = set_fn.args[0];
    k_s = set_fn.args[1];
    v_s = set_fn.args[2];
    res_s = bs.call(find_fn, [d_s, k_s], name="res");
    is_fnd = bs.icmp_signed(">=", res_s, ir.Constant(i64, 0), name="found");
    upd_bb = set_fn.append_basic_block("upd");
    ins_bb = set_fn.append_basic_block("ins");
    reh_bb = set_fn.append_basic_block("reh");
    done_s = set_fn.append_basic_block("done");
    bs.cbranch(is_fnd, upd_bb, ins_bb);

    bu = ir.IRBuilder(upd_bb);
    vals_as = bu.load(
        bu.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"), name="va"
    );
    vsp = bu.gep(vals_as, [res_s], name="vsp");

    if isinstance(val_type, ir.PointerType) and not self._nogc_headerless() {
        bu.call(self.rc_retain_fn, [bu.bitcast(v_s, i8p, name="nvc")]);
        ov_u = bu.load(vsp, name="ov");
        bu.store(v_s, vsp);
        bu.call(self.rc_release_simple_fn, [bu.bitcast(ov_u, i8p, name="ovc")]);
    } else {
        bu.store(v_s, vsp);
    }
    bu.ret_void();

    bi = ir.IRBuilder(ins_bb);
    isl = bi.xor(res_s, ir.Constant(i64, -1), name="isl");

    h_s = bi.call(hash_fn, [k_s], name="h");
    h2r_s = bi.lshr(h_s, ir.Constant(i64, 57), name="h2r");
    h27_s = bi.and_(h2r_s, ir.Constant(i64, 0x7F), name="h27");
    h2o_s = bi.or_(h27_s, ir.Constant(i64, 0x80), name="h2o");
    h2_s = bi.trunc(h2o_s, i8, name="h2");

    len_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lrp");
    keys_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="krp");
    vals_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vrp");
    ctrl_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="crp");
    used_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 5)], name="urp");
    cap_rp = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="carp");
    ka_s = bi.load(keys_rp, name="ka");
    va_s = bi.load(vals_rp, name="va");
    ca_s = bi.load(ctrl_rp, name="ca");

    icp = bi.gep(ca_s, [isl], name="icp");
    icb = bi.load(icp, name="icb");
    was_tb = bi.icmp_unsigned("==", icb, ir.Constant(i8, CTRL_TOMBSTONE), name="wt");

    _k_ins = k_s;
    if self._nogc_headerless() {
        if (
            isinstance(key_type, ir.PointerType)
            and isinstance(key_type.pointee, ir.IntType)
            and key_type.pointee.width == 8
        ) {
            _strdup_i = self._get_or_declare_extern("strdup", i8p, [i8p]);
            _k_ins = bi.call(_strdup_i, [bi.bitcast(k_s, i8p, name="dins_key_src")]);
            _k_ins = bi.bitcast(_k_ins, key_type, name="dins_key_copy");
        }
    } else {
        if isinstance(key_type, ir.PointerType) {
            bi.call(self.rc_retain_fn, [bi.bitcast(k_s, i8p, name="kc")]);
        }
        if isinstance(val_type, ir.PointerType) {
            bi.call(self.rc_retain_fn, [bi.bitcast(v_s, i8p, name="vc")]);
        }
    }
    bi.store(_k_ins, bi.gep(ka_s, [isl], name="ksp"));
    bi.store(v_s, bi.gep(va_s, [isl], name="vsp"));
    bi.store(h2_s, icp);

    cl_s = bi.load(len_rp, name="cl");
    ord_ip = bi.gep(d_s, [ir.Constant(i32, 0), ir.Constant(i32, 6)], name="orp");
    ord_a = bi.load(ord_ip, name="ora");
    bi.store(isl, bi.gep(ord_a, [cl_s], name="oslp"));
    bi.store(bi.add(cl_s, ir.Constant(i64, 1), name="nl"), len_rp);

    ntb = bi.not_(was_tb, name="ntb");
    cu_s = bi.load(used_rp, name="cu");
    nu_s = bi.add(cu_s, bi.zext(ntb, i64, name="ntbx"), name="nu");
    bi.store(nu_s, used_rp);

    cc_s = bi.load(cap_rp, name="cc");
    u4 = bi.mul(nu_s, ir.Constant(i64, 4), name="u4");
    c3 = bi.mul(cc_s, ir.Constant(i64, 3), name="c3");
    nreh = bi.icmp_unsigned(">", u4, c3, name="nreh");
    bi.cbranch(nreh, reh_bb, done_s);

    breh = ir.IRBuilder(reh_bb);
    breh.call(rehash_fn, [d_s]);
    breh.branch(done_s);
    ir.IRBuilder(done_s).ret_void();

    get_fnty = ir.FunctionType(val_type, [dict_ptr_type, key_type]);
    get_fn = ir.Function(
        self.llvm_module, get_fnty, name=f"__dict_get_{key_type_name}_{val_type_name}"
    );
    get_fn.linkage = "private";
    get_fn.args[0].name = "dict";
    get_fn.args[1].name = "key";
    bg = ir.IRBuilder(get_fn.append_basic_block("entry"));
    res_g = bg.call(find_fn, [get_fn.args[0], get_fn.args[1]], name="res");
    fnd_g = bg.icmp_signed(">=", res_g, ir.Constant(i64, 0), name="found");
    got_bb = get_fn.append_basic_block("got");
    miss_bb = get_fn.append_basic_block("miss");
    bg.cbranch(fnd_g, got_bb, miss_bb);
    bgg = ir.IRBuilder(got_bb);
    va_g = bgg.load(
        bgg.gep(get_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"),
        name="va"
    );
    bgg.ret(bgg.load(bgg.gep(va_g, [res_g], name="vsp"), name="v"));
    bmi = ir.IRBuilder(miss_bb);
    if isinstance(val_type, ir.PointerType) {
        bmi.ret(ir.Constant(val_type, None));
    } elif val_type?.elements and val_type.elements {
        bmi.ret(ir.Constant(val_type, [ir.Constant(e, 0) for e in val_type.elements]));
    } else {
        bmi.ret(ir.Constant(val_type, 0));
    }

    contains_fnty = ir.FunctionType(i1, [dict_ptr_type, key_type]);
    contains_fn = ir.Function(
        self.llvm_module,
        contains_fnty,
        name=f"__dict_contains_{key_type_name}_{val_type_name}"
    );
    contains_fn.linkage = "private";
    contains_fn.args[0].name = "dict";
    contains_fn.args[1].name = "key";
    bc = ir.IRBuilder(contains_fn.append_basic_block("entry"));
    res_c = bc.call(find_fn, [contains_fn.args[0], contains_fn.args[1]], name="res");
    bc.ret(bc.icmp_signed(">=", res_c, ir.Constant(i64, 0), name="found"));

    remove_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type, key_type]);
    remove_fn = ir.Function(
        self.llvm_module,
        remove_fnty,
        name=f"__dict_remove_{key_type_name}_{val_type_name}"
    );
    remove_fn.linkage = "private";
    remove_fn.args[0].name = "dict";
    remove_fn.args[1].name = "key";
    brm = ir.IRBuilder(remove_fn.append_basic_block("entry"));
    d_rm = remove_fn.args[0];
    k_rm = remove_fn.args[1];
    res_rm = brm.call(find_fn, [d_rm, k_rm], name="res");
    fnd_rm = brm.icmp_signed(">=", res_rm, ir.Constant(i64, 0), name="found");
    del_bb = remove_fn.append_basic_block("del");
    done_rm = remove_fn.append_basic_block("done");
    brm.cbranch(fnd_rm, del_bb, done_rm);
    bdel = ir.IRBuilder(del_bb);
    ka_rm = bdel.load(
        bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"), name="ka"
    );
    va_rm = bdel.load(
        bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"), name="va"
    );
    ca_rm = bdel.load(
        bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"),
        name="ca"
    );
    lp_rm = bdel.gep(d_rm, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp");

    _hl_rm = self._nogc_headerless();
    _free_rm = self._get_or_declare_extern("free", ir.VoidType(), [i8p])
        if _hl_rm
        else None;
    if isinstance(key_type, ir.PointerType) {
        kv_rm = bdel.load(bdel.gep(ka_rm, [res_rm], name="kvp"), name="kv");
        if _hl_rm {
            bdel.call(_free_rm, [bdel.bitcast(kv_rm, i8p, name="kc")]);
        } else {
            bdel.call(self.rc_release_simple_fn, [bdel.bitcast(kv_rm, i8p, name="kc")]);
        }

        bdel.store(
            ir.Constant(key_type, None), bdel.gep(ka_rm, [res_rm], name="kclear")
        );
    }
    if isinstance(val_type, ir.PointerType) {
        vv_rm = bdel.load(bdel.gep(va_rm, [res_rm], name="vvp"), name="vv");
        if not _hl_rm {
            bdel.call(self.rc_release_simple_fn, [bdel.bitcast(vv_rm, i8p, name="vc")]);
        }

        bdel.store(
            ir.Constant(val_type, None), bdel.gep(va_rm, [res_rm], name="vclear")
        );
    }
    bdel.store(ir.Constant(i8, CTRL_TOMBSTONE), bdel.gep(ca_rm, [res_rm], name="csp"));
    cl_rm = bdel.load(lp_rm, name="cl");
    _new_len_rm = bdel.sub(cl_rm, ir.Constant(i64, 1), name="nl");
    bdel.store(_new_len_rm, lp_rm);

    bdel2 = self._emit_dict_order_compact(
        bdel, remove_fn, d_rm, res_rm, _new_len_rm, i32, i64
    );
    bdel2.branch(done_rm);
    ir.IRBuilder(done_rm).ret_void();

    pop_fnty = ir.FunctionType(val_type, [dict_ptr_type, key_type]);
    pop_fn = ir.Function(
        self.llvm_module, pop_fnty, name=f"__dict_pop_{key_type_name}_{val_type_name}"
    );
    pop_fn.linkage = "private";
    pop_fn.args[0].name = "dict";
    pop_fn.args[1].name = "key";
    bpop = ir.IRBuilder(pop_fn.append_basic_block("entry"));
    d_pop = pop_fn.args[0];
    k_pop = pop_fn.args[1];
    res_p = bpop.call(find_fn, [d_pop, k_pop], name="res");
    fnd_p = bpop.icmp_signed(">=", res_p, ir.Constant(i64, 0), name="found");
    del_p = pop_fn.append_basic_block("del");
    miss_p = pop_fn.append_basic_block("miss");
    bpop.cbranch(fnd_p, del_p, miss_p);
    bdp = ir.IRBuilder(del_p);
    ka_p = bdp.load(
        bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"), name="ka"
    );
    va_p = bdp.load(
        bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"), name="va"
    );
    ca_p = bdp.load(
        bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"),
        name="ca"
    );
    lp_p = bdp.gep(d_pop, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp");
    v_out = bdp.load(bdp.gep(va_p, [res_p], name="vsp"), name="v");

    if isinstance(val_type, ir.PointerType) {
        bdp.store(ir.Constant(val_type, None), bdp.gep(va_p, [res_p], name="vclear"));
    }
    if isinstance(key_type, ir.PointerType) {
        kv_p = bdp.load(bdp.gep(ka_p, [res_p], name="kvp"), name="kv");

        if self._nogc_headerless() {
            _free_p = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
            bdp.call(_free_p, [bdp.bitcast(kv_p, i8p, name="kc")]);
        } else {
            bdp.call(self.rc_release_simple_fn, [bdp.bitcast(kv_p, i8p, name="kc")]);
        }
        bdp.store(ir.Constant(key_type, None), bdp.gep(ka_p, [res_p], name="kclear"));
    }
    bdp.store(ir.Constant(i8, CTRL_TOMBSTONE), bdp.gep(ca_p, [res_p], name="csp"));
    cl_p = bdp.load(lp_p, name="cl");
    _new_len_p = bdp.sub(cl_p, ir.Constant(i64, 1), name="nl");
    bdp.store(_new_len_p, lp_p);

    bdp2 = self._emit_dict_order_compact(
        bdp, pop_fn, d_pop, res_p, _new_len_p, i32, i64
    );
    bdp2.ret(v_out);
    bmp = ir.IRBuilder(miss_p);
    if isinstance(val_type, ir.PointerType) {
        bmp.ret(ir.Constant(val_type, None));
    } elif val_type?.elements and val_type.elements {
        bmp.ret(ir.Constant(val_type, [ir.Constant(e, 0) for e in val_type.elements]));
    } else {
        bmp.ret(ir.Constant(val_type, 0));
    }

    clear_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
    clear_fn = ir.Function(
        self.llvm_module,
        clear_fnty,
        name=f"__dict_clear_{key_type_name}_{val_type_name}"
    );
    clear_fn.linkage = "private";
    clear_fn.args[0].name = "dict";
    bcl = ir.IRBuilder(clear_fn.append_basic_block("entry"));
    d_cl = clear_fn.args[0];
    cap_cl = bcl.load(
        bcl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp"), name="cap"
    );
    ka_cl = bcl.load(
        bcl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"), name="ka"
    );
    va_cl = bcl.load(
        bcl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"), name="va"
    );
    ca_cl = bcl.load(
        bcl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"), name="ca"
    );
    si_cl = bcl.alloca(i64, name="si");
    bcl.store(ir.Constant(i64, 0), si_cl);

    cl_loop = clear_fn.append_basic_block("loop");
    cl_chk = clear_fn.append_basic_block("chk");
    cl_live = clear_fn.append_basic_block("live");
    cl_zero = clear_fn.append_basic_block("zero");
    cl_done = clear_fn.append_basic_block("done");
    bcl.branch(cl_loop);

    blc_cl = ir.IRBuilder(cl_loop);
    si_v_cl = blc_cl.load(si_cl, name="si");
    blc_cl.cbranch(
        blc_cl.icmp_unsigned(">=", si_v_cl, cap_cl, name="end"), cl_done, cl_chk
    );

    bch_cl = ir.IRBuilder(cl_chk);
    cb_cl = bch_cl.load(bch_cl.gep(ca_cl, [si_v_cl], name="cbp"), name="cb");
    bch_cl.cbranch(
        bch_cl.icmp_unsigned(">=", cb_cl, ir.Constant(i8, 0x80), name="occ"),
        cl_live,
        cl_zero
    );

    blv_cl = ir.IRBuilder(cl_live);
    _hl_cl = self._nogc_headerless();
    _free_cl = self._get_or_declare_extern("free", ir.VoidType(), [i8p])
        if _hl_cl
        else None;
    if isinstance(key_type, ir.PointerType) {
        kv_cl = blv_cl.load(blv_cl.gep(ka_cl, [si_v_cl], name="kvp"), name="kv");
        if _hl_cl {
            blv_cl.call(_free_cl, [blv_cl.bitcast(kv_cl, i8p, name="kc")]);
        } else {
            blv_cl.call(
                self.rc_release_simple_fn, [blv_cl.bitcast(kv_cl, i8p, name="kc")]
            );
        }
        blv_cl.store(
            ir.Constant(key_type, None), blv_cl.gep(ka_cl, [si_v_cl], name="kclear")
        );
    }
    if isinstance(val_type, ir.PointerType) {
        vv_cl = blv_cl.load(blv_cl.gep(va_cl, [si_v_cl], name="vvp"), name="vv");
        if not _hl_cl {
            blv_cl.call(
                self.rc_release_simple_fn, [blv_cl.bitcast(vv_cl, i8p, name="vc")]
            );
        }
        blv_cl.store(
            ir.Constant(val_type, None), blv_cl.gep(va_cl, [si_v_cl], name="vclear")
        );
    }
    blv_cl.branch(cl_zero);

    bz_cl = ir.IRBuilder(cl_zero);
    bz_cl.store(ir.Constant(i8, CTRL_EMPTY), bz_cl.gep(ca_cl, [si_v_cl], name="czp"));
    bz_cl.store(bz_cl.add(si_v_cl, ir.Constant(i64, 1), name="nsi"), si_cl);
    bz_cl.branch(cl_loop);

    bdn_cl = ir.IRBuilder(cl_done);
    bdn_cl.store(
        ir.Constant(i64, 0),
        bdn_cl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp")
    );
    bdn_cl.store(
        ir.Constant(i64, 0),
        bdn_cl.gep(d_cl, [ir.Constant(i32, 0), ir.Constant(i32, 5)], name="up")
    );
    bdn_cl.ret_void();

    len_fn = self._emit_container_len_fn(
        f"__dict_len_{key_type_name}_{val_type_name}", dict_ptr_type
    );

    get_key_fnty = ir.FunctionType(key_type, [dict_ptr_type, i64]);
    get_key_fn = ir.Function(
        self.llvm_module,
        get_key_fnty,
        name=f"__dict_get_key_{key_type_name}_{val_type_name}"
    );
    get_key_fn.linkage = "private";
    get_key_fn.args[0].name = "dict";
    get_key_fn.args[1].name = "i";
    bgk = ir.IRBuilder(get_key_fn.append_basic_block("entry"));
    d_gk = get_key_fn.args[0];
    tgt_gk = get_key_fn.args[1];
    len_gk = bgk.load(
        bgk.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp"), name="len"
    );
    gk_ok_bb = get_key_fn.append_basic_block("ok");
    gk_oob_bb = get_key_fn.append_basic_block("oob");
    _gk_inb = bgk.and_(
        bgk.icmp_signed(">=", tgt_gk, ir.Constant(i64, 0), name="gk.ge0"),
        bgk.icmp_signed("<", tgt_gk, len_gk, name="gk.lt"),
        name="gk.inb"
    );
    bgk.cbranch(_gk_inb, gk_ok_bb, gk_oob_bb);
    bok = ir.IRBuilder(gk_ok_bb);
    ord_gk = bok.load(
        bok.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, 6)], name="orp"),
        name="order"
    );
    keys_gk = bok.load(
        bok.gep(d_gk, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"),
        name="keys"
    );
    _gk_slot = bok.load(bok.gep(ord_gk, [tgt_gk], name="gk.slp"), name="gk.slot");
    bok.ret(bok.load(bok.gep(keys_gk, [_gk_slot], name="gk.kp"), name="k"));
    boob = ir.IRBuilder(gk_oob_bb);
    if isinstance(key_type, ir.PointerType) {
        boob.ret(ir.Constant(key_type, None));
    } else {
        boob.ret(ir.Constant(key_type, 0));
    }

    get_val_fnty = ir.FunctionType(val_type, [dict_ptr_type, i64]);
    get_val_fn = ir.Function(
        self.llvm_module,
        get_val_fnty,
        name=f"__dict_get_val_{key_type_name}_{val_type_name}"
    );
    get_val_fn.linkage = "private";
    get_val_fn.args[0].name = "dict";
    get_val_fn.args[1].name = "i";
    bgv = ir.IRBuilder(get_val_fn.append_basic_block("entry"));
    d_gv = get_val_fn.args[0];
    tgt_gv = get_val_fn.args[1];
    len_gv = bgv.load(
        bgv.gep(d_gv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lp"), name="len"
    );
    gv_ok_bb = get_val_fn.append_basic_block("ok");
    gv_oob_bb = get_val_fn.append_basic_block("oob");
    _gv_inb = bgv.and_(
        bgv.icmp_signed(">=", tgt_gv, ir.Constant(i64, 0), name="gv.ge0"),
        bgv.icmp_signed("<", tgt_gv, len_gv, name="gv.lt"),
        name="gv.inb"
    );
    bgv.cbranch(_gv_inb, gv_ok_bb, gv_oob_bb);
    bvok = ir.IRBuilder(gv_ok_bb);
    ord_gv = bvok.load(
        bvok.gep(d_gv, [ir.Constant(i32, 0), ir.Constant(i32, 6)], name="orp"),
        name="order"
    );
    vals_gv = bvok.load(
        bvok.gep(d_gv, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"),
        name="vals"
    );
    _gv_slot = bvok.load(bvok.gep(ord_gv, [tgt_gv], name="gv.slp"), name="gv.slot");
    bvok.ret(bvok.load(bvok.gep(vals_gv, [_gv_slot], name="gv.vp"), name="v"));
    bvoob = ir.IRBuilder(gv_oob_bb);
    if isinstance(val_type, ir.PointerType) {
        bvoob.ret(ir.Constant(val_type, None));
    } elif val_type?.elements and val_type.elements {
        bvoob.ret(
            ir.Constant(val_type, [ir.Constant(e, 0) for e in val_type.elements])
        );
    } else {
        bvoob.ret(ir.Constant(val_type, 0));
    }

    if not self._nogc_headerless() {
        rel_fnty2 = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
        try {
            _ex = self.llvm_module.get_global(_rel_fn_name);
            if isinstance(_ex, ir.Function) and not _ex.blocks {
                release_fn = _ex;
                release_fn.linkage = "private";
            } else {
                release_fn = ir.Function(
                    self.llvm_module, rel_fnty2, name=_rel_fn_name
                );
                release_fn.linkage = "private";
            }
        } except KeyError {
            release_fn = ir.Function(self.llvm_module, rel_fnty2, name=_rel_fn_name);
            release_fn.linkage = "private";
        }
        release_fn.args[0].name = "dict";
        (brel, done_rel_bb) = self._emit_rc_destructor_preamble(
            release_fn, dict_ptr_type
        );
        d_rel = release_fn.args[0];
        cap_rel = brel.load(
            brel.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cp"),
            name="cap"
        );
        keys_rel = brel.load(
            brel.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="kp"),
            name="keys"
        );
        vals_rel = brel.load(
            brel.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vp"),
            name="vals"
        );
        ctrl_rel = brel.load(
            brel.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="ctp"),
            name="ctrl"
        );
        need_kv = (
            isinstance(key_type, ir.PointerType) or isinstance(val_type, ir.PointerType)
        );
        if need_kv {
            _cycles_on_d = self._gc_mode() == "cycles";
            if _cycles_on_d and self.rc_collecting_gv is None {
                self._emit_rc_helpers();
            }
            si_ra = brel.alloca(i64, name="si");
            brel.store(ir.Constant(i64, 0), si_ra);
            rlp_bb = release_fn.append_basic_block("rlp");
            rchk_bb = release_fn.append_basic_block("rchk");
            rkv_bb = release_fn.append_basic_block("rkv");
            rnx_bb = release_fn.append_basic_block("rnx");
            rarr_bb = release_fn.append_basic_block("rarr");
            if _cycles_on_d {
                _dict_coll = brel.load(self.rc_collecting_gv, name="dict.collecting");
                brel.cbranch(
                    brel.icmp_unsigned(
                        "!=", _dict_coll, ir.Constant(i8, 0), name="dict.mid.coll"
                    ),
                    rarr_bb,
                    rlp_bb
                );
            } else {
                brel.branch(rlp_bb);
            }
            brlp = ir.IRBuilder(rlp_bb);
            si_r = brlp.load(si_ra, name="si");
            brlp.cbranch(
                brlp.icmp_unsigned(">=", si_r, cap_rel, name="end"), rarr_bb, rchk_bb
            );
            brchk = ir.IRBuilder(rchk_bb);
            cb_r = brchk.load(brchk.gep(ctrl_rel, [si_r], name="cbp"), name="cb");
            brchk.cbranch(
                brchk.icmp_unsigned(">=", cb_r, ir.Constant(i8, 0x80), name="occ"),
                rkv_bb,
                rnx_bb
            );
            brkv = ir.IRBuilder(rkv_bb);
            if isinstance(key_type, ir.PointerType) {
                kv_r = brkv.load(brkv.gep(keys_rel, [si_r], name="kvp"), name="kv");
                brkv.call(
                    self.rc_release_simple_fn, [brkv.bitcast(kv_r, i8p, name="kc")]
                );
            }
            if isinstance(val_type, ir.PointerType) {
                vv_r = brkv.load(brkv.gep(vals_rel, [si_r], name="vvp"), name="vv");
                brkv.call(
                    self.rc_release_simple_fn, [brkv.bitcast(vv_r, i8p, name="vc")]
                );
            }
            brkv.branch(rnx_bb);
            brnx = ir.IRBuilder(rnx_bb);
            brnx.store(brnx.add(si_r, ir.Constant(i64, 1), name="nsi"), si_ra);
            brnx.branch(rlp_bb);
            brra = ir.IRBuilder(rarr_bb);
        } else {
            rarr_bb = release_fn.append_basic_block("rarr");
            brel.branch(rarr_bb);
            brra = ir.IRBuilder(rarr_bb);
        }
        brra.call(self.rc_safe_free_fn, [brra.bitcast(keys_rel, i8p, name="ki8")]);
        brra.call(self.rc_safe_free_fn, [brra.bitcast(vals_rel, i8p, name="vi8")]);
        brra.call(self.rc_safe_free_fn, [ctrl_rel]);

        _order_rel = brra.load(
            brra.gep(d_rel, [ir.Constant(i32, 0), ir.Constant(i32, 6)], name="orp"),
            name="order"
        );
        brra.call(self.rc_safe_free_fn, [brra.bitcast(_order_rel, i8p, name="ordi8")]);

        self._emit_release_header_free(release_fn, brra, done_rel_bb);
        self.dict_release_fns[dict_key] = release_fn;
    } else {
        _dstruct_name_hl = getattr(dict_ptr_type.pointee, "name", "");
        if _dstruct_name_hl {
            self._emit_container_drop_fn(_dstruct_name_hl);
        }
    }

    self.dict_helpers[dict_key] = {
        "new": new_fn,
        "set": set_fn,
        "get": get_fn,
        "len": len_fn,
        "contains": contains_fn,
        "get_key": get_key_fn,
        "get_val": get_val_fn,
        "remove": remove_fn,
        "pop": pop_fn,
        "find": find_fn,
        "clear": clear_fn,
        "key_type": key_type,
        "val_type": val_type
    };
}

impl NaIRGenPass._box_to_jacval(value: ir.Value) -> ir.Value {
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    if self?.jacval_type and value.type == self.jacval_type {
        return value;
    }
    jv_alloca = self._entry_alloca(self.jacval_type, "jacval");
    tag_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="jv.tag.ptr"
    );
    payload_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="jv.payload.ptr"
    );
    if isinstance(value.type, ir.IntType) and value.type.width == 1 {
        b.store(ir.Constant(i8, 7), tag_ptr);
        ext = b.zext(value, i64, name="jv.bext");
        b.store(ext, payload_ptr);
    } elif isinstance(value.type, ir.IntType) {
        b.store(ir.Constant(i8, 0), tag_ptr);
        if value.type.width == 64 {
            b.store(value, payload_ptr);
        } else {
            b.store(b.zext(value, i64, name="jv.iext"), payload_ptr);
        }
    } elif isinstance(value.type, ir.DoubleType) {
        b.store(ir.Constant(i8, 1), tag_ptr);
        payload = b.bitcast(value, i64, name="jv.f2i");
        b.store(payload, payload_ptr);
    } elif isinstance(value.type, ir.PointerType) {
        ptr_tag = 2;
        for (_, ltype) in self.list_types.items() {
            if value.type == ltype.as_pointer() {
                ptr_tag = 3;
                break;
            }
        }
        if ptr_tag == 2 {
            for (_, dtype) in self.dict_types.items() {
                if value.type == dtype.as_pointer() {
                    ptr_tag = 4;
                    break;
                }
            }
        }
        if ptr_tag == 2 {
            for (_, stype) in self.set_types.items() {
                if value.type == stype.as_pointer() {
                    ptr_tag = 5;
                    break;
                }
            }
        }
        if ptr_tag == 2 {
            for (_, structt) in self.struct_types.items() {
                if value.type == structt.as_pointer() {
                    ptr_tag = 6;
                    break;
                }
            }
        }
        payload = b.ptrtoint(value, i64, name="jv.p2i");
        if ptr_tag == 2 {
            is_null = b.icmp_unsigned(
                "==", payload, ir.Constant(i64, 0), name="jv.isnone"
            );
            none_or_str = b.select(
                is_null, ir.Constant(i8, 8), ir.Constant(i8, 2), name="jv.nonetag"
            );
            b.store(none_or_str, tag_ptr);
        } else {
            b.store(ir.Constant(i8, ptr_tag), tag_ptr);
        }
        b.store(payload, payload_ptr);
    } else {
        b.store(ir.Constant(i8, 0), tag_ptr);
        b.store(ir.Constant(i64, 0), payload_ptr);
    }
    return b.load(jv_alloca, name="jacval");
}

impl NaIRGenPass._unbox_from_jacval(jv: ir.Value, target_type: ir.Type) -> ir.Value {
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

impl NaIRGenPass._codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None) {
    if not nd.kv_pairs {
        _dk = self._dict_key_of(nd);
        _helpers = self.dict_helpers.get(_dk) if _dk is not None else None;
        if _helpers is not None {
            _empty_dv = self.builder.call(_helpers["new"], [], name="dict.empty");
            self._nogc_stamp_elem_drops(
                _empty_dv, self._nogc_type_arg_mangles(nd), "dict"
            );
            return _empty_dv;
        }
        return None;
    }

    first_pair = nd.kv_pairs[0];
    first_key = self._codegen_expr(first_pair.key);
    first_val = self._codegen_expr(first_pair.value);
    if first_key is None or first_val is None {
        return None;
    }

    _own_dk = self._dict_key_of(nd);
    use_jacval = _own_dk is not None and _own_dk.endswith(":jacval");

    if _own_dk is not None and not use_jacval and _own_dk in self.dict_helpers {
        dict_key = _own_dk;
        helpers = self.dict_helpers[dict_key];
        key_type = helpers["key_type"];
        val_type = helpers["val_type"];
    } else {
        key_type = first_key.type;
        (key_type_name, key_size) = self._dict_key_spec(key_type);
        if use_jacval {
            val_type = self.jacval_type;
            val_type_name = "jacval";
        } else {
            val_type = first_val.type;
            val_type_name = self._dict_val_spec(val_type);
        }
        dict_key = f"{key_type_name}:{val_type_name}";
        self._emit_dict_helpers(
            key_type_name, val_type_name, key_type, val_type, key_size
        );
        helpers = self.dict_helpers[dict_key];
    }

    _dict_new_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_dict_new_loc, name="dict.new"
    );
    self._nogc_stamp_elem_drops(dict_val, self._nogc_type_arg_mangles(nd), "dict");
    _dinit_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";

    first_val = self._nogc_elem_prep(first_pair.value, first_val);
    first_store_val = (
        self._box_to_jacval(first_val)
            if use_jacval
            else self._coerce_type(first_val, val_type)
    );
    self._rc_call_with_ctx(
        helpers["set"],
        [dict_val, self._coerce_type(first_key, key_type), first_store_val],
        op="dict_init",
        loc=_dinit_loc
    );

    if use_jacval and isinstance(first_val.type, ir.PointerType) {
        self._emit_rc_retain(first_val, op="dict_init", loc=_dinit_loc);
    }

    if isinstance(first_key.type, ir.PointerType) and self._is_owned(first_key) {
        self._emit_rc_release_simple(first_key, op="dict_init", loc=_dinit_loc);
    }
    if isinstance(first_val.type, ir.PointerType) and self._is_owned(first_val) {
        self._emit_rc_release_simple(first_val, op="dict_init", loc=_dinit_loc);
    }

    for i in range(1, len(nd.kv_pairs)) {
        pair = nd.kv_pairs[i];
        k = self._codegen_expr(pair.key);
        v = self._codegen_expr(pair.value);
        if k is not None and v is not None {
            v = self._nogc_elem_prep(pair.value, v);
            _orig_k = k;
            _orig_v = v;
            k = self._coerce_type(k, key_type);
            if use_jacval {
                v = self._box_to_jacval(v);
            } else {
                v = self._coerce_type(v, val_type);
            }
            self._rc_call_with_ctx(
                helpers["set"], [dict_val, k, v], op="dict_init", loc=_dinit_loc
            );

            if use_jacval and isinstance(_orig_v.type, ir.PointerType) {
                self._emit_rc_retain(_orig_v, op="dict_init", loc=_dinit_loc);
            }

            if isinstance(_orig_k.type, ir.PointerType) and self._is_owned(_orig_k) {
                self._emit_rc_release_simple(_orig_k, op="dict_init", loc=_dinit_loc);
            }
            if isinstance(_orig_v.type, ir.PointerType) and self._is_owned(_orig_v) {
                self._emit_rc_release_simple(_orig_v, op="dict_init", loc=_dinit_loc);
            }
        }
    }

    return dict_val;
}

impl NaIRGenPass._codegen_dict_access(
    target_val: ir.Value, key_val: ir.Value, key_type_name: str, val_type_name: str
) -> (ir.Value | None) {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return None;
    }
    key_type = helpers["key_type"];
    key_val = self._coerce_type(key_val, key_type);

    key_exists = self.builder.call(
        helpers["contains"], [target_val, key_val], name="dict.has"
    );
    not_exists = self.builder.not_(key_exists, name="dict.nokey");
    self._emit_runtime_raise(not_exists, "KeyError", "key not found");
    return self.builder.call(helpers["get"], [target_val, key_val], name="dict.get");
}

impl NaIRGenPass._codegen_dict_set(
    target_val: ir.Value,
    key_val: ir.Value,
    value: ir.Value,
    key_type_name: str,
    val_type_name: str
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return;
    }
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];
    _orig_value = value;
    key_val = self._coerce_type(key_val, key_type);
    value = self._coerce_type(value, val_type);
    _dset_ctx_loc = getattr(
        _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
    );
    self._rc_call_with_ctx(
        helpers["set"], [target_val, key_val, value], op="dict_set", loc=_dset_ctx_loc
    );

    if isinstance(val_type, ir.PointerType) and self._is_owned(_orig_value) {
        _dset_loc = getattr(
            _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
        );
        self._emit_rc_release_simple(_orig_value, op="dict_set", loc=_dset_loc);
    }
}
