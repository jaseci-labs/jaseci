"""Every `JAC_CLIENT_INTEGRATION`-gated suite must be named by a CI step.

A gated suite skips itself everywhere else, so one no workflow names never runs
while still reporting a pass -- how `test_react_state_semantics.jac` went
unexecuted until #8134, and how the #8023 defects shipped. `ci.yml` says so in a
comment; a comment cannot fail, so this does."""

import from pathlib { Path }

glob REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent,
     TESTS_ROOT = Path(__file__).resolve().parent.parent,
     WORKFLOWS_DIR = REPO_ROOT / ".github" / "workflows",
     _GATE = "JAC_CLIENT_INTEGRATION";

"""Gated suites that no workflow runs, each with the defect that blocks it.

Red on a clean checkout for their own reasons, so naming them in CI would only
turn the lane red. Listed here so the set cannot grow silently."""
glob QUARANTINED: dict[str, str] = {
         "runtimelib/test_client_bundle_retry.jac": "the server under test exits 1"
         " instead of surviving the deliberately broken bundle, so the retry"
         " it asserts never happens",
         "runtimelib/test_serve_client.jac": "8 of 96 cases fail against a real"
         " Vite/Bun build; the header says jac-client's own suite covers"
         " them, and no such lane exists in this repo",
         "runtimelib/test_preact_e2e.jac": "the project it scaffolds writes a"
         " jac.toml with a duplicated [client] table, which fails to parse"
         " before any browser starts"
     };

"""Repo-relative posix paths of every `.jac` test file gated on the flag.

Gated means it names the flag and skips on it, directly or through a helper.
This file names the flag to look for it, so it excludes itself."""
def _gated_suites -> list[str] {
    self_path = Path(__file__).resolve();
    gated: list[str] = [];
    for path in sorted(TESTS_ROOT.rglob("test_*.jac")) {
        if path.resolve() == self_path {
            continue;
        }
        try {
            source = path.read_text(encoding="utf-8");
        } except OSError {
            continue;
        }
        skips = "testskip(" in source or "require_client_integration(" in source;
        if _GATE in source and skips {
            gated.append(path.relative_to(TESTS_ROOT).as_posix());
        }
    }
    return gated;
}

"""Concatenated text of every workflow, which is where suite paths are named."""
def _workflow_text -> str {
    chunks: list[str] = [];
    for wf in sorted(WORKFLOWS_DIR.glob("*.yml")) {
        try {
            chunks.append(wf.read_text(encoding="utf-8"));
        } except OSError {
            continue;
        }
    }
    return "\n".join(chunks);
}

test "every JAC_CLIENT_INTEGRATION-gated suite is named by a CI step" {
    gated = _gated_suites();
    assert gated , (
        f"found no gated suites under {TESTS_ROOT}; the discovery glob is wrong,"
        " which would make this test vacuous"
    );

    workflows = _workflow_text();
    unwired = [
        suite
        for suite in gated
        if suite not in workflows and suite not in QUARANTINED
    ];
    assert not unwired , (
        "these suites skip themselves unless "
        + _GATE
        + " is set, and no workflow names them, so they never run:\n  "
        + "\n  ".join(unwired)
        + "\n\nName them in a CI step (the jsdom step in ci.yml is the usual"
        " home), or add them to QUARANTINED in this file with the defect that"
        " blocks them."
    );
}

test "the quarantine list stays honest" {
    # A stale entry is how a suite gets forgotten twice.
    gated = _gated_suites();
    workflows = _workflow_text();

    missing = [
        suite
        for suite in QUARANTINED
        if suite not in gated
    ];
    assert not missing , (
        "QUARANTINED names suites that are no longer gated test files; drop"
        " them:\n  "
        + "\n  ".join(missing)
    );

    wired = [
        suite
        for suite in QUARANTINED
        if suite in workflows
    ];
    assert not wired , (
        "these suites are quarantined but a workflow already names them;"
        " remove them from QUARANTINED:\n  "
        + "\n  ".join(wired)
    );
}

test "the jsdom CI step names every jsdom suite" {
    # They all share one step; pin that, so a suite landing elsewhere shows up.
    ci = (WORKFLOWS_DIR / "ci.yml").read_text(encoding="utf-8");
    step = ci.split("Run jsdom runtime tests");
    assert len(step) == 2 , "ci.yml no longer has a 'Run jsdom runtime tests' step";
    body = step[1].split("- name:")[0];
    for suite in [
        "test_solid_jsdom.jac",
        "test_react_state_semantics.jac",
        "test_react_auth_jsdom.jac"
    ] {
        assert suite in body , (
            f"{suite} is not named in the jsdom CI step, so it never executes"
        );
    }
}
