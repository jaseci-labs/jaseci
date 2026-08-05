"""Cost attached to the usage payload (#7896).

These tests drive litellm's real `completion_cost`. Mocking it would only prove
a float travelled from one function to another, and would keep passing if the
call itself broke -- which `_attach_call_cost` swallows silently, so a mocked
suite would stay green while the feature reported nothing. The pricing table is
local and synchronous, so using it costs no network and no key; the expected
figure is computed from that same table rather than hard-coded, so a price
change moves both sides together.
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
     COMPLETION_TOKENS = 20;


def _mt_run -> MTRuntime {
    return MTRuntime(
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
}


def _response(model: str = MODEL, usage: (dict | None) = None) -> dict {
    tokens = {
        "prompt_tokens": PROMPT_TOKENS,
        "completion_tokens": COMPLETION_TOKENS,
        "total_tokens": PROMPT_TOKENS + COMPLETION_TOKENS
    };
    return {
        "model": model,
        "choices": [
            {
                "message": {"role": "assistant", "content": "hi", "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "usage": tokens if usage is None else usage
    };
}


"""Read `cost` off either shape of usage object, or None when it is absent."""
def _cost_of(usage: any) -> any {
    if isinstance(usage, dict) {
        return usage.get("cost");
    }
    return getattr(usage, "cost", None);
}


obj _AsyncChunks {
    has items: list;

    def __aiter__ -> _AsyncChunks {
        return self;
    }

    async def __anext__ -> object {
        if not self.items {
            raise StopAsyncIteration;
        }
        return self.items.pop(0);
    }
}


async def _drain(agen: any) {
    async for _item in agen { }
}


"""Usage from the sync non-streaming path."""
def _via_no_streaming(llm: Model, response: (dict | None) = None) -> any {
    resp = response if response is not None else _response(llm.model_name);

    def _call(params: dict) -> dict {
        return resp;
    }
    with mock.patch.object(llm, "model_call_no_stream", _call) {
        return llm.dispatch_no_streaming(_mt_run()).usage;
    }
}


"""Usage from the async non-streaming path."""
def _via_no_streaming_async(llm: Model) -> any {
    resp = _response(llm.model_name);

    async def _call(params: dict) -> dict {
        return resp;
    }
    with mock.patch.object(llm, "model_call_no_stream_async", _call) {
        coro: any = llm.adispatch_no_streaming(_mt_run());
        return asyncio.run(coro).usage;
    }
}


"""Usage from the streaming-with-tools path (rebuilt by stream_chunk_builder)."""
def _via_streaming_with_tools(llm: Model) -> any {
    chunk = types.SimpleNamespace(
        choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
    );
    rebuilt = _response(llm.model_name);

    def _stream(params: dict) -> list {
        return [chunk];
    }
    def _builder(chunks: list) -> dict {
        return rebuilt;
    }
    out: list = [];
    with mock.patch.object(llm, "model_call_with_stream", _stream), mock.patch.object(
        _byllm_llm_mod.litellm, "stream_chunk_builder", _builder
    ) {
        list(llm.dispatch_streaming_with_tools(_mt_run(), out));
    }
    return out[0].usage;
}


"""A real litellm Usage, which is what the streaming paths actually carry."""
def _stream_chunks -> list {
    live_usage = litellm.Usage(
        prompt_tokens=PROMPT_TOKENS,
        completion_tokens=COMPLETION_TOKENS,
        total_tokens=PROMPT_TOKENS + COMPLETION_TOKENS
    );
    return [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        ),
        types.SimpleNamespace(usage=live_usage, choices=[])
    ];
}


"""Usage from the sync streaming path."""
def _via_streaming(llm: Model) -> any {
    chunks = _stream_chunks();

    def _stream(params: dict) -> list {
        return chunks;
    }
    with mock.patch.object(llm, "model_call_with_stream", _stream) {
        list(llm.dispatch_streaming(_mt_run()));
    }
    return llm._usage_history[-1];
}


"""Usage from the async streaming path."""
def _via_streaming_async(llm: Model) -> any {
    chunks = _stream_chunks();

    async def _stream(params: dict) -> _AsyncChunks {
        return _AsyncChunks(items=chunks);
    }
    with mock.patch.object(llm, "model_call_with_stream_async", _stream) {
        agen: any = llm.adispatch_streaming(_mt_run());
        asyncio.run(_drain(agen));
    }
    return llm._usage_history[-1];
}


test "every dispatch path reports the cost litellm computes for the call" {
    # The figure comes from litellm's own table, so this pins the integration
    # rather than a price: wrong arguments, a changed signature, or a silently
    # swallowed failure all land as a missing or mismatched cost.
    expected = litellm.completion_cost(completion_response=_response(), model=MODEL);
    assert expected > 0.0 , (
        f"litellm priced {MODEL} at {expected}; this fixture can no longer detect a "
        "regression"
    );

    paths = {
        "dispatch_no_streaming": _via_no_streaming(Model(model_name=MODEL)),
        "adispatch_no_streaming": _via_no_streaming_async(Model(model_name=MODEL)),
        "dispatch_streaming_with_tools": _via_streaming_with_tools(
            Model(model_name=MODEL)
        ),
        "dispatch_streaming": _via_streaming(Model(model_name=MODEL)),
        "adispatch_streaming": _via_streaming_async(Model(model_name=MODEL))
    };

    for (name, usage) in paths.items() {
        cost = _cost_of(usage);
        assert cost is not None , f"{name} left no cost on the usage payload";
        assert abs(cost - expected) < 1e-12 , (
            f"{name} reported {cost}, litellm computes {expected} for the same call"
        );
    }
}


test "cost survives the serialisation the aggregate reads usage through" {
    # The streaming paths set `cost` on a real litellm Usage, and the aggregate in
    # `_invoke_streaming` reads each entry via `model_dump()`. That only carries an
    # attribute litellm never declared because Usage allows extras, so the totals
    # rest on a third-party detail worth pinning here.
    llm = Model(model_name=MODEL);
    usage = _via_streaming(llm);

    assert not isinstance(usage, dict) , "streaming should carry litellm's Usage object";
    dumped = usage.model_dump();
    assert "cost" in dumped , (
        f"cost is set on the object but lost in model_dump(), so the aggregate would "
        f"drop it. Keys: {sorted(dumped.keys())}"
    );
    assert dumped["cost"] == _cost_of(usage) , dumped;
}


test "a model litellm cannot price leaves cost unset and never raises" {
    llm = Model(model_name=UNPRICEABLE);
    usage = _via_no_streaming(llm, _response(UNPRICEABLE));

    assert _cost_of(usage) is None , (
        f"an unpriceable model must leave cost unset, got {_cost_of(usage)}"
    );
    assert usage["prompt_tokens"] == PROMPT_TOKENS , (
        "token counts must survive a pricing failure"
    );
}


test "a response carrying no usage data reports no cost rather than zero" {
    # litellm prices an empty usage at 0.0. Attaching that makes a call whose
    # tokens are unknown indistinguishable from a free one and drags the aggregate
    # down silently -- the failure mode #7896 exists to remove.
    llm = Model(model_name=MODEL);
    usage = _via_no_streaming(llm, _response(MODEL, {}));

    assert _cost_of(usage) is None , (
        f"a response with no usage data reported cost={_cost_of(usage)}; unknown "
        "must stay distinguishable from free"
    );
}
