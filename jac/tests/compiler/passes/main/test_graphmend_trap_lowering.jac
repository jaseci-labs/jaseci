"""GraphMend trap-lowering (validation guard) tests.

Assertions run against the generated Python source (the lowering target),
plus the detection tag table where source alone cannot distinguish "not
detected" from "detected but declined by the trap pass"."""
import ast;
import os;
import tempfile;
import from tests.support {
    GRAPHMEND_FIXTURES as FIXTURES,
    graphmend_compile_path as _compile_path,
    graphmend_pysrc as _pysrc
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

"""Compile a fixture with graphmend on and count the detection tags recorded.

Observes detection directly (the side table survives the full compile), so a
guard the trap pass would decline anyway still cannot hide a mis-tag."""
def _break_count(name: str) -> int {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    return len(prog.graphmend_breaks);
}

"""A Python-source model with a tensor-bool validation guard.

Written to a temp file at test time rather than checked in as a .py fixture:
the repository does not accept new Python files, and the point of the fixture
is only that GraphMend ingests .py source, which a generated file exercises
just as well."""
glob PY_VAL_GUARD_SRC = '''
import torch


@torch.compile()
def f(x, mask: torch.Tensor):
    x = torch.relu(x)
    if not mask.all():
        raise ValueError("mask must be all true")
    return torch.sin(x) * 2.0
''';

"""Compile the generated .py model above and return its Python lowering."""
def _py_fixture_src(gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "py_val_guard.py");
        with open(path, "w") as fh {
            fh.write(PY_VAL_GUARD_SRC);
        }
        return _compile_path(path, gm);
    }
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
    assert "raise ValueError" not in src;
    assert "if not torch.equal" not in src;
    assert _break_count("val_guard.jac") == 1;
}

test "tensor-bool guard with a proven receiver lowers to a direct assert" {
    src = _pysrc("val_guard_all.jac", True);
    # `mask: torch.Tensor` proves the receiver, so the guard lowers to
    # torch._assert_async directly: no runtime helper, no import, nothing
    # decided at runtime.
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
    assert "if not mask.all()" not in src;
}

test "tensor-bool guard without a receiver proof is declined" {
    src = _pysrc("guard_unproven_receiver.jac", True);
    # Same guard shape, `mask: any`: the structural `.all` match alone cannot
    # establish tensor-ness, so the lowering declines and the original guard
    # (and its duck-typing contract) survives unchanged.
    assert "torch._assert_async(" not in src;
    assert "raise ValueError('mask must be all true')" in src;
    assert "if not mask.all():" in src;
    assert _break_count("guard_unproven_receiver.jac") == 1;
}

test "a comparison guard lowers on the negated condition" {
    # `if a != b: raise` is the same guard as `if not (a == b)`, so it lowers;
    # the assert takes the negation, keeping the guard's original truth value.
    src = _pysrc("val_guard_compare.jac", True);
    assert "torch._assert_async(torch.logical_not(mask.sum() != 4)" in src;
    assert "raise ValueError('mask must have four set entries')" not in src;
    assert "@__jac_trap_guard__" in src;
}

test "a comparison guard without a tensor operand is declined" {
    # Detected, but the receiver has no tensor proof, so the assert would
    # receive a Python bool; the guard keeps its original form.
    src = _pysrc("guard_compare_unproven.jac", True);
    assert "torch._assert_async(" not in src;
    assert "raise ValueError('mask must have four set entries')" in src;
    assert "if mask.sum() != 4:" in src;
    assert _break_count("guard_compare_unproven.jac") == 1;
}

test "a guard inside a lexical try declines to keep the handler live" {
    # The lowered assert fails at the boundary, outside the enclosing except,
    # so the handler would silently stop firing; the guard stays.
    src = _pysrc("guard_in_try.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError('mask must be all true')" in src;
    assert _break_count("guard_in_try.jac") == 1;
}

test "escaped message literal round-trips through the trap marker" {
    # The marker embeds the DECODED message, so the emitted literal must
    # re-escape it or the string pipeline decodes it a second time and a
    # backslash-n becomes a real newline in the restored exception.
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, "val_guard_escaped_msg.jac"),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    marker: (str | None) = None;
    for n in ast.walk(mod_ast) {
        if isinstance(n, ast.Constant)
            and isinstance(n.value, str)
            and ("GM-TRAP" in n.value) {
            marker = n.value;
        }
    }
    expected = '[[GM-TRAP ValueError]]bad mask C:\\new "q"\tend[[/GM-TRAP]]';
    assert marker == expected , f"marker mangled: {repr(marker)}";
}

test "py source: proven tensor-bool guard lowers to a direct assert" {
    # The .py front-end (PyastBuildPass) produces UniIR whose nodes unparse
    # differently from .jac-origin nodes, so the trap pattern must match
    # structurally; this guards `jac run model.py` under the default auto mode.
    src = _py_fixture_src(True);
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
}

test "no transformation when graphmend disabled" {
    src = _pysrc("val_guard.jac", False);
    assert "__jac_tensor_eq_assert__(" not in src;
    assert "if not torch.equal(attention_mask, expected):" in src;
    assert "raise ValueError('unsupported attention mask')" in src;
    src = _py_fixture_src(False);
    assert "torch._assert_async(" not in src;
    assert "if not mask.all():" in src;
}

