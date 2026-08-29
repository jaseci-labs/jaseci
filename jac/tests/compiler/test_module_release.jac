"""A released module's graph is collectable (#8744 WS5).

The syntax graph's structure edges are adjacency-only (no kernel rows, no
handle registry), so once `JacProgram.release_module` evicts a module from
the hub, the node/edge cycle must be reclaimable by the garbage collector.
This is the memory contract per-module release relies on.
"""
import gc;
import weakref;
import from jaclang.compiler.driver.program { JacProgram }

glob SRC = "def area(r: float) -> float { return 3.14 * r * r; }\n";

def _probe(prog: JacProgram) -> tuple {
    mod = prog.parse_str(SRC, "release_probe.jac");
    assert mod is not None;
    return (
        mod.loc.mod_path,
        weakref.ref(mod),
        weakref.ref(mod.kid[0]),
        weakref.ref(getattr(mod.kid[0], "__jac__")),

    );
}

test "released module trees are garbage collectable" {
    prog = JacProgram();
    (path, mod_ref, kid_ref, anchor_ref) = _probe(prog);
    prog.release_module(JacProgram.hub_key(path));
    gc.collect();
    dead = [mod_ref() is None, kid_ref() is None, anchor_ref() is None];
    assert all(dead) , f"leaked (module, kid, anchor): {dead}";
}

def _compile_probe(prog: JacProgram) -> tuple {
    mod = prog.compile(file_path="release_closure_probe.jac", use_str=SRC);
    assert mod is not None;
    return (weakref.ref(mod), weakref.ref(mod.kid[0]));
}

test "a fully compiled module is collectable after release_compile_closure" {
    prog = JacProgram();
    (mod_ref, kid_ref) = _compile_probe(prog);
    prog.release_compile_closure();
    gc.collect();
    dead = [mod_ref() is None, kid_ref() is None];
    assert all(dead) , (
        f"compiled tree pinned after release (module, kid): {dead}; a long-lived "
        "node holds a strong link into it (check the direction of relations to "
        "the builtins scope, codespaces and stub symbols)"
    );
}
