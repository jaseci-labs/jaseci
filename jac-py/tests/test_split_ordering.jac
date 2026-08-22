"""Split-ordering conformance lock.

Locks the compiler module-split's loading contract (VERIFIED 2026-08-22):
compiler_codegen must finish loading before any split sibling binds names
from it. Sibling-first entry is illegal and fails loudly - importing e.g.
compiler_defs directly pauses its body at its own codegen import, so
codegen's late-import block re-enters a partially initialized module and
raises "cannot import name ... from partially initialized module". This
file enters through product_compile (the legal path) and drives one full
native compile, so any regression of the split's loading order surfaces
here.
"""

import from objects { is_error }
import from product_compile { compile_source }


test "split: product-path entry compiles after full sibling graph load" {
    r = compile_source("1 + 2", "<split-ordering>", "eval", 0);
    assert not is_error(r), r;
}
