"""Tool-argument streaming: `tool_call_delta` (jaseci-labs/jac#7997).

litellm delivers tool-call argument fragments during streaming, in
`chunk.choices[0].delta.tool_calls[].function.arguments`. byllm used to read
only `delta.content` and rebuild the call at the end, so a caller learned a
tool was being invoked only once every argument had been generated.

The feature is display-only and opt-in. Each test below pins ONE invariant:

  1. off unless enabled, and the tool still runs
  2. deltas precede the call, and the first one names the tool
  3. coalescing bounds a pathological provider
  4. the executed call is byte-identical to the rebuilt one
  5. a parallel batch keeps its calls separate
  6. a retry announces the reset before the replacement's deltas, on BOTH
     drain paths (during the token loop, and from the end-of-stream flush)
  7. an abandoned stream is announced even when byllm's retry counter never
     moves, as with emergency context compaction
"""

import litellm;
import types;
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole, Tool }

glob RETRY: str = "__retry__";


def write_file(path: str, content: str) -> str {
    return f"wrote {len(content)} chars to {path}";
}


def read_file(path: str) -> str {
    return f"read {path}";
}


"""One streaming chunk. Prose when `content` is set, otherwise a tool-argument
fragment. Only a call's FIRST fragment carries `id` and `name`, as litellm
delivers them."""
def _chunk(
    content: str = "", frag: str = "", call_id: str = "", name: str = "", index: int = 0
) -> any {
    calls = None;
    if not content {
        fn = types.SimpleNamespace(name=(name or None), arguments=frag);
        calls = [
            types.SimpleNamespace(
                index=index, id=(call_id or None), type="function", function=fn
            )
        ];
    }
    return types.SimpleNamespace(
        usage=None,
        choices=[
            types.SimpleNamespace(
                delta=types.SimpleNamespace(
                    content=(content or None), tool_calls=calls
                ),
                finish_reason=None
            )
        ]
    );
}


"""Split `args` into `size`-char fragments and wrap them as one call's chunks."""
def _frags(args: str, tool: str, call_id: str, size: int = 12, index: int = 0) -> list {
    out: list = [];
    for i in range(0, len(args), size) {
        first = i == 0;
        out.append(
            _chunk(
                frag=args[i:i + size],
                call_id=(call_id if first else ""),
                name=(tool if first else ""),
                index=index
            )
        );
    }
    return out;
}


"""What `stream_chunk_builder` would return for `calls`, each (id, name, args)."""
def _rebuilt(calls: list) -> dict {
    tcs = [
        types.SimpleNamespace(
            id=c[0],
            type="function",
            function=types.SimpleNamespace(name=c[1], arguments=c[2])
        ) for c in calls
    ];
    return {
        "choices": [
            {
                "message": {"role": "assistant", "content": "", "tool_calls": tcs},
                "finish_reason": "tool_calls"
            }
        ],
        "model": "gpt-4o",
        "usage": {}
    };
}


def _plain(text: str) -> dict {
    return {
        "choices": [
            {
                "message": {"role": "assistant", "content": text, "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "model": "gpt-4o",
        "usage": {}
    };
}


"""Drive `_invoke_streaming` over scripted turns and collect the events.

`turns` is one entry per LLM round: a list of chunks, or RETRY to drop the
stream with a transient error. `rebuilts` is parallel to it (None where a turn
retries). Any turn past the end answers in plain text so the ReAct loop ends.
`enabled` False means the caller never opts in, i.e. the shipped default.
"""
def _run(turns: list, rebuilts: list, tools: list, enabled: bool = True) -> list {
    llm = Model(model_name="gpt-4o");
    wrapped = [Tool(func=t) for t in tools];
    wrapped.append(Tool.make_finish_tool(str));
    mt = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="u")
        ],
        resp_type=str,
        stream=True,
        tools=wrapped,
        call_params=({"stream_tool_args": True} if enabled else {}),
        mtir=None
    );
    at = [0];

    def _stream(params: dict) -> any {
        i = at[0];
        at[0] += 1;
        if i >= len(turns) {
            return [_chunk(content="all done")];
        }
        if turns[i] == RETRY {
            raise litellm.APIConnectionError(
                message="dropped", llm_provider="openai", model="gpt-4o"
            );
        }
        return turns[i];
    }

    def _rebuild(seen: list) -> dict {
        i = at[0] - 1;
        if i < len(rebuilts) and rebuilts[i] is not None {
            return rebuilts[i];
        }
        return _plain("all done");
    }

    events: list = [];
    with mock.patch.object(llm, "model_call_with_stream", _stream), mock.patch.object(
        _byllm_llm_mod.litellm, "stream_chunk_builder", _rebuild
    ) {
        for ev in llm._invoke_streaming(mt) {
            events.append(ev);
        }
    }
    return events;
}


