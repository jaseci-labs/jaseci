"""The type-system stage's native measurement, pinned the way the unitree seal is.

`types.jac` is the keystone: nothing else in `jaclang.compiler.type_system` can
enter a native unit until the module that defines `ClassType` lowers, because
every other module in the stage carries its types in fields and signatures. A
module-scoped refusal denies the whole module its IR, so a seam census taken
against it reads "not reached" rather than "clean" -- which is why `has_ir` is
asserted before any seam count is believed.

Five measurements, one memoized census each, and they answer different
questions:

* `types.jac` -- does the keystone reach codegen at all, and which of its
  methods still seam. Its closure membership is pinned too: a new native
  dependency (a module-level import replacing a typing-only or function-local
  one) has to reach zero seams before the stage can seal, so it fails loudly
  here rather than at seal time.
* `properties.jac` -- lowers whole. It is the first module above the keystone
  to do so, and it does it with no waiver of its own, which is the shape the
  rest of the stage is aiming at.
* `ts_decl_parser.jac` -- already clean, and pinned so it stays that way.
* `type_evaluator.jac` -- measurable at all. A construct that no callable owns
  refuses the module instead of demoting one method, and the census then
  records no seams whatsoever: 196 methods' worth of measurement lost to one
  un-lowerable statement. The pin is that the module reaches per-method
  demotion, plus an enumeration of the refusals that still escape an owner.
  Since #8234 a constructor owns its own body, so what remains ownerless here
  is field declarations alone.
* `enum_utils.jac` and `operations.jac` -- refused outright, and pinned as
  refused. A parameter typed `TypeEvaluator` is resolved before any body opens
  a demotion window, so it strands the module the way a field declaration
  does. Nothing of either module's own bodies is measurable until that
  changes, but the unit around them links now, and that is pinned too.

Waivers are enumerated one at a time and name what blocks each, so the suite
never degrades into a "fewer than N" threshold: an un-waived seam fails, and a
waiver that stops matching a real seam fails too, which keeps the baseline
current as the backend grows. Only seams in files this stage owns are
enumerated -- `unitree.jac`, `type_utils.jac` and `helpers.jac` ride in
`types.jac`'s closure and their seams are owned by
`test_unitree_seal_census.jac`, the seal's own gate, which would double-book
them here.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     TS_PATH = PKG_PATH / "compiler" / "type_system";

"""Every module the native compile of `types.jac` puts in its closure.

`operations` and the evaluator are deliberately absent: the methods that reach
them are seams, so their calls never become native edges. `unitree` is present
and cannot be avoided -- `ClassDetailsShared.symbol_table` is a `UniScopeNode`
field, which is a layout dependency no matter that the import is `import type`.

`type_utils` is present now and was not before. `ClassVar` becoming a
compile-time import name made `types.jac` linkable, which closed the
`unitree <-> types` layout cycle in the other direction too, and the modules
on the far side of it are in the unit whichever end is the root. This set is
`unitree`'s closure exactly -- `test_unitree_seal_census.jac` pins the same
eleven from the other root, and that is the seal's own view.
"""
glob TYPES_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "constant.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "pathlib.jac",
         "srcloc.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "unitree.jac"
     ),
     DECL_PARSER_CLOSURE: tuple = ("ts_decl_parser.jac", ),
     # `properties.jac` links the keystone and nothing above it, so its unit is
     # the eleven minus `type_utils`'s own leaves that it does not reach.
     PROPERTIES_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "constant.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "pathlib.jac",
         "properties.jac",
         "srcloc.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "unitree.jac"
     ),
     # A module refused by a signature type still links its dependencies: the
     # refusal costs it its own IR, not the unit around it. Both refused
     # modules reach the same set, so it is named once and the module's own
     # file is added per case.
     REFUSED_MODULE_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "const_fold.jac",
         "constant.jac",
         "diagnostics.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "pathlib.jac",
         "srcloc.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "unitree.jac"
     );

"""Files this stage owns; seams outside them belong to another census test."""
glob STAGE_FILES: tuple = ("types.jac", "ts_decl_parser.jac");

"""Seams that stay, each naming what has to land before it goes.

