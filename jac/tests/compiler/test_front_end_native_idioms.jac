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
import types;
import jaclang.jac0core.helpers as helpers_mod;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.codeinfo { native_safe_sym }
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
# pascal_to_snake / native_safe_sym: `re.sub` -> explicit character loops
# ─────────────────────────────────────────────────────────────────────

# Both functions used `re.sub` with an ASCII-only character class, so their
# real contract is code-point ranges, not the Unicode-aware `str` predicates
# an eyeballed rewrite reaches for: `"É".isupper()` and `"é".isalnum()` are
# both True, while `[A-Z]` and `[a-zA-Z0-9_]` match neither. These pin the
# regex semantics so a loop that drifts to `isupper`/`isalnum` fails here.
test "pascal_to_snake splits on ASCII capitals only" {
    assert pascal_to_snake("") == "";
    assert pascal_to_snake("A") == "a";
    assert pascal_to_snake("a") == "a";
    assert pascal_to_snake("AB") == "a_b";
    assert pascal_to_snake("HTTPServer") == "h_t_t_p_server";
    assert pascal_to_snake("Foo2Bar") == "foo2_bar";
    assert pascal_to_snake("2Fast") == "2_fast";
    assert pascal_to_snake("foo_bar") == "foo_bar";
    assert pascal_to_snake("_Leading") == "__leading";
    assert pascal_to_snake("Multi\nLine") == "multi\n_line";
}

test "pascal_to_snake never splits before a non-ASCII capital" {
    assert pascal_to_snake("FooÉbar") == "fooébar";
    assert pascal_to_snake("Éclair") == "éclair";
    assert pascal_to_snake("CaféBar") == "café_bar";
}

"""Strip the sha1 disambiguator native_safe_sym appends to its sanitized stem."""
def safe_sym_stem(src: str) -> str {
    return native_safe_sym(src).rsplit("_", 1)[0];
}

test "native_safe_sym replaces every non-ASCII-word character with underscore" {
    assert safe_sym_stem("plain") == "plain";
    assert safe_sym_stem("pkg.mod") == "pkg_mod";
    assert safe_sym_stem("a/b\\c.d-e f") == "a_b_c_d_e_f";
    assert safe_sym_stem("Mixed_CASE09") == "Mixed_CASE09";
    assert safe_sym_stem("") == "";
    assert safe_sym_stem("trailing.") == "trailing_";
}

test "native_safe_sym treats non-ASCII letters as unsafe" {
    assert safe_sym_stem("café") == "caf_";
    assert safe_sym_stem("naïve_mod") == "na_ve_mod";
}

test "native_safe_sym keeps the kernel modules unhashed" {
    assert native_safe_sym("osp_kernel") == "osp_kernel";
    assert native_safe_sym("fmt_kernel") == "fmt_kernel";
}

test "native_safe_sym keeps distinct sources distinct after sanitizing" {
    assert native_safe_sym("a.b") != native_safe_sym("a_b");
    assert safe_sym_stem("a.b") == safe_sym_stem("a_b");
    assert native_safe_sym("a.b") == native_safe_sym("a.b");
}

# ─────────────────────────────────────────────────────────────────────
# helpers.jac: the Python-only tenants moved to their own modules
# ─────────────────────────────────────────────────────────────────────

# `helpers.jac` sits under most of the front end, so every module-scope
# import it carried was inherited by every closure above it. The debugger
# (`pdb`/`dis`/`marshal`), the jac.toml reader (`tomllib`), and the traceback
# renderer (`traceback`) each moved to their own module, leaving `os` as the
# only module object bound at helpers' module scope. This is the acceptance
# criterion for that move, spelled so re-adding an import fails here.
test "helpers module scope binds os and nothing else" {
    bound = sorted(
        [
            nm
            for (nm, val) in vars(helpers_mod).items()
            if isinstance(val, types.ModuleType) and not nm.startswith("__")
        ]
    );
    assert bound == ["os"] , f"helpers.jac module scope grew imports: {bound}";
}

test "helpers no longer exports the moved symbols" {
    for gone in [
        "Jdb",
        "MalformedJacTomlError",
        "TracebackException",
        "debugger",
        "dump_traceback",
        "read_toml_with_encoding"
    ] {
        assert not hasattr(helpers_mod, gone) , (
            f"{gone} is still reachable from helpers.jac"
        );
    }
}

