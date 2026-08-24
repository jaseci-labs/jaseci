"""Usage, cost, and per-call exposure tracking (#7896, #8462, #8484).

byLLM computes real token usage and cost for every LLM call, records it on
the per-call `mt_run` (never the shared model instance, which would corrupt
concurrent invocations), tags calls its own machinery makes on the caller's
behalf (final-answer restream, recovery, compaction) with a `call_kind`
distinct from ordinary ReAct iterations, and surfaces it three ways: the
`usage` StreamEvent (once, at the end of the whole invocation), `usage_step`
(once per individual call, so a caller enforcing a budget doesn't have to
wait for a possibly many-call turn to finish), and the `tokens` field on
`register_agent_callback`'s telemetry record. All three share the same
`_aggregate_usage`/`_record_usage` machinery and the same per-call record
shape, including cost (trusting litellm's own native computation when it's
available, falling back to a local `completion_cost()` call otherwise) and
cache token counts (normalized to the same field names regardless of how a
given provider reports them).
"""

import asyncio;
import unittest.mock;
import types;
import dataclasses;
import litellm;
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
import from jaclang.byllm.telemetry { register_agent_callback, _agent_callbacks }

glob MODEL = "gpt-4o-mini",
     UNPRICEABLE = "openai/ft:definitely-not-a-real-model:acme::zzz",
     TOKENS = {"prompt_tokens": 100, "completion_tokens": 20, "total_tokens": 120},
     DISPATCH_PATHS = [
         "dispatch_no_streaming",
         "adispatch_no_streaming",
         "dispatch_streaming_with_tools",
         "dispatch_streaming",
         "adispatch_streaming"
     ],
     _Person = dataclasses.make_dataclass(
         "UsageTestsPerson", [("name", str), ("age", int)]
     );


def step_a -> str {
    return "stepped";
}


def finish_tool(final_output: str) -> str {
    return final_output;
}


# A model_call_with_stream return value with a real .logging_obj, matching
# the shape of litellm's CustomStreamWrapper.
class _FakeStreamResp {
    def init(self: _FakeStreamResp, chunks: list, logging_obj: object) {
        self.chunks = chunks;
        self.logging_obj = logging_obj;
    }

    def __iter__(self: _FakeStreamResp) -> object {
        return iter(self.chunks);
    }
}


def _response(
    usage: dict | None = None, model: str = MODEL, content: str = "hi"
) -> dict {
    return {
        "model": model,
        "choices": [
            {
                "message": {"role": "assistant", "content": content, "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "usage": dict(TOKENS) if usage is None else usage
    };
}


def _mt(
    resp_type: type = str, stream: bool = False, tools: list | None = None
) -> MTRuntime {
    return MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="u")
        ],
        resp_type=resp_type,
        stream=stream,
        tools=tools if tools is not None else [],
        call_params={},
        mtir=None
    );
}


# A typed by-model() env whose fake response calls finish_tool - shared setup
# for both the "hidden call" tagging tests and usage_step's recovery test
# (recovery_response there is this same shape).
def _finish_env(arguments: str, usage: dict) -> tuple {
    model = Model(model_name="test-model");
    mt_run = _mt(resp_type=_Person, tools=[Tool.make_finish_tool(_Person)]);
    fake_fn = types.SimpleNamespace(name="finish_tool", arguments=arguments);
    fake_response = {
        "choices": [
            {
                "message": {
                    "content": None,
                    "tool_calls": [types.SimpleNamespace(id="call_1", function=fake_fn)]
                }
            }
        ],
        "usage": usage
    };
    return (model, mt_run, fake_response);
}


