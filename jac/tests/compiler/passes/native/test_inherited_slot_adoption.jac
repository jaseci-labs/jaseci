"""A subclass reaches slots its base declares, across a module boundary.

The pass base chain entering every root's closure exposed four refusals that
all named the same thing: an access to a slot the archetype inherits rather
than declares. `UniPass.transform` stored `ir_out`, `UniPass.traverse` stored
`cur_node`, `JsxIntrinsicGuardPass.before_pass` read `ir_in`, and
`UniPass.__post_init__` called `super.__post_init__`. Constructing a pass
inside a native root lowered; running one did not.

The cause is a phase ordering, and it is #8253's family one configuration
over. A module the consumer imports is compiled `symtab_ir_only`, so its
layout pass runs but its own `adopt_imported_bases` never does, and its
`class_parents` knows only the parents its own file declares. Its
linearization therefore stops one hop up -- `ModuleCodegenPass` reaches
`Transform` and not `BaseTransform` -- and `_register_imported_hierarchy`
copies that truncated answer into the consumer verbatim. Adoption then walks
`lay.mro`, sees no `BaseTransform`, and never brings `ir_out` across. Over a
five-deep chain crossing four module boundaries the truncation compounds:
every layout below `Transform` was missing all three slots.

`extended_mro` repairs it where the registry is finally complete, continuing
each recorded chain through its ancestors' own recorded chains. What it may
not do is trust a bare name: the registry holds one layout per name, so
`type_utils`'s `class PropertyWriteKind(Enum)` -- Python's enum -- resolves
to unitree's `Enum` archetype, and an unguarded repair walked straight into
unitree's scope methods. `corroborates` is the guard, and it asks for
evidence rather than a name match: a real ancestor's slots already sit at the
indices the child carries.

Pinned here two ways. The fixtures measure the mechanism directly, so a
regression names itself here rather than as a seam count in a census.
"""

import os;
import pytest;
import jaclang;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image }

glob FIXTURES = os.path.join(
         os.path.dirname(os.path.dirname(os.path.realpath(jaclang.__file__))),
         "tests",
         "compiler",
         "passes",
         "native",
         "fixtures"
     ),
     _MEMO: dict[(str, dict)] = {};

"""Seams the native census records for `rel`, keyed by callable."""
def _seams(rel: str) -> dict[(str, str)] {
    if _jaclang_image() is not None {
        pytest.skip("a sealed image measures its trust boundary, not this");
    }
    if rel in _MEMO {
        return _MEMO[rel];
    }
    path = os.path.join(FIXTURES, rel);
    prog = JacProgram();
    na_census_begin();
    try {
        prog.compile(
            file_path=path,
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        census = na_census_end();
    }
    rec = census.get(os.path.realpath(path));
    assert rec is not None and rec["outcome"] == "native" , (
        f"{rel} never compiled as a native root, so nothing below measures " "anything"
    );
    found: dict[(str, str)] = {};
    for seam in (rec["seams"] or []) {
        (name, sep, why) = str(seam).partition(": ");
        found[name if sep else str(seam)] = why if sep else "";
    }
    _MEMO[rel] = found;
    return found;
}


"""Two module boundaries from the slot, which is where the truncation bit."""
test "a leaf reaches a slot its grandparent declares, across two modules" {
    seams = _seams("deep_chain_leaf.jac");
    for meth in ("DeepLeaf.store_grandparent_slot", "DeepLeaf.read_grandparent_slot") {
        assert meth not in seams , (
            f"{meth} refused again: {seams.get(meth, '')}. `DeepMid`'s "
            "recorded linearization stopped at itself, so `slot_a` was "
            "invisible from the leaf -- the same truncation that took "
            "`UniPass.transform` and `UniPass.traverse` down, where a pass "
            "could be constructed natively but not run"
        );
    }
}


"""The chain the compiler's own passes form, measured on the real thing."""
test "the pass chain's traversal methods lower" {
    if _jaclang_image() is not None {
        pytest.skip("a sealed image measures its trust boundary, not this");
    }
    pkg = os.path.dirname(os.path.realpath(jaclang.__file__));
    prog = JacProgram();
    na_census_begin();
    try {
        prog.compile(
            file_path=os.path.join(pkg, "jac0core", "passes", "uni_pass.jac"),
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        census = na_census_end();
    }
    rec = census.get(
        os.path.realpath(os.path.join(pkg, "jac0core", "passes", "uni_pass.jac"))
    );
    assert rec is not None , "uni_pass.jac never entered the census";
    names: set[str] = set();
    for seam in (rec["seams"] or []) {
        names.add(str(seam).partition(": ")[0]);
    }
    for meth in ("UniPass.transform", "UniPass.traverse") {
        assert meth not in names , (
            f"{meth} demoted again. This is the seam that decides whether a "
            "natively constructed pass can walk a tree, and the fused prefix "
            "root is gated on it"
        );
    }
}


"""What the repair still refuses, kept honest rather than hidden.

`UniPass.__post_init__` refuses on `super.__post_init__`, a different
mechanism from the slot access this file fixes, and the flat-header case
below is a second one: `adopt_imported_bases` declines to reassign where a
flat ancestor sits under a subclass that carries a vtable, because no
assignment satisfies both units. `SlotChild` overrides a method and so needs
one; `SlotBase`, having no subclass in its own unit, does not.
"""
test "the flat-base header disagreement is still refused, and says so" {
    seams = _seams("inherited_slot_child.jac");
    why = seams.get("SlotChild.store_inherited", "");
    assert why , (
        "the flat-ancestor/vtable-child case started lowering. That is real "
        "progress -- `needs_vtable` is `bool(parents)` in "
        "`layout_pass.impl.jac`, so a child of a flat base carries a vtable "
        "its base lacks -- but it needs its own measurement, so record it "
        "and drop this test"
    );
}
