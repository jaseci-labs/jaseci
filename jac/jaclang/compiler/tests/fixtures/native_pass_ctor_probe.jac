"""A pass constructed inside a native root, which is the rung-3 gate.

Measured by `test_pass_base_chain_lowers.jac`. `probe_construct` is the
smallest thing a fused root has to be able to do: construct a pass over a
tree it already holds and read a field back off it. The construction
passes `prog` because the driver rim demands one at every pass
construction -- the Python lane raises a `TypeError` without it
(`test_sealed_pass_tier.jac` pins that), and with the base chain visible
to the native compile since B4 (#8323), the native lane refuses the same
omission at compile time instead of discovering it at run time.
"""

import from jaclang.jac0core.unitree { Module, Name }
import from jaclang.jac0core.passes.uni_pass { UniPass }

obj LocalCountPass(UniPass) {
    has seen: int = 0;

    def enter_name(nd: Name) {
        self.seen = self.seen + 1;
    }
}

def probe_construct(m: Module, prog: any) -> int {
    p = LocalCountPass(ir_in=m, prog=prog);
    return p.seen;
}
