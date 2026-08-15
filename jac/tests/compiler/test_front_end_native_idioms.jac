"""The front end's Python-isms, and the plain-Jac forms that replaced them.

The #8039 census sweep showed the compiler front end's native gaps were not
backend omissions but source idioms: constructs the native capability
authority rejects, reached for where Jac (or plain data) already said the
same thing. This file pins the replacements behaviorally, and guards the
native boundary each one was crossing.

Scope note: the sweep's original table over-collected by globbing
`jac0core/*.jac`. `archetype.jac` and `runtime.jac` are NOT imported by the
front end -- they are the object-spatial runtime and the driver -- so their
`@cached_property` / `object.__new__` / `cls` uses are outside the native
closure and are deliberately untouched.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.helpers { pascal_to_snake }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Run a snippet through the front-end check schedule with the native
capability authority on -- the `jac check` path that surfaces E5090."""
def check_na_inline(label: str, code: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, f"_idiom_{label}.jac"),
        use_str=code,
        options=CompileOptions(
            type_check=True,
            no_cgen=True,
            force_codespace="native",
            force_target_program=True
        )
    );
    return prog;
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

"""Format errors for assertion messages."""
def fmt_errors(prog: JacProgram) -> str {
    return str([str(e) for e in prog.errors_had]);
}

# ─────────────────────────────────────────────────────────────────────
# pascal_to_snake: @lru_cache -> an explicit module-level dict cache
# ─────────────────────────────────────────────────────────────────────

test "pascal_to_snake converts the shapes the compiler actually feeds it" {
    assert pascal_to_snake("FuncCall") == "func_call";
    assert pascal_to_snake("Name") == "name";
    assert pascal_to_snake("KWPair") == "k_w_pair";
    assert pascal_to_snake("JsxElement") == "jsx_element";
    assert pascal_to_snake("") == "";
}

# The `@lru_cache(maxsize=256)` this function used to carry was sized to the
# ~150 unitree node types, the fingerprint of the old reflective visitor
# dispatch (`getattr(self, f"enter_{pascal_to_snake(type(nd).__name__)}")`).
# `gen_uni_dispatch` (#6942 A.1) replaced that with static accept_enter /
# accept_exit, so the hot loop the cache existed for is gone: what remains
# are comptime (`ct.snake`), the generators, and the `jac tool` surface, all
# of which call it a bounded number of times. The cache was dropped rather
# than re-spelled -- a dict memo is three lines if measurement ever asks.
test "pascal_to_snake is deterministic across repeat calls without a cache" {
    probe = "AVeryDistinctArchetypeName";
    first = pascal_to_snake(probe);
    assert first == "a_very_distinct_archetype_name";
    assert pascal_to_snake(probe) == first;
}

# ─────────────────────────────────────────────────────────────────────
# placement: typ.__name__ -> the name carried beside the type
# ─────────────────────────────────────────────────────────────────────

# `scan_native_blockers` read `typ.__name__` off entries of a constant class
# list purely to name the offender in a diagnostic string. The name now rides
# beside the type so the runtime does no reflection. Reflection is fine HERE --
# a test is never lowered natively -- so this pins the pair against drift.
test "placement blocker tables carry the real class name" {
    import from jaclang.jac0core.placement {
        PLACEMENT_NATIVE_REJECT_NODES,
        PLACEMENT_SV_SIGNAL_NODES
    }
    tables = [PLACEMENT_SV_SIGNAL_NODES, PLACEMENT_NATIVE_REJECT_NODES];
    seen = 0;
    for table in tables {
        for (nd_name, typ) in table {
            assert nd_name == typ.__name__ , (
                f"placement table name {nd_name!r} drifted from {typ.__name__!r}"
            );
            seen += 1;
        }
    }
    assert seen == 3 , f"expected 3 tabled node types, saw {seen}";
}

test "scan_native_blockers names the offending node from the table" {
    import from jaclang.jac0core.placement { scan_native_blockers }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "_idiom_jsx_blocker.jac"),
        use_str="def view -> any {\n    return <div>hi</div>;\n}\n",
        options=CompileOptions(type_check=False)
    );
    (reason, _deps) = scan_native_blockers(ir, os.path.dirname(FIXTURES));
    assert reason == "contains JsxElement" , f"got reason {reason!r}";
}

test "guardrail: @lru_cache demotes where a dict cache does not" {
    import from tests.support { native_force_opts }
    dec = JacProgram();
    dec_ir = dec.compile(
        file_path=os.path.join(FIXTURES, "_idiom_lru_cache.jac"),
        use_str="import from functools { lru_cache }\n"
        "@lru_cache(maxsize=8)\n"
        "def twice(n: int) -> int { return n * 2; }\n",
        options=native_force_opts()
    );
    assert not has_error_code(dec, "E5090") , (
        f"a dynamically-decorated function must demote to its Python "
        f"implementation (which applies @lru_cache), got {fmt_errors(dec)}"
    );
    assert dec_ir.gen.native_layout is not None , (
        "whole-module native compile aborted"
    );
    assert "twice" not in dec_ir.gen.native_layout.functions , (
        "the @lru_cache function must be demoted out of the native layout, "
        "never run undecorated"
    );
    memo = check_na_inline(
        "dict_memo",
        "glob _MEMO: dict[int, int] = {};\n"
        "def twice(n: int) -> int {\n"
        "    got = _MEMO.get(n);\n"
        "    if got is not None { return got; }\n"
        "    out = n * 2;\n"
        "    _MEMO[n] = out;\n"
        "    return out;\n"
        "}\n"
        "with entry { print(twice(3)); }\n"
    );
    assert not has_error_code(memo, "E5090") , (
        f"dict memo should clear the gate: {fmt_errors(memo)}"
    );
}
