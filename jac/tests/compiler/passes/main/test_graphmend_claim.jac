"""Automatic import claiming: GraphMend reaches imported model code with no
user-supplied module scope.

A module seeds GraphMend when it imports torch and either wraps something with
`torch.compile` or defines a `forward` whose class provably binds a torch Module
base through its import bindings. Claiming then follows the import graph out of
a seed: a library module reached only through its importer joins the compiled
region even though it holds no entry of its own.

Three boundaries keep the closure honest, and each is measured here: imports
guarded by `if TYPE_CHECKING:` never extend it, the closure never leaves the
seeding module's top-level package, and a class that merely spells `forward`
without binding a torch Module base is not a seed.

Fixtures are generated into a temp tree at test time; the repository does not
accept new Python files."""
import ast;
import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob SEED_SRC = '''
import torch

from .util import reachable_helper


class Net(torch.nn.Module):
    def forward(self, x):
        return reachable_helper(torch.relu(x))
''',
     DEP_SRC = '''
import torch


def reachable_helper(x):
    print("IN-HELPER", x)
    return x * 2
''';

"""Write `name` under `tmp` and return its absolute path."""
def _write(tmp: str, name: str, src: str) -> str {
    path = os.path.join(tmp, name);
    os.makedirs(os.path.dirname(path), exist_ok=True);
    with open(path, "w") as fh {
        fh.write(src);
    }
    return path;
}

"""Compile `path` in `prog` and return its generated Python source."""
def _src(prog: JacProgram, path: str) -> str {
    prog.invalidate_module(path);
    mod = prog.compile(
        file_path=path, options=CompileOptions(graphmend=True, type_check=False)
    );
    pa = mod.gen.py_ast;
    return ast.unparse(pa[0] if isinstance(pa, list) else pa);
}

"""Lay out a package whose seed module imports one in-package helper."""
def _seed_pkg(tmp: str) -> tuple[str, str] {
    _write(tmp, os.path.join("pkg", "__init__.py"), "");
    seed = _write(tmp, os.path.join("pkg", "model.py"), SEED_SRC);
    dep = _write(tmp, os.path.join("pkg", "util.py"), DEP_SRC);
    return (seed, dep);
}

test "an importer claims its dependency with no scope configured" {
    # The dependency holds no torch.compile entry and no forward at all: it is
    # reached only because the seed that imports it is compiled first, exactly
    # the shape of a library module pulled in by a model file.
    with tempfile.TemporaryDirectory() as tmp {
        (seed, dep) = _seed_pkg(tmp);
        prog = JacProgram();
        seed_src = _src(prog, seed);
        assert os.path.realpath(seed) in prog.graphmend_claimed , (
            "the seed must claim itself"
        );
        assert os.path.realpath(dep) in prog.graphmend_claimed , (
            "an eager in-package import of a seed must be claimed"
        );
        dep_src = _src(prog, dep);
        assert "__jac_se_emit__(print," in dep_src , (
            "the claimed dependency was not transformed"
        );
    }
}

glob TC_SEED_SRC = '''
import torch

from typing import TYPE_CHECKING

from .eager import eager_helper

if TYPE_CHECKING:
    from .typeonly import TypeOnly


class Net(torch.nn.Module):
    def forward(self, x):
        return eager_helper(torch.relu(x))
''',
     PLAIN_DEP_SRC = '''
import torch


def eager_helper(x):
    print("EAGER", x)
    return x * 2
''',
     TYPE_ONLY_SRC = '''
import torch


class TypeOnly:
    pass
''';

test "a type-checking guarded import does not extend the claim" {
    # `if TYPE_CHECKING:` bodies never run, so following them would drag in the
    # whole package through the type-only edges its hub modules carry.
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, os.path.join("pkg", "__init__.py"), "");
        seed = _write(tmp, os.path.join("pkg", "model.py"), TC_SEED_SRC);
        eager = _write(tmp, os.path.join("pkg", "eager.py"), PLAIN_DEP_SRC);
        type_only = _write(tmp, os.path.join("pkg", "typeonly.py"), TYPE_ONLY_SRC);
        prog = JacProgram();
        _src(prog, seed);
        assert os.path.realpath(eager) in prog.graphmend_claimed , (
            "an eager import must still be claimed"
        );
        assert os.path.realpath(type_only) not in prog.graphmend_claimed , (
            "a TYPE_CHECKING-guarded import must not extend the claim"
        );
    }
}

