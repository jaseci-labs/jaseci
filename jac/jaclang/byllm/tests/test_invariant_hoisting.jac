"""Invariant prompt hoisting: compiler plan, prompt split, usage log, routing."""

import json;
import os;
import tempfile;
import types;
import unittest.mock;

import jaclang.byllm.llm as _llm_mod;
import jaclang.byllm.visit_routing as _routing_mod;
import from jaclang { JacRuntime as Jac }
import from jaclang { JacRuntimeInterface as JacIface }
import from jaclang.compiler.driver.mtp {
    ClassInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo
}
import from jaclang.compiler.driver.program { JacProgram }

import from jaclang.byllm.invariant {
    hoisting_enabled,
    invariant_plan_of,
    invariant_token_count,
    render_contract_block,
    reset_invariant_cache
}
import from jaclang.byllm.llm {
    BaseLLM,
    _CACHE_CONTROL_EPHEMERAL,
    _apply_prompt_caching
}
import from jaclang.byllm.mtir { MTIR }
import from jaclang.byllm.usage_log { build_usage_record, log_completion }

glob jac_import = JacIface.jac_import,
     FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "fixtures"),
     HOIST_ENV = "BYLLM_INVARIANT_HOISTING";

obj Person {
    has name: str,
        age: int;
}

"""Generate a person matching criteria."""
def sample_fn(criteria: str, seed: int) -> Person {
    return Person(name="x", age=1);
}

"""Say something about the topic."""
def free_text(topic: str) -> str {
    return topic;
}

def volatile_prompt -> str {
    return "Be loud.";
}

def sample_info -> FunctionInfo {
    return FunctionInfo(
        name="sample_fn",
        semstr="Generate a person matching criteria.",
        params=[
            ParamInfo(
                name="criteria",
                semstr="Description of the person to generate.",
                type_info="str"
            ),
            ParamInfo(name="seed", semstr="Deterministic seed.", type_info="int")
        ],
        return_type=ClassInfo(
            name="Person",
            semstr="A person entity.",
            fields=[
                FieldInfo(name="name", semstr="The person's name.", type_info="str"),
                FieldInfo(name="age", semstr="The person's age.", type_info="int")
            ],
            base_classes=[],
            methods=[]
        ),
        tools=[],
        invariant_plan={
            "description": True,
            "params": True,
            "self": False,
            "return_type": True,
            "schema": True,
            "tools": False,
            "system_prompt": True
        }
    );
}

def text_info -> FunctionInfo {
    return FunctionInfo(
        name="free_text",
        semstr="Say something about the topic.",
        params=[ParamInfo(name="topic", semstr="The topic.", type_info="str")],
        return_type="str",
        tools=[],
        invariant_plan={
            "description": True,
            "params": True,
            "self": False,
            "return_type": True,
            "schema": False,
            "tools": False,
            "system_prompt": True
        }
    );
}

