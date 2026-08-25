"""Regression tests for native RC move-lowering (#6905 payoff, borrow-checker split).

When an assignment `b = a` binds a bare local `Name` that the native
the core `RcFactsPass` proves safe (LOCAL source, every use an alias-value, dead-out
at the move site), the native pass lowers it as a MOVE instead of an alias-copy:
it skips the defensive `__rc_retain` and nulls the source slot so the source's
later scope/iter cleanup release is a no-op. The destination inherits the single
reference and frees it exactly once.

These tests lock both halves: that the retain is actually elided (IR count) and
that the result is sound at runtime (no leak, no double free over a heavy loop).

The proof is native-owned and does NOT depend on the ownership checker: the
elision lives in the native codegen path rather than the analysis schedule.

The same guard covers a second source of ownership: a type coercion applied to
the assigned value can itself MINT a fresh owned temporary (a list flavor change
lowers to a spread-copy into a new list). The guard must read the coerced value,
not the pre-coercion one, or that temporary is retained once more than it is
released and leaks along with everything it holds.

The mirror case is an owned value nobody disposes of. Returning a borrowed
element (`return self.toks[0]`) retains it so the caller gets an owned
reference; reading a field off that result (`s.current().k`) then has to release
it, because unlike a method call the field read never hands the receiver to the
call machinery that would have freed it.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }
import from jaclang.compiler.passes.native.na_ir_gen_pass { NaIRGenPass }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Stand-in for `_can_native_move_lower` that disables move-lowering (baseline)."""
def _no_move_lower(pass_self: any, nd: any) -> bool {
    return False;
}

"""Compile a fixture and return (engine, ir). Defaults to the nacompile path."""
def compile_fixture(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Count emitted __rc_retain call sites, optionally with move-lowering off."""
def retain_calls(fixture: str, move_lower: bool) -> int {
    orig = NaIRGenPass._can_native_move_lower;
    if not move_lower {
        _napatch: any = NaIRGenPass;
        _napatch._can_native_move_lower = _no_move_lower;
    }
    try {
        (eng, ir) = compile_fixture(fixture);
        return str(ir.gen.llvm_ir).count('call void @"__rc_retain"');
    } finally {
        NaIRGenPass._can_native_move_lower = orig;
    }
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}

"""Count __rc_retain call sites emitted inside one function's body."""
def retain_calls_in(fixture: str, fn_name: str) -> int {
    (eng, ir) = compile_fixture(fixture);
    body = str(ir.gen.llvm_ir).split(f'define i64 @"{fn_name}"')[1].split("\n}")[0];
    return body.count('call void @"__rc_retain"');
}

"""Count RC ops of one kind against an SSA value in a function body.

`kind` is "release" or "retain". Counting bare bitcasts of the value counts
both, so a regression emitting a retain where a release belongs would leave the
total unchanged and pass -- and a leak does not crash the runtime half either,
so nothing else would catch it. The cast's own SSA name carries the kind, which
is what makes the two distinguishable.
"""
def rc_ops_of(fixture: str, fn_name: str, ssa_name: str, ty: str, kind: str) -> int {
    (eng, ir) = compile_fixture(fixture);
    body = str(ir.gen.llvm_ir).split(f'define i64 @"{fn_name}"')[1].split("\n}")[0];
    n = 0;
    for line in body.splitlines() {
        if f'bitcast %"{ty}"* %"{ssa_name}" to i8*' in line
            and f'%"rc.{kind}.cast' in line {
            n += 1;
        }
    }
    return n;
}

test "move-lowering elides exactly the `b = a` alias retain" {
    # A/B on identical IR: the ONLY difference is whether the move is lowered.
    off = retain_calls("move_elision.jac", False);
    on = retain_calls("move_elision.jac", True);
    assert off - on == 1 , f"move-lowering should elide exactly one retain call; off={off} on={on}";
    # `take(x: Box)` receives an i64 (pointer-as-int), so the aliasing `b = a`
    # is the sole retain; move-lowering removes it entirely.
    assert on == 0 , f"expected 0 retain calls after move-lowering, got {on}";
}

test "move-lowering nulls the source slot (keeps the free sound)" {
    (eng, ir) = compile_fixture("move_elision.jac");
    text = str(ir.gen.llvm_ir);
    # Nulling the moved-from slot is what makes eliding the retain sound: the
    # source's cleanup release then loads null and is a no-op, so the object is
    # freed exactly once (by the destination's cleanup).
    assert 'store %"Box"* null, %"Box"** %"a"' in text , "move source 'a' was not nulled after the move";
}

test "move-lowering is sound at runtime: correct result, no leak, no double free" {
    (eng, _) = compile_fixture("move_elision.jac");
    f = get_func(eng, "run_moves", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
    # A heavy loop: a double free would corrupt the heap and crash here; a leak
    # would grow RSS unbounded. Reaching the assert cleanly proves neither.
    assert f(400000) == 400000;
}

test "a coercion that mints an owned value gets its retain elided too" {
    # `stack = nxt` needs a list flavor coercion, which builds a FRESH owned list.
    # Reading ownership off the pre-coercion value calls it borrowed and emits a
    # retain the fresh list never sees released -- rc parks at 1 and it is never
    # freed. Every value in run_coerced is freshly minted, so the correct count
    # is zero.
    n = retain_calls_in("coerce_owned_assign.jac", "run_coerced");
    assert n == 0 , (
        f"a coerced owned temporary must not be retained; got {n} retain call(s)"
    );
}

test "the coerced-assign elision is sound at runtime" {
    (eng, _) = compile_fixture("coerce_owned_assign.jac");
    f = get_func(eng, "run_coerced", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
    # Heavy loop: eliding a retain that was actually needed would free the list
    # early and corrupt the heap here.
    assert f(400000) == 400000;
}

test "a field read releases the owned receiver it consumed" {
    # `s.current()` hands back an owned reference; `.k` reads through it and is
    # its only consumer. Without a release the element's refcount climbs once
    # per read, so the stream that owns it can never be freed either -- the
    # shape the jac parser hits on every `self.current().kind`.
    n = rc_ops_of(
        "field_read_owned_receiver.jac", "run_reads", "call.current", "Tok", "release"
    );
    assert n == 1 , (f"the consumed receiver must be released exactly once; got {n}");
    r = rc_ops_of(
        "field_read_owned_receiver.jac", "run_reads", "call.current", "Tok", "retain"
    );
    assert r == 0 , (f"the receiver is dropped, not aliased; got {r} retain(s)");
}

test "releasing the field-read receiver is sound at runtime" {
    (eng, _) = compile_fixture("field_read_owned_receiver.jac");
    f = get_func(eng, "run_reads", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
    # Releasing a receiver still owned elsewhere would free the element early
    # and corrupt the heap over a heavy loop.
    assert f(400000) == 400000;
}

test "a property read is left alone, not double-retained" {
    # A property read is a call and its return already retained what it hands
    # back, but that value carries no ownership flag. Consuming the receiver
    # here would retain it a second time -- trading the receiver leak for a
    # value leak, which is strictly worse. Until accessor results are flagged
    # owned at their source, this read keeps its old behaviour.
    (eng, ir) = compile_fixture("property_read_owned_receiver.jac");
    body = str(ir.gen.llvm_ir).split('define i64 @"run_props"')[1].split("\n}")[0];
    assert '%"acc.v.__get__"' in body , "fixture must exercise a property read";
    assert 'bitcast %"Val"* %"acc.v.__get__"' not in body , (
        "the accessor result must not be RC-touched at the read site"
    );
}
