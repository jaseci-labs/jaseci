"""Rendering, mode resolution and instrumentation for use-site specialization.

The end-to-end fixture lives in `jac/tests/byllm/fixtures`, OUTSIDE the jaclang
package, on purpose: a module under the jaclang root is compiled by the
selfhost program, which skips the analysis schedule while an import is in
flight, so a fixture in `byllm/tests/fixtures` would never get a use site
stamped onto its MTIR.
"""

import copy;
import json;
import os;
import tempfile;
import types;
import from pathlib { Path }
import from unittest { mock }
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.byllm.config_loader { get_byllm_config, reset_byllm_config }
import from jaclang.byllm.mtir { MTIR, MTRuntime }
import from jaclang.byllm.types { CompletionResult }
import from jaclang.byllm.use_site {
    render_use_site_block,
    resolve_use_site_mode,
    use_site_suffix,
    use_site_word_count
}
import from jaclang.compiler.driver.mtp { FunctionInfo, UseSiteInfo, fetch_mtir }

glob FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "fixtures"),
     USE_SITE_TOML = os.path.join(FIXTURE_DIR, "use_site_config"),
     PIPELINE_DIR = str(
         Path(__file__).resolve().parents[3] / "tests" / "byllm" / "fixtures"
     ),
     MODES = ["off", "signature", "semantic", "generic"],
     SEMANTIC_BLOCK = "\n".join(
         [
             "## Downstream use",
             "The result is passed as `claims` (list of verifiable factual assertions)",
             "to `verify` (checks each claim against the provided sources).",
             "Fields read downstream: text, cited_span."
         ]
     ),
     SIGNATURE_BLOCK = "\n".join(
         [
             "## Downstream use",
             "The result is passed as `claims` (list[Claim])",
             "to `verify`."
         ]
     );


"""Set or clear an environment variable, returning the previous value."""
def env_set(name: str, value: (str | None)) -> (str | None) {
    prev = os.environ.get(name);
    if value is None {
        os.environ.pop(name, None);
    } else {
        os.environ[name] = value;
    }
    return prev;
}


"""The resolved use site of the SPEC's worked example."""
def resolved_site -> UseSiteInfo {
    return UseSiteInfo(
        resolved=True,
        consumer_name="verify",
        consumer_semstr="Checks each claim against the provided sources.",
        consumer_module="/tmp/pipeline.jac",
        param_name="claims",
        param_semstr="list of verifiable factual assertions",
        param_type="list[Claim]",
        fields_read=["text", "cited_span"]
    );
}


"""A FunctionInfo carrying the given use site."""
def info_with(us: any) -> FunctionInfo {
    return FunctionInfo(
        name="extract_claims",
        semstr="Extract the claims made in a document.",
        params=[],
        return_type="list[Claim]",
        use_site=us
    );
}


"""Import the out-of-package pipeline fixture.

The test runner hands every test a fresh `JacRuntime.program` and drops the
module from `sys.modules`, so the MTIR registrations only exist inside the test
that performed the import. Every test that needs them must import for itself.
"""
def pipeline -> any {
    import sys;

    sys.modules.pop("use_site_pipeline", None);
    (mod, ) = Jac.jac_import("use_site_pipeline", base_path=PIPELINE_DIR);
    return mod;
}


"""The user-message text a by-llm call would build for this caller and info."""
def user_text(caller: any, info: any) -> str {
    mtir = MTIR(caller=caller, args={0: "some document"}, call_params={}, ir_info=info);
    run: any = mtir.runtime;
    msg: any = run.messages[1];
    return msg.content[0].text;
}


# =============================================================================
# Rendering
# =============================================================================
test "semantic mode renders the block from the specification" {
    block = render_use_site_block(info_with(resolved_site()), "semantic");
    assert block == SEMANTIC_BLOCK , f"got:\n{block}";
}

test "signature mode names the consumer and the parameter type only" {
    block = render_use_site_block(info_with(resolved_site()), "signature");
    assert block == SIGNATURE_BLOCK , f"got:\n{block}";
    assert "verifiable factual assertions" not in block;
    assert "sources" not in block;
    assert "Fields read downstream" not in block;
}

