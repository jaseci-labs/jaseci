"""The fused runtime's bring-up, composed: materialize the payload carried by
a host binary (`_fused.materialize`), then dlopen + bind its bundled libpython
(`_fused.embed`). Both the `jac` launcher stub and the desktop host start
here; they differ only in how they then initialize the interpreter.
"""

import from .embed { Embed, open_tree }
import from .materialize { materialize }
import from .report { die }
import from _exec_native { executable_path }

"""Materialize the runtime carried by `exe_path` and dlopen its libpython."""
def:pub open_runtime(exe_path: str) -> Embed {
    return open_tree(materialize(exe_path), exe_path);
}

"""The desktop host's bring-up: this process image IS the host binary
carrying the trailer payload. Materialize, dlopen, and initialize with no
argv (the embedded default `sys.argv == ['']`). Returns the bound embed; the
host owns what runs after init."""
def:pub engine_boot -> Embed {
    exe = executable_path();
    if exe == "" {
        die("cannot resolve executable path");
    }
    emb = open_runtime(exe);
    if emb.init_interpreter([], False) >= 0 {
        die("interpreter initialization failed");
    }
    return emb;
}
