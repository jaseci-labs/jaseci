# Testing byLLM

Run the suite from `jac/`:

```
jac test jaclang/byllm/tests --ignore jaclang/byllm/tests/test_mtir_integration.jac
jac test jaclang/byllm/tests/test_compaction.jac -t "below threshold does not trigger compaction"
```

`test_mtir_integration.jac` runs from a copy outside the checkout in CI (see `ci.yml`). `validate_schema.jac` needs a live model and an API key.

## One seam: `support_tests.jac`

Every test fakes the model the same way. `support_tests.jac` is the only place a fake LLM, a response shape, or an `MTRuntime` constructor lives. It is not a suite (no `test_` prefix), so import what you need:

```jac
import from support_tests { FakeLLM, call, finish, say, mk_run, scripted, run_fixture, capture_logs }
```

| Helper | What it gives you |
|---|---|
| `FakeLLM(model_name=..., replies=[...])` | A `BaseLLM` that serves scripted turns on all five dispatch paths, sync and async, streaming and not. Records every outgoing params dict in `llm.seen`; `llm.sent("tools")` pulls one key across calls. |
| `say(text)`, `call(name, args)`, `calls([...])`, `finish(output)`, `fail(exc, after=n)` | One scripted turn each. `usage=` and `finish_reason=` are keyword options. |
| `scripted(model, replies)` | Context manager that scripts a real `Model` (or any `BaseLLM`) when the test is about provider-specific behaviour. Yields the recording `Script`. |
| `mk_run(resp_type=str, tools=[...], stream=False, call_params=...)` | An `MTRuntime` with system and user messages; callables are wrapped as tools and a finish tool is appended when tools are given. |
| `response(reply)`, `chunks(reply)` | The raw non-streaming dict and the real litellm chunk list, for the rare test that asserts on wire shape. |
| `run_fixture(name)`, `load_fixture(name)` | Import a program under `fixtures/`; the first returns its stdout, the second the module. |
| `capture_logs(level, name)` | Context manager collecting log records; read `.text()`. |
| `tool_names(params)` | Tool names as the model saw them in one recorded call. |

Extend the seam when it lacks something. Never add a second fake next to a test.

## Rules for every PR

1. **A regression is a row, not a test.** Find the test for the behaviour and add a tuple to its table or an assert to its body. Do not add a sibling named after the issue.
2. **No fakes in test files.** No `patch.object(model, "model_call_*")`, no `SimpleNamespace` responses, no inline `MTRuntime(...)`. Use the seam; extend it if a path is missing.
3. **No new fixture for a single function.** Write `def task(q: str) -> str by llm(...)` inside the test with a `FakeLLM`. A fixture is for multi-module or compile-time behaviour.
4. **Fixtures do not assert or print sentinels.** The test asserts on the value the fixture returns or on `run_fixture` output.
5. **A new file only for a new subsystem.** Never one per PR.
6. **The PR description names the test each new row went into.**

## Patterns

Table-driven, with a label per row so a failure names the case:

```jac
test "api key resolves in precedence order" {
    for (why, kwargs, expected) in [
        ("constructor", {"api_key": "sk-a"}, "sk-a"),
        ("instance config", {"config": {"api_key": "sk-b"}}, "sk-b"),
        ("constructor over config", {"api_key": "sk-a", "config": {"api_key": "sk-b"}}, "sk-a")
    ] {
        assert Model(model_name="m", **kwargs).api_key == expected , why;
    }
}
```

`parametrize()` from `jaclang.testing.test` when rows must report independently.

Scripting a ReAct loop end to end:

```jac
test "tool result reaches the next turn" {
    def lookup(q: str) -> str { return f"found {q}"; }
    llm = FakeLLM(replies=[call("lookup", {"q": "x"}), say("done")]);
    def task(q: str) -> str by llm(tools=[lookup]);
    assert task("x") == "done";
    assert "found x" in str(llm.seen[1]["messages"][-1]["content"]);
}
```

A unit under `BaseLLM` without the loop:

```jac
test "narration call keeps the tools array" {
    llm = FakeLLM(model_name="anthropic/claude-test", replies=[say("Done.")]);
    mt = mk_run(tools=[tool_a, tool_b], stream=True);
    list(llm._stream_final_answer(mt));
    assert tool_names(llm.seen[0]) == [t.get_name() for t in mt.tools];
}
```
