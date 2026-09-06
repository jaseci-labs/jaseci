"""Ratchet that keeps the byLLM suite from growing back the way it grew.

Every number below is today's measured count, not a target. Ceilings may only fall and
floors may only rise; a PR that moves one the wrong way fails here with the reason and
the fix. Lowering a ceiling or raising a floor as you clean up is the point, and is a
one-line edit in the same PR.

See TESTING.md for what the suite is converging on and why each rule exists.
"""

import os;
import re;

glob TESTS_DIR: str = os.path.dirname(os.path.abspath(__file__)),
     FIXTURE_DIR: str = os.path.join(TESTS_DIR, "fixtures"),
     ANNEX: str = "support_tests.jac";


"""Every .jac under tests/, excluding fixtures/ and this file."""
def test_files -> list[str] {
    out: list[str] = [];
    for name in sorted(os.listdir(TESTS_DIR)) {
        if name.endswith(".jac") and name != "test_guard.jac" {
            out.append(name);
        }
    }
    return out;
}


"""Every fixture program, including the ones in subdirectories."""
def fixture_files -> list[str] {
    out: list[str] = [];
    for (dirpath, _dirnames, filenames) in os.walk(FIXTURE_DIR) {
        for name in filenames {
            if name.endswith(".jac") {
                full = os.path.join(dirpath, name);
                out.append(os.path.relpath(full, FIXTURE_DIR));
            }
        }
    }
    return sorted(out);
}


def read(path: str) -> str {
    with open(path, "r", encoding="utf-8", errors="replace") as fh {
        return fh.read();
    }
}


def read_test(name: str) -> str {
    return read(os.path.join(TESTS_DIR, name));
}


def read_fixture(rel: str) -> str {
    return read(os.path.join(FIXTURE_DIR, rel));
}


def count(pattern: str, text: str) -> int {
    return len(re.findall(pattern, text));
}


"""Compare measured counts to a baseline. `direction` is 'ceiling' or 'floor'."""
def ratchet(
    label: str,
    measured: dict[str, int],
    baseline: dict[str, int],
    direction: str,
    fix: str
) {
    problems: list[str] = [];
    for (key, limit) in baseline.items() {
        got = measured.get(key, 0);
        if direction == "ceiling" and got > limit {
            problems.append(f"  {key}: {got}, was {limit} (+{got - limit})");
        }
        if direction == "floor" and got < limit {
            problems.append(f"  {key}: {got}, was {limit} ({got - limit})");
        }
    }
    for (key, got) in measured.items() {
        if key not in baseline and got > 0 and direction == "ceiling" {
            problems.append(f"  {key}: {got}, not in the baseline at all");
        }
    }
    word = "rose" if direction == "ceiling" else "fell";
    assert not problems , (
        f"{label} {word}:\n"
        + "\n".join(problems)
        + f"\n\n{fix}\n\n"
        + "If this is a deliberate cleanup, edit the baseline in test_guard.jac in "
        + "the same PR. If it is new code, use the annex instead. See TESTING.md."
    );
}


# ---------------------------------------------------------------------------
# 1. Fixture programs. A new one has to be justified in the same PR.
# ---------------------------------------------------------------------------
glob FIXTURE_BUDGET: int = 66;

test "fixture count does not grow" {
    found = fixture_files();
    assert len(found) <= FIXTURE_BUDGET , (
        f"fixtures/ holds {len(found)} programs, budget is {FIXTURE_BUDGET}.\n\n"
        + "Most tests do not need a fixture. A `by llm()` def belongs in the test "
        + "file beside its test, scripted with FakeLLM. A fixture is only for a "
        + "program whose SHAPE is the subject (node/walker/edge) or a compile "
        + "target for the MTIR, import and scope tests.\n\n"
        + "If this one really is a program under test, raise FIXTURE_BUDGET here in "
        + "the same PR and say why in the PR description. See TESTING.md."
    );
}


# ---------------------------------------------------------------------------
# 2. A fixture is a program under test, not a test.
#    Today 52 fixtures still print or assert; that number may only fall.
# ---------------------------------------------------------------------------
glob IMPURE_FIXTURE_BUDGET: int = 52;

test "no new fixture asserts or prints its own result" {
    impure: list[str] = [];
    for rel in fixture_files() {
        src = read_fixture(rel);
        if count(r"(?m)^\s*assert\s", src) > 0 or count(r"print\s*\(", src) > 0 {
            impure.append(rel);
        }
    }
    assert len(impure) <= IMPURE_FIXTURE_BUDGET , (
        f"{len(impure)} fixtures assert or print, budget is "
        + f"{IMPURE_FIXTURE_BUDGET}.\n\n"
        + "A fixture that asserts hides its checks from the runner: the test greps a "
        + "sentinel out of stdout and cannot report which assert failed. Put the "
        + "assertions in the test and let it read values back directly.\n\n"
        + f"Fixtures currently doing this: {len(impure)}. Lower the budget as you "
        + "convert them."
    );
}


# ---------------------------------------------------------------------------
# 3. One way to fake the model. Every count here is a ceiling.
# ---------------------------------------------------------------------------
glob MOCKLLM_BASELINE: dict[str, int] = {
         "test_compaction.jac": 14,
         "test_usage.jac": 5
     },
     FIXTURE_MOCKLLM_BASELINE: int = 53,
     SIMPLENAMESPACE_BASELINE: dict[str, int] = {
         "test_byllm.jac": 10,
         "test_compaction.jac": 4,
         "test_telemetry_.jac": 8,
         "test_tool_arg_streaming.jac": 7,
         "test_usage.jac": 19
     };

