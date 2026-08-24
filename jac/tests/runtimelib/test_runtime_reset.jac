"""Per-run runtime state is reset in one place, and that place cannot drift.

`JacRuntime` carries the process-global handles a run needs: the compiler,
the program, the thread pool, the execution context, the loaded-module table.
Anything that reuses a process across runs -- the test pool's fork workers, a
language server, an embedded host -- has to put those back to a clean state
between runs, or the previous run's compilation unit stays reachable.

Doing that from the caller is how a slot gets missed: `_fresh_jac_state`
reset four of the five and left `compiler` behind, which kept a `JacCompiler`
and its internal program alive for the life of the worker. The reset belongs
next to the declarations, and the last test here fails if a new slot is added
without deciding what the reset does with it.
"""

import types;
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.test_runner { _fresh_jac_state }

glob PER_RUN_SLOTS: set = {
         "compiler",
         "program",
         "pool",
         "exec_ctx",
         "loaded_modules"
     },
     CONFIG_SLOTS: set = {"strict_permissions"};

test "a per-run reset drops the cached compiler" {
    JacRuntime.get_compiler();
    JacRuntime.loaded_modules["_probe"] = types.ModuleType("_probe");
    assert JacRuntime.compiler is not None;

    _fresh_jac_state();

    assert JacRuntime.compiler is None , (
        "the cached JacCompiler survived the reset; it holds an internal "
        "JacProgram, so every module that compiler loaded stays reachable "
        "for the life of the process"
    );
    assert not JacRuntime.loaded_modules , "the module table survived the reset";
}

test "the reset shuts the old thread pool down instead of abandoning it" {
    old = JacRuntime.pool;
    old.submit(len, "warm").result();
    _fresh_jac_state();
    assert JacRuntime.pool is not old , "the pool was reused, not replaced";
    raised = False;
    try {
        old.submit(len, "after");
    } except RuntimeError {
        raised = True;
    }
    assert raised , (
        "the previous pool still accepts work, so it was abandoned rather "
        "than shut down and its worker threads outlive the run"
    );
}

test "every process-global slot is classified, so the reset cannot drift" {
    live: set = set();
    for (name, value) in vars(JacRuntime).items() {
        if name.startswith("_")
            or callable(value)
            or isinstance(value, (classmethod, staticmethod, property)) {
            continue;
        }
        live.add(name);
    }
    unclassified = live - PER_RUN_SLOTS - CONFIG_SLOTS;
    assert not unclassified , (
        f"JacRuntime grew process-global state that no one classified: "
        f"{sorted(unclassified)}. Add it to PER_RUN_SLOTS and reset it in "
        "JacRuntime.reset_process_state, or to CONFIG_SLOTS if it is "
        "process configuration that must survive a reset."
    );
    assert PER_RUN_SLOTS <= live , (
        f"PER_RUN_SLOTS names slots JacRuntime no longer has: "
        f"{sorted(PER_RUN_SLOTS - live)}"
    );
}
