impl NaIRGenPass._build_vtable(arch_name: str) -> None {
    lay = self._arch_layout(arch_name);
    if lay is None or not lay.has_vtable {
        self.vtable_layouts[arch_name] = [];
        self.vtable_method_indices[arch_name] = {};
        return;
    }
    self.vtable_layouts[arch_name] = [m.name for m in lay.methods];
    self.vtable_method_indices[arch_name] = dict(lay.method_index);
}

impl NaIRGenPass._emit_vtable_global(arch_name: str) -> None {
    layout = self.vtable_layouts.get(arch_name);

    if layout is None {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();

    vtable_type = ir.ArrayType(i8_ptr, len(layout) + VTABLE_HEADER_SLOTS);
    entries: list[ir.Constant] = [self._emit_class_name_const(arch_name)];
    for method_name in layout {
        func = self._resolve_method(arch_name, method_name);
        if func is not None {
            entries.append(func.bitcast(i8_ptr));
        } else {
            entries.append(ir.Constant(i8_ptr, None));
        }
    }
    vtable_init = ir.Constant(vtable_type, entries);

    vtable_global = self.vtable_globals.get(arch_name);
    if vtable_global is None {
        vtable_global = ir.GlobalVariable(
            self.llvm_module, vtable_type, name=f"{arch_name}.__vtable"
        );
        self.vtable_globals[arch_name] = vtable_global;
    }
    vtable_global.global_constant = True;

    vtable_global.linkage = "";
    vtable_global.initializer = vtable_init;
}

impl NaIRGenPass._vtable_global_for(arch_name: str) -> (ir.GlobalVariable | None) {
    existing = self.vtable_globals.get(arch_name);
    if existing is not None {
        return existing;
    }
    lay = self._arch_layout(arch_name);
    if lay is None or not lay.has_vtable or arch_name not in self.struct_types {
        return None;
    }

    i8_ptr = ir.IntType(8).as_pointer();
    vtable_type = ir.ArrayType(i8_ptr, len(lay.methods) + VTABLE_HEADER_SLOTS);
    vtable_ref = ir.GlobalVariable(
        self.llvm_module, vtable_type, name=f"{arch_name}.__vtable"
    );
    vtable_ref.global_constant = True;
    vtable_ref.linkage = "external";
    self.vtable_globals[arch_name] = vtable_ref;
    return vtable_ref;
}

impl NaIRGenPass._vtable_candidates(names: list[str]) -> list[ir.GlobalVariable] {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }

    reg = get_layout_registry(self.ir_in, self.prog);
    out: list[ir.GlobalVariable] = [];
    for cand in reg.mro_order {
        cand_mro = self._mro_of(cand);
        for name in names {
            if name in cand_mro {
                vt = self._vtable_global_for(cand);
                if vt is not None {
                    out.append(vt);
                }
                break;
            }
        }
    }
    return out;
}

