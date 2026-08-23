"""Check-time capability rules for the type-shaped native lowering gaps (#8539 W2-F).

NaIRGenPass used to discover these shapes at codegen and report them as E5092
(demoting the owning function, or refusing the module when nothing owned the
construct). Each rule below is decided from checker facts alone inside
NativeCapabilityCheckPass, so it is part of the analysis schedule (`jac check`
sees it without running the backend) and lands in the module's capability
partition: demotable when a function owns the construct, a fatal E5090 when
none does. The same snippet in server context records nothing.

  "list display" / "set display" / "dict display" / "list comprehension" /
  "`list()` call" ... "with no element type"
  "set display element type" / "dict display key type" ... "<type>"
  "binding" ... "'x' to a value of type None"
  "for-loop target" ... "N-name unpack of `<type>` elements"
  "generator" ... "yield in 'inner'" / "yield in a lambda"
  E5060  a C-library import declaration that carries a body (now a static
         analysis rule, so it surfaces at check time)
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES_DIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     NA_CHECK_OPTS = CompileOptions(
         no_cgen=True,
         native_parity=True,
         force_codespace="native",
         force_target_program=True
     );

"""Compile a snippet through the check schedule with codegen off, in native
context (the `jac check` path); return the program and the module."""
def check_na(label: str, code: str) -> tuple {
    path = os.path.join(FIXTURES_DIR, f"_check_rules_{label}.jac");
    prog = JacProgram();
    mod = prog.compile(file_path=path, use_str=code, options=NA_CHECK_OPTS);
    return (prog, mod, );
}

"""Every native capability violation recorded for the module: the fatal ones
(reported as E5090) plus the demotable ones, which the backend absorbs by
demoting their owning function. Each entry is (node, kind, name, help)."""
def violations(prog: JacProgram, mod: any) -> list {
    part = mod.gen.native_capability_partition;
    assert part is not None , "no capability partition was stored";
    (fatal, demotable) = part;
    out = list(fatal);
    for viols in demotable.values() {
        out.extend(viols);
    }
    return out;
}

def kinds_of(viols: list) -> list[str] {
    return sorted({v[1] for v in viols});
}

def codes(prog: JacProgram) -> list[str] {
    return sorted(
        {
            e.code.code
            for e in prog.errors_had
            if e.code is not None
        }
    );
}

def fmt_errors(prog: JacProgram) -> str {
    return "\n".join(str(e) for e in prog.errors_had);
}

def fmt_viols(viols: list) -> str {
    return "; ".join(f"{v[1]} '{v[2]}'" for v in viols);
}

"""Assert the native check records a violation of `kind` whose name contains
`name_part`, and that the server pathway records nothing of that kind."""
def assert_native_only(label: str, code: str, kind: str, name_part: str) {
    (prog, mod) = check_na(label, code);
    viols = violations(prog, mod);
    hits = [
        v
        for v in viols
        if v[1] == kind and name_part in v[2]
    ];
    assert hits , (
        f"{label}: expected a '{kind}' violation naming '{name_part}', got: "
        f"{fmt_viols(viols)}; errors: {fmt_errors(prog)}"
    );
    for v in hits {
        assert v[3] , f"{label}: the violation must carry a help text";
    }
    sv_path = os.path.join(FIXTURES_DIR, f"_check_rules_sv_{label}.jac");
    sv_prog = JacProgram();
    sv_mod = sv_prog.compile(
        file_path=sv_path,
        use_str=code,
        options=CompileOptions(default_codespace="server")
    );
    sv_part = sv_mod.gen.native_capability_partition;
    if sv_part is not None {
        (sv_fatal, sv_demotable) = sv_part;
        sv_all = list(sv_fatal);
        for vs in sv_demotable.values() {
            sv_all.extend(vs);
        }
        leaked = [
            v
            for v in sv_all
            if v[1] == kind
        ];
        assert not leaked , f"{label}: native rule leaked into server context: {fmt_viols(
            leaked
        )}";
    }
}

def assert_clean(label: str, code: str, kinds: tuple) {
    (prog, mod) = check_na(label, code);
    viols = violations(prog, mod);
    hit = [
        v
        for v in viols
        if v[1] in kinds
    ];
    assert not hit , f"{label}: unexpected violations {fmt_viols(hit)}; errors: {fmt_errors(
        prog
    )}";
}

glob CONTAINER_KINDS: tuple = (
         "list display",
         "set display",
         "dict display",
         "list comprehension",
         "set comprehension",
         "dict comprehension",
         "`list()` call",
         "`set()` call",
         "`dict()` call",
         "set display element type",
         "set comprehension element type",
         "dict display key type",
         "dict comprehension key type"
     );

test "element-typed containers record nothing" {
    assert_clean(
        "annotated_list",
        "def f() -> int { xs: list[int] = []; xs.append(1); return len(xs); }\n",
        CONTAINER_KINDS
    );
    assert_clean(
        "flow_list",
        "obj Box { has n: int = 0; }\n"
        "def f() -> int { xs = []; xs.append(Box()); return len(xs); }\n",
        CONTAINER_KINDS
    );
    assert_clean(
        "expected_ctor",
        "def f() -> int { d: dict[str, int] = dict(); return len(d); }\n",
        CONTAINER_KINDS
    );
}

test "a set display mixing scalar element types has no native hash slot" {
    assert_native_only(
        "mixed_set",
        "def f() -> int { s = {1, \"a\"}; return len(s); }\n",
        "set display element type",
        "int | str"
    );
}

test "a dict display mixing key types, and an `any`-keyed comprehension" {
    assert_native_only(
        "mixed_dict_key",
        "def f() -> int { d = {1: 1, \"a\": 2}; return len(d); }\n",
        "dict display key type",
        "int | str"
    );
    assert_native_only(
        "any_key_compr",
        "def f(xs: list) -> int { d = {x: 1 for x in xs}; return len(d); }\n",
        "dict comprehension key type",
        "any"
    );
    assert_native_only(
        "opt_int_set",
        "def f(x: int | None) -> int { s: set[int | None] = {x}; return len(s); }\n",
        "set display element type",
        "int | None"
    );
}

test "one concrete hash type, or an all-reference union, records nothing" {
    assert_clean(
        "one_key_type",
        "def f() -> int { d = {\"a\": 1, \"b\": 2}; s = {1, 2}; return len(d) + len(s); }\n",
        CONTAINER_KINDS
    );
    assert_clean(
        "opt_str_set",
        "def f(x: str | None) -> int { s: set[str | None] = {x}; return len(s); }\n",
        CONTAINER_KINDS
    );
}

test "binding a None-returning call (or the literal None) to a native local" {
    assert_native_only(
        "void_bind",
        "def g() -> None { return; }\ndef f() -> int { x = g(); return 1; }\n",
        "binding",
        "'x' to a value of type None"
    );
    assert_native_only(
        "none_bind",
        "def f() -> int { x = None; return 1; }\n",
        "binding",
        "'x' to a value of type None"
    );
    assert_clean(
        "optional_decl",
        "def f() -> int { x: int | None = None; if x is None { return 0; } return x; }\n",
        ("binding", )
    );
}

test "a tuple loop target needs tuple elements of the same arity" {
    assert_native_only(
        "unpack_nontuple",
        "def f() -> int { xs: list[int] = [1, 2]; for (a, b) in xs { return a; } return 0; }\n",
        "for-loop target",
        "2-name unpack of `int` elements"
    );
    assert_native_only(
        "unpack_arity",
        "def f() -> int { xs: list[tuple[int, int, int]] = [(1, 2, 3)]; for (a, b) in xs { return a; } return 0; }\n",
        "for-loop target",
        "2-name unpack of `tuple[int, int, int]` elements"
    );
    assert_native_only(
        "items_three",
        "def f() -> int { d: dict[str, int] = {\"a\": 1}; for (k, v, w) in d.items() { return v; } return 0; }\n",
        "for-loop target",
        "3-name unpack"
    );
    assert_clean(
        "unpack_ok",
        "def f() -> int { xs: list[tuple[int, int]] = [(1, 2)]; t = 0; for (a, b) in xs { t = a + b; } return t; }\n",
        ("for-loop target", )
    );
    assert_clean(
        "items_ok",
        "def f() -> int { d: dict[str, int] = {\"a\": 1}; t = 0; for (k, v) in d.items() { t = v; } return t; }\n",
        ("for-loop target", )
    );
}

test "a generator nested in another function, or a yield in a lambda" {
    assert_native_only(
        "nested_gen",
        "def outer() -> int { def inner() -> Iterator[int] { yield 1; } return 1; }\n",
        "generator",
        "inner"
    );
    (lam_prog, lam_mod) = check_na(
        "lambda_gen",
        "with entry { f = lambda (x: int) -> Iterator[int] { yield x; }; }\n"
    );
    assert "E5090" in codes(lam_prog) , f"a yield in a lambda that no function owns is a fatal E5090: {fmt_errors(
        lam_prog
    )}";
    assert_clean(
        "top_gen",
        "def gen() -> Iterator[int] { yield 1; yield 2; }\n"
        "def f() -> int { t = 0; for v in gen() { t += v; } return t; }\n",
        ("generator", )
    );
}

test "E5060: a C-library declaration with a body is a static-analysis error" {
    (prog, mod) = check_na(
        "clib_body",
        "import from \"libm\" { def sqrt(x: float) -> float { return 1.0; } }\n"
        "def f() -> float { return sqrt(4.0); }\n"
    );
    assert "E5060" in codes(prog) , f"E5060 must surface on the check path: {fmt_errors(
        prog
    )}";
}
