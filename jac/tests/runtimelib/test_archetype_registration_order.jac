"""Archetype registration must not depend on module import order.

`Archetype._subclass_hooks` is only consulted by `__init_subclass__`, so a hook
installed at time T used to see nothing that existed before T. When the
serializer's registration hook landed after an application's node/edge classes
were created, those classes were never registered and every read of their
anchors was refused and dropped, which reads back to the caller as "no such
record". These tests pin both halves of the fix: hook installation back-fills
the existing subclass tree, and resolution falls back to the class's own module
so an unregistered-but-resolvable archetype is never refused.
"""

import importlib;
import os;
import shutil;
import sys;
import from tempfile { mkdtemp }
import from types { ModuleType }
import from uuid { uuid4 }
import from jaclang.jac0core.archetype { Archetype, NodeAnchor, Root }
import from jaclang.runtimelib.serializer { Serializer }


obj _EarlyNode(Root) {
    has name: str = "";
}


obj _EarlyChild(_EarlyNode) {
    has extra: int = 0;
}


def _key(cls: type) -> str {
    return f"{cls.__module__}.{cls.__name__}";
}


def _publish_home_module -> (object | None) {
    # The jac test collector imports a test file twice, so the module object
    # sitting in sys.modules under this file's name is not the one whose
    # classes are running here, and resolution would hand back a same-named
    # twin. Publish the live classes under their own module name for the
    # duration of a test, which is what an ordinary application module that
    # defines archetypes looks like to the runtime.
    shim = ModuleType(_EarlyNode.__module__);
    setattr(shim, '_EarlyNode', _EarlyNode);
    setattr(shim, '_EarlyChild', _EarlyChild);
    previous = sys.modules.get(_EarlyNode.__module__);
    sys.modules[_EarlyNode.__module__] = shim;
    return previous;
}


def _restore_home_module(previous: (object | None)) -> None {
    if previous is None {
        sys.modules.pop(_EarlyNode.__module__, None);
    } else {
        sys.modules[_EarlyNode.__module__] = previous;
    }
}


def _anchor_blob(arch: object) -> dict {
    raw = Serializer.serialize(arch, include_type=True);
    return {
        '__type__': 'NodeAnchor',
        '__module__': 'jaclang.jac0core.archetype',
        'id': str(uuid4()),
        'root': None,
        'persistent': False,
        'access': {'all': -1, 'roots': {'anchors': {}}},
        'archetype': raw,
        'edges': [],
        'version': 0
    };
}


# --- Back-fill on hook install ---------------------------------------------
test "installing a hook back-fills archetype classes that already exist" {
    seen: list = [];

    def recorder(cls: type) -> None {
        seen.append(_key(cls));
    }
    Archetype.install_subclass_hook(recorder);
    try {
        # Both classes above were created long before this hook existed.
        assert _key(_EarlyNode) in seen , (
            f"hook did not back-fill a pre-existing class: {len(seen)} seen"
        );
        # ...including one that is a subclass of a subclass (transitive walk).
        assert _key(_EarlyChild) in seen , "back-fill did not walk the whole tree";
        # Framework base classes are skipped, exactly as __init_subclass__ does.
        assert _key(Root) not in seen , "__jac_base__ classes must stay excluded";
    } finally {
        Archetype._subclass_hooks.remove(recorder);
    }
}


test "installing the same hook twice neither duplicates it nor re-runs it" {
    calls: list = [];

    def recorder(cls: type) -> None {
        calls.append(cls);
    }
    Archetype.install_subclass_hook(recorder);
    first_pass = len(calls);
    hook_count = len(Archetype._subclass_hooks);
    Archetype.install_subclass_hook(recorder);
    try {
        assert first_pass > 0 , "back-fill saw no existing archetype classes";
        assert len(calls) == first_pass , "re-installing a hook re-ran the back-fill";
        assert len(Archetype._subclass_hooks) == hook_count , (
            "re-installing a hook appended a duplicate"
        );
    } finally {
        Archetype._subclass_hooks.remove(recorder);
    }
}


test "an installed hook still fires for classes created afterwards" {
    seen: list = [];

    def recorder(cls: type) -> None {
        seen.append(cls.__name__);
    }
    Archetype.install_subclass_hook(recorder);
    try {
        late = type("_LateNode", (_EarlyNode, ), {'__annotations__': {}});
        assert "_LateNode" in seen , (
            "install_subclass_hook broke the forward path of __init_subclass__"
        );
        assert late is not None;
    } finally {
        Archetype._subclass_hooks.remove(recorder);
    }
}


# --- Order-independent resolution ------------------------------------------
test "an anchor whose class is not registered round-trips instead of dropping" {
    original = _EarlyNode(name="visible");
    blob = _anchor_blob(original);
    key = _key(_EarlyNode);
    # Exactly the state a class lands in when it is created before the
    # serializer's hook is installed: the class object exists, the registry
    # has never heard of it.
    saved = Serializer._registry.pop(key, None);
    previous_home = _publish_home_module();
    Serializer._reset_warn_cache();
    try {
        anchor = Serializer.deserialize(blob);
        assert anchor is not None , (
            "a resolvable archetype was refused and its anchor dropped"
        );
        assert isinstance(anchor, NodeAnchor);
        arch = anchor.archetype;
        assert type(arch) is _EarlyNode , f"wrong class rehydrated: {type(arch)}";
        assert getattr(arch, 'name') == "visible";
        # Resolution self-heals the registry, so the next read is a plain hit.
        assert Serializer._registry.get(key) is _EarlyNode , (
            "resolved class was not registered for subsequent reads"
        );
    } finally {
        _restore_home_module(previous_home);
        if saved is not None {
            Serializer._registry[key] = saved;
        }
        Serializer._reset_warn_cache();
    }
}