test "the moved symbols resolve from their new modules" {
    import from jaclang.jac0core.debugger { Jdb, debugger }
    import from jaclang.jac0core.tomlio {
        MalformedJacTomlError,
        read_toml_with_encoding
    }
    import from jaclang.jac0core.traceback_render { dump_traceback }
    assert isinstance(debugger, Jdb);
    assert callable(read_toml_with_encoding);
    assert callable(dump_traceback);
    assert issubclass(MalformedJacTomlError, Exception);
}

# The exception crosses a module boundary into `tomllib`, and existing
# `except MalformedJacTomlError` sites catch by identity, so the move has to
# leave exactly one class object reachable under exactly one base.
test "MalformedJacTomlError keeps its identity and its tomllib base" {
    import tempfile;
    import tomllib;
    import from jaclang.jac0core.tomlio {
        MalformedJacTomlError,
        read_toml_with_encoding
    }
    assert issubclass(MalformedJacTomlError, tomllib.TOMLDecodeError);
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", suffix=".toml", delete=False
    ) as f {
        f.write("this is not valid toml [[[\n");
        temp_path = f.name;
    }
    raised: (Exception | None) = None;
    try {
        try {
            read_toml_with_encoding(temp_path);
        } except tomllib.TOMLDecodeError as exc {
            raised = exc;
        }
    } finally {
        os.unlink(temp_path);
    }
    assert type(raised) is MalformedJacTomlError , (
        f"malformed toml must raise the one MalformedJacTomlError, got {raised!r}"
    );
    assert getattr(raised, "file_path") == temp_path;
}

# ─────────────────────────────────────────────────────────────────────
# runtime reflection -> frozen name tables
# ─────────────────────────────────────────────────────────────────────

# Two passes asked the running interpreter what names exist -- `dir(builtins)`
# for the undefined-name check, `dir(TestCase())` for the assert stubs a
# `test` block gets. Both are now tables generated from CPython 3.14. These
# are the drift alarms: if a CPython upgrade changes either surface, they
# fail here with the exact delta, and the tables get regenerated.
test "the frozen builtins table matches the running interpreter" {
    import builtins;
    import from jaclang.compiler.passes.main.static_analysis_pass { BUILTIN_NAMES }
    live = set(dir(builtins));
    assert BUILTIN_NAMES == live , (
        f"regenerate BUILTIN_NAMES: missing {sorted(live - BUILTIN_NAMES)}, "
        f"stale {sorted(BUILTIN_NAMES - live)}"
    );
}

test "the frozen TestCase assert table matches the running interpreter" {
    import from unittest { TestCase }
    import from jaclang.jac0core.passes.sym_tab_build_pass { TEST_ASSERT_METHOD_NAMES }
    live = [
        j
        for j in dir(TestCase())
        if j.startswith('assert')
    ];
    assert list(TEST_ASSERT_METHOD_NAMES) == live , (
        f"regenerate TEST_ASSERT_METHOD_NAMES: live surface is {live}"
    );
}

test "a test block still binds the assert names to symbols" {
    import from jaclang.jac0core.unitree { Name }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "_idiom_test_asserts.jac"),
        use_str="test \"probe\" {\n"
        "    assertEqual(1, 1);\n"
        "    assertNotIn(2, [1]);\n"
        "}\n",
        options=CompileOptions(type_check=False)
    );
    bound = {
        nd.value: (nd.sym is not None)
        for nd in ir.get_all_sub_nodes(typ=Name)
        if nd.value.startswith("assert")
    };
    assert bound == {"assertEqual": True, "assertNotIn": True} , (
        f"assert stubs did not bind: {bound}"
    );
}

test "Jdb.has_breakpoint still reads the compiled bytecode" {
    import marshal;
    import from jaclang.jac0core.debugger { debugger }
    with_bp = compile("breakpoint()\n", "<probe>", "exec");
    without_bp = compile("x = 1\n", "<probe>", "exec");
    assert debugger.has_breakpoint(marshal.dumps(with_bp));
    assert not debugger.has_breakpoint(marshal.dumps(without_bp));
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
