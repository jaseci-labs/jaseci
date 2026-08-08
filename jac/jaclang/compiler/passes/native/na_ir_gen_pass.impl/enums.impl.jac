impl NaIRGenPass._class_form_enum_llvm(t: any) -> (ir.Type | None) {
    import from jaclang.compiler.passes.main.layout_pass { class_form_enum_scalar }
    _scalar = class_form_enum_scalar(t);
    if _scalar is None {
        return None;
    }
    if _scalar == "int" {
        return ir.IntType(64);
    }
    return self.type_map.get("str", ir.IntType(8).as_pointer());
}

impl NaIRGenPass._class_form_enum_self_type(arch_name: str) -> (ir.Type | None) {
    _arch = self.arch_ast_map.get(arch_name);
    if _arch is None or not (_arch?.name) {
        return None;
    }
    return self._class_form_enum_llvm(_arch.name.type);
}

impl NaIRGenPass._codegen_class_form_enum_member(
    nd: uni.AtomTrailer
) -> (ir.Value | None) {
    import from jaclang.compiler.passes.main.layout_pass { class_form_enum_member }
    _member = class_form_enum_member(nd.type if isinstance(nd, uni.Expr) else None);
    if _member is None {
        return None;
    }
    (_scalar, _lit, _name) = _member;
    if _scalar == "int" {
        return ir.Constant(ir.IntType(64), _lit);
    }
    return self._make_global_string(_lit, name_prefix=".cfenum");
}

impl NaIRGenPass._ensure_enum_lowered(t: any) -> bool {
    import from jaclang.compiler.passes.main.layout_pass {
        is_enum_class_type,
        enum_decl_of
    }
    if not is_enum_class_type(t) {
        return False;
    }
    _decl = enum_decl_of(t);
    if _decl is not None {
        self._codegen_enum(_decl);
    }
    return True;
}

impl NaIRGenPass._codegen_enum(nd: uni.Enum) -> None {
    enum_name = (nd).name.value if (nd).name else "unknown_enum";

    if enum_name in self.enum_types {
        return;
    }
    self.enum_types[enum_name] = ir.IntType(64);
    self.has_native_code = True;

    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    _owner_mod = nd.find_parent_of_type(uni.Module) or self.ir_in;
    lay = get_layout_registry(_owner_mod, self.prog).get_enum_layout(enum_name);
    if lay is None or not lay.members {
        return;
    }

    i64 = ir.IntType(64);
    if lay.is_string_enum {
        entries: list = [];
        for m in lay.members {
            full_name = f"{enum_name}.{m.name}";
            self.enum_values[full_name] = ir.Constant(i64, m.ordinal);
            self.enum_member_ordinal[full_name] = m.ordinal;
            entries.append((m.name, m.str_value or "", m.ordinal));
        }
        self.enum_string_values[enum_name] = entries;
        self._build_enum_string_table(enum_name, entries);
    } else {
        name_entries: list = [];
        for m in lay.members {
            full_name = f"{enum_name}.{m.name}";
            self.enum_values[full_name] = ir.Constant(i64, m.int_value);
            self.enum_member_ordinal[full_name] = m.ordinal;
            name_entries.append((m.name, "", m.ordinal));
        }
        self._build_enum_string_table(enum_name, name_entries, with_values=False);
    }
}

impl NaIRGenPass._build_enum_string_table(
    enum_name: str, entries: list, with_values: bool = True
) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    value_ptrs: list = [];
    name_ptrs: list = [];
    for (mname, str_val, ordinal) in entries {
        if with_values {
            (val_struct_type, val_struct) = self._static_str_struct_const(
                (str_val + "\0").encode("utf8")
            );
            val_gv = ir.GlobalVariable(
                self.llvm_module,
                val_struct_type,
                name=f"__enum.{enum_name}.v.{ordinal}"
            );
            val_gv.linkage = "private";
            val_gv.global_constant = True;
            val_gv.initializer = val_struct;

            val_ptr = val_gv.gep(
                [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
            );
            value_ptrs.append(val_ptr);
        }

        (name_struct_type, name_struct) = self._static_str_struct_const(
            (mname + "\0").encode("utf8")
        );
        name_gv = ir.GlobalVariable(
            self.llvm_module, name_struct_type, name=f"__enum.{enum_name}.n.{ordinal}"
        );
        name_gv.linkage = "private";
        name_gv.global_constant = True;
        name_gv.initializer = name_struct;
        name_ptr = name_gv.gep(
            [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
        );
        name_ptrs.append(name_ptr);
    }
    n = len(entries);
    arr_type = ir.ArrayType(i8p, n);

    if with_values {
        val_arr_gv = ir.GlobalVariable(
            self.llvm_module, arr_type, name=f"__enum_values.{enum_name}"
        );
        val_arr_gv.linkage = "private";
        val_arr_gv.global_constant = True;
        val_arr_gv.initializer = ir.Constant(arr_type, value_ptrs);
        self.enum_value_arrays[enum_name] = val_arr_gv;
    }

    name_arr_gv = ir.GlobalVariable(
        self.llvm_module, arr_type, name=f"__enum_names.{enum_name}"
    );
    name_arr_gv.linkage = "private";
    name_arr_gv.global_constant = True;
    name_arr_gv.initializer = ir.Constant(arr_type, name_ptrs);
    self.enum_name_arrays[enum_name] = name_arr_gv;
}

impl NaIRGenPass._codegen_enum_value_lookup(
    enum_name: str, ordinal_val: ir.Value, use_name: bool = False
) -> (ir.Value | None) {
    arr_global = (self.enum_name_arrays if use_name else self.enum_value_arrays).get(
        enum_name
    );
    if arr_global is None {
        return None;
    }
    i32 = ir.IntType(32);
    i8p = ir.IntType(8).as_pointer();

    idx = self.builder.trunc(ordinal_val, i32, name="enum.idx");

    ptr_ptr = self.builder.gep(
        arr_global, [ir.Constant(i32, 0), idx], name=f"enum.{enum_name}.ptr"
    );
    return self.builder.load(ptr_ptr, name=f"enum.{enum_name}.str");
}
