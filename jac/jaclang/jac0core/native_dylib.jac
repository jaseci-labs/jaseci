"""AOT native-artifact loader for sealed images.

Binds a sealed, AOT-compiled Jac shared library (see the seal's
native-artifact step in ``utils/precompile_bytecode.jac``) into the running
process with nothing but ctypes -- no LLVM, no MCJIT, nothing on the boot
path beyond one dlopen. ``DylibEngine`` satisfies the single engine API the
marshal layer uses (``get_function_address``), and ``layout_from_dict``
rebuilds the ``NativeModuleLayout`` shape ``native_marshal`` reads from the
JSON the seal persisted (writer: ``codeinfo.native_layout_to_dict`` -- change
both together).

Bootstrap-tier module: jac0-compiled, importable by the other jac0core
modules (the parser binds through it before the full compiler exists).
"""
import ctypes;
import from types { SimpleNamespace }

# Must match jaclang.jac0core.codeinfo.NATIVE_ABI_VERSION; asserted at bind
# time so a stale artifact fails closed instead of marshalling garbage.
glob NATIVE_ABI_VERSION: int = 1;

"""Engine-shaped wrapper over a dlopen'd sealed native artifact.

The artifact is linked with ``auto_init=False``: dlopen runs no Jac
initializers, so ``initialize()`` must run (exactly once) before any other
export is called -- it invokes ``__jac_shared_init``, which chains every
``__jac_glob_init*`` in the module closure.
"""
obj DylibEngine {
    has lib_path: str,
        _cdll: any = None,
        _initialized: bool = False;

    def postinit {
        self._cdll = ctypes.CDLL(self.lib_path);
    }

    def get_function_address(name: str) -> int {
        try {
            fn = getattr(self._cdll, name);
        } except AttributeError {
            return 0;
        }
        return ctypes.cast(fn, ctypes.c_void_p).value or 0;
    }

    def initialize {
        if self._initialized {
            return;
        }
        addr = self.get_function_address("__jac_shared_init");
        if addr {
            ctypes.CFUNCTYPE(None)(addr)();
        }
        self._initialized = True;
    }
}

def _tuple_layout(d: (dict | None)) -> any {
    if d is None {
        return None;
    }
    return SimpleNamespace(
        key=d["key"],
        element_types=list(d.get("element_types", [])),
        element_struct_hints=list(d.get("element_struct_hints", []))
    );
}

def _func_layout(d: dict) -> any {
    return SimpleNamespace(
        name=d["name"],
        param_types=list(d.get("param_types", [])),
        param_names=list(d.get("param_names", [])),
        ret_type=d.get("ret_type", "i64"),
        ret_struct_name=d.get("ret_struct_name"),
        ret_tuple_layout=_tuple_layout(d.get("ret_tuple_layout")),
        ret_enum_type=d.get("ret_enum_type"),
        ret_elem_keys=d.get("ret_elem_keys")
    );
}

def _field_info(f: dict) -> any {
    return SimpleNamespace(
        name=f["name"],
        llvm_type=f["llvm_type"],
        index=f["index"],
        enum_type=f.get("enum_type"),
        is_func_ptr=f.get("is_func_ptr", False),
        func_param_types=f.get("func_param_types"),
        func_ret_type=f.get("func_ret_type")
    );
}

"""Rebuild a NativeModuleLayout-shaped object from persisted JSON."""
def layout_from_dict(data: dict) -> any {
    stamped = data.get("abi_version");
    if stamped != NATIVE_ABI_VERSION {
        raise ValueError(
            f"sealed native layout has abi_version={stamped}, "
            f"this runtime expects {NATIVE_ABI_VERSION}"
        );
    }
    structs: dict = {};
    for (name, s) in data.get("structs", {}).items() {
        structs[name] = SimpleNamespace(
            name=s["name"],
            has_vtable=s.get("has_vtable", False),
            fields=[_field_info(f) for f in s.get("fields", [])]
        );
    }
    enums: dict = {};
    for (name, e) in data.get("enums", {}).items() {
        enums[name] = SimpleNamespace(
            name=e["name"],
            is_string_valued=e.get("is_string_valued", False),
            members=[
                tuple(m) if isinstance(m, list) else m
                for m in e.get("members", [])
            ]
        );
    }
    functions: dict = {};
    for (n, f) in data.get("functions", {}).items() {
        functions[n] = _func_layout(f);
    }
    methods: dict = {};
    for (n, f) in data.get("methods", {}).items() {
        methods[n] = _func_layout(f);
    }
    tuples: dict = {};
    for (k, t) in data.get("tuples", {}).items() {
        tuples[k] = _tuple_layout(t);
    }
    return SimpleNamespace(
        abi_version=stamped,
        structs=structs,
        enums=enums,
        functions=functions,
        methods=methods,
        list_elem_types=dict(data.get("list_elem_types", {})),
        tuples=tuples,
        tests=[]
    );
}
