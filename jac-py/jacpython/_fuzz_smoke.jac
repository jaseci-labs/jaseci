# Layer-1 dual-execution replay driver for the pinned differential-fuzz corpus
# (BrightTiger lane; see jac-py/tools/fuzz_corpus_pinned.json + fuzz_run.py).
#
# fuzz_run.py extracts the corpus `cases` array to a scratch JSON file and runs
# this driver via `JACPYTHON_CPYTHON=python3 .venv/bin/jac run
# jac-py/jacpython/_fuzz_smoke.jac`. Each case source replays through the
# layer0_replay_harness Layer-1 machinery: the case's self-contained setup runs
# on BOTH host CPython and the jacpython VM, then every assert argument is
# evaluated in both namespaces in source order and diffed cross-engine.
#
# Line protocol consumed by fuzz_run.py:
#   ok <case> passed: <n> skipped: <m>   GREEN when n > 0 and m == 0;
#                                        SKIP when n == 0 and m > 0
#   FUZZFAIL <case> <detail>             RED: divergence or replay error
#
# A case whose body fails harvest entirely prints `ok ... passed: 0 skipped: 0`
# (PARTIAL under fuzz_run.py -- action required), never a silent green.
import json;
import os;
import from layer0_replay_harness { layer1_replay_source }


def _cases_path() -> str {
    # Scratch-discipline override so concurrent agents never share a file;
    # legacy default kept for the documented manual invocation.
    return os.environ.get("FUZZ_CASES_FILE") or "/tmp/fuzz_cases.json";
}


with entry {
    with open(_cases_path()) as fh {
        cases: list = json.load(fh);
    }
    green = 0;
    red = 0;
    for row in cases {
        name: str = row["name"] as str;
        src: str = row["src"] as str;
        result = layer1_replay_source(src);
        if result.failed > 0 {
            red += 1;
            detail = "";
            if result.failures {
                detail = result.failures[0] as str;
            }
            print("FUZZFAIL " + name + " diverged: " + detail);
        } elif result.errored > 0 {
            red += 1;
            detail = "";
            if result.errors {
                detail = result.errors[0] as str;
            }
            print("FUZZFAIL " + name + " errored: " + detail);
        } else {
            if result.passed > 0 and result.skipped == 0 {
                green += 1;
            }
            print(
                "ok " + name + " passed: " + str(result.passed)
                + " skipped: " + str(result.skipped)
            );
        }
    }
    print(
        "smoke: " + str(green) + " green / " + str(red) + " red / "
        + str(len(cases)) + " cases"
    );
}