test "generic mode leaks no downstream information" {
    info = info_with(resolved_site());
    block = render_use_site_block(info, "generic");
    assert block.startswith("## Downstream use");
    for leak in [
        "verify",
        "claims",
        "Claim",
        "text",
        "cited_span",
        "verifiable",
        "sources"
    ] {
        assert leak not in block , f"generic block leaked {leak!r}:\n{block}";
    }
}

test "generic mode is word count matched to semantic mode" {
    shapes = [
        resolved_site(),
        UseSiteInfo(
            resolved=True,
            consumer_name="run",
            consumer_parent_class="Checker",
            param_name="items",
            param_type="list[Claim]"
        ),
        UseSiteInfo(
            resolved=True,
            consumer_name="summarize",
            consumer_semstr="Produces a single paragraph digest of everything given.",
            param_name="body",
            param_semstr="the raw article body as plain text",
            param_type="str",
            fields_read=["a", "b", "c", "d", "e"]
        )
    ];
    for us in shapes {
        info = info_with(us);
        semantic = use_site_word_count(render_use_site_block(info, "semantic"));
        generic = use_site_word_count(render_use_site_block(info, "generic"));
        assert generic == semantic , f"{us.consumer_name}: {generic} vs {semantic}";
    }
}

test "off mode renders nothing" {
    assert render_use_site_block(info_with(resolved_site()), "off") == "";
}

test "an unknown mode renders nothing" {
    for bogus in ["semantics", "SIGNATURE", "", "1", "on"] {
        assert render_use_site_block(info_with(resolved_site()), bogus) == "" , f"mode {bogus!r} rendered something";
    }
}

test "an unresolved use site renders nothing in every mode" {
    info = info_with(
        UseSiteInfo(resolved=False, reason="uses reach more than one consumer")
    );
    for mode in MODES {
        assert render_use_site_block(info, mode) == "" , f"mode {mode} rendered something";
    }
}

test "a function info without a use site attribute renders nothing" {
    legacy = info_with(None);
    legacy.__dict__.pop("use_site", None);
    old_pickle = types.SimpleNamespace(name="extract_claims");
    for mode in MODES {
        assert render_use_site_block(legacy, mode) == "";
        assert render_use_site_block(old_pickle, mode) == "";
    }
    assert use_site_suffix(old_pickle) == "";
}

test "the suffix is the block behind exactly one blank line" {
    prev = env_set("BYLLM_USE_SITE", "semantic");
    try {
        info = info_with(resolved_site());
        assert use_site_suffix(info) == "\n\n" + SEMANTIC_BLOCK;
        env_set("BYLLM_USE_SITE", "off");
        assert use_site_suffix(info) == "";
    } finally {
        env_set("BYLLM_USE_SITE", prev);
    }
}


# =============================================================================
# Mode resolution
# =============================================================================
test "the environment variable selects the mode" {
    prev = os.environ.get("BYLLM_USE_SITE");
    reset_byllm_config();
    try {
        cases = {
            "semantic": "semantic",
            "  Semantic ": "semantic",
            "GENERIC": "generic",
            "signature": "signature",
            "off": "off",
            "bogus": "off",
            "": "off"
        };
        for (raw, want) in cases.items() {
            env_set("BYLLM_USE_SITE", raw);
            got = resolve_use_site_mode();
            assert got == want , f"{raw!r} resolved to {got!r}, wanted {want!r}";
        }
        env_set("BYLLM_USE_SITE", None);
        assert resolve_use_site_mode() == "off";
    } finally {
        env_set("BYLLM_USE_SITE", prev);
        reset_byllm_config();
    }
}