obj FakeBackend(BaseLLM) {
    override def model_call_no_stream(params: dict) -> dict {
        return {
            "model": "fake-model",
            "choices": [
                {
                    "message": {"role": "assistant", "content": "hi"},
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 120,
                "completion_tokens": 5,
                "cache_read_input_tokens": 96,
                "cache_creation_input_tokens": 24
            }
        };
    }
}

def set_hoisting(on: bool) {
    os.environ[HOIST_ENV] = "1" if on else "0";
    reset_invariant_cache();
}

def clear_hoisting {
    os.environ.pop(HOIST_ENV, None);
    reset_invariant_cache();
}

def runtime_for(caller: any, args: dict, call_params: dict, info: any) -> any {
    return MTIR(caller, args, call_params, info).runtime;
}

def compiled_map -> dict {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURE_DIR, "invariant_hoist.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert Jac.program is not None;
    return {
        scope.rsplit(".", 1)[-1]: info
        for (scope, info) in Jac.program.mtir_map.items()
        if scope.startswith("invariant_hoist.")
    };
}

# ---------------------------------------------------------------- compiler

test "compiler records an invariant plan for every by-llm ability" {
    by_name = compiled_map();
    info: any = by_name["generate_person"];
    plan = info.invariant_plan;
    assert plan is not None;
    assert plan["description"] == True;
    assert plan["params"] == True;
    assert plan["self"] == False;
    assert plan["return_type"] == True;
    assert plan["schema"] == True , "Person return type needs a schema hint";
}

test "a str return needs no schema hint in the plan" {
    by_name = compiled_map();
    info: any = by_name["greet"];
    assert info.invariant_plan["schema"] == False;
    assert info.invariant_plan["return_type"] == True;
}

test "a method plan marks self as invariant" {
    by_name = compiled_map();
    info: any = by_name["summarize"];
    assert isinstance(info, MethodInfo);
    assert info.invariant_plan["self"] == True;
    assert info.parent_class is not None;
}

test "a literal tools list is static, a variable one is not" {
    by_name = compiled_map();
    static_call: any = by_name["solve"];
    dynamic_call: any = by_name["dispatch"];
    assert static_call.static_tools == True;
    assert static_call.invariant_plan["tools"] == True;
    assert dynamic_call.static_tools == False;
    assert dynamic_call.invariant_plan["tools"] == False;
}

test "a literal system_prompt is static, a callable one is not" {
    by_name = compiled_map();
    literal: any = by_name["greet"];
    callable_sp: any = by_name["shout"];
    absent: any = by_name["generate_person"];
    assert literal.static_system_prompt == True;
    assert callable_sp.static_system_prompt == False;
    assert absent.static_system_prompt == True;
}

# ------------------------------------------------------------ prompt shape

test "flag off leaves every message byte-identical" {
    clear_hoisting();
    mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, sample_info());
    msgs = mt.get_msg_list();
    assert len(msgs) == 2;
    assert msgs[0]["role"] == "system";
    assert msgs[1]["role"] == "user";
    assert msgs[1]["content"][0]["text"]
        == (
            "Generate a person matching criteria.\n\n"
            "criteria = ('tall', 'Description of the person to generate.')\n"
            "seed = (7, 'Deterministic seed.')"
        );
    assert mt._hoisted == False;
    assert mt._schema_hint_hoisted == False;
}

test "flag on splits the prompt into invariant prefix and variant suffix" {
    set_hoisting(True);
    try {
        mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, sample_info());
        msgs = mt.get_msg_list();
        assert len(msgs) == 3;
        assert msgs[0]["role"] == "system";
        assert msgs[1]["role"] == "system";
        assert msgs[2]["role"] == "user";
        contract = msgs[1]["content"];
        assert contract.startswith("Task: Generate a person matching criteria.");
        assert "criteria (str): Description of the person to generate." in contract;
        assert "seed (int): Deterministic seed." in contract;
        assert "Returns: Person" in contract;
        assert msgs[2]["content"][0]["text"] == "criteria = 'tall'\nseed = 7";
        assert mt._hoisted == True;
    } finally {
        clear_hoisting();
    }
}

test "hoisting moves semstrings, it never drops or duplicates them" {
    set_hoisting(True);
    try {
        mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, sample_info());
        blob = "\n".join(
            [
                m["content"]
                    if isinstance(m["content"], str)
                    else "\n".join([b.get("text", "") for b in m["content"]])
                for m in mt.get_msg_list()
            ]
        );
        for text in [
            "Description of the person to generate.",
            "Deterministic seed.",
            "The person's name.",
            "The person's age."
        ] {
            assert blob.count(text) == 1 , f"{text!r} appears {blob.count(text)}x";
        }
    } finally {
        clear_hoisting();
    }
}

test "the contract block is scaffolding, not conversation history" {
    set_hoisting(True);
    try {
        conversation: list = [];
        mt = runtime_for(
            sample_fn, {0: "tall", 1: 7}, {"conversation": conversation}, sample_info()
        );
        assert len(mt.messages) == 3;
        kept = mt.get_history_for_persist();
        assert len(kept) == 1 , "only the user message survives into history";
        assert kept[0].role == "user";
    } finally {
        clear_hoisting();
    }
}

test "conversation turns sit between the contract and the new user message" {
    set_hoisting(True);
    try {
        mt = runtime_for(
            sample_fn,
            {0: "tall", 1: 7},
            {"conversation": [{"role": "user", "content": "hi"}]},
            sample_info()
        );
        roles = [m["role"] for m in mt.get_msg_list()];
        assert roles == ["system", "system", "user", "user"];
        assert mt.get_msg_list()[2]["content"] == "hi";
    } finally {
        clear_hoisting();
    }
}

test "the schema hint moves into the contract instead of the user message" {
    set_hoisting(True);
    try {
        mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, sample_info());
        contract = mt.get_msg_list()[1]["content"];
        assert "Respond with a single JSON object." in contract;
        assert "The person's name." in contract;
        assert mt._schema_hint_hoisted == True;
        user_text = mt.get_msg_list()[2]["content"][0]["text"];
        assert "Respond with a single JSON object." not in user_text;
    } finally {
        clear_hoisting();
    }
}

