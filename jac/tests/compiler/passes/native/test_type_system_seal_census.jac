"""The type-system stage's native measurement, pinned the way the unitree seal is.

`types.jac` is the keystone: nothing else in `jaclang.compiler.type_system` can
enter a native unit until the module that defines `ClassType` lowers, because
every other module in the stage carries its types in fields and signatures. A
module-scoped refusal denies the whole module its IR, so a seam census taken
against it reads "not reached" rather than "clean" -- which is why `has_ir` is
asserted before any seam count is believed.

Three measurements, one memoized census each, and they answer different
questions:

* `types.jac` -- does the keystone reach codegen at all, and which of its
  methods still seam. Its closure membership is pinned too: a new native
  dependency (a module-level import replacing a typing-only or function-local
  one) has to reach zero seams before the stage can seal, so it fails loudly
  here rather than at seal time.
* `ts_decl_parser.jac` -- already clean, and pinned so it stays that way.
* `type_evaluator.jac` -- measurable at all. A construct that no method owns
  (`postinit` owns nothing, per #8234) refuses the module instead of demoting
  one method, and the census then records no seams whatsoever: 196 methods'
  worth of measurement lost to one un-lowerable statement. The pin is that the
  module reaches per-method demotion, plus an enumeration of the refusals that
  still escape an owner.

Waivers are enumerated one at a time and name what blocks each, so the suite
never degrades into a "fewer than N" threshold: an un-waived seam fails, and a
waiver that stops matching a real seam fails too, which keeps the baseline
current as the backend grows. Only seams in files this stage owns are
enumerated -- `unitree.jac` rides in `types.jac`'s closure and its seams are
owned by `test_unitree_seal_census.jac`, which would double-book them here.
"""

import os;
import pytest;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     TS_PATH = PKG_PATH / "compiler" / "type_system";

"""Every module the native compile of `types.jac` puts in its closure.

`type_utils`, `operations` and the evaluator are deliberately absent: the
methods that reach them are seams, so their calls never become native edges.
`unitree` is present and cannot be avoided -- `ClassDetailsShared.symbol_table`
is a `UniScopeNode` field, which is a layout dependency no matter that the
import is `import type`.
"""
glob TYPES_CLOSURE: tuple = (
         "constant.jac",
         "pathlib.jac",
         "srcloc.jac",
         "types.jac",
         "unitree.jac"
     ),
     DECL_PARSER_CLOSURE: tuple = ("ts_decl_parser.jac", );

"""Files this stage owns; seams outside them belong to another census test."""
glob STAGE_FILES: tuple = ("types.jac", "ts_decl_parser.jac");

