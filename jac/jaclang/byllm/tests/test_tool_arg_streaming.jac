"""Tool-argument fragments must reach the caller while they are still being
generated (jaseci-labs/jac#7997).

litellm already delivers argument deltas in
`chunk.choices[0].delta.tool_calls[].function.arguments`, but
`dispatch_streaming_with_tools` reads only `delta.content` and reconstructs the
call with `stream_chunk_builder` at the end. A caller therefore learns a tool is
being invoked only once every argument is complete, which is what leaves an
agent UI frozen for the whole time a large file body is generated.

These tests pin the display-only contract:
  * fragments surface as `tool_call_delta` BEFORE the terminal `tool_call`
  * the tool NAME arrives early, since that alone carries most of the value
  * emission is coalesced, so one big argument cannot flood a consumer
  * the executed call is byte-identical to the non-streaming reconstruction
  * ordering and `call_id` isolation hold across a parallel batch
"""

import types;
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole, Tool }


def write_file(path: str, content: str) -> str {
    return f"wrote {len(content)} chars to {path}";
}


def read_file(path: str) -> str {
    return f"contents of {path}";
}


"""One streaming chunk carrying a tool-call argument fragment, shaped the way
litellm delivers them."""
def _arg_chunk(
    index: int, fragment: str, call_id: (str | None) = None, name: (str | None) = None
) -> any {
    fn = types.SimpleNamespace(name=name, arguments=fragment);
    tc = types.SimpleNamespace(index=index, id=call_id, type="function", function=fn);
    return types.SimpleNamespace(
        usage=None,
        choices=[
            types.SimpleNamespace(
                delta=types.SimpleNamespace(content=None, tool_calls=[tc]),
                finish_reason=None
            )
        ]
    );
}


"""A plain prose chunk (the `thought` channel)."""
def _text_chunk(text: str) -> any {
    return types.SimpleNamespace(
        usage=None,
        choices=[
            types.SimpleNamespace(
                delta=types.SimpleNamespace(content=text, tool_calls=None),
                finish_reason=None
            )
        ]
    );
}


"""Split `text` into `n`-character fragments, the way a provider streams JSON."""
def _fragments(text: str, n: int = 12) -> list[str] {
    return [text[i:i + n] for i in range(0, len(text), n)];
}


def _runtime(tools: list) -> MTRuntime {
    # MTRuntime expects wrapped Tool objects plus a finish tool; MTIR builds
    # both for a real call, so a hand-made runtime has to do the same.
    wrapped = [Tool(func=t) for t in tools];
    wrapped.append(Tool.make_finish_tool(str));
    return MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="u")
        ],
        resp_type=str,
        stream=True,
        tools=wrapped,
        call_params={},
        mtir=None
    );
}


"""Drive `_invoke_streaming` over a scripted chunk sequence and collect events.

`rebuilt` is what `stream_chunk_builder` would return, i.e. the fully assembled
message. The second LLM turn returns a plain reply so the ReAct loop terminates.
"""
def _events_for(chunk_script: list, rebuilt: dict, tools: list) -> list {
    llm = Model(model_name="gpt-4o");
    mt = _runtime(tools);
    turns = [0];

    def _stream(params: dict) -> any {
        turns[0] += 1;
        if turns[0] == 1 {
            return chunk_script;
        }
        return [_text_chunk("all done")];
    }

    def _rebuild(seen: list) -> dict {
        if turns[0] == 1 {
            return rebuilt;
        }
        return {
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": "all done",
                        "tool_calls": []
                    },
                    "finish_reason": "stop"
                }
            ],
            "model": "gpt-4o",
            "usage": {}
        };
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


def _rebuilt_one(call_id: str, name: str, arguments: str) -> dict {
    tc = types.SimpleNamespace(
        id=call_id,
        type="function",
        function=types.SimpleNamespace(name=name, arguments=arguments)
    );
    return {
        "choices": [
            {
                "message": {"role": "assistant", "content": "", "tool_calls": [tc]},
                "finish_reason": "tool_calls"
            }
        ],
        "model": "gpt-4o",
        "usage": {}
    };
}


def _of_type(events: list, kind: str) -> list {
    return [
        e
        for e in events
        if e.event_type == kind
    ];
}


test "argument fragments surface as tool_call_delta before the terminal tool_call" {
    body = '{"path": "main.jac", "content": "' + ("x" * 600) + '"}';
    script = [_text_chunk("Writing the entry point. ")];
    first = True;
    for frag in _fragments(body) {
        script.append(
            _arg_chunk(
                0,
                frag,
                call_id=("c1" if first else None),
                name=("write_file" if first else None)
            )
        );
        first = False;
    }

    events = _events_for(script, _rebuilt_one("c1", "write_file", body), [write_file]);
    kinds = [e.event_type for e in events];

    deltas = _of_type(events, "tool_call_delta");
    assert len(deltas) > 0 , f"no tool_call_delta emitted; the fragments were discarded. saw: {kinds}";

    first_delta = kinds.index("tool_call_delta");
    first_call = kinds.index("tool_call");
    assert first_delta < first_call , f"deltas must precede the terminal tool_call, got {kinds}";
}