Keyed `<module>::<Type>.<method>` exactly as `_seal_demotions` keys them, so an
entry reads the same as one in `NATIVE_SEAL_DEMOTION_WAIVERS` when the stage
eventually joins `NATIVE_SEAL_ROOTS`. A `<field>.__get__` entry is a property;
#8074 made accessors lower as methods, so their bodies reach the backend.

Five element-erasure waivers left this table when optional containers learned
to keep their element layout: `TypeBase.mangle`, `ClassType.__str__`,
`FunctionType.__str__`, `UnionType.__str__` and `ClassType.clone_with_literal`
walked or sliced `list[T] | None` slots and now lower. Three entries survived
that erasure but for a reason their old text did not name -- the two
remaining `clone_*` methods and `specialize_func_type_vars` -- so their
waivers were rewritten rather than kept.

A sixth left when `ClassType.get_class_symbol` stopped needing a waiver at
all. It was waived as "Python-only", but the real defect was a declared type:
`ClassDetailsShared.symbol_table` is typed `UniScopeNode`, which has no
`name`, while every caller passes the `Archetype` that does. Narrowing to the
`Archetype` made both the checker and the backend accept it, so the method
lowers rather than being excused.

A seventh left with #8256. `TypeBase.category.__get__` reads `self.CATEGORY`,
a `ClassVar` the abstract base declares without a value and every subclass
redefines. The backend now gives each declaring class its own constant and
picks between them on the receiver's vtable, so the accessor lowers and the
read answers per class rather than defaulting.

The two `clone_as_*` waivers left with #8266. `TypeFlags(...)` is a
value-to-member lookup, and for an int-valued enum the member *is* the value,
so the emitter checks it against the declared member table and raises the
`ValueError` CPython raises. `create_callable_type` is unaffected: its
`ParameterCategory` members are `auto()`, which no fold reaches, so the table
that read needs still cannot be encoded.

An eighth left when `type_utils` joined the closure.
`FunctionType.specialize_func_type_vars` was waived as calling a function
"outside this closure", and it is inside now, so it lowers.

Two arrived in their place, and both are cross-module cascades #8272 made
measurable: `FunctionType.specialize` and `ClassType.lookup_member_symbol`
each call a `type_utils` function that demotes. Before that protocol the
importer emitted their call sites before the dependency's verdicts existed,
so the caller lowered and the artifact linked against a name the demotion had
renamed away. Every seam this table holds is identical to the one the unitree
census records for `types.jac` from the other root, which is the point: the
seal reads the closure, not the entry it was reached from.
"""
glob TYPES_SEAM_WAIVERS: dict[(str, str)] = {
         "types.jac::ClassType.lookup_member_symbol": (
             "Cascade: calls `type_utils.collect_member_syms`, which demotes "
             "on `helpers.evaluate_version_condition` and is waived in the "
             "unitree census."
         ),
         "types.jac::FunctionType.specialize": (
             "Cascade: calls `type_utils.build_type_var_solution`, waived in "
             "the unitree census for its `enumerate(...)` for-loop iterable."
         ),
         "types.jac::create_callable_type": (
             "Backend gap: reads `ParameterCategory.Positional`, an `IntEnum` "
             "member accessed off the class, which has no instance layout."
         )
     },
     DECL_PARSER_SEAM_WAIVERS: dict[(str, str)] = {
         "ts_decl_parser.jac::_parse_dts_inner": (
             "Backend gap: `set.add` on a set built from an inferred element "
             "type; the emitter has no layout for the set's element."
         )
     };

"""Native refusals the evaluator's compile records that no method owns.

