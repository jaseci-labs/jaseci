"""GraphMend entry-point resolution on plain Python (.py) source files.

Real models are rarely decorated: `torch.compile(model)` lives at a call site
and the breaks sit in undecorated methods. Entry-point analysis resolves the
wrapped function or class through the symbol table, so those methods count as
in scope; a module imported under `--graphmend-scope` is one whole compiled
region with no local entry point at all. The .py front-end (PyastBuildPass)
produces UniIR whose nodes unparse differently from .jac-origin nodes, so
resolution must match structurally; these tests guard
`jac run model.py --graphmend` and the scoped-import path."""
import ast;
import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "graphmend"
     );

"""A Python model wrapped at a call site through a variable, written to a temp
file at test time rather than checked in as a .py fixture: the repository does
not accept new Python files, and the point of the fixture is only that
GraphMend ingests .py source, which a generated file exercises just as well."""
glob PY_CALLSITE_SRC = '''
import torch


class MyModel(torch.nn.Module):
    def forward(self, x):
        x = torch.relu(x)
        if x.sum() > 0:
            return x * 2.0
        else:
            return x * 3.0


model = MyModel()
compiled = torch.compile(model)
''';

"""Write the generated .py model to a temp file, compile it, and return its
generated Python source."""
def _pysrc(gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "py_callsite_module.py");
        with open(path, "w") as fh {
            fh.write(PY_CALLSITE_SRC);
        }
        prog = JacProgram();
        mod = prog.compile(
            file_path=path, options=CompileOptions(graphmend=gm, type_check=False)
        );
        pa = mod.gen.py_ast;
        mod_ast = pa[0] if isinstance(pa, list) else pa;
        return ast.unparse(mod_ast);
    }
}

"""Compile a checked-in fixture, optionally as one whole compiled region
(--graphmend-scope semantics)."""
def _fixture_src(name: str, scoped: bool) -> str {
    prog = JacProgram();
    prog.graphmend_scoped_compile = scoped;
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

test "py: torch.compile(model) call site tags the wrapped class methods" {
    # The entry point is the call site (resolved through `model = MyModel()`),
    # not a decorator; the undecorated forward method's data-dependent branch
    # must still be rewritten.
    src = _pysrc(True);
    assert "torch.where(" in src;
    assert "if x.sum() > 0" not in src;
}

test "py: call-site wrapped model untouched when graphmend disabled" {
    src = _pysrc(False);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0" in src;
}

test "scoped: a helper defers to the caller's region instead of flushing" {
    # Cross-function deferral is a whole-module-region property. In entry-file
    # mode the detect pass only tags calls inside the torch.compile entry, so a
    # helper's print is not a candidate in the first place.
    src = _fixture_src("se_in_helper.jac", True);
    # the helper buffers...
    assert "__jac_se_emit__(print," in src;
    # ...but emits NO flush of its own -- that would split the caller's graph
    assert "__jac_se_flush__()" not in src;
    # ...and the compiled entry carries the guard that drains it, even though
    # the entry holds no side-effect call itself.
    assert "@__jac_se_guard__" in src;
    assert src.index("@__jac_se_guard__") < src.index("@torch.compile");
}

test "entry-file compile reaches the helper through the compiled entry" {
    # Dynamo inlines the helper into the decorated entry's graph, so the
    # reachability closure covers it without a scope: the helper's print
    # buffers and the entry's boundary guard drains it.
    src = _fixture_src("se_in_helper.jac", False);
    assert "__jac_se_emit__(print," in src;
    assert "__jac_se_flush__()" not in src;
    assert "@__jac_se_guard__" in src;
}

"""Write a generated .py source to a temp file and compile it as one whole
compiled region (--graphmend-scope semantics for an imported module)."""
def _py_scoped_src(py_src: str, name: str) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, name);
        with open(path, "w") as fh {
            fh.write(py_src);
        }
        prog = JacProgram();
        prog.graphmend_scoped_compile = True;
        mod = prog.compile(
            file_path=path, options=CompileOptions(graphmend=True, type_check=False)
        );
        pa = mod.gen.py_ast;
        mod_ast = pa[0] if isinstance(pa, list) else pa;
        return ast.unparse(mod_ast);
    }
}

glob PY_SCOPED_GUARD_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x, mask):
        x = torch.relu(x)
        if not mask.all():
            raise ValueError("scoped mask must be all true")
        return torch.sin(x)