impl NaIRGenPass._codegen_virtual_call(
    obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
) -> (ir.Value | None) {
    indices = self.vtable_method_indices.get(obj_type_name);
    if indices is None or method_name not in indices {
        return None;
    }

    func = self._resolve_method(obj_type_name, method_name);
    if func is None {
        return None;
    }
    fn_type = func.function_type;

    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(fn_type.args) {
            coerced.append(self._coerce_type(arg, fn_type.args[i]));
        } else {
            coerced.append(arg);
        }
    }

    non_overridden = self._non_overridden_methods.get(obj_type_name);
    if non_overridden is not None and method_name in non_overridden {
        _dv_res = self.builder.call(func, coerced, name=f"call.{method_name}");

        self._release_owned_args(coerced, op="mcall_arg");
        return _dv_res;
    }

    method_idx = indices[method_name] + VTABLE_HEADER_SLOTS;
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();

    _vd_variants: list[tuple] = [];
    _vd_uniform = True;
    import from jaclang.compiler.passes.main.layout_pass {
        get_layout_registry as _vd_glr
    }
    _vd_reg = _vd_glr(self.ir_in, self.prog);
    for _vd_cls in _vd_reg.mro_order {
        if obj_type_name not in self._mro_of(_vd_cls) {
            continue;
        }
        _vd_lay = _vd_reg.get_layout(_vd_cls);
        if _vd_lay is None or not _vd_lay.has_vtable {
            continue;
        }
        _vd_idx = _vd_lay.method_index.get(method_name);
        _vd_fn = self._resolve_method(_vd_cls, method_name);
        _vd_vt = self._vtable_global_for(_vd_cls);
        if _vd_vt is None or _vd_fn is None {
            continue;
        }
        _vd_variants.append((_vd_cls, _vd_vt, _vd_fn));
        if _vd_idx != indices[method_name] {
            _vd_uniform = False;
        }
    }
    if not _vd_uniform and _vd_variants {
        vtable_ptr_ptr = self.builder.gep(
            obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="vt.id.pp"
        );
        _vd_vtp = self.builder.load(vtable_ptr_ptr, name="vt.id");
        _vd_fnc = self.builder.function;
        _vd_done = _vd_fnc.append_basic_block(name=f"vd.{method_name}.done");
        _vd_incoming: list[tuple] = [];
        for (_vc, _vt, _vf) in _vd_variants {
            _vd_hit = _vd_fnc.append_basic_block(name=f"vd.{method_name}.{_vc}");
            _vd_next = _vd_fnc.append_basic_block(name=f"vd.{method_name}.n.{_vc}");
            _vd_eq = self.builder.icmp_unsigned(
                "==",
                _vd_vtp,
                self.builder.bitcast(_vt, _vd_vtp.type, name="vd.cand"),
                name=f"vd.eq.{_vc}"
            );
            self.builder.cbranch(_vd_eq, _vd_hit, _vd_next);
            self.builder.position_at_end(_vd_hit);
            _vd_args: list[ir.Value] = [];
            for (_ai, _av) in enumerate(coerced) {
                if _ai < len(_vf.function_type.args) {
                    _vd_args.append(
                        self._coerce_type(_av, _vf.function_type.args[_ai])
                    );
                } else {
                    _vd_args.append(_av);
                }
            }
            _vd_r = self.builder.call(_vf, _vd_args, name=f"vd.call.{_vc}");
            _vd_ret_t = fn_type.return_type;
            if not isinstance(_vd_ret_t, ir.VoidType) and _vd_r.type != _vd_ret_t {
                _vd_r = self._coerce_type(_vd_r, _vd_ret_t);
            }
            _vd_incoming.append((_vd_r, self.builder.block));
            self.builder.branch(_vd_done);
            self.builder.position_at_end(_vd_next);
        }

        _vd_fb = self.builder.call(func, coerced, name=f"vd.fb.{method_name}");
        _vd_incoming.append((_vd_fb, self.builder.block));
        self.builder.branch(_vd_done);
        self.builder.position_at_end(_vd_done);
        _vd_ret_t = fn_type.return_type;
        if isinstance(_vd_ret_t, ir.VoidType) {
            self._release_owned_args(coerced, op="vcall_arg");
            return _vd_fb;
        }
        _vd_phi = self.builder.phi(_vd_ret_t, name=f"vd.{method_name}.res");
        for (_vr, _vb) in _vd_incoming {
            _vd_phi.add_incoming(_vr, _vb);
        }
        self._release_owned_args(coerced, op="vcall_arg");
        return _vd_phi;
    }

    vtable_ptr_ptr = self.builder.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="vtable.ptr.ptr"
    );
    vtable_ptr = self.builder.load(vtable_ptr_ptr, name="vtable.ptr");

    method_slot = self.builder.gep(
        vtable_ptr, [ir.Constant(i32, method_idx)], name=f"vt.{method_name}"
    );
    method_i8 = self.builder.load(method_slot, name=f"fn.{method_name}.raw");

    typed_fn = self.builder.bitcast(
        method_i8, fn_type.as_pointer(), name=f"fn.{method_name}"
    );
    _vt_res = self.builder.call(typed_fn, coerced, name=f"vcall.{method_name}");

    self._release_owned_args(coerced, op="vcall_arg");
    return _vt_res;
}

impl NaIRGenPass._emit_class_name_const(arch_name: str) -> ir.Value {
    cached = self._class_name_consts.get(arch_name);
    if cached is not None {
        return cached;
    }
    i32 = ir.IntType(32);
    (struct_type, struct_val) = self._static_str_struct_const(
        (arch_name + "\0").encode("utf8")
    );
    global_str = ir.GlobalVariable(
        self.llvm_module, struct_type, name=f".clsname.{self._str_count}"
    );
    self._str_count = self._str_count + 1;
    global_str.linkage = "private";
    global_str.global_constant = True;
    global_str.initializer = struct_val;

    ptr = global_str.gep(
        [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
    );
    self._class_name_consts[arch_name] = ptr;
    return ptr;
}

impl NaIRGenPass._codegen_class_name(nd: uni.AtomTrailer) -> (ir.Value | None) {
    if not (nd.is_attr and self._get_name(nd.right) == "__name__") {
        return None;
    }
    inner = nd.target;
    receiver: (uni.UniNode | None) = None;

