"""GraphMend entry-point resolution on plain Python (.py) source files.

Real models are rarely decorated: `torch.compile(model)` lives at a call site
and the breaks sit in undecorated methods. Entry-point analysis resolves the
wrapped function or class through the symbol table, so those methods count as
in scope. The .py front-end (PyastBuildPass) produces UniIR whose nodes
unparse differently from .jac-origin nodes, so resolution must match
structurally; these tests guard `jac run model.py --graphmend`."""
import ast;
import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

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
