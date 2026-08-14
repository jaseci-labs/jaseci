"""No waived seam is reachable from the sealed parser's entry points.

A waiver in `NATIVE_SEAL_DEMOTION_WAIVERS` ships an `abort()` stub into the
artifact, so a waived method that turns out to be reachable trades a wrong
answer for a process kill with no diagnostic. `test_unitree_seal_census.jac`
pins that each waiver still names a real seam; this pins the other half, that
none of them can be called.

The closure below is a deliberate over-approximation, so "not in it" is a
proof and "in it" is only a warning:

  - **Seeds** are every module-level function in the sealed closure (a
    superset of the artifact's exports), every module-level statement and glob
    initializer (what `__jac_shared_init` runs), and every dunder plus
    `accept_enter` / `accept_exit` on every class -- the dispatch an operator,
    an f-string, iteration or a visitor performs with no `FuncCall` in the AST
    to see.
  - **Call edges** ignore the receiver entirely: `x.m(...)` adds `C.m` for
    every class `C` that declares a method named `m`, so no amount of dynamic
    dispatch can escape the set.
  - **Accessor edges** are the ones this exists for: `x.a` adds
    `C.a.__get__`, `C.a.__set__` and `C.a.__del__` for every class declaring
    `a` as an accessor, again regardless of `x`'s type.
  - **Construction** of `Cls` adds `init`, `postinit` and the field-default
    expressions for every class in `Cls`'s MRO.

The last test is the load-bearing one for the other three: it asserts the
closure reaches accessors a parse demonstrably needs (`CodeLocInfo`'s spans,
`NameAtom.sym`). Without it a walker that silently found nothing would report
"no waived seam reachable" for the wrong reason.
"""

import os;
import pytest;
import jaclang;
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.main.layout_pass {
    archetype_accessors,
    get_layout_registry
}
import from jaclang.jac0core.sealed { native_artifact_for }
import from jaclang.utils.precompile_bytecode { _UNITREE_SEAM_WAIVERS }

glob PKG_PATH = Path(jaclang.__file__).parent,
     SEALED_ROOT = "jac0core/parser/parser.jac",
     _CLOSURE_MEMO: list = [];

"""Every archetype, module function and glob root in the sealed closure."""
def _sealed_program -> tuple[(dict, dict, list, any)] {
    # Same gate as the unitree census: a runtime that serves the sealed
    # closure from its own native artifacts answers this compile from the
    # seal, so the walker would see an empty program and every reachability
    # claim below would be vacuous. Seal time already ran the census.
    if native_artifact_for("jaclang.jac0core.unitree") is not None {
        pytest.skip(
            "the sealed closure is served from this runtime's native seal; "
            "reachability is measured in source lanes and at seal time"
        );
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(PKG_PATH / SEALED_ROOT),
        options=CompileOptions(
            aot_mode=True,
            type_check=False,
            force_codespace='native',
            force_target_program=True,
            na_gc_mode='cycles',
            no_ir_cache=True
        )
    );
    arch_of: dict = {};
    mod_funcs: dict = {};
    glob_roots: list = [];
    for (_path, mod) in prog.mod.hub.items() {
        for st in ModuleCodegenPass.iter_context_stmts(mod, CodeContext.NATIVE) {
            if isinstance(st, uni.Archetype) and st.name is not None {
                nm = st.name.value;
                if nm not in arch_of or st.body is not None {
                    arch_of[nm] = st;
                }
            } elif isinstance(st, uni.Ability)
                and st.name_ref is not None
                and not st.is_method {
                mod_funcs[st.name_ref.sym_name] = st;
            } elif isinstance(st, (uni.ModuleCode, uni.GlobalVars)) {
                glob_roots.append(st);
            }
        }
    }
    return (arch_of, mod_funcs, glob_roots, get_layout_registry(ir, prog));
}

