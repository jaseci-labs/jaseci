"""An ABC arm over an operand whose class inherits a Python-side base.

`PyBase` lives in a module the native import walk never registers, and it
inherits `abc.ABC` there, so `Kid`'s real MRO runs through classes this unit
only holds a shadow handle to. Which abstract base classes a `Kid` inhabits is
therefore not answerable from the native layout: reducing `Sequence` to the
builtin containers would report `False` for a `PyBase` that happened to inherit
one. The check refuses instead.
"""

import from collections.abc { Sequence }
import from pyb_base_lib { PyBase }

obj Kid(PyBase) {
    has extra: int = 1;
}

def chk -> int {
    k = Kid(label="x");
    if isinstance(k, Sequence) {
        return 1;
    }
    return 0;
}