test "the anthropic cache breakpoint lands on the contract block" {
    set_hoisting(True);
    try {
        mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, sample_info());
        msgs = mt.get_msg_list();
        _apply_prompt_caching(msgs, None);
        assert "cache_control" not in msgs[0] , "persona must stay off the breakpoint";
        assert msgs[1].get("cache_control") == _CACHE_CONTROL_EPHEMERAL;
    } finally {
        clear_hoisting();
    }
}

test "an ability with no runtime inputs is left alone" {
    set_hoisting(True);
    try {
        info = text_info();
        info.params = [];
        info.invariant_plan["params"] = False;
        mt = runtime_for(free_text, {}, {}, info);
        assert mt._hoisted == False;
        assert len(mt.get_msg_list()) == 2;
    } finally {
        clear_hoisting();
    }
}

test "an ability the compiler never planned is left alone" {
    set_hoisting(True);
    try {
        info = text_info();
        info.invariant_plan = None;
        mt = runtime_for(free_text, {0: "volcanoes"}, {}, info);
        assert mt._hoisted == False;
        assert len(mt.get_msg_list()) == 2;
        assert invariant_plan_of(info) is None;
    } finally {
        clear_hoisting();
    }
}

test "a literal call-site system prompt stays in the cached prefix" {
    set_hoisting(True);
    try {
        mt = runtime_for(
            sample_fn, {0: "tall", 1: 7}, {"system_prompt": "Be terse."}, sample_info()
        );
        msgs = mt.get_msg_list();
        assert len(msgs) == 3;
        assert "Be terse." in msgs[0]["content"];
        assert mt._hoisted == True;
        assert "Be terse." in mt._invariant_text;
    } finally {
        clear_hoisting();
    }
}

test "a system prompt the compiler cannot prove constant turns hoisting off" {
    set_hoisting(True);
    try {
        info = sample_info();
        info.invariant_plan["system_prompt"] = False;
        mt = runtime_for(
            sample_fn, {0: "tall", 1: 7}, {"system_prompt": volatile_prompt}, info
        );
        msgs = mt.get_msg_list();
        assert len(msgs) == 2 , "a volatile prefix must not be cached";
        assert "Be loud." in msgs[0]["content"];
        assert msgs[1]["content"][0]["text"]
            == (
                "Generate a person matching criteria.\n\n"
                "criteria = ('tall', 'Description of the person to generate.')\n"
                "seed = (7, 'Deterministic seed.')"
            );
        assert mt._hoisted == False;
    } finally {
        clear_hoisting();
    }
}

test "a non-static system prompt that resolves to nothing still hoists" {
    set_hoisting(True);
    try {
        info = sample_info();
        info.invariant_plan["system_prompt"] = False;
        mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, info);
        assert mt._hoisted == True;
        assert len(mt.get_msg_list()) == 3;
    } finally {
        clear_hoisting();
    }
}

test "static tool names ride along in the contract" {
    reset_invariant_cache();
    info = text_info();
    info.invariant_plan["tools"] = True;
    with_tools = render_contract_block(
        info, "Answer the question.", str, False, (), ("add_numbers", "lookup")
    );
    assert "Tools: add_numbers, lookup" in with_tools;

    info.invariant_plan["tools"] = False;
    without = render_contract_block(
        info, "Answer the question.", str, False, (), ("add_numbers", "lookup")
    );
    assert "Tools:" not in without;
}

test "render_contract_block takes an extra invariant block for later features" {
    reset_invariant_cache();
    info = text_info();
    plain = render_contract_block(info, "Say something.", str, False);
    extended = render_contract_block(
        info, "Say something.", str, False, (), (), "Use-site: caller is a REPL."
    );
    assert plain.endswith("Returns: str");
    assert extended.endswith("Use-site: caller is a REPL.");
    assert extended.startswith(plain);
}

test "the contract block is memoized per ability" {
    reset_invariant_cache();
    info = sample_info();
    first = render_contract_block(info, "Generate.", Person, True);
    second = render_contract_block(info, "Generate.", Person, True);
    assert first == second;
    assert first is second , "repeat renders must come from the memo";
}

test "config and env agree on whether hoisting is on" {
    clear_hoisting();
    assert hoisting_enabled() == False;
    os.environ[HOIST_ENV] = "1";
    assert hoisting_enabled() == True;
    os.environ[HOIST_ENV] = "false";
    assert hoisting_enabled() == False;
    clear_hoisting();
}