test "f-string guard message declines instead of dropping the diagnostic" {
    # MultiString.lit_value accumulates only String parts, so folding an
    # f-string into the trap marker would yield a well-formed marker wrapped
    # around an EMPTY message: right exception type, lost diagnostic, no signal.
    src = _pysrc("guard_fstring_msg.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "if not mask.all()" in src;
    assert "raise ValueError(f'" in src;
    # The decline is the trap pass declining, not detection missing it; the two
    # scopes must stay distinguishable or a real detection regression could hide
    # behind this test.
    assert _break_count("guard_fstring_msg.jac") == 1;
}

test "runtime-expression guard message declines instead of losing the type" {
    # A concatenation is not a literal, so no marker can be built and the
    # boundary guard would have nothing to restore: lowering would surface the
    # failure as RuntimeError rather than the original ValueError.
    src = _pysrc("guard_dynamic_msg.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError('bad mask in ' + name)" in src;
    assert _break_count("guard_dynamic_msg.jac") == 1;
}

test "guard in a compiled class declines for want of a call boundary" {
    # The archetype is an entry point, so the guard IS tagged, but no enclosing
    # ability carries the decorator: there is no compiled boundary at which the
    # trap guard could restore the exception, and the async assert may surface
    # after the method returns.
    src = _pysrc("guard_in_compiled_class.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError('mask must be all true')" in src;
    assert _break_count("guard_in_compiled_class.jac") == 1;
}

test "static (non-tensor) guard is not rewritten" {
    # `if not isinstance(flag, str): raise` has no tensor-data dependence;
    # Dynamo traces it without a break, so GraphMend must leave it alone.
    src = _pysrc("static_guard.jac", True);
    assert "torch._assert_async(" not in src;
    assert "__jac_tensor_eq_assert__(" not in src;
    assert "if not isinstance(flag, str)" in src;
    assert "raise TypeError" in src;
    # rewrite absence alone would not prove precision: the trap pass would
    # decline this shape even if it were mis-tagged, so check the tag table
    assert _break_count("static_guard.jac") == 0;
}

test "multi-argument exception declines instead of truncating its args" {
    # Only one string literal fits in the trap marker, so lowering
    # ValueError('msg', 42) would reconstruct ValueError('msg') at the
    # boundary: right type, silently truncated args. Decline instead.
    src = _pysrc("guard_multi_arg_msg.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError('mask must be all true', 42)" in src;
    assert _break_count("guard_multi_arg_msg.jac") == 1;
}

test "raise-from guard declines instead of dropping the chained cause" {
    # The boundary guard re-raises `from None`, so an explicit `from cause`
    # chain cannot be reconstructed at the call site.
    src = _pysrc("guard_raise_from.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "from upstream" in src;
    assert _break_count("guard_raise_from.jac") == 1;
}

test "argument-less exception declines instead of gaining an empty arg" {
    # Reconstructing `raise ValueError` or `raise ValueError()` from a marker
    # yields ValueError('') whose args is ('',) where the original had ():
    # an observable contract change, so both shapes decline.
    src = _pysrc("guard_no_arg_msg.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError" in src;
    assert _break_count("guard_no_arg_msg.jac") == 2;
}

test "message containing the trap delimiter declines instead of truncating" {
    # The runtime parse stops at the first close delimiter, so a literal
    # message embedding [[/GM-TRAP]] would come back truncated at that point.
    src = _pysrc("guard_marker_msg.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError" in src;
    assert _break_count("guard_marker_msg.jac") == 1;
}

test "shadowed builtin exception name declines instead of switching class" {
    # `glob ValueError = RuntimeError` binds the name locally, so the raise no
    # longer selects the builtin the boundary guard would reconstruct. The
    # binding (Name.sym) is the proof; the spelling alone approves nothing.
    src = _pysrc("guard_shadowed_exc.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError('bad mask')" in src;
    assert _break_count("guard_shadowed_exc.jac") == 1;
}

test "bare Tensor annotation bound by a torch import lowers" {
    # `from torch import Tensor` proves the bare-name annotation through its
    # binding, so this is equivalent to the qualified torch.Tensor proof.
    src = _pysrc("val_guard_tensor_import.jac", True);
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
}

test "bare Tensor annotation from a non-torch import declines" {
    # Same spelling, different binding: `from mylib import Tensor` disproves
    # the receiver, so lowering would feed a non-torch value to
    # torch._assert_async. The guard keeps its original semantics.
    src = _pysrc("guard_foreign_tensor.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "if not mask.all()" in src;
    assert "raise ValueError('mask must be all true')" in src;
    assert _break_count("guard_foreign_tensor.jac") == 1;
}

test "non-builtin exception type declines instead of degrading its type" {
    # The boundary guard restores the type by looking the marker name up in
    # builtins, so an aliased (MaskError = RuntimeError) or qualified
    # (torch.MaskError) exception would come back as a bare RuntimeError:
    # an observable type change. Only bare builtin exception names lower.
    src = _pysrc("guard_custom_exc.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise MaskError" in src;
    assert "raise torch.MaskError" in src;
    assert _break_count("guard_custom_exc.jac") == 2;
}

test "shadowed torch name declines instead of binding the assert to a local" {
    # The receiver is provable via `Tensor`, but a parameter named `torch`
    # captures the emitted `torch._assert_async`, which would raise
    # AttributeError or silently skip the check. Proving the module by its
    # import binding, not by the spelling `torch`, is what declines it.
    src = _pysrc("guard_shadowed_torch.jac", True);
    assert "_assert_async(" not in src;
    assert "raise ValueError('mask must be all true')" in src;
    assert _break_count("guard_shadowed_torch.jac") == 1;
}
