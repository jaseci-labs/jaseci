"""Config changes invalidate the JIR module cache (#8073).

``compute_module_key`` folds every codegen-relevant input into the cache key --
source content, annex content, schema, versions, and the config-derived inputs
(``[placement.pins]``, project kind, service cut, codegen flags). These tests
pin that ``is_module_cache_valid`` actually consults that key, rather than
short-circuiting on file mtimes: editing ``jac.toml`` never touches the ``.jac``
source mtime, so an mtime-only check silently serves the previous placement and
the entry cannot be rewritten, leaving ``rm -rf .jac/cache`` as the only cure.

The config half is compared as a value rather than inferred from timestamps
because part of it (``JAC_OPT_LEVEL``, ``JAC_NATIVE_TARGET`` and friends) comes
from the environment, where there is no file to stat.
"""

import os;
import tempfile;
import from jaclang.jac0core.jir {
    get_module_cache_path,
    is_module_cache_valid,
    jir_matches_source,
    module_cache_key,
    write_module_jir_cache
}
import from jaclang.jac0core.program { JacProgram }

def _write(path: str, text: str) -> None {
    with open(path, "w") as f {
        f.write(text);
    }
}

def _bump(path: str, ref: str) -> None {
    stamp = os.path.getmtime(ref) + 100.0;
    os.utime(path, (stamp, stamp));
}

def _seed_project(toml_body: str) -> tuple[str, str, any] {
    tmp = tempfile.mkdtemp(prefix="jircache_");
    toml = os.path.join(tmp, "jac.toml");
    src = os.path.join(tmp, "m.jac");
    _write(toml, toml_body);
    _write(src, "def f(x: int) -> int {\n    return x * 2;\n}\n");
    mod = JacProgram().compile(src);
    assert write_module_jir_cache(src, mod) , "expected a fresh cache write";
    cache_path = get_module_cache_path(src);
    assert is_module_cache_valid(src, cache_path) , "fresh entry should be valid";
    return (toml, src, cache_path);
}

glob BASE: str = "[project]\nname = \"probe\"\n";

test "a [placement.pins] change invalidates the cached module" {
    (toml, src, cache_path) = _seed_project(BASE);
    key_before = module_cache_key(src);

    _write(toml, BASE + "\n[placement.pins]\n\"m.f\" = \"server\"\n");
    _bump(toml, str(cache_path));

    assert module_cache_key(src) != key_before , "pins must change the module key";
    assert not jir_matches_source(cache_path.read_bytes(), src) , "stored key must stop matching once pins change";
    assert not is_module_cache_valid(src, cache_path) , "cache must not be served after a [placement.pins] change";
}

test "a [project] kind change invalidates the cached module" {
    (toml, src, cache_path) = _seed_project(BASE);
    key_before = module_cache_key(src);

    _write(toml, "[project]\nname = \"probe\"\nkind = \"js-package\"\n");
    _bump(toml, str(cache_path));

    assert module_cache_key(src) != key_before , "project kind must change the module key";
    assert not is_module_cache_valid(src, cache_path) , "cache must not be served after a [project] kind change";
}

test "an environment-driven codegen change invalidates the cached module" {
    (toml, src, cache_path) = _seed_project(BASE);
    prev = os.environ.get("JAC_OPT_LEVEL", "");
    try {
        os.environ["JAC_OPT_LEVEL"] = "0";
        key_o0 = module_cache_key(src);
        os.environ["JAC_OPT_LEVEL"] = "3";
        assert module_cache_key(src) != key_o0 , "opt level must change the module key";
        assert not is_module_cache_valid(src, cache_path) , "cache must not be served across a codegen flag change";
    } finally {
        if prev {
            os.environ["JAC_OPT_LEVEL"] = prev;
        } else {
            os.environ.pop("JAC_OPT_LEVEL", None);
        }
    }
}

test "a stale entry can be rewritten rather than needing a manual cache wipe" {
    (toml, src, cache_path) = _seed_project(BASE);
    mtime_before = os.path.getmtime(cache_path);

    _write(toml, BASE + "\n[placement.pins]\n\"m.f\" = \"server\"\n");
    _bump(toml, str(cache_path));

    mod = JacProgram().compile(src);
    assert write_module_jir_cache(src, mod) , "a correct recompile must be allowed to overwrite the stale entry";
    assert os.path.getmtime(cache_path) != mtime_before , "entry should be rewritten";
    assert jir_matches_source(cache_path.read_bytes(), src) , "rewritten entry should carry the current module key";
    assert is_module_cache_valid(src, cache_path) , "rewritten entry should be valid";
}

test "an untouched project keeps serving its cached module" {
    (toml, src, cache_path) = _seed_project(BASE);
    assert is_module_cache_valid(src, cache_path) , "unchanged config must stay valid";

    _write(toml, BASE);
    _bump(toml, str(cache_path));
    assert is_module_cache_valid(src, cache_path) , "rewriting jac.toml with identical content must not invalidate";

    os.utime(src, None);
    assert is_module_cache_valid(src, cache_path) , "touching the source without editing it must not invalidate";
}
