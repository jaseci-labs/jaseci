"""Cost attached to the usage payload (#7896).

These tests drive litellm's real `completion_cost`. Mocking it would only prove
a float travelled from one function to another, and would keep passing if the
call itself broke -- `_attach_call_cost` swallows every exception, so a mocked
suite stays green while the feature reports nothing. The pricing table is local
and synchronous, so exercising it costs no network and no key, and the expected
figure is read from that same table rather than hard-coded so a repricing moves
both sides together.
"""

import asyncio;
import types;
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import litellm;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole }

glob MODEL = "gpt-4o-mini",
     UNPRICEABLE = "openai/ft:definitely-not-a-real-model:acme::zzz",
     PROMPT_TOKENS = 100,
     COMPLETION_TOKENS = 20,
     PATHS = [
         "dispatch_no_streaming",
         "adispatch_no_streaming",
         "dispatch_streaming_with_tools",
         "dispatch_streaming",
         "adispatch_streaming"
     ];


def _response(model: str = MODEL, usage: (dict | None) = None) -> dict {
    return {
        "model": model,
        "choices": [
            {
                "message": {"role": "assistant", "content": "hi", "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "usage": usage
            if usage is not None
            else {
                "prompt_tokens": PROMPT_TOKENS,
                "completion_tokens": COMPLETION_TOKENS,
                "total_tokens": PROMPT_TOKENS + COMPLETION_TOKENS
            }
    };
}


"""Read `cost` off either shape of usage object, or None when it is absent."""
def _cost_of(usage: any) -> any {
    return usage.get("cost")
        if isinstance(usage, dict)
        else getattr(usage, "cost", None);
}


async def _aiter(items: list) {
    for item in items {
        yield item;
    }
}


async def _drain(agen: any) {
    async for _item in agen { }
}


"""Run one dispatch path against a canned response and hand back its usage.

The streaming paths carry a real litellm `Usage`, which is what production sees
and what the aggregate later serialises; the others carry the response's dict.
"""
def _usage_from(path: str, response: (dict | None) = None) -> any {
    resp = response if response is not None else _response();
    llm = Model(model_name=resp["model"]);
    mt = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="u")
        ],
        resp_type=str,
        stream=False,
        tools=[],
        call_params={},
        mtir=None
    );
    chunks = [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        ),
        types.SimpleNamespace(
            usage=litellm.Usage(
                prompt_tokens=PROMPT_TOKENS,
                completion_tokens=COMPLETION_TOKENS,
                total_tokens=PROMPT_TOKENS + COMPLETION_TOKENS
            ),
            choices=[]
        )
    ];

    _call = lambda (params: dict) { return resp; };
    _stream = lambda (params: dict) { return chunks; };
    _rebuild = lambda (seen: list) { return resp; };

    async def _acall(params: dict) -> dict {
        return resp;
    }
    async def _astream(params: dict) -> any {
        return _aiter(chunks);
    }

    if path == "dispatch_no_streaming" {
        with mock.patch.object(llm, "model_call_no_stream", _call) {
            return llm.dispatch_no_streaming(mt).usage;
        }
    }
    if path == "adispatch_no_streaming" {
        with mock.patch.object(llm, "model_call_no_stream_async", _acall) {
            coro: any = llm.adispatch_no_streaming(mt);
            result: any = asyncio.run(coro);
            return result.usage;
        }
    }
    if path == "dispatch_streaming_with_tools" {
        out: list = [];
        with mock.patch.object(llm, "model_call_with_stream", _stream), mock.patch.object(
            _byllm_llm_mod.litellm, "stream_chunk_builder", _rebuild
        ) {
            list(llm.dispatch_streaming_with_tools(mt, out));
        }
        return out[0].usage;
    }
    if path == "dispatch_streaming" {
        with mock.patch.object(llm, "model_call_with_stream", _stream) {
            list(llm.dispatch_streaming(mt));
        }
        return llm._usage_history[-1];
    }
    with mock.patch.object(llm, "model_call_with_stream_async", _astream) {
        agen: any = llm.adispatch_streaming(mt);
        asyncio.run(_drain(agen));
    }
    return llm._usage_history[-1];
}


test "every dispatch path reports the cost litellm computes for the call" {
    # Comparing against litellm's own table pins the integration rather than a
    # price: wrong arguments, a changed signature, or a swallowed failure all
    # land as a missing or mismatched cost. Agreement across the five also pins
    # the synthetic {"model", "usage"} wrapper the streaming paths build against
    # the full response the others pass.
    expected = litellm.completion_cost(completion_response=_response(), model=MODEL);
    assert expected > 0.0 , (
        f"litellm priced {MODEL} at {expected}; this fixture can no longer detect a "
        "regression"
    );

    for path in PATHS {
        cost = _cost_of(_usage_from(path));
        assert cost is not None , f"{path} left no cost on the usage payload";
        assert abs(cost - expected) < 1e-12 , (
            f"{path} reported {cost}, litellm computes {expected} for the same call"
        );
    }
}


test "cost survives the serialisation the aggregate reads usage through" {
    # The streaming paths set `cost` on a real litellm Usage, and the aggregate
    # in `_invoke_streaming` reads each entry via `model_dump()`. That carries an
    # attribute litellm never declared only because Usage permits extras, so the
    # totals rest on a third-party detail worth pinning.
    usage = _usage_from("dispatch_streaming");

    assert not isinstance(usage, dict) , "streaming should carry litellm's Usage object";
    dumped = usage.model_dump();
    assert "cost" in dumped , (
        f"cost is set on the object but lost in model_dump(), so the aggregate would "
        f"drop it. Keys: {sorted(dumped.keys())}"
    );
    assert dumped["cost"] == _cost_of(usage) , dumped;
}


test "a model litellm cannot price leaves cost unset and never raises" {
    usage = _usage_from("dispatch_no_streaming", _response(UNPRICEABLE));

    assert _cost_of(usage) is None , (
        f"an unpriceable model must leave cost unset, got {_cost_of(usage)}"
    );
    assert usage["prompt_tokens"] == PROMPT_TOKENS , (
        "token counts must survive a pricing failure"
    );
}


test "a response carrying no usage data reports no cost rather than zero" {
    # litellm prices an empty usage at 0.0. Attaching that makes a call whose
    # tokens are unknown indistinguishable from a free one and drags the
    # aggregate down silently -- the failure mode #7896 exists to remove.
    usage = _usage_from("dispatch_no_streaming", _response(MODEL, {}));

    assert _cost_of(usage) is None , (
        f"a response with no usage data reported cost={_cost_of(usage)}; unknown "
        "must stay distinguishable from free"
    );
}
