"""`abc`'s abstractness markers are compile-time, so they stop poisoning placement.

`import from abc { ABC }` used to be an unresolved import, which the placement
solver treats as an all-or-nothing verdict on the whole module: one such line
demotes the file and, through `_native_deps_ok`, every module whose import
closure reaches it. Two of the compiler's most widely-reached modules carry
exactly that line -- `type_system/types.jac` and `jac0core/passes/transform.jac`,
the base every pass inherits -- so the reach was most of the pass tree.

Nothing about `ABC` needs to survive to run time. Jac models abstractness with
its own bodiless-ability rule, and the *server* lane emits `@abstractmethod`
from `Ability.is_abstract` rather than reading it, so the Python spelling is a
restatement of something the compiler already knows.

The erasure is scoped to names, not to the module: `abc` exposes machinery that
is emphatically not compile-time (`ABCMeta.register` performs virtual
subclassing, which the native lane has no way to honor), so only `ABC` and
`abstractmethod` are waved through and every other spelling still refuses.
That boundary is what the refusal tests below pin.
"""

import ctypes;
import os;
import from jaclang.jac0core.parser { parse as rd_parse }
import from jaclang.jac0core.placement { scan_native_blockers }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { JAC_ROOT, native_force_opts }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "native", "fixtures"
     );


"""The placement solver's blocker verdict for a snippet, or 'OK' if it has none."""
def scan_verdict(src: str) -> str {
    (mod, had_err) = rd_parse(
        src, os.path.join(FIXTURES, "abc_scan_probe.jac"), prog=JacProgram()
    );
    assert not had_err , f"fixture source did not parse: {src!r}";
    (reason, _deps) = scan_native_blockers(mod, FIXTURES, allow_pub=True);
    return reason or "OK";
}


"""Wrap a snippet in a module the scanner will accept apart from the import."""
def module_with(import_line: str) -> str {
    return import_line + "\n\nwith entry {\n    print(1);\n}\n";
}


test "an abc marker import no longer blocks native placement" {
    assert scan_verdict(module_with("import from abc { ABC }")) == "OK" , (
        "`import from abc { ABC }` still demotes the module, so every import "
        "closure reaching it stays demoted too"
    );
    assert scan_verdict(module_with("import from abc { ABC, abstractmethod }"))
        == "OK" , "the two erasable abc names are not accepted together";
}


test "a non-erasable abc name still refuses" {
    verdict = scan_verdict(module_with("import from abc { ABCMeta }"));
    assert verdict != "OK" , (
        "`ABCMeta` was waved through -- `register` performs virtual "
        "subclassing, which no native unit can honor"
    );
}


test "a bare abc module import still refuses" {
    verdict = scan_verdict(module_with("import abc;"));
    assert verdict != "OK" , (
        "a bare `import abc` binds a module object whose attributes are read "
        "at run time; only named imports are erasable"
    );
}


test "an ABC base and an abstractmethod lower natively" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "abc_marker_base.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the abc fixture";
}


test "the erased markers leave the archetype's behavior intact" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "abc_marker_base.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the abc fixture";
    addr = eng.get_function_address("run");
    assert addr != 0 , "'run' is absent from the JIT engine";
    run = ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
    assert run() == 25 , (
        f"the concrete override did not run through the erased abstract "
        f"declaration: got {run()}, expected 25"
    );
}