glob OUTSIDE_SEED_SRC = '''
import torch

import otherpkg.thing

from .util import reachable_helper


class Net(torch.nn.Module):
    def forward(self, x):
        return reachable_helper(torch.relu(x))
''',
     OUTSIDE_SRC = '''
def thing(x):
    print("OUTSIDE", x)
    return x
''';

test "the claim stops at the seeding module's top level package" {
    # Model packages import third-party packages at module level; without a
    # package boundary the closure would follow every one of them.
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, os.path.join("pkg", "__init__.py"), "");
        seed = _write(tmp, os.path.join("pkg", "model.py"), OUTSIDE_SEED_SRC);
        _write(tmp, os.path.join("pkg", "util.py"), DEP_SRC);
        _write(tmp, os.path.join("otherpkg", "__init__.py"), "");
        outside = _write(tmp, os.path.join("otherpkg", "thing.py"), OUTSIDE_SRC);
        prog = JacProgram();
        _src(prog, seed);
        assert os.path.realpath(outside) not in prog.graphmend_claimed , (
            "the closure must not leave the seeding module's top-level package"
        );
    }
}

glob NOT_A_MODULE_SRC = '''
import torch


class Bookkeeper:
    def forward(self, x):
        if x.sum() > 0:
            y = x * 2.0
        else:
            y = x * 3.0
        return y
''';

test "a plain class with a forward method is not a seed" {
    # The seed proof is the base binding, never the name: an unrelated class
    # that happens to define `forward` must not put its body in a graph.
    with tempfile.TemporaryDirectory() as tmp {
        path = _write(tmp, "bookkeeper.py", NOT_A_MODULE_SRC);
        prog = JacProgram();
        src = _src(prog, path);
        assert os.path.realpath(path) not in prog.graphmend_claimed , (
            "a class that only spells forward must not seed GraphMend"
        );
        assert "torch.where(" not in src;
        assert "if x.sum() > 0" in src;
    }
}

glob GUARD_ENTRY_SRC = '''
import torch

from .checks import verify


class Net(torch.nn.Module):
    def forward(self, x, mask):
        verify(mask)
        return torch.relu(x)
''',
     GUARD_WRAP_ENTRY_SRC = '''
import torch

from .checks import verify


class Net(torch.nn.Module):
    def forward(self, x, mask):
        verify(mask)
        return torch.relu(x)


model = torch.compile(Net())
''',
     GUARD_DEP_SRC = '''
import torch


def verify(mask: torch.Tensor):
    if not mask.all():
        raise ValueError("mask must be all true")
''';

"""Compile a claimed importer, then its guard-holding dependency, and return
the dependency's generated Python source."""
def _guard_pkg_src(tmp: str, entry_src: str) -> str {
    _write(tmp, os.path.join("pkg", "__init__.py"), "");
    entry = _write(tmp, os.path.join("pkg", "entry.py"), entry_src);
    checks = _write(tmp, os.path.join("pkg", "checks.py"), GUARD_DEP_SRC);
    prog = JacProgram();
    _src(prog, entry);
    return _src(prog, checks);
}

test "a guard with no boundary in reach declines instead of marking" {
    # The marker string is the only channel back to the original exception and
    # only the trap boundary decodes it. Nothing in this program is wrapped or
    # decorated, so no boundary exists anywhere and lowering would surface the
    # raw marker text to the caller. The pass must decline.
    with tempfile.TemporaryDirectory() as tmp {
        dep_src = _guard_pkg_src(tmp, GUARD_ENTRY_SRC);
        assert "torch._assert_async(" not in dep_src , (
            "a guard with no boundary must not emit an undecodable marker"
        );
        assert "raise ValueError" in dep_src;
        assert "GM-TRAP" not in dep_src;
    }
}

test "a guard lowers once the importer wraps the model at a call site" {
    # The importer's `torch.compile` assignment gets the boundary attached, so
    # the guard the wrapped entry reaches has something that decodes its marker
    # at the outermost eager frame, and it becomes graph-native.
    with tempfile.TemporaryDirectory() as tmp {
        dep_src = _guard_pkg_src(tmp, GUARD_WRAP_ENTRY_SRC);
        assert (
            "torch._assert_async(mask.all(), "
            "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
            in dep_src
        );
        assert "raise ValueError" not in dep_src;
    }
}

test "the run manifest carries no graphmend scope argument" {
    import from jaclang.cli.manifest { get_command_meta }
    meta = get_command_meta("run");
    assert meta is not None;
    by_name = {a.name: a for a in meta.args};
    assert "graphmend_scope" not in by_name , (
        "claiming is automatic; there is no scope flag to configure"
    );
    assert by_name["graphmend_disable"].config_key == "run.graphmend_disable";
}