test "MockLLM constructions in test files do not grow" {
    measured: dict[str, int] = {};
    for name in test_files() {
        if name == ANNEX {
            continue;
        }
        n = count(r"MockLLM\s*\(", read_test(name));
        if n > 0 {
            measured[name] = n;
        }
    }
    ratchet(
        "MockLLM constructions",
        measured,
        MOCKLLM_BASELINE,
        "ceiling",
        "Use FakeLLM from support_tests instead. MockLLM replaces "
            + "dispatch_no_streaming, which sits above make_model_params and "
            + "parse_response, so the prompt is built and discarded and the reply is "
            + "never parsed: the test cannot assert on what was sent, and a typed "
            + "return is not converted. FakeLLM replaces only model_call_*, so the "
            + "real dispatch runs and llm.sent(...) shows the outgoing params."
    );
}

test "fixtures reaching for MockLLM do not grow" {
    n = 0;
    for rel in fixture_files() {
        if "MockLLM" in read_fixture(rel) {
            n += 1;
        }
    }
    assert n <= FIXTURE_MOCKLLM_BASELINE , (
        f"{n} fixtures construct a MockLLM, budget is "
        + f"{FIXTURE_MOCKLLM_BASELINE}.\n\n"
        + "A fixture should not own a model at all. Declare `glob llm: any = None;` "
        + "and let the test assign its own FakeLLM: `by llm()` resolves the global "
        + "at call time, so the fixture stays a pure program under test."
    );
}

test "hand-rolled SimpleNamespace fakes do not grow" {
    measured: dict[str, int] = {};
    for name in test_files() {
        n = count(r"SimpleNamespace\s*\(", read_test(name));
        if n > 0 {
            measured[name] = n;
        }
    }
    ratchet(
        "SimpleNamespace fakes",
        measured,
        SIMPLENAMESPACE_BASELINE,
        "ceiling",
        "support_tests gives you response(), chunks() and mk_run(), which build "
            + "real litellm objects and a real MTRuntime. A SimpleNamespace stand-in "
            + "accepts any shape, so it keeps passing after the real object's shape "
            + "changes."
    );
}


# ---------------------------------------------------------------------------
# 4. Tests read values, not stdout.
# ---------------------------------------------------------------------------
glob STDOUT_GREP_BASELINE: dict[str, int] = {
         "support_tests.jac": 2,
         "test_byllm.jac": 95,
         "test_mtir_integration.jac": 4,
         "test_visit_routing.jac": 13
     };

test "stdout scraping does not grow" {
    measured: dict[str, int] = {};
    for name in test_files() {
        n = count(r"in stdout_value|getvalue\(\)", read_test(name));
        if n > 0 {
            measured[name] = n;
        }
    }
    ratchet(
        "stdout scraping",
        measured,
        STDOUT_GREP_BASELINE,
        "ceiling",
        "Assert on the value the function returned and on llm.sent(\"messages\") / "
            + "llm.sent(\"tools\"). A stdout match cannot tell a wrong answer from a "
            + "missing print, and it cannot see the request at all."
    );
}


# ---------------------------------------------------------------------------
# 5. Floors. These may only rise.
#    Assert count is here because a deleted fixture can take its checks with it
#    without changing the test count: 66 of the suite's asserts live in fixtures,
#    guarded by 10 sentinel greps.
# ---------------------------------------------------------------------------
glob ASSERT_FLOOR_TESTS: int = 776,
     ASSERT_FLOOR_FIXTURES: int = 66,
     ANNEX_IMPORT_FLOOR: int = 2;

test "total assert count does not fall" {
    in_tests = 0;
    for name in test_files() {
        in_tests += count(r"(?m)^\s*assert\s", read_test(name));
    }
    in_fixtures = 0;
    for rel in fixture_files() {
        in_fixtures += count(r"(?m)^\s*assert\s", read_fixture(rel));
    }
    total = in_tests + in_fixtures;
    floor = ASSERT_FLOOR_TESTS + ASSERT_FLOOR_FIXTURES;
    assert total >= floor , (
        f"assert statements fell to {total} ({in_tests} in test files, "
        + f"{in_fixtures} in fixtures); the floor is {floor}.\n\n"
        + "Deleting a fixture deletes its asserts, and the test count does not "
        + "move, so this is the only check that notices. Move each assert into the "
        + "test that owned the fixture before deleting it.\n\n"
        + "If a check is genuinely redundant, lower the floor here and name the "
        + "dropped assert in the PR description."
    );
}

test "annex adoption does not fall" {
    n = 0;
    for name in test_files() {
        if name != ANNEX and "import from support_tests" in read_test(name) {
            n += 1;
        }
    }
    assert n >= ANNEX_IMPORT_FLOOR , (
        f"{n} test files import support_tests, the floor is "
        + f"{ANNEX_IMPORT_FLOOR}.\n\n"
        + "The annex is the one place a fake, an MTRuntime or a response shape is "
        + "defined. A file that stops importing it has grown its own copy."
    );
}
