"""Tests for per-call usage exposure during a streaming ReAct loop (#8484).

`usage` only ever fired once, after the whole invocation finished, even
though byLLM already records real, cost-inclusive usage on `mt_run` the
moment each individual call completes. `usage_step` surfaces that same data
per call instead of only in the final aggregate, at every site that makes a
real LLM call: the main ReAct loop iteration, the final-answer restream, and
the recovery call - reusing the exact `_aggregate_usage` shape `usage`
already has, so a caller can parse both with the same code.

Also covers `IterationContext.total_cost`: `on_iteration` already exposes
real cumulative `total_tokens` between calls, but not cost, which is what a
credit/budget check actually needs.
"""

import unittest.mock;
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model, MockLLM }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types {
    Tool,
    Message,
    MessageRole,
    MockToolCall,
    IterationContext,
    CompletionResult
}
import from jaclang.byllm.exceptions { OutputConversionError }
import dataclasses;
import types;

glob _Person8484 = dataclasses.make_dataclass(
         "Person8484", [("name", str), ("age", int)]
     );


def step_a -> str {
    return "stepped";
}


def finish_tool(final_output: str) -> str {
    return final_output;
}


test "usage_step fires once per react iteration, scoped to that iteration's own usage" {
    llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
                ),
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 200, "completion_tokens": 20, "total_tokens": 220}
                ),
                "done"
            ]
        }
    );

    def task(q: str) -> str by llm(tools=[step_a], stream=True, logging=True);

    usage_steps: list = [];
    for event in task("go") {
        if event.event_type == "usage_step" {
            usage_steps.append(event.data);
        }
    }

    assert len(usage_steps) == 2 , (
        f"expected one usage_step per react-loop call, got {len(usage_steps)}"
    );
    assert usage_steps[0]["total"]["total_tokens"] == 110;
    assert usage_steps[0]["per_call"][0]["call_kind"] == "react_iteration";
    assert usage_steps[1]["total"]["total_tokens"] == 220 , (
        "each usage_step must carry only its own call's usage, not a running "
        "cumulative sum"
    );
}


test "usage_step correctly attributes an interleaved compaction call" {
    # MockLLM's default compactor shares its config["outputs"] queue with the
    # main loop (_copy_for_compaction shallow-copies), so driving a real
    # threshold-triggered compaction through it consumes the wrong queued
    # response. Simulate the interleaving directly instead: real per-call
    # dispatch is mocked, and _maybe_compact is made to append a compaction
    # record the same way the real one does when it actually fires.
    model = Model(model_name="test-model");

    responses = [
        CompletionResult(
            output=None,
            tool_calls=[MockToolCall(tool=step_a, args={}).to_tool_call()],
            usage={"prompt_tokens": 850, "completion_tokens": 10, "total_tokens": 860}
        ),
        CompletionResult(
            output=None,
            tool_calls=[
                MockToolCall(
                    tool=finish_tool, args={"final_output": "done"}
                ).to_tool_call()
            ],
            usage={"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55}
        )
    ];

    def fake_dispatch_streaming_with_tools(
        mt: MTRuntime, out: list
    ) -> Generator[str, None, None] {
        response = responses.pop(0);
        _byllm_llm_mod._record_usage(mt, response.usage, "test-model");
        out.append(response);
        for _tok in [] {
            yield _tok;
        }
    }

    def fake_maybe_compact(
        mt: MTRuntime, usage: object, just_compacted: bool, cp: dict
    ) -> bool {
        if len(mt._usage_history) == 1 {
            mt._usage_history.append(
                {
                    "model": "test-model",
                    "call_kind": "compaction",
                    "prompt_tokens": 300,
                    "completion_tokens": 40,
                    "total_tokens": 340
                }
            );
        }
        return just_compacted;
    }

    def _empty_stream(mt: MTRuntime) -> Generator[str, None, None] {
        for _tok in [] {
            yield _tok;
        }
    }

    mt_run = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="go")
        ],
        resp_type=str,
        stream=True,
        tools=[Tool(func=step_a), Tool.make_finish_tool(str)],
        call_params={},
        mtir=None
    );

    usage_steps: list = [];
    with unittest.mock.patch.object(
        model, "dispatch_streaming_with_tools", fake_dispatch_streaming_with_tools
    ), unittest.mock.patch.object(model, "_maybe_compact", fake_maybe_compact), unittest.mock.patch.object(
        model, "dispatch_streaming", _empty_stream
    ) {
        for event in model._invoke_streaming(mt_run) {
            if event.event_type == "usage_step" {
                usage_steps.append(event.data);
            }
        }
    }

    assert len(usage_steps) >= 1;
    kinds = [e["call_kind"] for e in usage_steps[0]["per_call"]];
    assert "compaction" in kinds , (
        f"the usage_step covering the iteration where compaction fired must "
        f"include the compaction call, got call_kinds={kinds}"
    );
    assert "react_iteration" in kinds , (
        f"...and must not drop the react iteration's own usage in favor of "
        f"just the compaction entry, got call_kinds={kinds}"
    );
    assert usage_steps[0]["total"]["total_tokens"] == 860 + 340 , (
        "the usage_step must sum both the react call and the interleaved "
        "compaction call, not just one of them"
    );
}