def _kinds(events: list) -> list {
    return [e.event_type for e in events];
}


def _of(events: list, kind: str) -> list {
    return [
        e
        for e in events
        if e.event_type == kind
    ];
}


glob BODY: str = '{"path": "main.jac", "content": "' + ("x" * 400) + '"}';


test "streaming is off until it is enabled, and the call still runs" {
    events = _run(
        [_frags(BODY, "write_file", "c1")],
        [_rebuilt([("c1", "write_file", BODY)])],
        [write_file],
        enabled=False
    );

    assert len(_of(events, "tool_call_delta")) == 0 , f"deltas leaked while disabled: {_kinds(
        events
    )}";
    calls = _of(events, "tool_call");
    assert len(calls) >= 1 , f"the tool call vanished: {_kinds(events)}";
    assert calls[0].data.get("args", {}).get("path") == "main.jac" , calls[0].data;
}


test "deltas precede the call and the first one names the tool" {
    events = _run(
        [[_chunk(content="Writing it. ")] + _frags(BODY, "write_file", "c1")],
        [_rebuilt([("c1", "write_file", BODY)])],
        [write_file]
    );
    kinds = _kinds(events);

    deltas = _of(events, "tool_call_delta");
    assert len(deltas) > 0 , f"no deltas emitted: {kinds}";
    assert kinds.index("tool_call_delta") < kinds.index("tool_call") , f"deltas must precede the call: {kinds}";
    assert deltas[0].data.get("tool") == "write_file" , f"the first delta must name the tool: {deltas[
        0
    ].data}";
}


test "coalescing bounds a provider that fragments pathologically" {
    sent = len(range(0, len(BODY), 2));
    events = _run(
        [_frags(BODY, "write_file", "c1", size=2)],
        [_rebuilt([("c1", "write_file", BODY)])],
        [write_file]
    );

    deltas = _of(events, "tool_call_delta");
    assert len(deltas) > 0 , "no deltas emitted";
    assert len(deltas) < sent / 4 , f"expected coalescing, got {len(deltas)} events for {sent} fragments";
}


test "the executed call is byte-identical to the rebuilt one" {
    body = '{"path": "main.jac", "content": "hello world"}';
    events = _run(
        [_frags(body, "write_file", "c1", size=5)],
        [_rebuilt([("c1", "write_file", body)])],
        [write_file]
    );

    calls = _of(events, "tool_call");
    assert calls[0].data.get("args", {}).get("content") == "hello world" , calls[
        0
    ].data;
    results = _of(events, "tool_result");
    assert "wrote 11 chars to main.jac" in str(results[0].data.get("result", "")) , results[
        0
    ].data;
}