# ------------------------------------------------------------------- usage

test "a usage record carries the cache and invariant counters" {
    set_hoisting(True);
    try {
        mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, sample_info());
        record = build_usage_record(
            mt,
            "anthropic/claude-sonnet-4-6",
            {
                "prompt_tokens": 900,
                "completion_tokens": 40,
                "cache_read_input_tokens": 700,
                "cache_creation_input_tokens": 0,
                "cost": 0.004
            },
            123.5
        );
        assert record["prompt_tokens"] == 900;
        assert record["cache_read_input_tokens"] == 700;
        assert record["cache_creation_input_tokens"] == 0;
        assert record["cost"] == 0.004;
        assert record["latency_ms"] == 123.5;
        assert record["hoisted"] == True;
        assert record["invariant_tokens"] > 0;
        assert str(record["scope"]).endswith("sample_fn");
    } finally {
        clear_hoisting();
    }
}

test "cached_tokens is read from prompt_tokens_details when present" {
    clear_hoisting();
    mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, sample_info());
    record = build_usage_record(
        mt,
        "gpt-4o",
        {"prompt_tokens": 500, "prompt_tokens_details": {"cached_tokens": 384}},
        10.0
    );
    assert record["cache_read_input_tokens"] == 384;
    assert record["hoisted"] == False;
    assert record["invariant_tokens"] == 0;
}

test "usage lines are only written when BYLLM_USAGE_LOG points somewhere" {
    clear_hoisting();
    mt = runtime_for(sample_fn, {0: "tall", 1: 7}, {}, sample_info());
    os.environ.pop("BYLLM_USAGE_LOG", None);
    log_completion(mt, "gpt-4o", {"prompt_tokens": 1}, 1.0);

    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "usage.jsonl");
        os.environ["BYLLM_USAGE_LOG"] = path;
        try {
            log_completion(mt, "gpt-4o", {"prompt_tokens": 11}, 2.0);
            log_completion(mt, "gpt-4o", {"prompt_tokens": 22}, 3.0);
            with open(path, encoding="utf-8") as handle {
                lines = [
                    json.loads(line)
                    for line in handle
                    if line.strip()
                ];
            }
            assert len(lines) == 2;
            assert [line["prompt_tokens"] for line in lines] == [11, 22];
        } finally {
            os.environ.pop("BYLLM_USAGE_LOG", None);
        }
    }
}

test "the sync dispatch path writes one usage line per completion" {
    set_hoisting(True);
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "usage.jsonl");
        os.environ["BYLLM_USAGE_LOG"] = path;
        try {
            mt = runtime_for(free_text, {0: "volcanoes"}, {}, text_info());
            backend = FakeBackend(model_name="fake-model");
            backend.dispatch_no_streaming(mt);
            with open(path, encoding="utf-8") as handle {
                lines = [
                    json.loads(line)
                    for line in handle
                    if line.strip()
                ];
            }
            assert len(lines) == 1;
            record = lines[0];
            assert record["prompt_tokens"] == 120;
            assert record["cache_read_input_tokens"] == 96;
            assert record["cache_creation_input_tokens"] == 24;
            assert record["hoisted"] == True;
            assert record["invariant_tokens"] > 0;
            assert record["latency_ms"] >= 0;
        } finally {
            os.environ.pop("BYLLM_USAGE_LOG", None);
            clear_hoisting();
        }
    }
}

test "the streaming tool path writes one usage line per completion" {
    set_hoisting(True);
    chunks = [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        )
    ];
    rebuilt = {
        "model": "fake-model",
        "choices": [
            {
                "message": {"role": "assistant", "content": "hi", "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "usage": {"prompt_tokens": 210, "completion_tokens": 4}
    };
    _stream = lambda (params: dict) { return chunks; };
    _rebuild = lambda (seen: list) { return rebuilt; };
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "usage.jsonl");
        os.environ["BYLLM_USAGE_LOG"] = path;
        try {
            mt = runtime_for(free_text, {0: "volcanoes"}, {}, text_info());
            backend = FakeBackend(model_name="fake-model");
            out: list = [];
            with unittest.mock.patch.object(
                backend, "model_call_with_stream", _stream
            ), unittest.mock.patch.object(
                _llm_mod.litellm, "stream_chunk_builder", _rebuild
            ) {
                list(backend.dispatch_streaming_with_tools(mt, out));
            }
            with open(path, encoding="utf-8") as handle {
                lines = [
                    json.loads(line)
                    for line in handle
                    if line.strip()
                ];
            }
            assert len(lines) == 1;
            assert lines[0]["prompt_tokens"] == 210;
            assert lines[0]["hoisted"] == True;
            assert lines[0]["invariant_tokens"] > 0;
        } finally {
            os.environ.pop("BYLLM_USAGE_LOG", None);
            clear_hoisting();
        }
    }
}

