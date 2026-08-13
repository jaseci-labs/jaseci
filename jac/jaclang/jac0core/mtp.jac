import from collections.abc { Callable }

obj MTRuntime {
    has caller: Callable[(..., object)],
        args: dict[((int | str), object)],
        call_params: dict[(str, object)],
        mtir: (MTIR | None);

    static def factory(
        caller: Callable[(..., object)],
        args: dict[((int | str), object)],
        call_params: dict[(str, object)],
        mtir: (MTIR | None) = None
    ) -> MTRuntime {
        return MTRuntime(caller=caller, args=args, call_params=call_params, mtir=mtir);
    }
}

obj MTIR {
    has caller: Callable[(..., object)],
        args: dict[((int | str), object)],
        call_params: dict[(str, object)],
        ir_info: (Info | None) = None;

    has runtime: MTRuntime { getter; }
}

obj Info {
    has name: str,
        semstr: (str | None),
        mod_path: (str | None) = None;
}

obj VarInfo(Info) {
    has type_info: (ClassInfo | str | tuple | None) = None;
}

obj ParamInfo(VarInfo) {}

obj FieldInfo(VarInfo) {}

obj EnumInfo(Info) {
    has members: list[FieldInfo];
}

obj ClassInfo(Info) {
    has fields: list[FieldInfo],
        base_classes: list[ClassInfo],
        methods: list[MethodInfo];

    def postinit -> object;
}

obj FunctionInfo(Info) {
    has params: (list[ParamInfo] | None) = None,
        return_type: (str | ClassInfo | tuple | None) = None,
        tools: (list[MethodInfo] | None) = None,
        by_call: bool = False;

    def postinit -> object;
}

obj MethodInfo(FunctionInfo) {
    has parent_class: (ClassInfo | None) = None;
}

def mk_list(inner: object) -> tuple {
    return ('list', inner);
}

def mk_dict(key: object, val: object) -> tuple {
    return ('dict', key, val);
}

def mk_tuple(*types: object) -> tuple {
    return (('tuple', ) + `tuple(types));
}


def type_to_str(t: object) -> str {
    if (t is None) {
        return 'None';
    }
    if isinstance(t, str) {
        return t;
    }
    try {
        import from dataclasses { is_dataclass }
        if (is_dataclass(t) and t?.name) {
            return t.name;
        }
    } except Exception {
        ;
    }
    if isinstance(t, `tuple) {
        head = t[0];
        if (head == 'list') {
            return f"list[{type_to_str(t[1])}]";
        }
        if (head == 'dict') {
            return f"dict[{type_to_str(t[1])},{type_to_str(t[2])}]";
        }
        if (head == 'tuple') {
            return 'tuple[' + ','.join(type_to_str(x) for x in t[1:]) + ']';
        }
        if (head == 'union') {
            return '|'.join(type_to_str(x) for x in t[1:]);
        }
        return (head + '[' + ','.join(type_to_str(x) for x in t[1:]) + ']');
    }
    return str(t);
}

def fetch_mtir(func: Callable) -> Info | None {
    import sys;
    import from jaclang.jac0core.runtime { JacRuntime }
    import from jaclang.jac0core.jir { mtir_module_key, mtir_module_stem }

    module_name = func?.__module__;

    path = None;
    if module_name == "__main__" or module_name is None {
        main_mod = sys.modules.get("__main__");
        if main_mod {
            path = main_mod?.__file__;
        }
        if path is None and sys.argv and sys.argv[0] {
            path = sys.argv[0];
        }
    } else {
        mod = sys.modules.get(module_name);
        if mod {
            path = mod?.__file__;
        }
    }
    if path is None {
        return None;
    }

    prog = JacRuntime.program;
    if prog is None {
        return None;
    }

    key = mtir_module_key(path);
    slice = prog.mtir_by_module.get(key);
    if slice is None {
        try {
            internal = prog._get_compiler().internal_program;
        } except Exception {
            internal = None;
        }
        if internal is not None and internal is not prog {
            slice = internal.mtir_by_module.get(key);
        }
    }
    if slice is None {
        return None;
    }

    qualname = func?.__qualname__;
    if qualname is None {
        return None;
    }
    scope = mtir_module_stem(path) + "." + qualname;
    return slice.get(scope);
}