def _with_callback(cb: Callable, fn: Callable) -> object {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    register_agent_callback(cb);
    try {
        return fn();
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}


# =============================================================================
# Cost computation (#7896)
# =============================================================================
# Uses litellm's real `completion_cost` rather than a stub: `_attach_call_cost`
# swallows every exception, so a mocked suite stays green while the feature
# reports nothing. The pricing table is local, so this needs no network or key.

def _usage_from(path: str, response: dict | None = None) -> any {
    resp = response if response is not None else _response();
    llm = Model(model_name=resp["model"]);
    mt = _mt();
    chunks = [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        ),
        types.SimpleNamespace(usage=litellm.Usage(**TOKENS), choices=[])
    ];
    _call = lambda (params: dict) { return resp; };
    _stream = lambda (params: dict) { return chunks; };
    _rebuild = lambda (seen: list, logging_obj: object = None) { return resp; };

    async def _acall(params: dict) -> dict {
        return resp;
    }
    async def _astream(params: dict) -> any {
        async def _aiter -> any {
            for item in chunks {
                yield item;
            }
        }
        return _aiter();
    }

    if path == "dispatch_no_streaming" {
        with unittest.mock.patch.object(llm, "model_call_no_stream", _call) {
            return llm.dispatch_no_streaming(mt).usage;
        }
    }
    if path == "adispatch_no_streaming" {
        with unittest.mock.patch.object(llm, "model_call_no_stream_async", _acall) {
            coro: any = llm.adispatch_no_streaming(mt);
            result: any = asyncio.run(coro);
            return result.usage;
        }
    }
    if path == "dispatch_streaming_with_tools" {
        out: list = [];
        with unittest.mock.patch.object(llm, "model_call_with_stream", _stream), unittest.mock.patch.object(
            _byllm_llm_mod.litellm, "stream_chunk_builder", _rebuild
        ) {
            list(llm.dispatch_streaming_with_tools(mt, out));
        }
        return out[0].usage;
    }
    if path == "dispatch_streaming" {
        with unittest.mock.patch.object(llm, "model_call_with_stream", _stream) {
            list(llm.dispatch_streaming(mt));
        }
        return mt._usage_history[-1];
    }
    with unittest.mock.patch.object(llm, "model_call_with_stream_async", _astream) {
        agen: any = llm.adispatch_streaming(mt);
        async def _drain {
            async for _item in agen { }
        }
        asyncio.run(_drain());
    }
    return mt._usage_history[-1];
}


def _cost_of(usage: any) -> any {
    return usage.get("cost") if isinstance(usage, dict) else usage?.cost;
}


test "every dispatch path reports the cost litellm computes for the call" {
    expected = litellm.completion_cost(completion_response=_response(), model=MODEL);
    assert expected > 0.0 , f"litellm priced {MODEL} at {expected}; fixture is blind";

    for path in DISPATCH_PATHS {
        usage = _usage_from(path);
        cost = _cost_of(usage);
        assert cost is not None , f"{path} left no cost on the usage payload";
        assert abs(cost - expected) < 1e-12 , (
            f"{path} reported {cost}, litellm computes {expected}"
        );
        if not isinstance(usage, dict) {
            dumped: dict = usage.model_dump();
            assert "cost" in dumped , (
                f"{path} set cost but model_dump() dropped it, so would the aggregate"
            );
        }
    }
}


test "cost is omitted rather than guessed when it cannot be computed" {
    for (label, resp) in [
        ("unpriceable model", _response(model=UNPRICEABLE)),
        ("response with no usage data", _response(usage={}))
    ] {
        usage = _usage_from("dispatch_no_streaming", resp);
        assert _cost_of(usage) is None , (
            f"{label} reported cost={_cost_of(usage)}; unknown must stay distinct "
            "from free"
        );
        if resp["usage"] {
            assert usage["prompt_tokens"] == TOKENS["prompt_tokens"] , (
                f"{label} must leave the token counts intact"
            );
        }
    }
}


