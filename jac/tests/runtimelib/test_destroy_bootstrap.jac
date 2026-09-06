import sys;
import from unittest.mock { patch }
import from jaclang { JacRuntime as Jac }

test "deleting ordinary values does not import graph cleanup modules" {
    # Cache invalidation can delete values while these modules are importing.
    # Ordinary Python values must not re-enter graph or region initialization.
    with patch.dict(
        sys.modules,
        {"jaclang.runtime.region": None, "jaclang.runtime.osp_kernel": None}
    ) {
        Jac.destroy({"discarded": 42});
        Jac.destroy([]);
    }
}
