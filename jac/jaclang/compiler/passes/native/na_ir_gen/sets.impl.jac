impl NaIRGenSets._emit_set_helpers(
    elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
) -> None {
    if elem_type_name in self.set_helpers {
        return;
    }

    _struct_name = f"Set.{elem_type_name}";
    layout = self._container_layout_hash(elem_type, None);
    set_struct = self.llvm_module.context.get_identified_type(_struct_name);
    if not set_struct.elements {
        set_struct.set_body(*self._container_struct_fields(layout));
    }
    self.set_types[elem_type_name] = set_struct;
    self.container_layouts[_struct_name] = layout;
    set_ptr_type = set_struct.as_pointer();

    _rel_fn_decl_s = None;
    _rel_fn_name_s = f"__rc_release_set_{elem_type_name}";
    if not self._nogc_headerless() {
        _rel_fnty_s = ir.FunctionType(ir.VoidType(), [set_ptr_type]);
        try {
            _rel_fn_decl_s = self.llvm_module.get_global(_rel_fn_name_s);
        } except KeyError {
            _rel_fn_decl_s = ir.Function(
                self.llvm_module, _rel_fnty_s, name=_rel_fn_name_s
            );
            _rel_fn_decl_s.linkage = "private";
        }
    }

    new_fn = self._emit_container_new_fn(
        f"__set_new_{elem_type_name}",
        set_ptr_type,
        layout,
        dtor_fn=_rel_fn_decl_s,
        type_name=f"set_{elem_type_name}"
    );

    core = self._emit_hash_core_helpers(
        "set",
        elem_type_name,
        set_ptr_type,
        elem_type,
        None,
        elem_type_name,
        elem_size,
        layout
    );

    len_fn = self._emit_container_len_fn(f"__set_len_{elem_type_name}", set_ptr_type);

    if self._nogc_headerless() {
        self._emit_container_drop_fn(_struct_name);
    } else {
        release_fn = self._emit_container_release_fn(
            _rel_fn_name_s, set_ptr_type, layout
        );
        self.set_release_fns[elem_type_name] = release_fn;
    }

    self.set_helpers[elem_type_name] = {
        "new": new_fn,
        "add": core["insert"],
        "add_ph": core["insert_ph"],
        "contains": core["contains"],
        "contains_ph": core["contains_ph"],
        "remove": core["remove"],
        "remove_ph": core["remove_ph"],
        "clear": core["clear"],
        "get": core["get_key"],
        "find": core["find"],
        "len": len_fn,
        "elem_type": elem_type,
        "elem_size": elem_size
    };
}

impl NaIRGenSets._codegen_set_val(nd: uni.SetVal) -> (ir.Value | None) {
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    _sty = self._expr_type_of(nd);
    _elem_tb = self._tb_elem(_sty);
    if _elem_tb is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="set display without an element type",
            help_text="The checker stamped no element type on this set display, so there is no native layout to build it in. Annotate the binding (for example `s: set[int] = set()`), or give the display an element."
        );
        return None;
    }
    _el = self._elem_slot_llvm(_elem_tb);
    if _el is not None and self?.jacval_type and _el == self.jacval_type {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="set of mixed element types",
            help_text="Native sets hash a single concrete element type; a set whose elements mix representations has no native storage. Use a homogeneous element type, or a list for mixed values."
        );
        return None;
    }
    if _el is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name=f"set of {_elem_tb}",
            help_text="The element type has no native lowering, so the set has no native layout. Use a lowerable element type, or move this code to a @sv/Python context."
        );
        return None;
    }
    elem_type_name = self._set_spec_for_type(_sty);
    if elem_type_name is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name=f"set of {_elem_tb}",
            help_text="The set's element type did not resolve to one native hash layout. Give the display one concrete element type."
        );
        return None;
    }
    helpers = self.set_helpers[elem_type_name];
    elem_type = helpers["elem_type"];
    set_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="set.new"
    );
    self._nogc_stamp_elem_drops(set_val, [_elem_tb]);

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
                    name="spread in a set display",
                    help_text="A `*` spread is copied element by element out of a native list or set; this operand lowered to neither. Give it a lowerable list or set type, or write the elements out."
                );
                return None;
            }
            self._emit_spread_copy(
                _src_info["value"],
                _src_info["helpers"],
                set_val,
                helpers,
                "set",
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
                name="set element",
                help_text="This element of the set display did not lower, so the set would have been built without it. Move the expression out of the display, or move the enclosing code to a @sv/Python context."
            );
            return None;
        }
        if isinstance(elem_type, ir.PointerType)
            and isinstance(elem_type.pointee, ir.LiteralStructType)
            and isinstance(val.type, ir.LiteralStructType) {
            val = self._coerce_tuple_to_struct(val, elem_type.pointee);
        }
        val = self._box_value_tuple(val, loc=_loc);
        val = self._nogc_elem_prep(v_nd, val);
        _orig_sv = val;
        val = self._coerce_typed(val, elem_type, self._expr_type_of(v_nd));
        (_add_fn, _kh) = self._static_key_op(helpers, "add", v_nd);
        _add_args = [set_val, val];
        if _kh is not None {
            _add_args.append(_kh);
        }
        self._rc_call_with_ctx(_add_fn, _add_args, op="set_init", loc=_loc);

        if isinstance(_orig_sv.type, ir.PointerType) and self._is_owned(_orig_sv) {
            self._emit_rc_release_simple(_orig_sv, op="set_init", loc=_loc);
        }
    }
    return set_val;
}