test "_attach_call_cost trusts a cost litellm already computed" {
    usage = litellm.Usage(**TOKENS);
    usage.cost = 0.0042;
    with unittest.mock.patch.object(
        litellm, "completion_cost", return_value=999.0
    ) as spy {
        _byllm_llm_mod._attach_call_cost(usage, MODEL);
        assert spy.call_count == 0 , (
            "a cost litellm already attached must not trigger recomputation"
        );
    }
    assert usage.cost == 0.0042 , "a cost litellm already attached must not be overwritten";
}


test "byllm opts in to litellm's native include_cost_in_streaming_usage, configurably" {
    # litellm can compute `cost` on the usage object itself, from its own
    # full response context, when this flag is set - byLLM's own fallback
    # (`completion_cost` from a synthetic {model, usage} shape) is strictly
    # less accurate, so byLLM opts in by default.
    litellm.include_cost_in_streaming_usage = False;
    Model(model_name=MODEL);
    assert litellm.include_cost_in_streaming_usage , (
        "byllm should opt in to litellm's native streaming cost computation by default"
    );

    with unittest.mock.patch.dict(
        _byllm_llm_mod._litellm_config,
        {"debug": False, "drop_params": True, "include_cost_in_streaming_usage": False},
        clear=True
    ) {
        litellm.include_cost_in_streaming_usage = True;
        Model(model_name=MODEL);
        assert not litellm.include_cost_in_streaming_usage , (
            "config should be able to turn off litellm's native streaming cost "
            "computation"
        );
    }

    import from jaclang.byllm.config_loader { JacByllmConfig }
    defaults = JacByllmConfig().get_default_config();
    assert defaults["litellm"]["include_cost_in_streaming_usage"] == True , (
        "include_cost_in_streaming_usage should default to True"
    );
}


test "dispatch_streaming_with_tools passes the stream's own logging_obj to stream_chunk_builder" {
    # litellm only attaches a native cost via include_cost_in_streaming_usage
    # when stream_chunk_builder receives a logging_obj - byLLM's own rebuild
    # call must forward the one attached to the CustomStreamWrapper it got
    # back from model_call_with_stream, or every tools-loop call silently
    # loses the native path and falls back to a manual completion_cost().
    llm = Model(model_name=MODEL);
    mt = _mt(stream=True);

    fake_logging_obj = object();
    fake_chunk = types.SimpleNamespace(
        usage=None,
        choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
    );
    stream_resp = _FakeStreamResp(chunks=[fake_chunk], logging_obj=fake_logging_obj);
    seen_logging_obj: list = [];
    def _rebuild(seen: list, logging_obj: object = None) -> dict {
        seen_logging_obj.append(logging_obj);
        return _response();
    }

    out: list = [];
    with unittest.mock.patch.object(
        llm, "model_call_with_stream", lambda (params: dict) { return stream_resp; }
    ), unittest.mock.patch.object(
        _byllm_llm_mod.litellm, "stream_chunk_builder", _rebuild
    ) {
        list(llm.dispatch_streaming_with_tools(mt, out));
    }

    assert seen_logging_obj == [fake_logging_obj] , (
        f"stream_chunk_builder should receive the stream's own logging_obj, "
        f"got {seen_logging_obj}"
    );
}


# =============================================================================
# Usage capture and call_kind tagging (#8462)
# =============================================================================
# Usage lives on the per-call mt_run, not the shared model instance (which is
# routinely reused across concurrent invocations - a module-level
# `glob llm = Model(...)`, or a tool function that itself calls `by llm()`
# from dispatch_batch's thread pool). Calls byLLM's own machinery makes on
# the caller's behalf are tagged with a call_kind distinct from ordinary
# react_iteration calls.

