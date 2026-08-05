"""GraphMend predicated trap-lowering (validation guard) tests.

Assertions run against the generated Python source (the lowering target)."""
import ast;
import os;
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

"""Compile a fixture and return its generated Python source."""
def _pysrc(name: str, gm: bool) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=gm, type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

test "torch.equal guard lowers to the tensor-equality assert helper" {
    src = _pysrc("val_guard.jac", True);
    # The original ValueError type/message are folded into a trap marker so the
    # boundary @__jac_trap_guard__ decorator can restore them at the call site.
    assert (
        "__jac_tensor_eq_assert__(attention_mask, expected, "
        "'[[GM-TRAP ValueError]]unsupported attention mask[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    # helper imports are emitted and the raising branch is gone
    assert "import __jac_tensor_eq_assert__" in src;
    assert "__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
    assert "if not torch.equal" not in src;
}

test "tensor-bool guard lowers to torch._assert_async directly" {
    src = _pysrc("val_guard_all.jac", True);
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    # boundary decorator restores the exception type at the call site
    assert "@__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
    assert "if not mask.all()" not in src;
}

test "validation guard preserved when graphmend disabled" {
    src = _pysrc("val_guard.jac", False);
    assert "__jac_tensor_eq_assert__(" not in src;
    assert "if not torch.equal(attention_mask, expected):" in src;
    assert "raise ValueError('unsupported attention mask')" in src;
}

test "py source: validation guard lowers to torch._assert_async" {
    # The .py front-end (PyastBuildPass) produces UniIR whose nodes unparse
    # differently from .jac-origin nodes, so the trap pattern must match
    # structurally; this guards `jac run model.py --graphmend`.
    src = _pysrc("py_val_guard.py", True);
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
}

test "py source: no transformation when graphmend disabled" {
    src = _pysrc("py_val_guard.py", False);
    assert "torch._assert_async(" not in src;
    assert "if not mask.all():" in src;
}