"""Seams that stay, each naming what has to land before it goes.

Keyed `<module>::<Type>.<method>` exactly as `_seal_demotions` keys them, so an
entry reads the same as one in `NATIVE_SEAL_DEMOTION_WAIVERS` when the stage
eventually joins `NATIVE_SEAL_ROOTS`. A `<field>.__get__` entry is a property;
#8074 made accessors lower as methods, so their bodies reach the backend.
"""
glob TYPES_SEAM_WAIVERS: dict[(str, str)] = {
         "types.jac::TypeBase.mangle": (
             "Backend gap: comprehends over `private.type_args`, a "
             "`list[TypeBase] | None` whose element type erases to a pointer, "
             "so the comprehension has no element layout to walk."
         ),
         "types.jac::TypeBase.category.__get__": (
             "Backend gap: reads `self.CATEGORY`, a `ClassVar` declared on the "
             "abstract base and redefined per subclass. A class-level slot is "
             "not part of the instance layout the accessor is emitted against."
         ),
         "types.jac::ClassType.__str__": (
             "Backend gap: same element-erased comprehension over "
             "`private.type_args` as `TypeBase.mangle`."
         ),
         "types.jac::ClassType.clone_as_instance": (
             "Backend gap: slices `private.type_args` (an optional list) into "
             "a fresh `ClassDetailsPrivate`; the emitter has no layout for the "
             "sliced element type."
         ),
         "types.jac::ClassType.clone_as_class": (
             "Backend gap: same optional-list slice into `ClassDetailsPrivate` "
             "as `clone_as_instance`."
         ),
         "types.jac::ClassType.clone_with_literal": (
             "Backend gap: same optional-list slice into `ClassDetailsPrivate` "
             "as `clone_as_instance`."
         ),
         "types.jac::ClassType.get_class_symbol": (
             "Python-only: reaches `UniScopeNode.name.sym`, and `Symbol` is a "
             "symbol-table handle the native unit does not model."
         ),
         "types.jac::ClassType.lookup_member_symbol": (
             "Python-only: calls `collect_member_syms` from `type_utils`, a "
             "module outside this closure that walks symbol tables."
         ),
         "types.jac::FunctionType.__str__": (
             "Backend gap: formats `parameters`, an optional list of "
             "`Parameter`, through `or []` guards the emitter cannot type."
         ),
         "types.jac::FunctionType.specialize": (
             "Python-only: calls `build_type_var_solution` from `type_utils`, "
             "outside this closure."
         ),
         "types.jac::FunctionType.specialize_func_type_vars": (
             "Backend gap: iterates `clone.parameters`, an optional list, so "
             "the for-loop has no element type."
         ),
         "types.jac::UnionType.__str__": (
             "Backend gap: joins a generator over `self.types`, an optional "
             "list, which erases the element type."
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

"""Native refusals in the evaluator that no method owns, and so refuse the module.

Keyed `<file>::<message>` with the location dropped, because these move with
every edit above them. Each is a construct sitting outside an ability body --
`postinit` (#8234) or a field declaration -- where there is nothing to demote.
The seven CPython `ast` handles that used to head this list are gone: they now
live in `TypeEvaluator._read_dunder_all` and
`TypeEvaluator._read_ambient_imports_by_module`, which own their own demotion.
"""
glob EVALUATOR_FATAL_WAIVERS: dict[(str, str)] = {
         "type_evaluator.jac::Native lowering failed for type 'TypeBase'": (
             "Field declaration: `NarrowingTarget.declared_type` and "
             "`NarrowingPredicate.narrow_type` hold the abstract `TypeBase`, "
             "which has no concrete layout. A field is not an ability, so "
             "there is no owner to demote."
         ),
         "type_evaluator.jac::Native lowering failed for type '[MultiString]'": (
             "Field declaration: a list of `MultiString` unitree nodes."
         ),
         (
             "type_evaluator.jac::Native lowering failed for type "
             "'dict[tuple, TypeBase | NoneType]'"
         ): (
             "Field declaration: a cache keyed by tuple holding optional "
             "`TypeBase`; neither half has a native layout."
         ),
         (
             "type_evaluator.jac::Native lowering failed for type "
             "'dict[str, ModuleType]'"
         ): "Field declaration: a module cache holding `ModuleType` values.",
         (
             "type_evaluator.jac::Native lowering failed for type "
             "'dict[int, TypeBase]'"
         ): "Field declaration: a cache holding abstract `TypeBase` values.",
         (
             "type_evaluator.jac::Native lowering failed for integer operator "
             "layout 'BW_OR on %\"Set.ptr\"* vs i8*'"
         ): (
             "Module-scoped: a set union whose operands lower to mismatched "
             "pointer layouts, emitted outside any ability."
         ),
         (
             "type_evaluator.impl.jac::Native lowering failed for expression "
             "'FuncCall'"
         ): (
             "`postinit` (#8234): the stub-module loads and prefetch lookups "
             "call methods that are themselves seams. With no owner to demote, "
             "each call refuses the module instead."
         ),
         (
             "type_evaluator.impl.jac::Native lowering failed for for-loop "
             "iterable element type 'typing_ambient_flat'"
         ): (
             "`postinit` (#8234): iterates a `set[str]` built by union, whose "
             "element type the emitter cannot recover."
         )
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
        pytest.skip(
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

"""Census seams as `<module>::<Type>.<method>` -> reason, stage files only."""
def _stage_seams(census: dict) -> dict[(str, str)] {
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(census.items()) {
        where = os.path.basename(path);
        if where not in STAGE_FILES {
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
    _assert_waivers_match(_stage_seams(census), TYPES_SEAM_WAIVERS, "types.jac");
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
        _stage_seams(census), DECL_PARSER_SEAM_WAIVERS, "ts_decl_parser.jac"
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
