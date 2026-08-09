"""Torch-gated integration tests for --graphmend-scope.

Confirm the import-time claim: a plain .py module whose dotted name falls
under the scope is claimed by the Jac meta importer, compiled through the
full GraphMend schedule as one whole compiled region, and executes the
transformed bytecode, while out-of-scope modules (torch itself above all)
are untouched. A validation guard in a scoped module must surface its
ORIGINAL exception through the boundary attached at the entry script's
torch.compile call site.

Skipped automatically when PyTorch is not installed."""
import ast;
import dis;
import importlib;
import os;
import pytest;
import sys;
import tempfile;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.runtime { JacRuntime }

glob PY_SCOPED_NET_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x):
        x = torch.relu(x)
        if x.sum() > 0:
            return x * 2.0
        else:
            return x * 3.0
''';

"""Import torch or skip the calling test."""
def _torch -> any {
    try {
        import torch;
        return torch;
    } except ImportError {
        pytest.skip("torch not installed");
    }
}

test "a package imported under --graphmend-scope is transformed" {
    # The model class lives in an imported module with no local torch.compile
    # (the wrap would be in the entry script); it is reached only because its
    # package is in the graphmend scope. torch (not in scope) must stay
    # untouched.
    torch = _torch();
    prog = JacRuntime.get_program();
    saved_en = prog.graphmend_enabled;
    saved_scope = prog.graphmend_scope;
    with tempfile.TemporaryDirectory() as tmp {
        pkg = os.path.join(tmp, "scopedmodel");
        os.mkdir(pkg);
        with open(os.path.join(pkg, "__init__.py"), "w") as fh {
            fh.write("");
        }
        with open(os.path.join(pkg, "net.py"), "w") as fh {
            fh.write(PY_SCOPED_NET_SRC);
        }
        sys.path.insert(0, tmp);
        try {
            prog.graphmend_enabled = True;
            prog.graphmend_scope = ["scopedmodel"];
            sys.modules.pop("scopedmodel", None);
            sys.modules.pop("scopedmodel.net", None);
            net = importlib.import_module("scopedmodel.net");
            names = [
                i.argval
                for i in dis.get_instructions(net.Net.forward.__code__)
                if isinstance(i.argval, str)
            ];
            assert "where" in names , "imported scoped model was not transformed";
            # torch itself (not in scope) must be unaffected
            assert hasattr(torch, "_dynamo");
        } finally {
            prog.graphmend_enabled = saved_en;
            prog.graphmend_scope = saved_scope;
            sys.path.remove(tmp);
            sys.modules.pop("scopedmodel", None);
            sys.modules.pop("scopedmodel.net", None);
        }
    }
}

glob PY_GUARDED_NET_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x, mask):
        x = torch.relu(x)
        if not mask.all():
            raise ValueError("scoped mask must be all true")
        return torch.sin(x)
''',
     PY_GUARD_ENTRY_SRC = '''
import torch

from scopedmodel.net import Net

model = torch.compile(Net())
''';

test "scoped guard raises the original exception through the wrapped entry" {
    # The guard lives in the imported (scoped) module and lowers to a marked
    # graph-native assert there; the entry's torch.compile call site gets
    # `model = __jac_trap_guard__(model)` injected, which wraps `forward` in
    # place on the module instance. A failing guard must surface as the
    # ORIGINAL ValueError with the original message, and the good path must
    # compute normally.
    torch = _torch();
    prog = JacRuntime.get_program();
    saved_en = prog.graphmend_enabled;
    saved_scope = prog.graphmend_scope;
    with tempfile.TemporaryDirectory() as tmp {
        pkg = os.path.join(tmp, "scopedmodel");
        os.mkdir(pkg);
        with open(os.path.join(pkg, "__init__.py"), "w") as fh {
            fh.write("");
        }
        with open(os.path.join(pkg, "net.py"), "w") as fh {
            fh.write(PY_GUARDED_NET_SRC);
        }
        entry_path = os.path.join(tmp, "entry.py");
        with open(entry_path, "w") as fh {
            fh.write(PY_GUARD_ENTRY_SRC);
        }
        eprog = JacProgram();
        eprog.graphmend_scope = ["scopedmodel"];
        emod = eprog.compile(
            file_path=entry_path,
            options=CompileOptions(graphmend=True, type_check=False)
        );
        pa = emod.gen.py_ast;
        entry_src = ast.unparse(pa[0] if isinstance(pa, list) else pa);
        assert "model = __jac_trap_guard__(model)" in entry_src;
        sys.path.insert(0, tmp);
        ns: dict = {};
        orig_compile = torch.compile;
        def _shim(*a: any, **k: any) -> any {
            if a {
                return a[0];
            }
            def _wrap(f: any) -> any {
                return f;
            }
            return _wrap;
        }
        torch.compile = _shim;
        try {
            prog.graphmend_enabled = True;
            prog.graphmend_scope = ["scopedmodel"];
            sys.modules.pop("scopedmodel", None);
            sys.modules.pop("scopedmodel.net", None);
            exec(compile(entry_src, "entry.py", "exec"), ns);
            x = torch.tensor([1.0, 2.0, 3.0]);
            good = torch.tensor([True, True, True]);
            bad = torch.tensor([True, False, True]);
            out = ns["model"](x, good);
            assert torch.allclose(out, torch.sin(torch.relu(x)));
            raised: any = None;
            try {
                ns["model"](x, bad);
            } except BaseException as e {
                raised = e;
            }
            assert type(raised) is ValueError , f"expected ValueError, got {repr(
                raised
            )}";
            assert str(raised) == "scoped mask must be all true" , (
                f"message lost: {repr(raised)}"
            );
            assert "GM-TRAP" not in str(raised) , "internal trap marker leaked";
        } finally {
            torch.compile = orig_compile;
            prog.graphmend_enabled = saved_en;
            prog.graphmend_scope = saved_scope;
            sys.path.remove(tmp);
            sys.modules.pop("scopedmodel", None);
            sys.modules.pop("scopedmodel.net", None);
        }
    }
}