test "the pure-text streaming path writes one usage line per completion" {
    set_hoisting(True);
    chunks = [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        ),
        types.SimpleNamespace(
            usage={"prompt_tokens": 175, "completion_tokens": 2}, choices=[]
        )
    ];
    _stream = lambda (params: dict) { return chunks; };
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "usage.jsonl");
        os.environ["BYLLM_USAGE_LOG"] = path;
        try {
            mt = runtime_for(free_text, {0: "volcanoes"}, {}, text_info());
            backend = FakeBackend(model_name="fake-model");
            with unittest.mock.patch.object(
                backend, "model_call_with_stream", _stream
            ) {
                list(backend.dispatch_streaming(mt));
            }
            with open(path, encoding="utf-8") as handle {
                lines = [
                    json.loads(line)
                    for line in handle
                    if line.strip()
                ];
            }
            assert len(lines) == 1;
            assert lines[0]["prompt_tokens"] == 175;
            assert lines[0]["hoisted"] == True;
            assert lines[0]["invariant_tokens"] > 0;
        } finally {
            os.environ.pop("BYLLM_USAGE_LOG", None);
            clear_hoisting();
        }
    }
}

test "a stream that reports no usage still writes a line" {
    set_hoisting(True);
    chunks = [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        )
    ];
    _stream = lambda (params: dict) { return chunks; };
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "usage.jsonl");
        os.environ["BYLLM_USAGE_LOG"] = path;
        try {
            mt = runtime_for(free_text, {0: "volcanoes"}, {}, text_info());
            backend = FakeBackend(model_name="fake-model");
            with unittest.mock.patch.object(
                backend, "model_call_with_stream", _stream
            ) {
                list(backend.dispatch_streaming(mt));
            }
            with open(path, encoding="utf-8") as handle {
                lines = [
                    json.loads(line)
                    for line in handle
                    if line.strip()
                ];
            }
            assert len(lines) == 1;
            assert lines[0]["prompt_tokens"] == 0;
            assert lines[0]["cost"] == 0.0;
        } finally {
            os.environ.pop("BYLLM_USAGE_LOG", None);
            clear_hoisting();
        }
    }
}

test "token counting is bounded and cached" {
    reset_invariant_cache();
    assert invariant_token_count("", "gpt-4o") == 0;
    count = invariant_token_count("a fairly ordinary sentence", "gpt-4o");
    assert count > 0;
    assert invariant_token_count("a fairly ordinary sentence", "gpt-4o") == count;
}

# ----------------------------------------------------------------- routing

test "visit routing hoists the candidate list into its own system message" {
    mod = jac_import("routing_hoist", base_path=FIXTURE_DIR + "/")[0];
    fake = ClassInfo(
        name="Agent", semstr="An agent", fields=[], base_classes=[], methods=[]
    );

    clear_hoisting();
    off = mod.run_route();
    assert [m["role"] for m in off] == ["system", "user"];
    assert "Candidates (choose by handle):" in off[1]["content"];
    assert "Goal: pick an agent" in off[1]["content"];

    set_hoisting(True);
    try {
        with unittest.mock.patch.object(
            _routing_mod, "_class_info", return_value=fake
        ) {
            on = mod.run_route();
        }
    } finally {
        clear_hoisting();
    }
    assert [m["role"] for m in on] == ["system", "system", "user"];
    assert "Candidates (choose by handle):" in on[1]["content"];
    assert "Candidates" not in on[2]["content"];
    assert "Goal: pick an agent" in on[2]["content"];
}

test "visit routing leaves the prompt alone when the archetypes are unknown" {
    mod = jac_import("routing_hoist", base_path=FIXTURE_DIR + "/")[0];
    set_hoisting(True);
    try {
        with unittest.mock.patch.object(
            _routing_mod, "_class_info", return_value=None
        ) {
            msgs = mod.run_route();
        }
    } finally {
        clear_hoisting();
    }
    assert [m["role"] for m in msgs] == ["system", "user"];
    assert "Candidates (choose by handle):" in msgs[1]["content"];
}