''';

test "scoped: a validation guard lowers with the exception marker" {
    # A scoped module has no decorated function to carry @__jac_trap_guard__;
    # the boundary is attached at the entry script's torch.compile call site
    # instead, so the guard lowers with the marker and NO local decorator.
    src = _py_scoped_src(PY_SCOPED_GUARD_SRC, "scoped_guard.py");
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]scoped mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "raise ValueError" not in src;
    assert "@__jac_trap_guard__" not in src;
}

glob PY_ENTRY_WRAP_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x):
        return torch.relu(x)


model = torch.compile(Net())
''';

test "scoped: the entry wrap gets the trap boundary attach" {
    # When a scope is configured, every torch.compile call-site assignment in
    # the entry gets the boundary attached; for an nn.Module the runtime wraps
    # `forward` in place, so the async assert failure of any scoped guard is
    # restored to its original exception at the outermost eager frame.
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "entry_wrap.py");
        with open(path, "w") as fh {
            fh.write(PY_ENTRY_WRAP_SRC);
        }
        prog = JacProgram();
        prog.graphmend_scope = ["scopedmodel"];
        mod = prog.compile(
            file_path=path, options=CompileOptions(graphmend=True, type_check=False)
        );
        pa = mod.gen.py_ast;
        src = ast.unparse(pa[0] if isinstance(pa, list) else pa);
    }
    assert "model = __jac_trap_guard__(model)" in src;
    # the helper import must be emitted by the preamble
    assert any(
        [
            ("from jaclang" in line) and ("__jac_trap_guard__" in line)
            for line in src.splitlines()
        ]
    );
}

"""The discriminant validation guard from transformers v4.52.4
`modeling_vits._rational_quadratic_spline` (Apache-2.0), a real-model [Trap]
case, vendored so the evidence does not rot with transformers releases
(5.x rewrote this guard into a torch-compilable check upstream). The message is
reduced to a literal: non-literal messages decline, because formatting a
tensor inside the graph would itself force a break. The forward caller
mirrors the real file, where the spline is forward-reachable."""
glob PY_VITS_GUARD_SRC = '''
import torch


def rational_quadratic_spline_root(a, b, c):
    discriminant = b.pow(2) - 4 * a * c
    if not (discriminant >= 0).all():
        raise RuntimeError("invalid discriminant in rational quadratic spline")
    return (2 * c) / (-b - torch.sqrt(discriminant))


class Spline(torch.nn.Module):
    def forward(self, a, b, c):
        return rational_quadratic_spline_root(a, b, c)
''',
     PY_VITS_GUARD_FSTRING_SRC = '''
import torch


def rational_quadratic_spline_root(a, b, c):
    discriminant = b.pow(2) - 4 * a * c
    if not (discriminant >= 0).all():
        raise RuntimeError(f"invalid discriminant {discriminant}")
    return (2 * c) / (-b - torch.sqrt(discriminant))


class Spline(torch.nn.Module):
    def forward(self, a, b, c):
        return rational_quadratic_spline_root(a, b, c)
''';

test "scoped: the real VITS guard shape lowers under a literal message" {
    src = _py_scoped_src(PY_VITS_GUARD_SRC, "vits_guard.py");
    assert (
        "torch._assert_async((discriminant >= 0).all(), "
        "'[[GM-TRAP RuntimeError]]invalid discriminant in rational quadratic "
        "spline[[/GM-TRAP]]')"
        in src
    );
    assert "if not (discriminant >= 0).all():" not in src;
}

test "scoped: a guard with a non-literal message is declined" {
    # The verbatim upstream form carries an f-string message; folding it into
    # the assert would evaluate the tensor format on every call inside the
    # graph, so the lowering declines and the break is left intact.
    src = _py_scoped_src(PY_VITS_GUARD_FSTRING_SRC, "vits_guard_fstring.py");
    assert "torch._assert_async(" not in src;
    assert "if not (discriminant >= 0).all():" in src;
}

glob PY_SCOPED_MIXED_SRC = '''
import torch


def reachable_helper(x):
    print("IN-HELPER", x)
    return x * 2


def unreachable_util(x):
    print("UTIL", x)
    if x.sum() > 0:
        y = x * 2
    else:
        y = x * 3
    return y


class Net(torch.nn.Module):
    def forward(self, x):
        return reachable_helper(torch.relu(x))
''';

test "scoped: only forward-reachable code is transformed" {
    # The compiled region is the reachability closure over the call graph
    # (what Dynamo would inline), not the whole module: a utility no forward
    # reaches keeps its print and its data-dependent branch untouched.
    src = _py_scoped_src(PY_SCOPED_MIXED_SRC, "scoped_mixed.py");
    assert "__jac_se_emit__(print," in src;
    assert "print('UTIL', x)" in src;
    assert "torch.where(" not in src;
}
