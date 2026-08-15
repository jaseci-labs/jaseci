"""The pass-tier tripwire: a sealed pass's bytecode body refuses to run.

Sealing wave 1 put four compiler passes into `NATIVE_SEAL_ROOTS`, so a
sealed image's manifest now claims their method bodies exist natively.
The parser already had the runtime half of that claim
(`_require_bootstrap_tier`: reaching the bytecode parser inside a sealed
image raises); these tests pin the pass equivalent,
`_require_native_pass_tier`, seated in `BaseTransform.postinit`, the one
facade every pass invocation passes through.

The contract:

  - a pass class whose module the loaded image seals natively refuses to
    run its bytecode `transform`, loudly, naming the module and the
    remedy -- silently executing bytecode the image claims to serve
    natively is the #8178/#8139 failure mode;
  - registering the module in `_NATIVE_SERVED_PASSES` (what the
    pass-serving binder will do once it binds the artifact) lets the same
    class construct, without any cache invalidation dance;
  - passes from modules the image does not seal, and passes from outside
    jaclang, never consult the image verdict and run bytecode legally --
    dev trees and images without pass roots are untouched.

The sealed-image claim is faked by patching `native_artifact_for`, the
same seam the tripwire reads in production; the per-class memo is cleared
around each patch so every test states its own precondition.
"""

import pytest;
import jaclang.jac0core.sealed as sealed;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.annex_pass { JacAnnexPass }
import from jaclang.jac0core.passes.transform {
    _NATIVE_PASS_TIER_MEMO,
    _NATIVE_SERVED_PASSES,
    Transform
}
import from jaclang.jac0core.program { JacProgram }

glob ANNEX_MODULE: str = "jaclang.jac0core.passes.annex_pass";

obj LocalPass(Transform[uni.Module, uni.Module]) {
    def transform(ir_in: uni.Module) -> uni.Module {
        return ir_in;
    }
}

def _fake_artifact(fullname: str) -> (tuple | None) {
    if fullname == ANNEX_MODULE {
        return ("/nonexistent/libjac_annex_pass.so", {});
    }
    return None;
}

def _run_annex -> object {
    return JacAnnexPass(ir_in=uni.Module.make_stub(), prog=JacProgram());
}


test "an unsealed tree runs a pass's bytecode body" {
    if sealed.native_artifact_for(ANNEX_MODULE) is not None {
        pytest.skip(
            "this runtime seals the pass natively; the refusal tests below "
            "are the ones that apply to it"
        );
    }
    _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    inst = _run_annex();
    assert isinstance(inst.ir_out, uni.Module) , "annex pass did not run";
    assert _NATIVE_PASS_TIER_MEMO.get(JacAnnexPass) == "" , (
        "a clean verdict must be memoized so later constructions skip the "
        "image lookup"
    );
}


test "a natively sealed pass refuses its bytecode body" {
    real = sealed.native_artifact_for;
    _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    sealed.native_artifact_for = _fake_artifact;
    try {
        with pytest.raises(RuntimeError, match=ANNEX_MODULE) {
            _run_annex();
        }
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
        with pytest.raises(RuntimeError, match="bytecode body") {
            _run_annex();
        }
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
        with pytest.raises(RuntimeError, match="rebuild the payload") {
            _run_annex();
        }
    } finally {
        sealed.native_artifact_for = real;
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    }
}


test "the memoized verdict still refuses on the next construction" {
    real = sealed.native_artifact_for;
    _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    sealed.native_artifact_for = _fake_artifact;
    try {
        with pytest.raises(RuntimeError) {
            _run_annex();
        }
        assert _NATIVE_PASS_TIER_MEMO.get(JacAnnexPass) == ANNEX_MODULE;
    } finally {
        sealed.native_artifact_for = real;
    }
    try {
        with pytest.raises(RuntimeError) {
            _run_annex();
        }
    } finally {
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    }
}


test "registering the served pass lifts the refusal without cache games" {
    real = sealed.native_artifact_for;
    _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    sealed.native_artifact_for = _fake_artifact;
    try {
        with pytest.raises(RuntimeError) {
            _run_annex();
        }
        _NATIVE_SERVED_PASSES.add(ANNEX_MODULE);
        inst = _run_annex();
        assert isinstance(inst.ir_out, uni.Module) , (
            "a served pass must run even though the refusing verdict is "
            "already memoized"
        );
    } finally {
        _NATIVE_SERVED_PASSES.discard(ANNEX_MODULE);
        sealed.native_artifact_for = real;
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    }
}


test "unsealed and non-jaclang passes never trip while another is sealed" {
    real = sealed.native_artifact_for;
    sealed.native_artifact_for = _fake_artifact;
    try {
        inst = LocalPass(ir_in=uni.Module.make_stub(), prog=JacProgram());
        assert isinstance(inst.ir_out, uni.Module) , (
            "a pass from an unsealed module was blocked by another module's " "artifact"
        );
    } finally {
        sealed.native_artifact_for = real;
        _NATIVE_PASS_TIER_MEMO.pop(LocalPass, None);
    }
}
