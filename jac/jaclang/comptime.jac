import sys;
import platform as _platform;
import from dataclasses {
    MISSING as _MISSING,
    fields as _dc_fields,
    is_dataclass as _is_dataclass
}
import from enum { Enum as _PyEnum }
import from typing { get_type_hints as _get_type_hints }
import from importlib { import_module as _import_module }

enum Codespace {
    SERVER = "server",
    CLIENT = "client",
    NATIVE = "native",
    with entry {
        has is_server: bool { getter; }

        has is_client: bool { getter; }

        has is_native: bool { getter; }
    }
}

impl Codespace.is_server.getter -> bool {
    return self.value == "server";
}

impl Codespace.is_client.getter -> bool {
    return self.value == "client";
}

impl Codespace.is_native.getter -> bool {
    return self.value == "native";
}

obj TargetInfo {
    has os: str,
        arch: str;
}

obj FieldInfo {
    has name: str,
        `type: any = None,
        has_default: bool = False,
        `default: any = None,
        semstr: (str | None) = None;
}

obj LazyRef {
    has module: str,
        qualname: str;

    has resolved: any { getter; }

    def __call__(*args: any, **kwargs: any) -> any {
        return self.resolved(*args, **kwargs);
    }

    def __getattr__(name: str) -> any {
        return getattr(self.resolved, name);
    }

    def __repr__ -> str {
        return f"LazyRef({self.module}.{self.qualname})";
    }
}

impl LazyRef.resolved.getter -> any {
    cur: any = _import_module(self.module);
    for part in self.qualname.split(".") {
        cur = getattr(cur, part);
    }
    return cur;
}

def _host_os -> str {
    if sys.platform.startswith("win") {
        return "windows";
    }
    if sys.platform == "darwin" {
        return "darwin";
    }
    return "linux";
}

glob codespace: Codespace = Codespace.SERVER,
     target: TargetInfo = TargetInfo(os=_host_os(), arch=_platform.machine());

def __ct_ref(module: str, qualname: str) -> any {
    return LazyRef(module=module, qualname=qualname).resolved;
}

def __ct_lazy(module: str, qualname: str) -> LazyRef {
    return LazyRef(module=module, qualname=qualname);
}

def typeof(x: any) -> type {
    return `type(x);
}

def name(t: any) -> str {
    got = t?.__name__;
    if isinstance(got, str) {
        return got;
    }
    return str(t);
}

def module_of(t: any) -> str {
    got = t?.__module__;
    if isinstance(got, str) {
        return got;
    }
    return "";
}

def is_subtype(t: type, u: type) -> bool {
    try {
        return issubclass(t, u);
    } except TypeError {
        return False;
    }
}

def _semstr_of(target: any) -> (str | None) {
    got = target?._jac_semstr;
    if isinstance(got, str) and got {
        return got;
    }
    return None;
}

def semstr(t: any, field: str = "") -> (str | None) {
    if not field {
        return _semstr_of(t);
    }
    inner = t?._jac_semstr_inner;
    if isinstance(inner, dict) {
        got = inner.get(field);
        if isinstance(got, str) and got {
            return got;
        }
    }
    return None;
}

def fields(t: type) -> list[FieldInfo] {
    out: list[FieldInfo] = [];
    if not _is_dataclass(t) {
        return out;
    }
    try {
        hints = _get_type_hints(t);
    } except Exception {
        hints = {};
    }
    inner = t?._jac_semstr_inner;
    sems: dict = inner if isinstance(inner, dict) else {};
    for f in _dc_fields(t) {
        if f.name.startswith("_") {
            continue;
        }
        plain = f.`default;
        factory = f.default_factory;
        has_dflt = plain is not _MISSING or factory is not _MISSING;
        dflt: any = plain if plain is not _MISSING else None;
        out.append(
            FieldInfo(
                name=f.name,
                `type=hints.get(f.name, f.`type),
                has_default=has_dflt,
                `default=dflt,
                semstr=sems.get(f.name)
            )
        );
    }
    return out;
}

def has_field(t: type, field: str) -> bool {
    if _is_dataclass(t) {
        for f in _dc_fields(t) {
            if f.name == field {
                return True;
            }
        }
        return False;
    }
    return hasattr(t, field);
}

def get_field(target: any, field: str) -> any {
    return getattr(target, field);
}

def set_field(target: any, field: str, value: any) {
    setattr(target, field, value);
}

def members(e: type) -> list {
    if isinstance(e, `type) and issubclass(e, _PyEnum) {
        return `list(e);
    }
    return [];
}
