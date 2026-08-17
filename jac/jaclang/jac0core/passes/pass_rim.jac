"""The driver rim of the pass base: construction, the program handle, the tier.

`transform.jac` is a *sealable* unit -- the base chain every compiler pass
inherits, whose constructor has to exist natively before a fused root can
construct a pass at all (#8288 M1 rung 2). Two things it used to own are not
decisions about a tree, and therefore belong on the rim rather than in the
unit:

* **The program handle.** `BaseTransform` declared ``prog: JacProgram`` -- a
  field typed by a class the native lane has no layout for, which is the one
  module-fatal gap the transform census kept reporting. No sealed pass reads
  it: `jcir_gen_pass`'s single read became `Import.native_only_drop` (#8305),
  the same way `sym_tab_build_pass`'s became `Module` facts (#8274). What is
  left are the unsealed, Python-side passes, and for them the handle is a
  *driver-stamped fact*: the rim sets it on the instance at construction,
  before ``__init__`` runs, so a pass body reads ``self.prog`` exactly as it
  always did while the sealable unit declares nothing.

* **The pass-tier tripwire.** Whether the loaded image seals a pass module
  natively is a statement about the *image*, not about a tree, and answering
  it needs the sealed-image registry and the serving binder -- host-side
  machinery no native unit can host. Seated in `BaseTransform.postinit` it
  demoted the constructor of every compiler pass; seated here it guards the
  same door from outside it.

Both ride the same seam: ``_PassConstruction.__call__``. A metaclass is what
makes the seam *universal* -- ``run_pass`` is the driver's front door, but
`precompile_bytecode`, the cross-backend equivalence harness and the sealed-
pass tests all construct passes directly, and the refusal has to fire for
those too. Silently running a bytecode pass body that the image claims to
serve natively is the #8178/#8139 failure mode; a guard with a way around it
is not a guard.

The rim is deliberately *field-free and postinit-free*, so that as a base it
is shaped exactly like the `ABC` it replaces -- section 11.1 of
`fused-pipeline.md` measured an `ABC` base as costing the native lane
nothing. A base carrying a slot would not be free: a native class over a
Python-side base keeps that base's slots on a Python shadow, which is the
hazard E5088 exists to refuse.

The module is rim machinery and never a sealable unit. It is written with
`class`, not `obj`, so no dataclass shape is imposed on a base that must stay
field-free; it names `jac0core.sealed` and `pass_serve`, the host-side
lookups no native unit can host; and both of those are imported lazily, at
the call, so the patched-`native_artifact_for` seam the tier tests use stays
the seam production reads. What keeps it out of a native closure is
`placement._comptime_only_import`: `transform.jac` imports exactly the one
name `PassRim`, which `codeinfo.NATIVE_COMPTIME_RIM_BASES` allows, so the
edge is erased before dependency resolution -- the same erasure that held
while this file was plain Python.
"""

import from abc { ABC, ABCMeta }

glob _NATIVE_PASS_TIER_MEMO: dict[type, str] = {},
     _NATIVE_SERVED_PASSES: set[str] = set();

"""Refuse a bytecode pass body the loaded image claims to serve natively.

The verdict is memoized per class: a pass module is either sealed in this
image or it is not, and that cannot change under a running interpreter.
A sealed-but-unserved verdict triggers the serving binder once and is
re-checked, so first construction of a sealed pass is what binds the
artifacts rather than some separate startup step.
"""
def require_native_pass_tier(pass_type: type) {
    if pass_type not in _NATIVE_PASS_TIER_MEMO {
        fullname = getattr(pass_type, "__module__", "") or "";
        fresh = "";
        if fullname.startswith("jaclang.") {
            import from jaclang.jac0core.sealed { native_artifact_for }

            if native_artifact_for(fullname) is not None {
                fresh = fullname;
            }
        }
        _NATIVE_PASS_TIER_MEMO[pass_type] = fresh;
    }
    verdict = _NATIVE_PASS_TIER_MEMO[pass_type];
    if verdict and verdict not in _NATIVE_SERVED_PASSES {
        import from jaclang.jac0core.passes.pass_serve { bind_sealed_pass_artifacts }

        bind_sealed_pass_artifacts();
    }
    if verdict and verdict not in _NATIVE_SERVED_PASSES {
        raise RuntimeError(
            f"{pass_type.__name__}: this sealed image carries a native "
            f"artifact for {verdict}, but the pass's bytecode body was "
            "reached instead of the artifact serving it. The install is "
            "broken or the pass-serving layer is missing; reinstall or "
            "rebuild the payload."
        );
    }
}

"""The construction seam every pass instance passes through."""
class _PassConstruction(ABCMeta) {
    """Check the tier, stamp the program handle, then initialize."""
    def __call__(cls: type, *args: any, **kwargs: any) -> any {
        require_native_pass_tier(cls);
        try {
            prog = kwargs.pop("prog");
        } except KeyError {
            raise TypeError(
                f"{cls.__name__}: constructing a pass requires `prog`. The "
                "driver stamps the program handle on the instance -- the "
                "pass base declares no field for it, because a "
                "`JacProgram`-typed slot has no native layout."
            ) from None;
        }
        inst = cls.__new__(cls);
        inst.prog = prog;
        inst.__init__(*args, **kwargs);
        return inst;
    }
}

"""Base of the pass base chain: everything about a pass that is not a tree.

`BaseTransform` inherits this instead of `ABC`. It contributes no field
and no initializer, so the native lane sees the same opaque Python base it
already saw; what it contributes is the metaclass, and therefore the seam.
"""
class PassRim(ABC, metaclass=_PassConstruction) {}
