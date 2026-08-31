import fnmatch;
import json;
import os;
import from jaclang.compiler.driver.modresolver { find_jac_project_root }

glob _VALID_SPACES: tuple = ('server', 'client', 'native'),
     _pins_cache: dict[str, tuple[float, dict[str, str]]] = {};


def _load_pins(root_dir: str) -> dict[str, str] {
    toml_path = os.path.join(root_dir, "jac.toml");
    try {
        mtime = os.path.getmtime(toml_path);
    } except OSError {
        return {};
    }
    cached = _pins_cache.get(root_dir);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    import tomllib;
    try {
        with open(toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
    } except Exception {
        return {};
    }
    raw = doc.get("placement", {}).get("pins", {});
    pins: dict[str, str] = {};
    for (key, value) in raw.items() {
        space = str(value);
        if space not in _VALID_SPACES {
            raise ValueError(
                f"[placement.pins] in {toml_path}: '{key}' pins to "
                f"'{space}', expected one of {list(_VALID_SPACES)}."
            );
        }
        pins[str(key)] = space;
    }
    _pins_cache[root_dir] = (mtime, pins);
    return pins;
}


def _module_dot_path(source_path: str, root_dir: str) -> str {
    abs_path = os.path.realpath(os.path.abspath(source_path));
    rel = os.path.relpath(abs_path, os.path.realpath(root_dir));
    if rel.startswith("..") {
        rel = os.path.basename(abs_path);
    }
    if rel.endswith(".jac") {
        rel = rel[:-4];
    }
    return rel.replace(os.sep, ".");
}


def config_pins_for(source_path: str) -> dict[str, str] {
    if not source_path {
        return {};
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return {};
    }
    return _load_pins(root_dir);
}


def config_pin_for(source_path: str, element_name: str) -> str {
    if not source_path {
        return '';
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return '';
    }
    pins = _load_pins(root_dir);
    if not pins {
        return '';
    }
    mod_dot = _module_dot_path(source_path, root_dir);
    for (pattern, space) in pins.items() {
        if element_name and fnmatch.fnmatchcase(f"{mod_dot}.{element_name}", pattern) {
            return space;
        }
        if fnmatch.fnmatchcase(mod_dot, pattern) {
            return space;
        }
    }
    return '';
}


def config_module_pin(source_path: str) -> str {
    return config_pin_for(source_path, '');
}


def _demotion_sidecar(path: str) -> (str | None) {
    try {
        import from jaclang.compiler.driver.jir { get_module_cache_path }
        return str(get_module_cache_path(path).with_suffix('.nademote'));
    } except Exception {
        return None;
    }
}


def _file_key(path: str) -> (tuple | None) {
    try {
        st = os.stat(path);
        return (st.st_mtime_ns, st.st_size);
    } except OSError {
        return None;
    }
}


def _remove_demotion_sidecar(path: str) {
    sidecar = _demotion_sidecar(path);
    if sidecar is None {
        return;
    }
    try {
        os.remove(sidecar);
    } except OSError {
        ;
    }
}


obj NaVerdictStore {
    has mem: dict[str, (tuple | None)] = {};

    def lookup(path: str) -> (tuple | None) {
        if path in self.mem {
            hit = self.mem[path];
            if hit is None {
                return None;
            }
            if hit[2] == _file_key(path) {
                return (hit[0], hit[1]);
            }
            self.mem.pop(path, None);
            _remove_demotion_sidecar(path);
            return None;
        }
        loaded = self._load(path);
        if loaded is None {
            self.mem[path] = None;
            return None;
        }
        (key, code) = loaded;
        if key != _file_key(path) {
            self.mem[path] = None;
            _remove_demotion_sidecar(path);
            return None;
        }
        self.mem[path] = (True, code, key);
        return (True, code);
    }

    def record(path: str, demoted: bool, code: str) {
        if not demoted {
            self.mem.pop(path, None);
            _remove_demotion_sidecar(path);
            return;
        }
        key = _file_key(path);
        if key is None {
            return;
        }
        self.mem[path] = (True, code, key);
        sidecar = _demotion_sidecar(path);
        if sidecar is None {
            return;
        }
        import from jaclang.jac0core.cachefs { atomic_publish }
        try {
            atomic_publish(sidecar, f"{key[0]} {key[1]} {code}\n".encode());
        } except OSError {
            ;
        }
    }

    def reset {
        self.mem.clear();
    }

    def _load(path: str) -> (tuple | None) {
        sidecar = _demotion_sidecar(path);
        if sidecar is None {
            return None;
        }
        try {
            with open(sidecar, "r", encoding="utf-8") as f {
                parts = f.read().split();
            }
            if len(parts) < 2 {
                return None;
            }
            return (
                (int(parts[0]), int(parts[1])),
                parts[2] if len(parts) > 2 else ""
            );
        } except Exception {
            return None;
        }
    }
}


glob na_verdicts: NaVerdictStore = NaVerdictStore();


def _is_demoted_native(path: str) -> bool {
    verdict = na_verdicts.lookup(path);
    return verdict is not None and verdict[0];
}


def _demoted_native_code(path: str) -> str {
    verdict = na_verdicts.lookup(path);
    if verdict is None or not verdict[0] {
        return "";
    }
    return verdict[1];
}


def _mark_demoted_native(path: str, code: str = "") {
    na_verdicts.record(path, True, code);
}


def _clear_demoted_native(path: str) {
    na_verdicts.record(path, False, "");
}


def effective_pin_for(source_path: str, element_name: str) -> str {
    pin = config_pin_for(source_path, element_name);
    if pin == 'native' and _is_demoted_native(os.path.realpath(source_path)) {
        return '';
    }
    return pin;
}


def effective_module_pin(source_path: str) -> str {
    return effective_pin_for(source_path, '');
}


glob _kind_cache: dict[str, tuple[tuple, str]] = {},
     _kind_chain_cache: dict[str, list[str]] = {},
     _kind_probe: dict = {"active": False};


def _enclosing_project_root(root_dir: str) -> str {
    parent = os.path.dirname(os.path.realpath(root_dir));
    if not parent or parent == os.path.realpath(root_dir) {
        return '';
    }
    outer = find_jac_project_root(parent);
    if not outer or os.path.realpath(outer) == os.path.realpath(root_dir) {
        return '';
    }
    return outer;
}


def _declared_project_kind(root_dir: str) -> str {
    import tomllib;
    try {
        with open(os.path.join(root_dir, "jac.toml"), "rb") as f {
            doc = tomllib.load(f);
        }
        return str(doc.get("project", {}).get("kind", "") or "");
    } except Exception {
        return '';
    }
}


def _project_kind_chain(root_dir: str) -> list[str] {
    cached = _kind_chain_cache.get(root_dir);
    if cached is not None {
        return cached;
    }
    chain: list[str] = [];
    cur = root_dir;
    while cur {
        chain.append(cur);
        cur = _enclosing_project_root(cur);
    }
    _kind_chain_cache[root_dir] = chain;
    return chain;
}


def _load_project_kind(root_dir: str) -> str {
    chain = _project_kind_chain(root_dir);
    stamps: list[float] = [];
    for d in chain {
        try {
            stamps.append(os.path.getmtime(os.path.join(d, "jac.toml")));
        } except OSError {
            return '';
        }
    }
    stamp = tuple(stamps);
    cached = _kind_cache.get(root_dir);
    if cached is not None and cached[0] == stamp {
        return cached[1];
    }
    kind = '';
    for d in chain {
        kind = _declared_project_kind(d);
        if kind {
            break;
        }
    }
    _kind_cache[root_dir] = (stamp, kind);
    return kind;
}


def config_project_kind(source_path: str) -> str {
    if not source_path {
        return '';
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return '';
    }
    return _load_project_kind(root_dir);
}


def config_kind_space(source_path: str) -> str {
    kind = config_project_kind(source_path);
    if not kind or _kind_probe["active"] {
        return '';
    }
    _kind_probe["active"] = True;
    try {
        import from jaclang.project.kinds { kind_spec }
        spec = kind_spec(kind);
        return spec.codespace if spec is not None else '';
    } except Exception {
        return '';
    } finally {
        _kind_probe["active"] = False;
    }
}


def pins_digest(source_path: str) -> str {
    pins = config_pins_for(source_path);
    if not pins {
        return '';
    }
    return json.dumps(pins, sort_keys=True);
}

glob _npm_deps_cache: dict[str, tuple[float, set[str]]] = {};


def npm_dependency_names(source_path: str) -> set[str] {
    if not source_path {
        return set();
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return set();
    }
    toml_path = os.path.join(root_dir, "jac.toml");
    try {
        mtime = os.path.getmtime(toml_path);
    } except OSError {
        return set();
    }
    cached = _npm_deps_cache.get(root_dir);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    import tomllib;
    try {
        with open(toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
    } except Exception {
        return set();
    }
    deps = doc.get("dependencies", {});
    npm = deps.get("npm", {}) if isinstance(deps, dict) else {};
    names: set[str] = set();
    if isinstance(npm, dict) {
        for k in npm {
            key = str(k);
            if key == "dev" {
                continue;
            }
            names.add(key);
        }
        dev = npm.get("dev", {});
        if isinstance(dev, dict) {
            for k in dev {
                names.add(str(k));
            }
        }
    }
    _npm_deps_cache[root_dir] = (mtime, names);
    return names;
}

glob _framework_cache: dict[str, tuple[float, str]] = {};


def client_framework(source_path: str) -> str {
    if not source_path {
        return "react";
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return "react";
    }
    toml_path = os.path.join(root_dir, "jac.toml");
    try {
        mtime = os.path.getmtime(toml_path);
    } except OSError {
        return "react";
    }
    cached = _framework_cache.get(root_dir);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    import tomllib;
    fw = "react";
    try {
        with open(toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
        client = doc.get("client", {});
        if isinstance(client, dict) {
            fw = str(client.get("framework", "react"));
        }
    } except Exception {
        fw = "react";
    }
    _framework_cache[root_dir] = (mtime, fw);
    return fw;
}