test "usage_step fires for the final_answer_restream call" {
    llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
                ),
                (
                    "final answer text",
                    {"prompt_tokens": 300, "completion_tokens": 30, "total_tokens": 330}
                )
            ]
        }
    );

    def task(q: str) -> str by llm(tools=[step_a], stream=True, logging=True);

    usage_steps: list = [];
    for event in task("go") {
        if event.event_type == "usage_step" {
            usage_steps.append(event.data);
        }
    }

    assert len(usage_steps) == 2 , (
        f"expected the react call's own step plus the restream's, got "
        f"{len(usage_steps)}"
    );
    assert usage_steps[1]["per_call"][0]["call_kind"] == "final_answer_restream";
    assert usage_steps[1]["total"]["total_tokens"] == 330;
}


test "usage_step fires for the recovery call" {
    model = Model(model_name="test-model");

    def fake_dispatch_streaming_with_tools(
        mt: MTRuntime, out: list
    ) -> Generator[str, None, None] {
        raise OutputConversionError("forced for test");
        for _tok in [] {
            yield _tok;
        }
    }

    recovery_fn = types.SimpleNamespace(
        name="finish_tool", arguments='{"output": {"name": "Gus", "age": 29}}'
    );
    recovery_response = {
        "choices": [
            {
                "message": {
                    "content": None,
                    "tool_calls": [
                        types.SimpleNamespace(id="call_1", function=recovery_fn)
                    ]
                }
            }
        ],
        "usage": {"prompt_tokens": 40, "completion_tokens": 8, "total_tokens": 48}
    };

    def _empty_stream(mt: MTRuntime) -> Generator[str, None, None] {
        for _tok in [] {
            yield _tok;
        }
    }

    # by model(stream=True) rejects a typed return type outside stream_handler
    # at the macro level (see mtir.impl.jac); drive _invoke_streaming directly
    # to reach the recovery branch, same low-level pattern test_usage_history
    # already uses for typed dispatch scenarios.
    mt_run = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="go")
        ],
        resp_type=_Person8484,
        stream=True,
        tools=[Tool.make_finish_tool(_Person8484)],
        call_params={},
        mtir=None
    );

    usage_steps: list = [];
    with unittest.mock.patch.object(
        model, "dispatch_streaming_with_tools", fake_dispatch_streaming_with_tools
    ), unittest.mock.patch.object(
        model, "model_call_no_stream", return_value=recovery_response
    ), unittest.mock.patch.object(model, "dispatch_streaming", _empty_stream) {
        for event in model._invoke_streaming(mt_run) {
            if event.event_type == "usage_step" {
                usage_steps.append(event.data);
            }
        }
    }

    assert len(usage_steps) == 1 , (
        f"expected exactly one usage_step for the recovery episode, got "
        f"{len(usage_steps)}"
    );
    assert usage_steps[0]["per_call"][0]["call_kind"] == "recovery";
    assert usage_steps[0]["total"]["total_tokens"] == 48;
}


