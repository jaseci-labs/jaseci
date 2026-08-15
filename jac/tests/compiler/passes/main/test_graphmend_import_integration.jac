"""Torch-gated: an imported .py module that seeds GraphMend is claimed at
import time with nothing configured, runs its transformed bytecode, and still
raises its original exception. Skipped when PyTorch is absent."""
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

glob PY_CLAIMED_NET_SRC = '''
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

"""Lay out a one-module package under `tmp` and put it on sys.path."""
def _mk_pkg(tmp: str, src: str) {
    pkg = os.path.join(tmp, "claimedmodel");
    os.mkdir(pkg);
    with open(os.path.join(pkg, "__init__.py"), "w") as fh {
        fh.write("");
    }
    with open(os.path.join(pkg, "net.py"), "w") as fh {
        fh.write(src);
    }
}

test "an imported model package is claimed and transformed with no config" {
    # No local torch.compile: the module is claimed because it seeds GraphMend
    # on its own, under plain auto with nothing configured.
    torch = _torch();
    prog = JacRuntime.get_program();
    saved_en = prog.graphmend_enabled;
    with tempfile.TemporaryDirectory() as tmp {
        _mk_pkg(tmp, PY_CLAIMED_NET_SRC);
        sys.path.insert(0, tmp);
        try {
            prog.graphmend_enabled = "auto";
            sys.modules.pop("claimedmodel", None);
            sys.modules.pop("claimedmodel.net", None);
            net = importlib.import_module("claimedmodel.net");
            names = [
                i.argval
                for i in dis.get_instructions(net.Net.forward.__code__)
                if isinstance(i.argval, str)
            ];
            assert "where" in names , "imported model module was not transformed";
            # torch itself must be unaffected
            assert hasattr(torch, "_dynamo");
        } finally {
            prog.graphmend_enabled = saved_en;
            sys.path.remove(tmp);
            sys.modules.pop("claimedmodel", None);
            sys.modules.pop("claimedmodel.net", None);
        }
    }
}

glob PY_GUARDED_NET_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x, mask):
        x = torch.relu(x)
        if not mask.all():
            raise ValueError("mask must be all true")
        return torch.sin(x)
''',
     PY_GUARD_ENTRY_SRC = '''
import torch

from claimedmodel.net import Net

model = torch.compile(Net())
''';

test "a claimed guard raises the original exception through the boundary" {
    # The entry's call site gets `model = __jac_trap_guard__(model)`, which
    # wraps `forward` in place on the instance. A failing guard must surface as
    # the original ValueError, and the good path must compute normally.
    torch = _torch();
    prog = JacRuntime.get_program();
    saved_en = prog.graphmend_enabled;
    with tempfile.TemporaryDirectory() as tmp {
        _mk_pkg(tmp, PY_GUARDED_NET_SRC);
        entry_path = os.path.join(tmp, "entry.py");
        with open(entry_path, "w") as fh {
            fh.write(PY_GUARD_ENTRY_SRC);
        }
        eprog = JacProgram();
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
            prog.graphmend_enabled = "auto";
            sys.modules.pop("claimedmodel", None);
            sys.modules.pop("claimedmodel.net", None);
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
            assert str(raised) == "mask must be all true" , (
                f"message lost: {repr(raised)}"
            );
            assert "GM-TRAP" not in str(raised) , "internal trap marker leaked";
        } finally {
            torch.compile = orig_compile;
            prog.graphmend_enabled = saved_en;
            sys.path.remove(tmp);
            sys.modules.pop("claimedmodel", None);
            sys.modules.pop("claimedmodel.net", None);
        }
    }
}