test "usage is recorded on mt_run, isolated per invocation, sync and async alike" {
    llm = Model(model_name="gpt-4o-mini");
    mt_sync = _mt();
    mt_async = _mt();

    with unittest.mock.patch.object(
        llm,
        "model_call_no_stream",
        return_value=_response(
            {"prompt_tokens": 10, "completion_tokens": 1, "total_tokens": 11}
        )
    ) {
        llm.dispatch_no_streaming(mt_sync);
    }

    async def _fake(params: dict) -> dict {
        return _response(
            {"prompt_tokens": 20, "completion_tokens": 2, "total_tokens": 22}
        );
    }
    with unittest.mock.patch.object(llm, "model_call_no_stream_async", _fake) {
        coro: any = llm.adispatch_no_streaming(mt_async);
        asyncio.run(coro);
    }

    assert len(mt_sync._usage_history) == 1 , "mt_sync should see exactly its own call";
    assert len(mt_async._usage_history) == 1 , "mt_async should see exactly its own call";
    assert mt_sync._usage_history[0]["prompt_tokens"] == 10;
    assert mt_async._usage_history[0]["prompt_tokens"] == 20 , (
        "the async primitive must record usage too, not just the sync one"
    );
    assert mt_sync._usage_history[0]["call_kind"] == "react_iteration";
    assert mt_sync._usage_history[0]["model"] == "gpt-4o-mini";
}


test "a plain non-streaming by llm() call surfaces tokens via register_agent_callback" {
    # Model wraps a MockLLM delegate but is the layer that actually owns
    # telemetry emission (Model.invoke) - a bare MockLLM never fires it.
    llm = Model(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                    {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
                )
            ]
        }
    );

    def my_task(q: str) -> str by llm(tools=[finish_tool]);

    captured: list = [];
    def cb(record: dict) {
        captured.append(record);
    }

    result = _with_callback(cb, lambda { return my_task("test"); });

    assert result == "ok";
    assert len(captured) == 1;
    tokens = captured[0]["tokens"];
    assert tokens["requests"] == 1 , f"Expected 1 recorded call, got {tokens}";
    assert tokens["total"]["total_tokens"] == 110;
    assert "react_iteration" in tokens["by_kind"];
    assert tokens["by_kind"]["react_iteration"]["total_tokens"] == 110;
}


test "final_answer_restream call is tagged separately from react iterations" {
    (model, mt_run, _resp) = _finish_env(
        '{"output": {"name": "Gus", "age": 29}}',
        {"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55}
    );
    mt_run.stream = True;

    def _fake_stream(params: dict) -> object {
        return [
            types.SimpleNamespace(
                usage=None,
                choices=[
                    types.SimpleNamespace(delta=types.SimpleNamespace(content="Gus"))
                ]
            ),
            types.SimpleNamespace(
                usage=types.SimpleNamespace(
                    prompt_tokens=50, completion_tokens=5, total_tokens=55
                ),
                choices=[]
            )
        ];
    }

    with unittest.mock.patch.object(model, "model_call_with_stream", _fake_stream) {
        list(model._stream_final_answer(mt_run));
    }

    assert len(mt_run._usage_history) == 1;
    assert mt_run._usage_history[0]["call_kind"] == "final_answer_restream";
    # The temporary override must not leak onto later calls on the same mt_run.
    assert mt_run._call_kind == "react_iteration";
}


test "recovery call is tagged separately from react iterations" {
    (model, mt_run, fake_response) = _finish_env(
        '{"output": {"name": "Gus", "age": 29}}',
        {"prompt_tokens": 15, "completion_tokens": 3, "total_tokens": 18}
    );
    with unittest.mock.patch.object(
        model, "model_call_no_stream", return_value=fake_response
    ) {
        model._attempt_recovery(mt_run);
    }

    assert len(mt_run._usage_history) == 1;
    assert mt_run._usage_history[0]["call_kind"] == "recovery";
    assert mt_run._call_kind == "react_iteration";
}


test "default compactor's summarisation call is tagged compaction on the parent mt_run" {
    sys_msg = {"role": "system", "content": "You are a helpful assistant."};
    user_msg = {"role": "user", "content": "Do the thing."};
    round1 = [
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": "call_1",
                    "function": {"name": "search", "arguments": '{"q":"a"}'}
                }
            ]
        },
        {
            "role": "tool",
            "content": "result_1",
            "tool_call_id": "call_1",
            "name": "search"
        }
    ];
    messages = [sys_msg, user_msg] + round1 + round1 + round1;

    # MockLLM's (output, usage) tuple convention only recognizes tool-call
    # outputs (see mockllm.impl.jac's first_is_tool check) - compaction's
    # summariser call returns a plain string, so a real Model with a mocked
    # response is used here to inject usage.
    summariser = Model(model_name="test-model");
    parent_mt = _mt();

    with unittest.mock.patch.object(
        summariser,
        "model_call_no_stream",
        return_value=_response(
            {"prompt_tokens": 200, "completion_tokens": 20, "total_tokens": 220},
            content="a summary"
        )
    ) {
        _byllm_llm_mod._default_compact(messages, 1, summariser, parent_mt);
    }

    assert len(parent_mt._usage_history) == 1;
    assert parent_mt._usage_history[0]["call_kind"] == "compaction";
    assert parent_mt._usage_history[0]["total_tokens"] == 220;
}


