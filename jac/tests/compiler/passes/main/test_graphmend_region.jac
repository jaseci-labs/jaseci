"""GraphMend compiled-region invariant.

GraphMend analysis and transformation are restricted to the compiled region:
the torch.compile entry points (decorated functions and classes, call-site
wraps, and in scoped mode the forward seeds) plus their transitive callees. A
function never reachable from any entry must stay byte-identical no matter
which transformable patterns it contains, and a torch-importing module with no
torch.compile usage at all must compile byte-identical to a graphmend-off run
under auto and explicit on alike."""
import ast;
import os;
import from tests.support {
    GRAPHMEND_FIXTURES as FIXTURES,
    graphmend_break_kinds as _break_kinds,
    graphmend_pysrc as _pysrc
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

"""Unparse one named function out of generated Python source."""
def _fn_src(src: str, name: str) -> str {
    tree = ast.parse(src);
    for nd in ast.walk(tree) {
        if isinstance(nd, ast.FunctionDef) and (nd.name == name) {
            return ast.unparse(nd);
        }
    }
    return "";
}

"""Compile a fixture with default (auto) options and return its Python source."""
def _auto_pysrc(name: str) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name), options=CompileOptions(type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

"""Compile a fixture in an existing program and return its Python source."""
def _pysrc_in(prog: JacProgram, name: str) -> str {
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

test "an unreachable sibling keeps every transformable pattern untouched" {
    src_on = _pysrc("region_unreachable_sibling.jac", True);
    src_off = _pysrc("region_unreachable_sibling.jac", False);
    # The entry chain is transformed as usual.
    assert "torch._assert_async(mask.all()" in _fn_src(src_on, "entry");
    assert "__jac_se_emit__" in _fn_src(src_on, "entry");
    # The sibling holds a lowerable guard, a data-dependent branch, and a
    # print, yet none of them may move: it is byte-identical to graphmend-off.
    assert _fn_src(src_on, "orphan") == _fn_src(src_off, "orphan");
    assert _fn_src(src_on, "orphan_leaf") == _fn_src(src_off, "orphan_leaf");
    assert "raise ValueError('orphan mask must be all true')" in src_on;
    assert "print('ORPHAN-EFFECT', y)" in src_on;
    assert "torch.where" not in src_on;
}

test "detection tags nothing outside the compiled region" {
    kinds = sorted(_break_kinds("region_unreachable_sibling.jac"));
    assert kinds == ["side_effect", "val_guard"];
}

test "a torch module without torch compile compiles byte identical" {
    src_on = _pysrc("region_no_compile.jac", True);
    src_off = _pysrc("region_no_compile.jac", False);
    src_auto = _auto_pysrc("region_no_compile.jac");
    assert src_on == src_off;
    assert src_auto == src_off;
    assert _break_kinds("region_no_compile.jac") == [];
}

test "a decorated entry chain is transformed at depth" {
    src = _pysrc("region_chain.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "deep");
    assert "print('DEEP-EFFECT'" not in src;
}

test "a cross module helper is transformed when its entry is in the hub" {
    prog = JacProgram();
    _pysrc_in(prog, "region_xmod_entry.jac");
    src = _pysrc_in(prog, "region_xmod_helper.jac");
    assert "__jac_se_emit__" in _fn_src(src, "far_helper");
    assert "print('FAR-ORPHAN', x)" in _fn_src(src, "far_orphan");
}

test "a wrapped entry function is transformed through the wrap" {
    src = _pysrc("region_wrap_fn.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "wrapped");
}

test "a wrap entry callee is transformed at depth" {
    src = _pysrc("region_wrap_fn.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "wrap_helper");
    assert _break_kinds("region_wrap_fn.jac") == ["side_effect", "side_effect"];
}

test "a wrapped class forward callee is transformed" {
    src = _pysrc("region_wrap_cls.jac", True);
    assert "__jac_se_emit__" in _fn_src(src, "cls_helper");
}

test "scoped forward reaches a method through the self call and no further" {
    prog = JacProgram();
    prog.graphmend_scoped_compile = True;
    src = _pysrc_in(prog, "region_self_method.jac");
    assert "__jac_se_emit__" in _fn_src(src, "step");
    assert "print('UNUSED-EFFECT', x)" in _fn_src(src, "unused");
    assert "__jac_se_emit__" not in _fn_src(src, "unused");
}
