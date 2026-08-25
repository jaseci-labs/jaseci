"""Regression coverage: shared-registry layout resolves generic type tags.

`LayoutPass.resolve_ref` exact-matched a whole unparsed tag against the
declaring module's scope, so in shared-registry mode (tid-index present) a
field annotated ``list[Foo]`` kept the inner archetype unresolved while a
plain ``Foo`` field resolved to its tid. Consumers that look layout field
tags up in ``type_ids`` (e.g. C-gen attribute-assignment lowering) therefore
saw the generic field as unresolvable.

This pins the invariant: every archetype identifier inside a field's type
tag -- bare or nested under a generic -- is rewritten to its tid, and
non-archetype names (`list`, `int`, ...) pass through untouched.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.layout_pass { get_shared_layout_registry }

glob FIXTURE_DIR = str(
         Path(jaclang.__file__).parent
             / "compiler"
             / "tests"
             / "fixtures"
             / "shared_layout_generic_tags"
     );


def build_shared_registry -> object {
    prog = JacProgram();
    main_mod = prog.compile(os.path.join(FIXTURE_DIR, "main.jac"));
    foo_mod = prog.compile(os.path.join(FIXTURE_DIR, "foo.jac"));
    return get_shared_layout_registry([main_mod, foo_mod], prog);
}


test "generic annotation resolves inner archetype to its tid" {
    reg = build_shared_registry();
    bar = None;
    for (_name, lay) in reg.layouts.items() {
        if lay.name == "main__Bar" {
            bar = lay;
        }
    }
    assert bar is not None , sorted(reg.layouts.keys());
    tags = {};
    for f in bar.fields {
        tags[f.name] = f.type_tag;
    }
    assert tags["direct"] == "foo__Foo" , tags;
    assert "foo__Foo" in tags["items"] , tags;
}


test "non-archetype names in tags are left untouched" {
    reg = build_shared_registry();
    foo = None;
    for (_name, lay) in reg.layouts.items() {
        if lay.name == "foo__Foo" {
            foo = lay;
        }
    }
    assert foo is not None , sorted(reg.layouts.keys());
    for f in foo.fields {
        assert f.type_tag == "int" , f.type_tag;
    }
}