"""Every node the sealed entry points can reach, over-approximated."""
def reachable -> set {
    if _CLOSURE_MEMO {
        return _CLOSURE_MEMO[0];
    }
    # Runs in dev trees AND inside the sealed payload lanes: sources ship in
    # the payload and match the checkout that built it, so the reachability
    # walk proves the same closure a payload build seals.
    (arch_of, mod_funcs, glob_roots, reg) = _sealed_program();

    methods_named: dict = {};
    accessors_named: dict = {};
    for (cls, arch) in arch_of.items() {
        for meth in arch.get_methods() {
            mname = meth.name_ref.sym_name if meth.name_ref else None;
            if mname is not None {
                methods_named.setdefault(mname, {})[cls] = meth;
            }
        }
        for (slot, _var, acc) in archetype_accessors(arch) {
            accessors_named.setdefault(slot, {})[cls] = acc;
        }
    }

    def roots_of(node_id: str) -> list {
        out: list = [];
        if node_id == "<module>" {
            return list(glob_roots);
        }
        if node_id in mod_funcs {
            body = ModuleCodegenPass.unwrap_body(mod_funcs[node_id]);
            if body is not None {
                out.extend(body);
            }
            if mod_funcs[node_id].signature is not None {
                out.append(mod_funcs[node_id].signature);
            }
            return out;
        }
        (cls, _dot, rest) = node_id.partition(".");
        arch = arch_of.get(cls);
        if arch is None or not rest {
            return out;
        }
        if rest == "<defaults>" {
            for var in arch.get_has_vars() {
                if var.value is not None {
                    out.append(var.value);
                }
            }
            return out;
        }
        for (slot, _var, acc) in archetype_accessors(arch) {
            if slot == rest {
                body = ModuleCodegenPass.unwrap_body(acc);
                if body is not None {
                    out.extend(body);
                }
            }
        }
        for meth in arch.get_methods() {
            if (meth.name_ref.sym_name if meth.name_ref else None) == rest {
                body = ModuleCodegenPass.unwrap_body(meth);
                if body is not None {
                    out.extend(body);
                }
                if meth.signature is not None {
                    out.append(meth.signature);
                }
            }
        }
        return out;
    }

    def construction_of(cls: str) -> list {
        out: list = [];
        for ancestor in reg.get_mro(cls) {
            if ancestor in arch_of {
                out.extend(
                    [
                        f"{ancestor}.init",
                        f"{ancestor}.__init__",
                        f"{ancestor}.postinit",
                        f"{ancestor}.__post_init__",
                        f"{ancestor}.<defaults>"
                    ]
                );
            }
        }
        return out;
    }

    def attr_of(trailer: uni.UniNode) -> (str | None) {
        right = trailer.right if trailer?.right is not None else None;
        if isinstance(right, uni.Name) {
            return right.value;
        }
        return right.sym_name if isinstance(right, uni.AstSymbolNode) else None;
    }

    def edges_of(node_id: str) -> set {
        out: set = set();
        stack: list = roots_of(node_id);
        walked: set = set();
        while stack {
            nd = stack.pop();
            if nd is None or id(nd) in walked {
                continue;
            }
            walked.add(id(nd));
            for kid in (nd.kid or []) {
                if kid is not None {
                    stack.append(kid);
                }
            }
            named: (str | None) = None;
            if isinstance(nd, uni.FuncCall) {
                target = nd.target;
                if isinstance(target, uni.Name) {
                    named = target.value;
                } elif isinstance(target, uni.AtomTrailer) {
                    named = attr_of(target);
                }
            }
            if named is not None {
                if named in arch_of {
                    out.update(construction_of(named));
                }
                if named in mod_funcs {
                    out.add(named);
                }
                for cls in methods_named.get(named, {}) {
                    out.add(f"{cls}.{named}");
                }
            }
            if isinstance(nd, uni.AtomTrailer) and nd.is_attr {
                attr = attr_of(nd);
                if attr is not None {
                    for kind in ("__get__", "__set__", "__del__") {
                        slot = f"{attr}.{kind}";
                        for cls in accessors_named.get(slot, {}) {
                            out.add(f"{cls}.{slot}");
                        }
                    }
                }
            }
        }
        return out;
    }

    seeds: set = set(mod_funcs.keys());
    seeds.add("<module>");
    for (cls, arch) in arch_of.items() {
        for meth in arch.get_methods() {
            mname = meth.name_ref.sym_name if meth.name_ref else "";
            if (mname.startswith("__") and mname.endswith("__"))
                or mname in ("accept", "accept_enter", "accept_exit") {
                seeds.add(f"{cls}.{mname}");
            }
        }
    }

    seen: set = set();
    work: list = list(seeds);
    while work {
        current = work.pop();
        if current in seen {
            continue;
        }
        seen.add(current);
        for callee in edges_of(current) {
            if callee not in seen {
                work.append(callee);
            }
        }
    }
    _CLOSURE_MEMO.append(seen);
    return seen;
}

"""Waived seams, keyed the way `_seal_demotions` keys them, minus the module."""
def _waived_names -> set {
    return {entry.split("::")[-1] for entry in _UNITREE_SEAM_WAIVERS};
}


test "the closure reaches accessors a parse demonstrably needs" {
    seen = reachable();
    for needed in (
        "CodeLocInfo.orig_src.__get__",
        "CodeLocInfo.first_line.__get__",
        "CodeLocInfo.pos_end.__get__",
        "NameAtom.sym.__get__",
        "NameAtom.sym.__set__",
        "AstSymbolNode.sym_name.__get__"
    ) {
        assert needed in seen , (
            f"'{needed}' is missing from the reachable set -- the walker found "
            "nothing, so a clean result below would be vacuous"
        );
    }
}


test "the closure reaches the parser itself" {
    seen = reachable();
    assert "parse_program" in seen , "the sealed entry point is not a seed";
    assert len(seen) > 500 , (
        f"only {len(seen)} reachable nodes; the walk is not expanding"
    );
}


test "no waived seam is reachable from the sealed entry points" {
    seen = reachable();
    waived = _waived_names();
    reachable_waivers = sorted(
        name
        for name in waived
        if name in seen
    );
    assert not reachable_waivers , (
        f"{len(reachable_waivers)} waived seam(s) are reachable, so the "
        "artifact can abort at runtime instead of returning a wrong value:\n"
        + "\n".join(f"  {name}" for name in reachable_waivers)
    );
}