test "_get_class resolves an unregistered archetype from its own module" {
    key = _key(_EarlyChild);
    saved = Serializer._registry.pop(key, None);
    previous_home = _publish_home_module();
    Serializer._reset_warn_cache();
    try {
        resolved = Serializer._get_class(_EarlyChild.__module__, "_EarlyChild");
        assert resolved is _EarlyChild , (
            f"resolution refused a live class: {resolved}"
        );
    } finally {
        _restore_home_module(previous_home);
        if saved is not None {
            Serializer._registry[key] = saved;
        }
        Serializer._reset_warn_cache();
    }
}


# --- The allowlist still refuses everything that is not an archetype -------
test "resolution refuses names that are not archetype classes" {
    Serializer._reset_warn_cache();
    try {
        assert Serializer._get_class("os", "system") is None , (
            "callables must never resolve"
        );
        assert Serializer._get_class("builtins", "dict") is None , (
            "non-archetype types must never resolve"
        );
        # Every Jac `obj` is an Archetype subclass, so the runtime's own
        # internals are archetypes too. Auto-registration deliberately skips
        # `jaclang.*` (except `jaclang.scale.*`) and resolution honors the same
        # line: a runtime-internal class resolves only if it was registered
        # explicitly, exactly as before this fallback existed.
        assert not Serializer.is_auto_registered_module("jaclang.runtimelib.serializer");
        assert Serializer.is_auto_registered_module("jaclang.scale.something");
        assert Serializer.is_auto_registered_module("myapp.nodes");
        assert Serializer._get_class(
            "jaclang.runtimelib.serializer", "Serializer"
        ) is None , "runtime-internal archetypes must not resolve implicitly";
        assert Serializer._get_class("os", "does_not_exist") is None;
        assert Serializer._get_class("definitely.not", "Present") is None;
    } finally {
        Serializer._reset_warn_cache();
    }
}


test "deserialize still refuses a non-archetype class named in the payload" {
    Serializer._reset_warn_cache();
    try {
        assert Serializer.deserialize(
            {'__type__': 'dict', '__module__': 'builtins', 'a': 1}
        ) is None;
    } finally {
        Serializer._reset_warn_cache();
    }
}


test "resolution never imports a module whose package the process never loaded" {
    tmp = mkdtemp();
    mod_name = "jac8049_untrusted";
    marker = "JAC_8049_UNTRUSTED_RAN";
    with open(os.path.join(tmp, f"{mod_name}.py"), "w") as fh {
        fh.write(f"import os\nos.environ[{marker!r}] = '1'\n");
    }
    sys.path.insert(0, tmp);
    Serializer._reset_warn_cache();
    try {
        assert mod_name not in sys.modules;
        assert Serializer._get_class(mod_name, "Ghost") is None;
        assert mod_name not in sys.modules , (
            "resolution imported a module the payload merely named"
        );
        assert os.environ.get(marker) is None , (
            "resolution executed module-level code from an untrusted name"
        );
    } finally {
        if tmp in sys.path {
            sys.path.remove(tmp);
        }
        os.environ.pop(marker, None);
        shutil.rmtree(tmp, ignore_errors=True);
        Serializer._reset_warn_cache();
    }
}


test "resolution does load a submodule of a package the process already uses" {
    # The other side of the same gate: a lazily loaded submodule of a package
    # the application itself imported is inside the trust boundary, so a stored
    # anchor whose class lives there is still resolvable.
    tmp = mkdtemp();
    pkg_name = "jac8049_app";
    marker = "JAC_8049_APP_SUBMODULE_RAN";
    pkg_dir = os.path.join(tmp, pkg_name);
    os.makedirs(pkg_dir);
    with open(os.path.join(pkg_dir, "__init__.py"), "w") as fh {
        fh.write("");
    }
    with open(os.path.join(pkg_dir, "nodes.py"), "w") as fh {
        fh.write(f"import os\nos.environ[{marker!r}] = '1'\n");
    }
    sys.path.insert(0, tmp);
    Serializer._reset_warn_cache();
    try {
        importlib.import_module(pkg_name);
        assert os.environ.get(marker) is None , "submodule loaded too early";
        # No such class, so resolution still refuses, but the gate let the
        # import through because the top-level package was already loaded.
        assert Serializer._get_class(f"{pkg_name}.nodes", "Ghost") is None;
        assert os.environ.get(marker) == "1" , (
            "resolution did not load the submodule of an already-loaded package"
        );
    } finally {
        if tmp in sys.path {
            sys.path.remove(tmp);
        }
        for loaded in list(sys.modules.keys()) {
            if loaded == pkg_name or loaded.startswith(f"{pkg_name}.") {
                sys.modules.pop(loaded, None);
            }
        }
        os.environ.pop(marker, None);
        shutil.rmtree(tmp, ignore_errors=True);
        Serializer._reset_warn_cache();
    }
}
