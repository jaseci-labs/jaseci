"""The JCIR emitter in the fused seal: registration and the clean-member pins.

The emitter used to be its own seal root with its own closure table; under
the fused seal (#8707) it is one served module of the one native unit, and
the two-way seam-vs-waiver discipline for the whole closure lives in
`test_sealed_demotion_audit.jac` (the closure census itself in
`test_pass_seal_baselines.jac`). The emitter's four waived residue
families all cleared when the whole compiler fused into one unit -- the
larger closure gave their blocking reads in-unit layouts -- so it now
carries no waiver of its own.

What this file still pins is the emitter-specific claim no shared census
states: the JCIR container format and the baked facts must carry no seam
of their own. `codegen_ir`'s `decode_ops` once shipped as an advertised,
absent symbol that cost a three-minute link to find; a clean-member pin is
what keeps the container format from ever reaching that state again.

The measurement is a source-lane one: under a sealed jaclang image the
coverage reads the image's trust boundary instead of the unit's own
coupling, so the coverage helper skips there.
"""

import from jaclang.dist.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_REFUSED_MODULES,
    NATIVE_SEAL_SERVED_MODULES
}
import from tests.compiler.backends.native.seal_support {
    AUDIT_ROOT_REL,
    PKG_PATH,
    _seams_by_key,
    write_audit_seal_root
}

glob JCIR_ROOT: str = "compiler/backends/py/jcir_gen_pass.jac";

"""Closure members that must carry no seam of their own."""
glob JCIR_CLEAN_MEMBERS: tuple = (
         "compiler/backends/py/codegen_ir.jac",
         "compiler/backends/py/jcir_facts.jac",
         "compiler/frontend/constant.jac",
         "compiler/frontend/diagnostics.jac",
         "compiler/frontend/srcloc.jac",
         "runtime/na_stdlib/textwrap.jac"
     );

"""The fused unit's seams, via the source-lane stand-in root."""
def _fused_seams -> dict {
    write_audit_seal_root();
    try {
        return _seams_by_key(AUDIT_ROOT_REL);
    } finally {
        (PKG_PATH / AUDIT_ROOT_REL).unlink(missing_ok=True);
    }
}


test "the jcir emitter is served by the fused seal" {
    assert JCIR_ROOT in NATIVE_SEAL_SERVED_MODULES , (
        f"{JCIR_ROOT} is not served by the fused seal; the emitter fell "
        "out of the native unit"
    );
    assert JCIR_ROOT not in NATIVE_SEAL_REFUSED_MODULES , (
        f"{JCIR_ROOT} is both served and recorded as refused; it has to be "
        "one or the other"
    );
    for member in JCIR_CLEAN_MEMBERS {
        assert member in NATIVE_SEAL_CLOSURE , (
            f"{member} left NATIVE_SEAL_CLOSURE; the clean-member pin below "
            "would measure nothing"
        );
    }
}


test "the container format and the baked facts carry no seam" {
    seams = _fused_seams();
    for member in JCIR_CLEAN_MEMBERS {
        dirty = sorted(
            k
            for k in seams
            if k.startswith(member + "::")
        );
        assert not dirty , (
            f"{member} is in the emitter's sealed closure and has to stay "
            f"free of seams of its own; it grew {len(dirty)}:\n"
            + "\n".join(f"  {k}: {seams[k]}" for k in dirty)
        );
    }
}