test "usage_step is shape-compatible with the final usage event" {
    llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 10, "completion_tokens": 1, "total_tokens": 11}
                ),
                "done"
            ]
        }
    );

    def task(q: str) -> str by llm(tools=[step_a], stream=True, logging=True);

    usage_step_data = None;
    usage_data = None;
    for event in task("go") {
        if event.event_type == "usage_step" {
            usage_step_data = event.data;
        }
        if event.event_type == "usage" {
            usage_data = event.data;
        }
    }

    assert usage_step_data is not None;
    assert usage_data is not None;
    assert set(usage_step_data.keys()) == set(usage_data.keys()) , (
        "usage_step must reuse the exact usage event shape so both can be "
        "parsed with the same code"
    );
    for key in ["total", "by_kind", "per_call", "requests"] {
        assert key in usage_data , f"usage event missing expected key {key}";
    }
}


test "usage_step does not fire for the no-tools branch" {
    llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    "hello there",
                    {"prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7}
                )
            ]
        }
    );

    def task(q: str) -> str by llm(stream=True, logging=True);

    event_types: list = [];
    for event in task("go") {
        event_types.append(event.event_type);
    }

    assert "usage_step" not in event_types , (
        "a single-call invocation has nothing to distinguish a per-call step "
        "from the final aggregate; usage_step must not duplicate it"
    );
    assert event_types.count("usage") == 1;
}


test "_usage_history_total_cost sums real cost across recorded calls" {
    mt = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="u")
        ],
        resp_type=str,
        stream=True,
        tools=[],
        call_params={},
        mtir=None
    );
    mt._usage_history = [
        {"call_kind": "react_iteration", "total_tokens": 100, "cost": 0.001},
        {"call_kind": "react_iteration", "total_tokens": 50, "cost": 0.0005},
        {"call_kind": "compaction", "total_tokens": 300}
    ];

    total = _byllm_llm_mod._usage_history_total_cost(mt);
    assert abs(total - 0.0015) < 1e-12 , (
        f"expected cost-bearing entries summed and missing-cost entries "
        f"treated as 0, got {total}"
    );
}


test "on_iteration's IterationContext exposes total_cost" {
    llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
                ),
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55}
                ),
                "done"
            ]
        }
    );

    seen_contexts: list[IterationContext] = [];
    def hook(ctx: IterationContext) -> str {
        seen_contexts.append(ctx);
        return "continue";
    }

    def task(q: str) -> str by llm(
        tools=[step_a], stream=True, logging=True, on_iteration=hook
    );

    for event in task("go") { }

    assert len(seen_contexts) >= 1 , "on_iteration should have fired before iteration 2";
    assert hasattr(seen_contexts[0], "total_cost") , (
        "IterationContext must expose total_cost alongside total_tokens"
    );
}


test "llm_timing no longer duplicates token counts now that usage_step exists" {
    llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
                ),
                "done"
            ]
        }
    );

    def task(q: str) -> str by llm(tools=[step_a], stream=True, logging=True);

    timing_events: list = [];
    for event in task("go") {
        if event.event_type == "llm_timing" {
            timing_events.append(event.data);
        }
    }

    assert len(timing_events) == 1;
    assert set(timing_events[0].keys()) == {"duration_ms", "iteration"} , (
        f"llm_timing should carry only timing data now that usage_step covers "
        f"token/cost per call, got keys={list(timing_events[0].keys())}"
    );
}