test "a parallel batch keeps its calls separate" {
    a = '{"path": "a.jac", "content": "aaa"}';
    b = '{"path": "b.jac"}';
    events = _run(
        [
            _frags(a, "write_file", "c1", size=10, index=0)
                + _frags(b, "read_file", "c2", size=8, index=1)
        ],
        [_rebuilt([("c1", "write_file", a), ("c2", "read_file", b)])],
        [write_file, read_file]
    );

    joined: dict = {};
    for d in _of(events, "tool_call_delta") {
        cid = d.data.get("call_id", "");
        joined[cid] = joined.get(cid, "") + str(d.data.get("arg_fragment", ""));
    }
    assert "c1" in joined and "c2" in joined , f"both calls should stream under their own id: {list(
        joined.keys()
    )}";
    assert "a.jac" in joined["c1"] and "b.jac" in joined["c2"] , joined;
    assert "b.jac" not in joined["c1"] , f"fragments crossed calls: {joined}";
}


test "a retry announces the reset before the replacement's deltas" {
    # Both drain paths must hold the invariant. The "loop" replacement is long
    # and named, so it publishes while the token loop runs. The "flush" one is
    # short and unnamed, so no threshold trips and its deltas exist only because
    # the dispatcher flushes after the loop ends.
    short = '{"path": "a.jac"}';
    cases = [
        (
            "loop",
            _frags(BODY, "write_file", "c1"),
            _rebuilt([("c1", "write_file", BODY)]),
            [write_file]
        ),
        (
            "flush",
            [_chunk(frag=short[i:i + 4]) for i in range(0, len(short), 4)],
            _rebuilt([("c1", "read_file", short)]),
            [read_file]
        )
    ];

    for (label, replacement, rebuilt, tools) in cases {
        events = _run([RETRY, replacement], [None, rebuilt], tools);
        kinds = _kinds(events);

        assert "tool_call_delta" in kinds , f"[{label}] the replacement's deltas were lost: {kinds}";
        assert "stream_reset" in kinds , f"[{label}] the retry was never announced: {kinds}";
        assert kinds.index("stream_reset") < kinds.index("tool_call_delta") , f"[{label}] reset must precede the replacement's deltas: {kinds}";
    }
}


test "an abandoned stream is announced when compaction discards it" {
    # Emergency compaction discards a stream that may already have published
    # deltas, and it never increments _stream_reset_count, so no counter-based
    # guard can see it. Without an announcement a consumer keeps showing the
    # abandoned fragments.
    body = '{"path": "a.jac", "content": "' + ("a" * 200) + '"}';

    llm = Model(model_name="gpt-4o");
    wrapped = [Tool(func=write_file)];
    wrapped.append(Tool.make_finish_tool(str));
    mt = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="u")
        ],
        resp_type=str,
        stream=True,
        tools=wrapped,
        call_params={"stream_tool_args": True},
        mtir=None
    );

    def _stream(params: dict) -> any {
        # Publish deltas, then blow the context window mid-stream. This is not
        # a transient error, so byllm does not retry and the counter never moves.
        def overflow -> any {
            for ch in _frags(body, "write_file", "c1") {
                yield ch;
            }
            raise litellm.exceptions.ContextWindowExceededError(
                message="too long", model="gpt-4o", llm_provider="openai"
            );
        }
        return overflow();
    }

    def _no_stream(mt_arg: any) -> any {
        return _byllm_llm_mod.CompletionResult(output="done", tool_calls=[], usage={});
    }

    events: list = [];
    with mock.patch.object(llm, "model_call_with_stream", _stream), mock.patch.object(
        llm, "dispatch_no_streaming", _no_stream
    ) {
        try {
            for ev in llm._invoke_streaming(mt) {
                events.append(ev);
            }
        } except Exception {
            ;
        }
    }

    kinds = _kinds(events);
    assert len(_of(events, "tool_call_delta")) > 0 , f"the scenario published no deltas to abandon: {kinds}";
    assert "stream_reset" in kinds , f"compaction discarded a stream without announcing it: {kinds}";
    assert kinds.index("tool_call_delta") < kinds.index("stream_reset") , f"the reset must follow the deltas it abandons: {kinds}";
}
