"""A comptime fold keys on the content of the module it folded from.

A module that folds a value out of another module at compile time bakes
that value into its own artifact, so its cache must stop being valid the
moment the producing module's content moves -- transitively, through
whatever the comptime evaluation actually read. The ordinary
interface-hash cutoff cannot see this: a producer whose comptime value
changed still exports the same interface.

Every test builds its own throwaway project in a tempdir, whose cache
lands in <srcdir>/.jac/cache, so tests are isolated from each other and
from the user's real cache.
"""

import os;
import tempfile;
import time;
import from jaclang.compiler.driver.compiler { JacCompiler }
import from jaclang.compiler.driver.jir {
    SEC_CTDEPS,
    get_module_cache_path,
    read_section_bytes
}
import from jaclang.compiler.driver.program { JacProgram }
import from types { CodeType }

glob SPEC_SRC: str = "obj Spec {\n    has name: str,\n        help: str;\n}\n",
     OTHER_SRC: str = "def helper -> int {\n    return 1;\n}\n",
     OTHER_SRC_EDIT: str = "def helper -> int {\n    return 2;\n}\n",
     CONSUMER_SRC: str = (
         "import from specmod { Spec }\n"
         "import from othermod { helper }\n\n"
         "comptime import from prodmod { SPEC }\n\n"
         "comptime FOLDED: str = SPEC.help;\n\n"
         "with entry {\n"
         "    print(FOLDED);\n"
         "    print(helper());\n"
         "}\n"
     );

def _base_src(text: str) -> str {
    return f"comptime BASE: str = \"{text}\";\n";
}

def _prod_src(text: str) -> str {
    return (
        "import from specmod { Spec }\n\n"
        "comptime import from basemod { BASE }\n\n"
        f"comptime SPEC: Spec = Spec(name=\"create\", help=BASE + \"{text}\");\n"
    );
}

def _write(path: str, body: str, backdate: bool = False) {
    with open(path, "w") as fh {
        fh.write(body);
    }
    if backdate {
        past = time.time() - 5;
        os.utime(path, (past, past));
    }
}

def _project -> dict[str, str] {
    tmp = tempfile.mkdtemp();
    paths: dict[str, str] = {};
    for name in ("specmod", "othermod", "basemod", "prodmod", "consmod") {
        paths[name] = os.path.realpath(os.path.join(tmp, f"{name}.jac"));
    }
    _write(paths["specmod"], SPEC_SRC, backdate=True);
    _write(paths["othermod"], OTHER_SRC, backdate=True);
    _write(paths["basemod"], _base_src("base one"), backdate=True);
    _write(paths["prodmod"], _prod_src(" help"), backdate=True);
    _write(paths["consmod"], CONSUMER_SRC, backdate=True);
    return paths;
}

def _consts(code: CodeType) -> list[str] {
    out: list[str] = [];
    for c in code.co_consts {
        if isinstance(c, str) {
            out.append(c);
        } elif hasattr(c, "co_consts") {
            out.extend(_consts(c));
        }
    }
    return out;
}

def _folded(path: str) -> list[str] {
    compiler = JacCompiler();
    prog = JacProgram();
    code = compiler.get_bytecode(path, prog);
    assert code is not None , (
        f"no bytecode for {path}: " f"{[a.pretty_print() for a in prog.errors_had]}"
    );
    return _consts(code);
}

test "a direct comptime producer edit is observed without manual invalidation" {
    paths = _project();
    cold = _folded(paths["consmod"]);
    assert "base one help" in cold , f"cold compile did not fold: {cold}";
    _write(paths["prodmod"], _prod_src(" HELP"));
    warm = _folded(paths["consmod"]);
    assert "base one HELP" in warm , (
        f"the consumer served a stale fold after its producer changed: {warm}"
    );
}

test "a transitive comptime producer edit is observed too" {
    paths = _project();
    cold = _folded(paths["consmod"]);
    assert "base one help" in cold , f"cold compile did not fold: {cold}";
    _write(paths["basemod"], _base_src("base two"));
    warm = _folded(paths["consmod"]);
    assert "base two help" in warm , (
        "the consumer served a stale fold after a transitive producer "
        f"changed: {warm}"
    );
}

test "the comptime producers are recorded on the consumer's cache" {
    paths = _project();
    _folded(paths["consmod"]);
    data = get_module_cache_path(paths["consmod"]).read_bytes();
    raw = read_section_bytes(data, SEC_CTDEPS);
    assert raw is not None , "the consumer recorded no comptime dependencies";
    text = raw.decode("utf-8");
    assert paths["prodmod"] in text , (
        f"the direct comptime producer is missing from SEC_CTDEPS: {text}"
    );
    assert paths["basemod"] in text , (
        f"the transitive comptime producer is missing from SEC_CTDEPS: {text}"
    );
}

test "an edit to a module no fold read leaves the consumer's cache alone" {
    paths = _project();
    _folded(paths["consmod"]);
    cache = get_module_cache_path(paths["consmod"]);
    stamp = os.path.getmtime(cache);
    _write(paths["othermod"], OTHER_SRC_EDIT);
    _folded(paths["consmod"]);
    assert os.path.getmtime(cache) == stamp , (
        "a body-only edit to an ordinary dependency rebuilt the consumer"
    );
}

test "a fold still resolves when the producer is served from its cache" {
    paths = _project();
    cold = _folded(paths["consmod"]);
    assert "base one help" in cold , f"cold compile did not fold: {cold}";
    get_module_cache_path(paths["consmod"]).unlink();
    again = _folded(paths["consmod"]);
    assert "base one help" in again , (
        f"the fold broke once the producer came back from cache: {again}"
    );
}