test "the toml setting applies when the environment is silent" {
    prev = env_set("BYLLM_USE_SITE", None);
    reset_byllm_config();
    try {
        get_byllm_config(Path(USE_SITE_TOML));
        loaded = get_byllm_config().get_optimizations_config();
        assert loaded["use_site_specialization"] == "semantic" , f"fixture not loaded: {loaded}";
        assert resolve_use_site_mode() == "semantic";
    } finally {
        env_set("BYLLM_USE_SITE", prev);
        reset_byllm_config();
    }
}

test "the environment variable overrides the toml setting" {
    prev = env_set("BYLLM_USE_SITE", "off");
    reset_byllm_config();
    try {
        get_byllm_config(Path(USE_SITE_TOML));
        assert get_byllm_config().get_optimizations_config()["use_site_specialization"]
            == "semantic";
        assert resolve_use_site_mode() == "off";
        env_set("BYLLM_USE_SITE", "signature");
        assert resolve_use_site_mode() == "signature";
    } finally {
        env_set("BYLLM_USE_SITE", prev);
        reset_byllm_config();
    }
}

test "the default configuration keeps the feature off" {
    reset_byllm_config();
    try {
        defaults = get_byllm_config().get_default_config();
        assert defaults["optimizations"] == {"use_site_specialization": "off"};
    } finally {
        reset_byllm_config();
    }
}


# =============================================================================
# The compiled pipeline
# =============================================================================
test "the imported pipeline carries a resolved use site" {
    mod: any = pipeline();
    info: any = fetch_mtir(mod.extract_claims);
    assert info is not None , "extract_claims has no MTIR entry";
    us: any = info.use_site;
    assert us is not None , "the use-site pass never ran for the fixture";
    assert us.resolved , f"unresolved: {us.reason}";
    assert us.consumer_name == "verify";
    assert us.param_name == "claims";
    assert us.param_semstr == "list of verifiable factual assertions";
    assert us.param_type == "list[Claim]";
    assert us.fields_read == ["cited_span", "text"];
}

test "off mode yields a byte identical user message" {
    prev = os.environ.get("BYLLM_USE_SITE");
    reset_byllm_config();
    try {
        mod: any = pipeline();
        with_site: any = fetch_mtir(mod.extract_claims);
        assert with_site?.use_site is not None;
        without: any = copy.deepcopy(with_site);
        without.use_site = None;
        for raw in [None, "off"] {
            env_set("BYLLM_USE_SITE", raw);
            stamped = user_text(mod.extract_claims, with_site);
            bare = user_text(mod.extract_claims, without);
            assert stamped == bare , f"mode {raw!r} changed the message:\n{stamped!r}\n{bare!r}";
        }
        env_set("BYLLM_USE_SITE", "semantic");
        assert user_text(mod.extract_claims, with_site)
            != user_text(mod.extract_claims, without) , "semantic mode changed nothing, the off comparison proves nothing";
    } finally {
        env_set("BYLLM_USE_SITE", prev);
        reset_byllm_config();
    }
}

test "a by llm call renders the block into the user prompt" {
    prev = env_set("BYLLM_USE_SITE", "semantic");
    reset_byllm_config();
    captured: list = [];
    try {
        mod: any = pipeline();
        original = mod.llm.dispatch_no_streaming;
        def capturing(mt_run: MTRuntime) -> CompletionResult {
            msg: any = mt_run.messages[1];
            captured.append(msg.content[0].text);
            return original(mt_run);
        }
        with mock.patch.object(mod.llm, "dispatch_no_streaming", capturing) {
            assert mod.run_pipeline("some document");
        }
        assert len(captured) == 1;
        prompt = captured[0];
        assert prompt.startswith(
            "Extract the claims made in a document.\n\n## Downstream use\n"
        ) , f"got:\n{prompt}";
        assert "to `verify` (checks each claim against the provided sources)."
            in prompt;
        assert "Fields read downstream: cited_span, text." in prompt;
    } finally {
        env_set("BYLLM_USE_SITE", prev);
        reset_byllm_config();
    }
}


