"""GraphMend graph-break detection pass tests."""
import os;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.main.graphmend.break_kind { GraphBreakKind }
import from jaclang.compiler.passes.main.graphmend.graph_break_detect_pass {
    GraphBreakDetectPass
}

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "graphmend"
     );

"""Compile a fixture and, when `gm`, run ONLY the GraphMend detection pass.

The full GraphMend pipeline replaces the tagged IfStmt/FuncCall nodes during
transformation, so the detection tags are no longer observable on the final
module. To assert detection in isolation we compile without the transform
passes (graphmend=False) and then run GraphBreakDetectPass standalone with the
flag enabled, leaving the tagged nodes intact."""
def _compile(name: str, gm: bool) -> uni.Module {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=False, type_check=False)
    );
    if gm {
        prog._compile_options = CompileOptions(graphmend=True, type_check=False);
        GraphBreakDetectPass(ir_in=mod, prog=prog);
    }
    return mod;
}

"""Collect the GraphMend break-kind tag of every IfStmt in a module."""
def _if_kinds(mod: uni.Module) -> list {
    return [n?._gm_break_kind for n in mod.get_all_sub_nodes(uni.IfStmt)];
}

"""Collect non-empty GraphMend break-kind tags of FuncCalls in a module."""
def _call_kinds(mod: uni.Module) -> list {
    out = [];
    for n in mod.get_all_sub_nodes(uni.FuncCall) {
        k = n?._gm_break_kind;
        if k {
            out.append(k);
        }
    }
    return out;
}

test "detects data-dependent control flow" {
    mod = _compile("where_return.jac", True);
    assert GraphBreakKind.DYN_CTRL_FL in _if_kinds(mod);
}

test "detects validation guard" {
    mod = _compile("val_guard.jac", True);
    assert GraphBreakKind.VAL_GUARD in _if_kinds(mod);
}

test "detects print side effect" {
    mod = _compile("side_effect.jac", True);
    assert GraphBreakKind.SIDE_EFFECT in _call_kinds(mod);
}

test "no detection when graphmend disabled" {
    mod = _compile("where_return.jac", False);
    assert _if_kinds(mod) == [None];
}

test "static hasattr control flow is not tagged" {
    mod = _compile("hasattr_static.jac", True);
    assert GraphBreakKind.DYN_CTRL_FL not in _if_kinds(mod);
    assert GraphBreakKind.VAL_GUARD not in _if_kinds(mod);
}