test "async by llm() call with no tools surfaces telemetry and tokens the same as sync" {
    # No-tools, non-streaming is the branch BaseLLM.ainvoke dispatches directly
    # (_ainvoke_typed_retry) rather than delegating to the already-telemetered
    # sync Model.invoke via asyncio.to_thread - this is the branch that had no
    # telemetry at all before Model.ainvoke existed.
    llm = Model(model_name="test-model");

    async def _fake(params: dict) -> dict {
        return _response(
            {"prompt_tokens": 12, "completion_tokens": 2, "total_tokens": 14},
            content="async-ok"
        );
    }

    async def my_async_task(q: str) -> str by llm();

    captured: list = [];
    def cb(record: dict) {
        captured.append(record);
    }

    def _run -> str {
        with unittest.mock.patch.object(llm, "model_call_no_stream_async", _fake) {
            return asyncio.run(my_async_task("test"));
        }
    }
    result = _with_callback(cb, _run);

    assert result == "async-ok";
    assert len(captured) == 1 , "async invocation should emit telemetry exactly once";
    assert captured[0]["status"] == "success";
    assert captured[0]["tokens"]["total"]["total_tokens"] == 14;
}


test "usage StreamEvent always terminates a logging=True stream, even with no usage data" {
    llm = MockLLM(model_name="mockllm", config={"outputs": ["hello there"]});

    def my_task(q: str) -> str by llm(stream=True, logging=True);

    events = list(my_task("test"));
    assert events , "expected at least the usage event";
    assert events[-1].event_type == "usage" , (
        f"usage must be the last event even with no measurable tokens, got "
        f"{events[-1].event_type}"
    );
    assert events[-1].data["total"] == {};
    assert events[-1].data["per_call"] == [];
    assert events[-1].data["by_kind"] == {};
    assert events[-1].data["requests"] == 0;
}