# =============================================================================
# The usage log
# =============================================================================
test "one usage record is appended per call" {
    prev_mode = env_set("BYLLM_USE_SITE", "semantic");
    tmp = tempfile.mkdtemp();
    prev_log = env_set("BYLLM_USAGE_LOG", os.path.join(tmp, "usage.jsonl"));
    reset_byllm_config();
    try {
        mod: any = pipeline();
        assert mod.run_pipeline("some document");
        with open(os.path.join(tmp, "usage.jsonl"), encoding="utf-8") as fh {
            lines = [
                ln
                for ln in fh.read().splitlines()
                if ln.strip()
            ];
        }
        assert len(lines) == 1 , f"expected one record, got {len(lines)}";
        rec = json.loads(lines[0]);
        expected_keys = {
            "ts",
            "invocation_id",
            "parent_invocation_id",
            "scope",
            "caller_name",
            "model",
            "latency_ms",
            "use_site_mode",
            "use_site_resolved",
            "use_site_reason",
            "use_site_tokens",
            "consumer_name",
            "consumer_param",
            "fields_read",
            "prompt_tokens",
            "completion_tokens",
            "total_tokens",
            "cache_read_input_tokens",
            "cache_creation_input_tokens",
            "cost"
        };
        assert set(rec.keys()) == expected_keys , f"key drift: {sorted(
            set(rec.keys()) ^ expected_keys
        )}";
        assert rec["scope"] == "use_site_pipeline.extract_claims";
        assert rec["caller_name"] == "extract_claims";
        assert rec["model"] == "mockllm";
        assert rec["use_site_mode"] == "semantic";
        assert rec["use_site_resolved"] is True;
        assert rec["use_site_reason"] is None;
        assert rec["use_site_tokens"] == use_site_word_count("\n\n" + SEMANTIC_BLOCK) , f"got {rec[
            'use_site_tokens'
        ]}";
        assert rec["consumer_name"] == "verify";
        assert rec["consumer_param"] == "claims";
        assert rec["fields_read"] == ["cited_span", "text"];
        for key in [
            "prompt_tokens",
            "completion_tokens",
            "total_tokens",
            "cache_read_input_tokens",
            "cache_creation_input_tokens"
        ] {
            assert isinstance(rec[key], int) , f"{key} is {rec[key]!r}";
            assert rec[key] >= 0;
        }
    } finally {
        env_set("BYLLM_USE_SITE", prev_mode);
        env_set("BYLLM_USAGE_LOG", prev_log);
        reset_byllm_config();
    }
}

test "the usage record reports the mode that was active" {
    prev_mode = env_set("BYLLM_USE_SITE", "off");
    tmp = tempfile.mkdtemp();
    prev_log = env_set("BYLLM_USAGE_LOG", os.path.join(tmp, "usage.jsonl"));
    reset_byllm_config();
    try {
        mod: any = pipeline();
        assert mod.run_pipeline("some document");
        with open(os.path.join(tmp, "usage.jsonl"), encoding="utf-8") as fh {
            rec = json.loads(fh.read().splitlines()[0]);
        }
        assert rec["use_site_mode"] == "off";
        assert rec["use_site_tokens"] == 0;
        assert rec["use_site_resolved"] is True , "the analysis is recorded even when off";
    } finally {
        env_set("BYLLM_USE_SITE", prev_mode);
        env_set("BYLLM_USAGE_LOG", prev_log);
        reset_byllm_config();
    }
}

test "nothing is written when the usage log is not configured" {
    prev_mode = env_set("BYLLM_USE_SITE", "semantic");
    prev_log = env_set("BYLLM_USAGE_LOG", None);
    tmp = tempfile.mkdtemp();
    target = os.path.join(tmp, "usage.jsonl");
    reset_byllm_config();
    try {
        mod: any = pipeline();
        assert mod.run_pipeline("some document");
        assert not os.path.exists(target);
        assert os.listdir(tmp) == [] , f"the log wrote something: {os.listdir(tmp)}";
    } finally {
        env_set("BYLLM_USE_SITE", prev_mode);
        env_set("BYLLM_USAGE_LOG", prev_log);
        reset_byllm_config();
    }
}