    if isinstance(inner, uni.AtomTrailer)
        and inner.is_attr
        and self._get_name(inner.right) == "__class__" {
        receiver = inner.target;
    } elif isinstance(inner, uni.FuncCall)
        and self._get_name(inner.target) == "type"
        and inner.params
        and len(inner.params) == 1 {
        receiver = inner.params[0];
    }
    if receiver is None {
        return None;
    }
    arch_name = self._struct_name_of(receiver);
    if arch_name is None {
        return None;
    }

    if not self._arch_has_vtable(arch_name) {
        return self._emit_class_name_const(arch_name);
    }

    obj_val = self._codegen_expr(receiver);
    if obj_val is None {
        return None;
    }
    i32 = ir.IntType(32);
    vtable_ptr_ptr = self.builder.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="clsname.vt.ptr.ptr"
    );
    vtable_ptr = self.builder.load(vtable_ptr_ptr, name="clsname.vt.ptr");
    name_slot = self.builder.gep(
        vtable_ptr, [ir.Constant(i32, 0)], name="clsname.slot"
    );
    return self.builder.load(name_slot, name="clsname");
}

impl NaIRGenPass._generate_inherited_method_wrappers -> None {
    for child_name in self.arch_ast_map {
        mro = self._mro_of(child_name);
        child_struct = self.struct_types.get(child_name);
        if child_struct is None or len(mro) < 2 {
            continue;
        }

        seen_methods: set[str] = set();
        for ancestor_name in mro[1:] {
            ancestor_layout = self.vtable_layouts.get(ancestor_name, []);
            for method_name in ancestor_layout {
                if method_name in seen_methods {
                    continue;
                }
                seen_methods.add(method_name);
                child_full = f"{child_name}.{method_name}";

                if child_full in self.method_funcs {
                    continue;
                }

                impl_func = None;
                impl_class: (str | None) = None;
                for mro_class in mro[1:] {
                    parent_full = f"{mro_class}.{method_name}";
                    if parent_full in self.method_funcs {
                        impl_func = self.method_funcs[parent_full];
                        impl_class = mro_class;
                        break;
                    }
                }
                if impl_func is None {
                    continue;
                }

                orig_fn_type = impl_func.function_type;

                _has_self = False;
                if len(orig_fn_type.args) > 0
                    and isinstance(orig_fn_type.args[0], ir.PointerType) {
                    _p0_nm = getattr(orig_fn_type.args[0].pointee, "name", "") or "";
                    if _p0_nm == impl_class {
                        _has_self = True;
                    }
                }
                if not _has_self {
                    self.method_funcs[child_full] = impl_func;
                    self.func_symtab[child_full] = impl_func;
                    continue;
                }

                new_param_types: list[ir.Type] = [child_struct.as_pointer()];
                for i in range(1, len(orig_fn_type.args)) {
                    new_param_types.append(orig_fn_type.args[i]);
                }
                wrapper_fn_type = ir.FunctionType(
                    orig_fn_type.return_type, new_param_types
                );
                wrapper_fn = ir.Function(
                    self.llvm_module, wrapper_fn_type, name=child_full
                );

                wrapper_fn.args[0].name = "self";
                for i in range(1, len(impl_func.args)) {
                    wrapper_fn.args[i].name = impl_func.args[i].name;
                }

                entry_block = wrapper_fn.append_basic_block(name="entry");
                builder = ir.IRBuilder(entry_block);

                impl_struct = self.struct_types.get(impl_class);
                if impl_struct is None {
                    args: list[ir.Value] = list(wrapper_fn.args);
                } else {
                    parent_self = builder.bitcast(
                        wrapper_fn.args[0], impl_struct.as_pointer(), name="parent.self"
                    );
                    args: list[ir.Value] = [parent_self];
                    for i in range(1, len(wrapper_fn.args)) {
                        args.append(wrapper_fn.args[i]);
                    }
                }

                _exp_types = impl_func.function_type.args;
                for _ai in range(len(args)) {
                    if _ai < len(_exp_types)
                        and args[_ai].type != _exp_types[_ai]
                        and isinstance(args[_ai].type, ir.PointerType)
                        and isinstance(_exp_types[_ai], ir.PointerType) {
                        args[_ai] = builder.bitcast(
                            args[_ai], _exp_types[_ai], name=f"inh.arg{_ai}"
                        );
                    }
                }
                result = builder.call(impl_func, args, name=f"inherited.{method_name}");

                if isinstance(orig_fn_type.return_type, ir.VoidType) {
                    builder.ret_void();
                } else {
                    builder.ret(result);
                }

                self.method_funcs[child_full] = wrapper_fn;
                self.func_symtab[child_full] = wrapper_fn;
            }
        }
    }
}