test "cache token fields are normalized onto every recorded call, regardless of provider shape" {
    mt = _mt();

    # Anthropic-shaped: cache fields already top-level.
    _byllm_llm_mod._record_usage(
        mt,
        {
            "prompt_tokens": 100,
            "completion_tokens": 10,
            "total_tokens": 110,
            "cache_read_input_tokens": 40,
            "cache_creation_input_tokens": 15
        },
        "claude-sonnet-4-5"
    );

    # OpenAI-shaped: cache reads only nested under prompt_tokens_details, no
    # cache-creation concept at all.
    _byllm_llm_mod._record_usage(
        mt,
        {
            "prompt_tokens": 200,
            "completion_tokens": 20,
            "total_tokens": 220,
            "prompt_tokens_details": {"cached_tokens": 60}
        },
        "gpt-4o-mini"
    );

    # No cache concept whatsoever.
    _byllm_llm_mod._record_usage(
        mt,
        {"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55},
        "some-model"
    );

    assert len(mt._usage_history) == 3;

    anthropic_rec = mt._usage_history[0];
    assert anthropic_rec["cache_read_input_tokens"] == 40;
    assert anthropic_rec["cache_creation_input_tokens"] == 15;

    openai_rec = mt._usage_history[1];
    assert openai_rec["cache_read_input_tokens"] == 60 , (
        "cache_read_input_tokens must be normalized from the nested "
        "prompt_tokens_details.cached_tokens when no top-level field exists"
    );
    assert openai_rec["cache_creation_input_tokens"] == 0 , (
        "a provider with no cache-creation concept must report 0, not be "
        "missing the key entirely"
    );

    bare_rec = mt._usage_history[2];
    assert bare_rec["cache_read_input_tokens"] == 0;
    assert bare_rec["cache_creation_input_tokens"] == 0;
}


# =============================================================================
# Per-call usage exposure during a streaming ReAct loop (#8484)
# =============================================================================
# `usage` only fires once, after the whole invocation finishes - a caller
# enforcing a per-turn budget can only discover an overrun after a possibly
# many-call turn has already run. `usage_step` fires once per individual LLM
# call instead (main ReAct iteration, final-answer restream, recovery),
# reusing the exact `usage` shape so both can be parsed with the same code.
# `IterationContext.total_cost` gives the same real, cumulative cost between
# calls that `on_iteration` already exposes for tokens.

test "usage_step fires once per react call, scoped to that call's own usage, shape-matching usage" {
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
    final_usage: dict | None = None;
    events = list(task("go"));
    for event in events {
        if event.event_type == "usage_step" {
            usage_steps.append(event.data);
        }
        if event.event_type == "usage" {
            final_usage = event.data;
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
    assert final_usage is not None;
    assert set(usage_steps[0].keys()) == set(final_usage.keys()) , (
        "usage_step must reuse the exact usage event shape so both can be "
        "parsed with the same code"
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

    mt_run = _mt(stream=True, tools=[Tool(func=step_a), Tool.make_finish_tool(str)]);

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
    events = list(task("go"));
    for event in events {
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
    (model, mt_run, recovery_response) = _finish_env(
        '{"output": {"name": "Gus", "age": 29}}',
        {"prompt_tokens": 40, "completion_tokens": 8, "total_tokens": 48}
    );
    mt_run.stream = True;

    def fake_dispatch_streaming_with_tools(
        mt: MTRuntime, out: list
    ) -> Generator[str, None, None] {
        raise OutputConversionError("forced for test");
        for _tok in [] {
            yield _tok;
        }
    }

    def _empty_stream(mt: MTRuntime) -> Generator[str, None, None] {
        for _tok in [] {
            yield _tok;
        }
    }

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
    events = list(task("go"));
    for event in events {
        event_types.append(event.event_type);
    }

    assert "usage_step" not in event_types , (
        "a single-call invocation has nothing to distinguish a per-call step "
        "from the final aggregate; usage_step must not duplicate it"
    );
    assert event_types.count("usage") == 1;
}


test "_usage_history_total_cost sums real cost across recorded calls" {
    mt = _mt(stream=True);
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


test "on_iteration's IterationContext exposes real cumulative total_cost" {
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
    ctx = seen_contexts[0];
    assert ctx.total_tokens == 110 , (
        f"total_tokens should reflect the real first call, got {ctx.total_tokens}"
    );
    # MockLLM never attaches a cost (see mockllm.impl.jac - it calls
    # _record_usage directly, not _attach_call_cost), so the real, honest
    # expectation here is 0.0, not a fabricated number. The summation logic
    # itself is exercised with real, non-zero costs by
    # "_usage_history_total_cost sums real cost across recorded calls" above;
    # this test only needs to confirm the field is actually wired through.
    assert ctx.total_cost == 0.0 , (
        f"total_cost should reflect real recorded cost (none here), got {ctx.total_cost}"
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
    events = list(task("go"));
    for event in events {
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