Keyed `<file>::<message>` with the location dropped, because these move with
every edit above them. What is left in the evaluator itself is field
declarations: a `has` type that has no native layout is not inside any ability
body, so there is nothing to demote and the module pays for it. The seven
CPython `ast` handles that used to head this list moved into
`TypeEvaluator._read_dunder_all` and
`TypeEvaluator._read_ambient_imports_by_module` (#8237); the three that
`postinit` used to strand are owned seams since #8234 made a constructor
demotable like any other callable, and now read as
`TypeEvaluator.__post_init__` in the census instead.

Three entries name a different file, and that is the keystone's doing. The
evaluator imports `enum_utils` and `operations`, and now that `types.jac`
links, both are compiled as dependencies instead of being dropped before
placement, so their own declaration-time refusals join this compile's error
list. They are pinned twice on purpose: by module in
`SIGNATURE_REFUSED_MODULES` below, and by construct here, so a refusal that
moves fails whichever way it moves.
"""
glob EVALUATOR_FATAL_WAIVERS: dict[(str, str)] = {
         "type_evaluator.jac::Native lowering failed for type '[MultiString]'": (
             "Field declaration: `TypeEvaluator.program` is annotated "
             "`\"JacProgram\"`, a quoted forward reference. The backend reads "
             "the quotes literally, so `[MultiString]` names the string "
             "literal node rather than any list of unitree nodes. Unquoting it "
             "needs `JacProgram` to have a native layout, which is the same "
             "thing `enum_utils` and `operations` wait on below."
         ),
         (
             "type_evaluator.jac::Native lowering failed for type "
             "'dict[tuple, TypeBase | NoneType]'"
         ): (
             "Field declaration: a cache keyed by tuple holding optional "
             "`TypeBase`; neither half has a native layout."
         ),
         "enum_utils.jac::Native lowering failed for type 'TypeEvaluator'": (
             "A dependency's signature refusal, pinned by module in "
             "`SIGNATURE_REFUSED_MODULES`: `enum_utils` takes the evaluator as "
             "a parameter, and a signature resolves before any body opens a "
             "demotion window."
         ),
         "enum_utils.jac::Native lowering failed for type 'PrefetchedTypes'": (
             "The same declaration-time refusal on `enum_utils`'s other "
             "evaluator-side type: `PrefetchedTypes` is declared in "
             "`type_evaluator.jac`, which has no native layout of its own."
         ),
         "operations.jac::Native lowering failed for type 'TypeEvaluator'": (
             "The `enum_utils` refusal in the stage's other free-function "
             "module, same declaration-time shape."
         )
     };

"""Modules whose whole native compile is refused by a parameter's type.

Not a seam table: these two never reach codegen at all, so nothing about their
bodies is measured. Both hold `def f(evaluator: TypeEvaluator, ...)` at module
scope, and `TypeEvaluator` is the stage's upper half -- a class with no native
layout. A signature is resolved when the ability is declared, before any body
opens a demotion window, so the failure has no owner and costs the module its
IR the way an un-lowerable field declaration does.

That asymmetry is the clearing mechanism, and it is the same one #8234 and
#8237 already applied twice: a constructor now owns its body, and the
evaluator's `postinit` handles now demote as `__post_init__`. Declaration-time
signature resolution is the third case and the only one left. Until it lands,
both modules are un-sealable and un-measurable, which is why they are pinned
here by their refusal rather than waived into a seam table.
"""
glob SIGNATURE_REFUSED_MODULES: dict[(str, str)] = {
         "enum_utils.jac": "TypeEvaluator",
         "operations.jac": "TypeEvaluator"
     };

glob _CENSUS_MEMO: dict[(str, tuple)] = {};

"""Compile one module the way `seal_native_artifacts` does, up to the census.

Returns the per-module census, whether the root produced LLVM IR, and the
native refusals that survived every method demotion -- the ones that own the
`has_ir` verdict.
"""
def _census_of(src: Path) -> tuple[(dict, bool, list)] {
    # Runs in dev trees AND inside payload lanes that still compile from
    # source. When THIS runtime serves `unitree` from its own native seal the
    # measurement is not expressible: `unitree` sits in `types.jac`'s closure,
    # so the compile would be answered by the sealed artifact and every
    # assertion below would read an empty closure and pass vacuously.
    if native_artifact_for("jaclang.jac0core.unitree") is not None {
        testskip(
            "unitree is served from this runtime's native seal, so the "
            "type-system closure cannot be measured from source here"
        );
    }
    key = str(src);
    if key in _CENSUS_MEMO {
        return _CENSUS_MEMO[key];
    }
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
            file_path=key,
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
    fatal = [
        str(err)
        for err in prog.errors_had
        if err.code is not None and str(err.code.code).startswith("E50")
    ];
    result = (census, ir is not None and ir.gen.llvm_ir is not None, fatal, );
    _CENSUS_MEMO[key] = result;
    return result;
}

"""Census seams as `<module>::<Type>.<method>` -> reason, for the named files."""
def _seams_of(census: dict, files: tuple) -> dict[(str, str)] {
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(census.items()) {
        where = os.path.basename(path);
        if where not in files {
            continue;
        }
        for seam in (rec["seams"] or []) {
            (name, sep, why) = str(seam).partition(": ");
            found[f"{where}::{name if sep else str(seam)}"] = why if sep else "";
        }
        if rec["outcome"] == "demoted" {
            found[f"{where}::<module>"] = f"[{rec['code']}] {rec['detail']}";
        }
    }
    return found;
}

"""Ownerless refusals as `<file>::<message>`, with the moving location dropped."""
def _fatal_keys(fatal: list) -> set[str] {
    keys: set[str] = set();
    for line in fatal {
        (head, sep, msg) = str(line).partition(": ");
        if not sep {
            keys.add(str(line));
            continue;
        }
        keys.add(f"{os.path.basename(head.split(', line ')[0])}::{msg}");
    }
    return keys;
}

def _assert_waivers_match(found: dict, waived: dict, label: str) {
    unexpected = sorted(
        k
        for k in found
        if k not in waived
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in {label}:\n"
        + "\n".join(f"  {k}: {found[k]}" for k in unexpected)
    );
    stale = sorted(
        k
        for k in waived
        if k not in found
    );
    assert not stale , (
        f"waived seams in {label} that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}: {waived[k]}" for k in stale)
    );
}


test "types.jac lowers to native IR" {
    (_census, has_ir, fatal) = _census_of(TS_PATH / "types.jac");
    assert has_ir , (
        "no LLVM IR for types.jac -- the keystone refused codegen, so every "
        "seam count taken against it means 'not reached', not 'clean', and no "
        "type_system module can link it:\n"
        + "\n".join(f"  {f}" for f in fatal)
    );
}


test "types.jac's native closure is exactly the measured set" {
    (census, _has_ir, _fatal) = _census_of(TS_PATH / "types.jac");
    seen = tuple(sorted({os.path.basename(p) for p in census}));
    assert seen == TYPES_CLOSURE , (
        f"types.jac's native closure changed: {seen} != {TYPES_CLOSURE}. "
        "A new member has to reach zero seams too before the stage can seal."
    );
}


test "every types.jac seam is waived, and every waiver is live" {
    (census, _has_ir, _fatal) = _census_of(TS_PATH / "types.jac");
    _assert_waivers_match(
        _seams_of(census, STAGE_FILES), TYPES_SEAM_WAIVERS, "types.jac"
    );
}


test "properties.jac lowers whole" {
    (census, has_ir, fatal) = _census_of(TS_PATH / "properties.jac");
    assert has_ir , (
        "no LLVM IR for properties.jac -- it links the keystone, so a refusal "
        "here means the keystone stopped being linkable:\n"
        + "\n".join(f"  {f}" for f in fatal)
    );
    seen = tuple(sorted({os.path.basename(p) for p in census}));
    assert seen == PROPERTIES_CLOSURE , (
        f"properties.jac's native closure changed: {seen} != " f"{PROPERTIES_CLOSURE}."
    );
    own_seams = _seams_of(census, ("properties.jac", ));
    assert not own_seams , (
        f"{len(own_seams)} seam(s) in properties.jac, which lowered whole when "
        "the keystone became linkable:\n"
        + "\n".join(f"  {k}: {own_seams[k]}" for k in sorted(own_seams))
    );
}


test "ts_decl_parser stays clean" {
    (census, has_ir, fatal) = _census_of(TS_PATH / "ts_decl_parser.jac");
    assert has_ir , (
        "no LLVM IR for ts_decl_parser.jac:\n" + "\n".join(f"  {f}" for f in fatal)
    );
    seen = tuple(sorted({os.path.basename(p) for p in census}));
    assert seen == DECL_PARSER_CLOSURE , (
        f"ts_decl_parser.jac's native closure changed: {seen} != "
        f"{DECL_PARSER_CLOSURE}."
    );
    _assert_waivers_match(
        _seams_of(census, STAGE_FILES), DECL_PARSER_SEAM_WAIVERS, "ts_decl_parser.jac"
    );
}


test "the evaluator reaches per-method demotion" {
    (census, _has_ir, _fatal) = _census_of(TS_PATH / "type_evaluator.jac");
    evaluator = [
        rec
        for (path, rec) in census.items()
        if os.path.basename(path) == "type_evaluator.jac"
    ];
    assert evaluator , "the census recorded nothing for type_evaluator.jac";
    assert evaluator[0]["seams"] , (
        "type_evaluator.jac recorded no seams at all. That is not a clean "
        "module -- it is a module the backend refused before it could isolate "
        "a single one of its 196 abilities, so nothing about it is measured."
    );
}


test "every ownerless refusal in the evaluator is enumerated" {
    (_census, _has_ir, fatal) = _census_of(TS_PATH / "type_evaluator.jac");
    found = _fatal_keys(fatal);
    unexpected = sorted(
        k
        for k in found
        if k not in EVALUATOR_FATAL_WAIVERS
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived module-scoped native refusal(s) in the "
        "evaluator. Each one costs the whole module its IR, so it needs an "
        "owner or a waiver:\n"
        + "\n".join(f"  {k}" for k in unexpected)
    );
    stale = sorted(
        k
        for k in EVALUATOR_FATAL_WAIVERS
        if k not in found
    );
    assert not stale , (
        "waived refusals that no longer fire -- drop them:\n"
        + "\n".join(f"  {k}" for k in stale)
    );
}


test "a signature type still refuses its whole module" {
    for (mod, tname) in sorted(SIGNATURE_REFUSED_MODULES.items()) {
        (census, has_ir, fatal) = _census_of(TS_PATH / mod);
        assert not has_ir , (
            f"{mod} produced native IR. If declaration-time signature "
            "resolution learned to demote the owning ability, this module is "
            "measurable now: drop it from SIGNATURE_REFUSED_MODULES and give "
            "it a seam table of its own."
        );
        want = f"Native lowering failed for type '{tname}'";
        assert any(want in f for f in fatal) , (
            f"{mod} no longer refuses on `{tname}` in a parameter. It still "
            f"has no IR, so something else strands it now:\n"
            + "\n".join(f"  {f}" for f in fatal)
        );
        seen = tuple(sorted({os.path.basename(p) for p in census}));
        want = tuple(sorted(REFUSED_MODULE_CLOSURE + (mod, )));
        assert seen == want , (
            f"{mod}'s closure is {seen}, not {want}. The refusal costs the "
            "module its own IR, not the unit around it, so a change here is a "
            "change in what it links rather than in what refuses it."
        );
    }
}
