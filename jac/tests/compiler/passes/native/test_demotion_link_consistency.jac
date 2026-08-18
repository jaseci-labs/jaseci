"""A demotion verdict binds every emission in the unit, cycles included.

`_rename_demoted_symbol` moves a demoted body to `X.__jac_demoted` and pops
the original from the module's globals. A caller in another module of the
same unit that emitted BEFORE the callee's verdict landed still calls the
unsuffixed name -- a bare declaration that survives the link and kills the
sealed artifact at dlopen (`undefined symbol: pretty_print_source_location`
was the production instance: `Alert.pretty_print` in `transform.jac` was
compiled while `helpers.jac` sat inflight above it in the import walk, so
`_imported_function_demotions` answered None and the caller assumed live).

The law is #8272's, applied intra-unit: verdict-before-emission. The fix
records every callable declared live under an unknowable verdict
(`_na_unverified_live`), and the link phase -- the top frame, where every
verdict is resolvable -- re-validates the record and re-emits the caller
when a landed verdict disagrees. The re-emission is loud, and a caller that
cannot converge is E5028 rather than a broken artifact.

The fixtures are the production shape in miniature: `demote_cycle_helpers`
defines a function that demotes (`str % int`) and holds an `import type`
back-edge to the caller so the caller compiles under its inflight window;
`demote_cycle_caller.CycleReporter.describe` calls the demoted function;
`demote_cycle_root` imports them callee-first so the walk takes the failing
order deterministically.
"""

import os;
import re;
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
     _MEMO: list = [];

"""Compile the cycle root as a native unit; (linked IR text, census)."""
def _linked_unit -> tuple {
    if _jaclang_image() is not None {
        testskip("a sealed image measures its trust boundary, not this");
    }
    if _MEMO {
        return _MEMO[0];
    }
    path = os.path.join(FIXTURES, "demote_cycle_root.jac");
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
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
    assert ir is not None and ir.gen.llvm_ir is not None , (
        "the cycle root produced no linked native IR, so nothing below "
        "measures anything"
    );
    result = (str(ir.gen.llvm_ir), census, );
    _MEMO.append(result);
    return result;
}


"""Symbols the unit declares but never defines, whose demoted twin exists."""
def _dangling_demoted(ir_text: str) -> list[str] {
    name_re = r'@(?:"([^"]+)"|([A-Za-z0-9_.$\-]+))\s*\(';
    defined: set[str] = set();
    declared: set[str] = set();
    for m in re.finditer(r'^define\b[^@\n]*' + name_re, ir_text, re.MULTILINE) {
        defined.add(m.group(1) or m.group(2));
    }
    for m in re.finditer(r'^declare\b[^@\n]*' + name_re, ir_text, re.MULTILINE) {
        declared.add(m.group(1) or m.group(2));
    }
    return sorted(
        n
        for n in (declared - defined)
        if f"{n}.__jac_demoted" in defined
    );
}


test "the fixture's callee still demotes, so the cycle measures something" {
    (ir_text, census) = _linked_unit();
    helpers_rec = census.get(
        os.path.realpath(os.path.join(FIXTURES, "demote_cycle_helpers.jac"))
    );
    seams = {
        str(s).partition(": ")[0]
        for s in ((helpers_rec or {}).get("seams") or [])
    };
    assert "cycle_bad_fmt" in seams , (
        "cycle_bad_fmt no longer demotes -- `str % int` learned to lower. "
        "Real progress, but this suite needs a construct that still demotes "
        "or every test here is vacuous; swap the fixture's body and say so"
    );
    assert "cycle_bad_fmt.__jac_demoted" in ir_text , (
        "the demoted stub itself fell out of the linked unit; the rename "
        "convention changed and this scan needs to follow it"
    );
}


test "no emission in the unit calls a symbol its verdict popped" {
    (ir_text, _census) = _linked_unit();
    dangling = _dangling_demoted(ir_text);
    assert not dangling , (
        f"the linked unit declares {dangling} without defining them, and "
        "each has a `.__jac_demoted` twin -- a caller was emitted before its "
        "callee's demotion verdict landed and never re-emitted. This is the "
        "shape that reaches dlopen as `undefined symbol` in a sealed "
        "artifact (#8320 / #8323 A1)"
    );
}


test "the betrayed caller re-emits and cascades honestly" {
    (_ir_text, census) = _linked_unit();
    caller_rec = census.get(
        os.path.realpath(os.path.join(FIXTURES, "demote_cycle_caller.jac"))
    );
    seams = {
        str(s).partition(": ")[0]
        for s in ((caller_rec or {}).get("seams") or [])
    };
    assert "CycleReporter.describe" in seams , (
        "CycleReporter.describe kept a live body against a demoted callee "
        "(or its cascade demotion went unrecorded). The re-emission must "
        "produce the same verdict the acyclic order produces: the caller of "
        "a demoted function demotes, and the census says so"
    );
}
