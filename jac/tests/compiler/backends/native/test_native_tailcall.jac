"""Acceptance tests for guaranteed tail calls (`musttail`) on native.

Plan: jac/jaclang/NATIVE_TAILCALL_PLAN.md. Two families:

* POSITIVE — a `return f(...)` in an eligible function must be emitted
  as LLVM `musttail call` (asserted on the IR text; `musttail` is
  LLVM-verified, so the marker IS the O(1)-native-stack guarantee — a
  50M-frame in-process run would just kill the test runner on the old
  codegen) plus a safe-depth behavioral check through the JIT.

* NEGATIVE — shapes that must NEVER be musttail'd (work after the call,
  exception frame armed across the callee, signature mismatch) and RC
  shapes whose correctness must survive any epilogue reordering (owned
  local released per frame, owned argument handed off).
"""

import ctypes;
import from tests.support { compile_native, get_func }

"""Count `musttail` markers inside one function's IR body."""
def tc_musttail_in(ir: any, fn_name: str) -> int {
    text = str(ir.gen.llvm_ir);
    marker = f'define i64 @"{fn_name}"';
    start = text.find(marker);
    if start < 0 {
        marker = f'@"{fn_name}"';
        start = text.find(marker);
    }
    assert start >= 0 , f"function {fn_name} not in IR";
    body_end = text.find("\n}", start);
    body = text[start:body_end] if body_end > 0 else text[start:];
    return body.count("musttail");
}

"""Total musttail markers in the module (for whole-fixture negatives)."""
def tc_musttail_total(ir: any) -> int {
    return str(ir.gen.llvm_ir).count("musttail");
}

# ── POSITIVE ─────────────────────────────────────────────────────────────

test "tailcall: self-recursion emits musttail (the guarantee)" {
    (eng, ir) = compile_native("tailcall_self.jac");
    f = get_func(eng, "tc_count", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(50000, 0) == 50000;
    assert tc_musttail_in(ir, "tc_count") > 0 ,
        "return tc_count(...) must be a musttail call";
}

test "tailcall: mutual recursion emits musttail in both handlers" {
    (eng, ir) = compile_native("tailcall_mutual.jac");
    f = get_func(eng, "tc_is_even", ctypes.c_int64, ctypes.c_int64);
    assert f(50000) == 1;
    assert f(50001) == 0;
    assert tc_musttail_in(ir, "tc_is_even") > 0;
    assert tc_musttail_in(ir, "tc_is_odd") > 0;
}

test "tailcall: borrowed RC param threads through musttail" {
    (eng, ir) = compile_native("tailcall_borrowed.jac");
    f = get_func(eng, "tc_walk_drive", ctypes.c_int64, ctypes.c_int64);
    assert f(50000) == 4;
    assert tc_musttail_in(ir, "tc_walk") > 0;
}

test "tailcall: indirect call through a stored function value (T4)" {
    (eng, ir) = compile_native("tailcall_indirect.jac");
    f = get_func(eng, "tc_indirect_drive", ctypes.c_int64, ctypes.c_int64);
    # 2M-deep mutual recursion through closure-wrapped fn values: only
    # the env==null musttail fast path can survive this depth. The
    # closure box each frame allocates is released via the reordered
    # plan (leak would OOM long before 2M).
    assert f(2000000) == 1;
    assert f(2000001) == 0;
    assert tc_musttail_in(ir, "tc_even_i") >= 1 ,
        "indirect tail call should musttail on the env==null path";
}

test "tailcall: ternary else-arm is a tail position (T5)" {
    (eng, ir) = compile_native("tailcall_ternary.jac");
    f = get_func(eng, "tc_tern_drive", ctypes.c_int64, ctypes.c_int64);
    # 2M-deep accumulator recursion through the else arm; result is the
    # closed-form sum, so a dropped or double-counted frame is visible.
    assert f(2000000) == 2000000 * 2000001 // 2;
    assert tc_musttail_in(ir, "tc_tern") >= 1 ,
        "the call arm of a returned ternary should musttail";
}

# ── NEGATIVE ─────────────────────────────────────────────────────────────

test "tailcall: return-call inside try keeps its handler (no musttail)" {
    (eng, ir) = compile_native("tailcall_neg_try.jac");
    f = get_func(eng, "tc_guarded", ctypes.c_int64);
    assert f() == -1 , "raise inside callee must be caught by enclosing except";
    assert tc_musttail_in(ir, "tc_guarded") == 0 ,
        "exception frame must stay armed across the callee";
}

test "tailcall: try-enclosed call with MATCHING prototype still refused" {
    (eng, ir) = compile_native("tailcall_neg_try_samesig.jac");
    f = get_func(eng, "tc_guarded_same", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == -1 , "raise in callee must reach the enclosing except";
    # The armed setjmp frame lives in tc_guarded_same's stack frame; a
    # musttail would replace that frame under it (T3 regression: the
    # original neg_try only bailed via prototype mismatch).
    assert tc_musttail_in(ir, "tc_guarded_same") == 0 ,
        "try-enclosed return-call must never musttail, even same-sig";
}

test "tailcall: result-used call is never musttail" {
    (eng, ir) = compile_native("tailcall_neg_result_used.jac");
    f = get_func(eng, "tc_summy", ctypes.c_int64, ctypes.c_int64);
    assert f(500) == 500;
    assert tc_musttail_total(ir) == 0;
}

test "tailcall: signature mismatch / post-call coercion is never musttail" {
    (eng, ir) = compile_native("tailcall_neg_sig.jac");
    f = get_func(eng, "tc_sig_caller", ctypes.c_int64, ctypes.c_int64);
    assert f(200) == 3;
    assert tc_musttail_in(ir, "tc_sig_caller") == 0;
}

test "tailcall: owned per-frame local — correct with no leak or early free" {
    (eng, ir) = compile_native("tailcall_rc_owned.jac");
    f = get_func(
        eng, "tc_owned_drive", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    # 20k calls x depth 100: a per-call leak or premature free surfaces as
    # wrong result / crash. T2: junk does not alias any argument, so its
    # release is reordered BEFORE the call and the call musttails.
    assert f(20000, 100) == 0;
    assert tc_musttail_in(ir, "tc_owned") >= 1 ,
        "disjoint owned-local release should reorder and musttail (T2)";
}

test "tailcall: owned argument handoff — callee sees a live value" {
    (eng, ir) = compile_native("tailcall_rc_handoff.jac");
    f = get_func(
        eng, "tc_handoff_drive", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert f(10000, 100) == 10000 * 3;
    # The argument IS the owned local: its reference must outlive this
    # frame, so the keep-alive epilogue wins and musttail is refused.
    assert tc_musttail_in(ir, "tc_consume") == 0 ,
        "handoff arg must keep the normal epilogue (no early free)";
}
