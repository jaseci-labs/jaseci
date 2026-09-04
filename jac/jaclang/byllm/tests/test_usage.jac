"""Usage and cost reach the caller from every invocation shape (#8462).

Every dispatch primitive records what the model reported on the invocation's
own MTRuntime, so a model instance shared across concurrent calls never mixes
them, and the telemetry record's `tokens` carries the summary whether the call
streamed or not. Cost uses litellm's real `completion_cost`: `_attach_call_cost`
swallows every exception, so a stubbed one would stay green while the feature
reported nothing. The pricing table is local, so no network or key is needed.
"""

import asyncio;
import litellm;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.telemetry { register_agent_callback, _agent_callbacks }
import from support_tests { FakeLLM, TOKENS, call, mk_run, response, say, scripted }

glob MODEL = "gpt-4o-mini",
     UNPRICEABLE = "openai/ft:definitely-not-a-real-model:acme::zzz",
     PATHS = [
         "dispatch_no_streaming",
         "adispatch_no_streaming",
         "dispatch_streaming_with_tools",
         "dispatch_streaming",
         "adispatch_streaming"
     ];


def _cost_of(usage: any) -> any {
    return usage.get("cost") if isinstance(usage, dict) else usage?.cost;
}


async def _drain(agen: any) {
    async for _item in agen {}
}


"""Drive one dispatch path; returns the usage it reported and the MTRuntime."""
def _dispatch(llm: FakeLLM, path: str) -> tuple {
    mt = mk_run();
    if path == "dispatch_no_streaming" {
        return (llm.dispatch_no_streaming(mt).usage, mt);
    }
    if path == "adispatch_no_streaming" {
        coro: any = llm.adispatch_no_streaming(mt);
        result: any = asyncio.run(coro);
        return (result.usage, mt);
    }
    if path == "dispatch_streaming_with_tools" {
        out: list = [];
        list(llm.dispatch_streaming_with_tools(mt, out));
        return (out[0].usage, mt);
    }
    if path == "dispatch_streaming" {
        list(llm.dispatch_streaming(mt));
        return (mt._usage_history[-1], mt);
    }
    asyncio.run(_drain(llm.adispatch_streaming(mt)));
    return (mt._usage_history[-1], mt);
}


def _usage_from(path: str, model: str = MODEL, usage: dict | None = None) -> any {
    tokens = dict(TOKENS) if usage is None else usage;
    llm = FakeLLM(model_name=model, replies=[say("hi", usage=tokens)]);
    return _dispatch(llm, path)[0];
}


test "every dispatch path reports the cost litellm computes for the call" {
    expected = litellm.completion_cost(
        completion_response=response(say("hi", usage=TOKENS), MODEL), model=MODEL
    );
    assert expected > 0.0 , f"litellm priced {MODEL} at {expected}; fixture is blind";

    for path in PATHS {
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
    for (label, model, tokens) in [
        ("unpriceable model", UNPRICEABLE, dict(TOKENS)),
        ("response with no usage data", MODEL, {})
    ] {
        usage = _usage_from("dispatch_no_streaming", model, tokens);
        assert _cost_of(usage) is None , (
            f"{label} reported cost={_cost_of(usage)}; unknown must stay distinct "
            "from free"
        );
        if tokens {
            assert usage["prompt_tokens"] == TOKENS["prompt_tokens"] , (
                f"{label} must leave the token counts intact"
            );
        }
    }
}


test "every dispatch path records its usage on the invocation, never on the model" {
    llm = FakeLLM(replies=[say("hi", usage=TOKENS) for _p in PATHS]);
    seen: list = [];
    for path in PATHS {
        (usage, mt) = _dispatch(llm, path);
        assert len(mt._usage_history) == 1 , (
            f"{path}: expected one record on its own MTRuntime, got {mt._usage_history}"
        );
        assert mt.usage_summary()["total"]["total_tokens"] == TOKENS["total_tokens"] , (
            f"{path}: summary lost the tokens: {mt.usage_summary()}"
        );
        seen.append(mt);
    }
    assert not hasattr(llm, "_usage_history") , "usage must not accumulate on the shared model";
    assert len({id(m._usage_history) for m in seen}) == len(PATHS) , (
        "each invocation must own its history"
    );
}


test "a reply the caller cannot parse is still counted" {
    import dataclasses;
    import from jaclang.byllm.exceptions { OutputConversionError }
    person = dataclasses.make_dataclass("UsagePerson", [("name", str), ("age", int)]);
    for (why, use_async) in [("sync", False), ("async", True)] {
        llm = FakeLLM(replies=[say("not json at all", usage=TOKENS)]);
        mt = mk_run(resp_type=person);
        raised = False;
        try {
            if use_async {
                coro: any = llm.adispatch_no_streaming(mt);
                asyncio.run(coro);
            } else {
                llm.dispatch_no_streaming(mt);
            }
        } except OutputConversionError {
            raised = True;
        }
        assert raised , f"{why}: expected the parse failure to surface";
        assert len(mt._usage_history) == 1 , (
            f"{why}: the model was paid for this call, so it must be recorded: {mt._usage_history}"
        );
    }
}


"""Run `fn` with `cb` as the only telemetry callback; returns what it captured."""
def _telemetry_of(fn: any) -> list {
    captured: list = [];
    def cb(record: dict) {
        captured.append(record);
    }
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    register_agent_callback(cb);
    try {
        fn();
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
    return captured;
}


test "tokens reach the telemetry callback from every invocation shape" {
    def lookup(q: str) -> str {
        return f"found {q}";
    }
    model = Model(model_name=MODEL);
    def plain(q: str) -> str by model();
    def with_tools(q: str) -> str by model(tools=[lookup]);
    def streamed(q: str) -> str by model(tools=[lookup], stream=True, logging=True);
    async def plain_async(q: str) -> str by model();

    # (why, scripted replies, run, model calls made)
    shapes = [
        (
            "non-streaming, no tools",
            [say("ok", usage=TOKENS)],
            lambda { return plain("q"); },
            1
        ),
        (
            "non-streaming with tools",
            [call("lookup", {"q": "x"}, usage=TOKENS), say("ok", usage=TOKENS)],
            lambda { return with_tools("q"); },
            2
        ),
        (
            "streaming with tools, logging=True",
            [call("lookup", {"q": "x"}, usage=TOKENS), say("ok", usage=TOKENS)],
            lambda { return list(streamed("q")); },
            2
        ),
        (
            "async, no tools",
            [say("ok", usage=TOKENS)],
            lambda { return asyncio.run(plain_async("q")); },
            1
        )
    ];
    for (why, replies, run, calls_made) in shapes {
        results: list = [];
        with scripted(model, replies) as script {
            records = _telemetry_of(lambda { results.append(run()); });
            assert script.exhausted() , f"{why}: expected {calls_made} model calls";
        }
        assert len(records) == 1 , f"{why}: expected one telemetry record, got {len(
            records
        )}";
        tokens = records[0]["tokens"];
        assert len(tokens["per_call"]) == calls_made , (
            f"{why}: expected {calls_made} per-call records, got {tokens['per_call']}"
        );
        assert tokens["total"]["total_tokens"] == TOKENS["total_tokens"] * calls_made , (
            f"{why}: total lost calls: {tokens['total']}"
        );
        if why.startswith("streaming") {
            events: any = results[0];
            assert events[-1].event_type == "usage" , f"{why}: usage must stay the last event";
            assert events[-1].data == tokens , (
                f"{why}: the usage event and the telemetry record must agree"
            );
        }
    }
}