test "the tool name reaches the caller early, not only at the end" {
    body = '{"path": "main.jac", "content": "' + ("y" * 400) + '"}';
    script: list = [];
    first = True;
    for frag in _fragments(body) {
        script.append(
            _arg_chunk(
                0,
                frag,
                call_id=("c1" if first else None),
                name=("write_file" if first else None)
            )
        );
        first = False;
    }

    events = _events_for(script, _rebuilt_one("c1", "write_file", body), [write_file]);
    deltas = _of_type(events, "tool_call_delta");
    assert len(deltas) > 0 , "no tool_call_delta emitted";
    assert deltas[0].data.get("tool") == "write_file" , f"first delta should name the tool, got {deltas[
        0
    ].data}";
}


test "emission is coalesced so a large argument cannot flood the consumer" {
    body = '{"path": "main.jac", "content": "' + ("z" * 4000) + '"}';
    script: list = [];
    first = True;
    # 2-char fragments: a deliberately pathological provider.
    for frag in _fragments(body, 2) {
        script.append(
            _arg_chunk(
                0,
                frag,
                call_id=("c1" if first else None),
                name=("write_file" if first else None)
            )
        );
        first = False;
    }
    produced = len(_fragments(body, 2));

    events = _events_for(script, _rebuilt_one("c1", "write_file", body), [write_file]);
    deltas = _of_type(events, "tool_call_delta");

    assert len(deltas) > 0 , "no tool_call_delta emitted";
    assert len(deltas) < produced / 4 , f"expected coalescing, got {len(
        deltas
    )} events for {produced} fragments";
}


test "the executed tool call is unchanged by streaming the fragments" {
    body = '{"path": "main.jac", "content": "hello world"}';
    script: list = [];
    first = True;
    for frag in _fragments(body, 5) {
        script.append(
            _arg_chunk(
                0,
                frag,
                call_id=("c1" if first else None),
                name=("write_file" if first else None)
            )
        );
        first = False;
    }

    events = _events_for(script, _rebuilt_one("c1", "write_file", body), [write_file]);
    calls = _of_type(events, "tool_call");
    assert len(calls) >= 1 , "no tool_call emitted";
    assert calls[0].data.get("tool") == "write_file" , calls[0].data;
    assert calls[0].data.get("args", {}).get("path") == "main.jac" , calls[0].data;
    assert calls[0].data.get("args", {}).get("content") == "hello world" , calls[
        0
    ].data;

    results = _of_type(events, "tool_result");
    assert len(results) >= 1 , "the tool did not execute";
    assert "wrote 11 chars to main.jac" in str(results[0].data.get("result", "")) , results[
        0
    ].data;
}


test "fragments from a parallel batch stay separated by call_id" {
    a_body = '{"path": "a.jac", "content": "aaa"}';
    b_body = '{"path": "b.jac"}';
    script: list = [
        _arg_chunk(0, a_body[:10], call_id="c1", name="write_file"),
        _arg_chunk(1, b_body[:8], call_id="c2", name="read_file"),
        _arg_chunk(0, a_body[10:]),
        _arg_chunk(1, b_body[8:])
    ];

    tc_a = types.SimpleNamespace(
        id="c1",
        type="function",
        function=types.SimpleNamespace(name="write_file", arguments=a_body)
    );
    tc_b = types.SimpleNamespace(
        id="c2",
        type="function",
        function=types.SimpleNamespace(name="read_file", arguments=b_body)
    );
    rebuilt = {
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": "",
                    "tool_calls": [tc_a, tc_b]
                },
                "finish_reason": "tool_calls"
            }
        ],
        "model": "gpt-4o",
        "usage": {}
    };

    events = _events_for(script, rebuilt, [write_file, read_file]);
    deltas = _of_type(events, "tool_call_delta");
    assert len(deltas) > 0 , "no tool_call_delta emitted";

    by_id: dict = {};
    for d in deltas {
        cid = d.data.get("call_id", "");
        by_id[cid] = by_id.get(cid, "") + str(d.data.get("arg_fragment", ""));
    }
    assert "c1" in by_id and "c2" in by_id , f"both calls should stream under their own id, got {list(
        by_id.keys()
    )}";
    assert "a.jac" in by_id["c1"] , by_id;
    assert "b.jac" in by_id["c2"] , by_id;
    assert "b.jac" not in by_id["c1"] , f"fragments crossed calls: {by_id}";
}
