"""The driver rim of the pass base: the construction tripwire.

`transform.jac` is a *sealable* unit -- the base chain every compiler pass
inherits, whose constructor has to exist natively before a fused root can
construct a pass at all (#8288 M1 rung 2). What lives here is the one check
that is a statement about the *image* rather than about a tree: whether the
loaded image seals a pass module natively. Answering it needs the
sealed-image registry and the serving binder -- host-side machinery no
native unit can host. Seated in `BaseTransform.postinit` it demoted the
constructor of every compiler pass; seated here it guards the same door
from outside it.

The check rides `PassRim.__new__`, so it fires on every construction path:
`run_pass` is the driver's front door, but `precompile_bytecode`, the
cross-backend equivalence harness and the sealed-pass tests all construct
passes directly, and the refusal has to fire for those too. Silently
running a bytecode pass body that the image claims to serve natively is the
#8178/#8139 failure mode; a guard with a way around it is not a guard.

The rim is deliberately *slot-free and postinit-free*, so that as a base it
is shaped exactly like the `ABC` it replaces -- section 11.1 of
`fused-pipeline.md` measured an `ABC` base as costing the native lane
nothing, and a method contributes no slot. A pass that needs the program
handle declares `has prog: JacProgram` itself and tags itself
`static has HOST_PASS: bool = True`; the driver passes `prog` only to
tagged passes, so the sealable base chain never names a host type. The
module is rim machinery and never a sealable unit; it is written with
`class`, not `obj`, so no dataclass shape is imposed on a base that must
stay slot-free, and `placement._erased_only_import` erases the one edge
`transform.jac` has to it before dependency resolution.
"""

import from abc { ABC }

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
        import from jaclang.compiler.passes.pass_serve { bind_sealed_pass_artifacts }

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

"""Base of the pass base chain: check the tier, then allocate.

`allocate` is aliased through `any` because on a value of type `type`,
`__new__` resolves to overloads that create a class; the one-argument
allocation of an instance is `object.__new__`, reachable only once `cls`
is known concretely. Aliasing narrows the escape to this single expression
instead of untyping the whole body.
"""
class PassRim(ABC) {
    def __new__(cls: type, *args: any, **kwargs: any) -> any {
        require_native_pass_tier(cls);
        allocate: any = object.__new__;
        return allocate(cls);
    }
}
