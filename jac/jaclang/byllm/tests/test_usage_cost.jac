"""Every dispatch path that produces a usage object must attach a `cost` figure
(computed via litellm's own `completion_cost`) onto that same object, so the
`usage` StreamEvent's per-call/aggregate totals carry cost for free -- with no
extra plumbing, since the existing aggregation loop in basellm.impl.jac sums
any numeric field it finds. A pricing-table miss must degrade to no `cost` key,
never raise out of a dispatch call."""

import asyncio;
import types;
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole }


def _mt_run() -> MTRuntime {
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

def _text_response(content: str) -> dict {
    return {
        "model": "gpt-4o-mini",
        "choices": [
            {
                "message": {"role": "assistant", "content": content, "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "usage": {"prompt_tokens": 100, "completion_tokens": 20, "total_tokens": 120}
    };
}

def _fake_cost(**kwargs: object) -> float {
    return 0.0042;
}

def _raise_pricing_error(**kwargs: object) -> float {
    raise Exception("model not in litellm pricing map");
}


test "dispatch_no_streaming attaches cost from litellm.completion_cost" {
    llm = Model(model_name="gpt-4o-mini");

    def _fake_call(params: dict) -> dict {
        return _text_response("hi");
    }
    with mock.patch.object(
        llm, "model_call_no_stream", _fake_call
    ), mock.patch.object(_byllm_llm_mod.litellm, "completion_cost", _fake_cost) {
        result = llm.dispatch_no_streaming(_mt_run());
    }
    assert result.usage["cost"] == 0.0042 , result.usage;
}


test "adispatch_no_streaming attaches cost from litellm.completion_cost" {
    llm = Model(model_name="gpt-4o-mini");

    async def _fake_call(params: dict) -> dict {
        return _text_response("hi");
    }
    with mock.patch.object(
        llm, "model_call_no_stream_async", _fake_call
    ), mock.patch.object(_byllm_llm_mod.litellm, "completion_cost", _fake_cost) {
        result = asyncio.run(llm.adispatch_no_streaming(_mt_run()));
    }
    assert result.usage["cost"] == 0.0042 , result.usage;
}


test "dispatch_streaming_with_tools attaches cost via stream_chunk_builder" {
    llm = Model(model_name="gpt-4o-mini");
    chunk = types.SimpleNamespace(
        choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
    );
    rebuilt = _text_response("hi");

    def _fake_stream(params: dict) -> list {
        return [chunk];
    }
    def _fake_builder(chunks: list) -> dict {
        return rebuilt;
    }
    out: list = [];
    with mock.patch.object(
        llm, "model_call_with_stream", _fake_stream
    ), mock.patch.object(
        _byllm_llm_mod.litellm, "stream_chunk_builder", _fake_builder
    ), mock.patch.object(_byllm_llm_mod.litellm, "completion_cost", _fake_cost) {
        list(llm.dispatch_streaming_with_tools(_mt_run(), out));
    }
    assert out[0].usage["cost"] == 0.0042 , out[0].usage;
}


test "dispatch_streaming attaches cost to the stream's final usage chunk" {
    llm = Model(model_name="gpt-4o-mini");
    usage = types.SimpleNamespace(prompt_tokens=100, completion_tokens=20);
    chunks = [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        ),
        types.SimpleNamespace(usage=usage, choices=[])
    ];

    def _fake_stream(params: dict) -> list {
        return chunks;
    }
    with mock.patch.object(
        llm, "model_call_with_stream", _fake_stream
    ), mock.patch.object(_byllm_llm_mod.litellm, "completion_cost", _fake_cost) {
        list(llm.dispatch_streaming(_mt_run()));
    }
    assert llm._usage_history[-1].cost == 0.0042 , llm._usage_history;
}


obj _AsyncChunks {
    has items: list;

    def __aiter__() -> _AsyncChunks {
        return self;
    }

    async def __anext__() -> object {
        if not self.items {
            raise StopAsyncIteration;
        }
        return self.items.pop(0);
    }
}

async def _drain_async(agen: object) {
    async for _item in agen {}
}


test "adispatch_streaming attaches cost to the stream's final usage chunk" {
    llm = Model(model_name="gpt-4o-mini");
    usage = types.SimpleNamespace(prompt_tokens=100, completion_tokens=20);
    chunks = [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        ),
        types.SimpleNamespace(usage=usage, choices=[])
    ];

    async def _fake_stream(params: dict) -> _AsyncChunks {
        return _AsyncChunks(items=chunks);
    }
    with mock.patch.object(
        llm, "model_call_with_stream_async", _fake_stream
    ), mock.patch.object(_byllm_llm_mod.litellm, "completion_cost", _fake_cost) {
        asyncio.run(_drain_async(llm.adispatch_streaming(_mt_run())));
    }
    assert llm._usage_history[-1].cost == 0.0042 , llm._usage_history;
}


test "a pricing-table miss degrades to no cost key, never raises" {
    llm = Model(model_name="gpt-4o-mini");

    def _fake_call(params: dict) -> dict {
        return _text_response("hi");
    }
    with mock.patch.object(
        llm, "model_call_no_stream", _fake_call
    ), mock.patch.object(
        _byllm_llm_mod.litellm, "completion_cost", _raise_pricing_error
    ) {
        result = llm.dispatch_no_streaming(_mt_run());
    }
    assert result.output == "hi" , result.output;
    assert "cost" not in result.usage , result.usage;
}
