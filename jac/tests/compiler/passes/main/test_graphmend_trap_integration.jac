"""Torch-gated integration tests for GraphMend trap lowering.

Confirm the runtime claim that the transformation defragments the FX graph:
compile the fixture with and without graphmend and count how many contiguous
graphs TorchDynamo's backend actually receives. A validation guard splits the
forward pass into multiple graphs; GraphMend collapses it back to one.

Graph count (via a counting backend) is used rather than
``explain().graph_break_count`` (which under-reports for small functions) or
``fullgraph=True`` (which is stricter than how models actually run).

Skipped automatically when PyTorch is not installed."""
import ast;
import os;
import pytest;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "graphmend"
     );

"""Import torch or skip the calling test."""
def _torch -> any {
    try {
        import torch;
        return torch;
    } except ImportError {
        pytest.skip("torch not installed");
    }
}

"""Compile a fixture and return its generated Python source."""
def _compile_src(fixture: str, graphmend: bool) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, fixture),
        options=CompileOptions(graphmend=graphmend, type_check=False)
    );
    py = mod.gen.py_ast;
    py = py[0] if isinstance(py, list) else py;
    return ast.unparse(py);
}

"""Compile a fixture and count the contiguous graphs the backend receives.

``@torch.compile`` is neutralized to an identity decorator so the rewritten
body is what we drive through a counting backend ourselves."""
def _count_graphs(fixture: str, graphmend: bool, fn_name: str, args: tuple) -> int {
    torch = _torch();
    src = _compile_src(fixture, graphmend);
    ns: dict = {};
    orig_compile = torch.compile;
    def _neutral_compile(*a: any, **k: any) -> any {
        if a {
            return a[0];
        }
        def _dec(f: any) -> any {
            return f;
        }
        return _dec;
    }
    torch.compile = _neutral_compile;
    try {
        exec(compile(src, fixture, "exec"), ns);
    } finally {
        torch.compile = orig_compile;
    }
    graphs: list = [];
    def _backend(gm: any, inputs: any) -> any {
        graphs.append(gm);
        return gm.forward;
    }
    torch._dynamo.reset();
    torch.compile(ns[fn_name], backend=_backend)(*args);
    return len(graphs);
}

"""Compile a fixture with GraphMend and exec it, with ``@torch.compile``
rebound to a REAL eager-backend compile (not identity). The graph-native
assert then fails asynchronously at the call boundary, where the injected
``@__jac_trap_guard__`` decorator catches it -- exactly the production path."""
def _exec_with_real_eager_compile(fixture: str) -> dict {
    torch = _torch();
    src = _compile_src(fixture, True);
    ns: dict = {};
    orig_compile = torch.compile;
    def _eager_compile(*a: any, **k: any) -> any {
        if a {
            return orig_compile(a[0], backend="eager");
        }
        def _dec(f: any) -> any {
            return orig_compile(f, backend="eager");
        }
        return _dec;
    }
    torch.compile = _eager_compile;
    try {
        exec(compile(src, fixture, "exec"), ns);
    } finally {
        torch.compile = orig_compile;
    }
    return ns;
}

test "validation guard defragments to one contiguous graph" {
    torch = _torch();
    x = torch.tensor([1.0, 2.0, 3.0]);
    mask = torch.tensor([True, True, True]);
    orig = _count_graphs("val_guard_all.jac", False, "f", (x, mask));
    fixed = _count_graphs("val_guard_all.jac", True, "f", (x, mask));
    assert orig >= 2 , f"expected a fragmented graph (>=2) without GraphMend, got {orig}";
    assert fixed == 1 , f"expected one contiguous graph with GraphMend, got {fixed}";
}

test "trap guard restores exception type and message" {
    # A failing tensor-bool guard must surface as the ORIGINAL exception type
    # (ValueError) with the original message, not a raw RuntimeError --
    # restored by the boundary trap-guard decorator after the graph-native
    # assert fails.
    torch = _torch();
    ns = _exec_with_real_eager_compile("val_guard_all.jac");
    x = torch.tensor([1.0, 2.0, 3.0]);
    good = torch.tensor([True, True, True]);
    bad = torch.tensor([True, False, True]);

    torch._dynamo.reset();
    out = ns["f"](x, good);
    assert torch.allclose(out, torch.sin(torch.relu(x)) * 2.0);

    torch._dynamo.reset();
    raised = None;
    try {
        ns["f"](x, bad);
    } except BaseException as e {
        raised = e;
    }
    assert type(raised) is ValueError , f"expected ValueError, got {repr(raised)}";
    assert str(raised) == "mask must be all true" , f"message lost: {repr(raised)}";
    assert "GM-TRAP" not in str(raised) , "internal trap marker leaked to the user";
}
