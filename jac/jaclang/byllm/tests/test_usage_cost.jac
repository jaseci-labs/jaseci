"""Cost on the usage payload (#7896).

Uses litellm's real `completion_cost` rather than a stub: `_attach_call_cost`
swallows every exception, so a mocked suite stays green while the feature
reports nothing. The pricing table is local, so this needs no network or key.
"""

import asyncio;
import litellm;
import from support_tests { FakeLLM, TOKENS, mk_run, response, say }

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


def _usage_from(path: str, model: str = MODEL, usage: dict | None = None) -> any {
    tokens = dict(TOKENS) if usage is None else usage;
    llm = FakeLLM(model_name=model, replies=[say("hi", usage=tokens)]);
    mt = mk_run();
    if path == "dispatch_no_streaming" {
        return llm.dispatch_no_streaming(mt).usage;
    }
    if path == "adispatch_no_streaming" {
        coro: any = llm.adispatch_no_streaming(mt);
        result: any = asyncio.run(coro);
        return result.usage;
    }
    if path == "dispatch_streaming_with_tools" {
        out: list = [];
        list(llm.dispatch_streaming_with_tools(mt, out));
        return out[0].usage;
    }
    if path == "dispatch_streaming" {
        list(llm.dispatch_streaming(mt));
        return llm._usage_history[-1];
    }
    asyncio.run(_drain(llm.adispatch_streaming(mt)));
    return llm._usage_history[-1];
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
