# Testing byLLM

Read this before adding a test here. It is short on purpose.

The suite is mid-refactor (jaseci-labs/jac#9002). New tests follow the rules below;
old tests that do not are being converted cluster by cluster. `test_guard.jac` holds
today's counts and fails a PR that moves one the wrong way, so you find out here rather
than in review.

## Run it

```
JAC_TEST_JOBS=2 JAC_TEST_STRICT=1 jac test jac/jaclang/byllm/tests \
  --ignore jac/jaclang/byllm/tests/test_mtir_integration.jac
```

`test_mtir_integration.jac` runs in the sealed lane, from a copy outside the checkout;
`ci.yml` explains why. Read the pass count, not the exit code.

## The one rule

**Fake the model at `model_call_*`, never above it.**

A `by llm()` call goes through these layers:

```
  your function
  MTRuntime: messages, resp_type, tools
  BaseLLM.invoke: react loop, retries, compaction
  dispatch_no_streaming
  make_model_params ......... prompt, semstrings, schema, tool descriptions
  model_call_* .............. the network hop        <-- fake HERE
  _parse_tool_calls, parse_response .................. typed output
```

`FakeLLM` replaces only the network hop, so everything above and below it is the real
code. That buys two things a higher fake cannot give you: the request is really built,
so you can assert on it, and the reply is really parsed, so a declared return type is
actually enforced.

`MockLLM` replaces `dispatch_no_streaming`, four layers up. Under it the prompt is
built and thrown away and `parse_response` never runs. Two functions with opposite
`sem` strings return identical output, and `def f() -> int by llm()` hands back a
`str`. It is still exported for users, but do not reach for it in new tests here.

## Writing a test

```jac
import from support_tests { FakeLLM, say, call, finish, mk_run }

glob emoji_llm = FakeLLM(replies=[say("<emoji>")]);

def get_emoji(text: str) -> str by emoji_llm(temperature=0.7);

test "temperature is passed through and the input reaches the prompt" {
    assert get_emoji("lets move to paris") == "<emoji>";

    sent = emoji_llm.seen[0];
    assert sent["temperature"] == 0.7;
    assert "paris" in str(sent["messages"]).lower();
}
```

The last two assertions are the point. Assert on what came back **and** on what went
out. A test that only checks the return value is checking that the reply you scripted
came back, which is true by construction.

What the annex gives you, all in `support_tests.jac`:

| | |
|---|---|
| `FakeLLM(replies=[...])` | a `BaseLLM` that serves scripted replies and records every outgoing params dict |
| `scripted(model, replies)` | same, but patched onto a real `Model` when you need provider behaviour |
| `say(text)` | a plain-text reply |
| `call(name, args)`, `calls([...])` | one or several tool calls |
| `finish(value)` | a `finish_tool` call |
| `fail(err, content, after)` | raise, optionally mid-stream |
| `mk_run(...)` | an `MTRuntime` with sane defaults |
| `response()`, `chunks()` | real `litellm` objects, for tests that drive dispatch directly |
| `load_fixture(name)` | import a fixture module |
| `run_fixture(name)` | import a fixture and capture its stdout (legacy; prefer values) |
| `llm.sent(key)`, `llm.seen`, `llm.exhausted()` | what was sent, and whether the script was drained |

Add to the annex rather than defining a helper locally. If a helper already exists
under a different name, use it; if two exist, delete one.

## Fixtures

Most tests do not need one. A `by llm()` def belongs in the test file next to its test.

A fixture is for a **program whose shape is the subject**, and it contains no model, no
entry block, no prints and no asserts. Only two kinds qualify:

- **graph programs**: `node` / `walker` / `edge` with `visit ... by llm()`
- **compile targets**: files the MTIR, import and scope tests compile or analyze

```jac
# fixtures/routing_graph.jac  -- the program under test, nothing else
glob llm: any = None;          # the test assigns its own fake

edge Route { has priority: str = "low"; }
node Desk {}
node Agent {
    has tag: str = "x";
    can handle with dispatcher entry { visitor.visited.append(self.tag); }
}
walker dispatcher {
    has visited: list = [];
    can route with Desk entry { visit [-->] by llm(select=1); }
}
```

```jac
# the test drives it
import from fixtures.routing_graph { Desk, Agent, Route, dispatcher }
import fixtures.routing_graph as rg;
import from support_tests { FakeLLM, say }

test "routes along the edge attribute, not just the node" {
    llm = FakeLLM(replies=[say('["Agent_beta"]')]);
    rg.llm = llm;

    desk = root ++> Desk();
    desk +>: Route(priority="low") :+> Agent(tag="alpha");
    desk +>: Route(priority="high") :+> Agent(tag="beta");

    w = dispatcher() spawn desk;

    assert w.visited == ["beta"];
    assert "priority='high'" in str(llm.sent("messages")[0]);
}
```

Five things about that example are load-bearing and were each found the hard way:

1. **`glob llm: any = None;`**, not `glob llm = None;`. The bare form infers `NoneType`
   and the test's assignment fails `jac check` with E1001.
2. **`by llm()` resolves the global at call time**, which is why the test can own the
   fake and the fixture can stay pure.
3. **Static import of the archetypes.** `load_fixture()` returns the module as `any`,
   and `root ++> g.Desk()` then fails `jac check` with
   `E1097: Connection right operand must be a node instance`. Import the names directly;
   use the module alias only to rebind `llm`.
4. **The routing reply is a handle, not an index.** The return type is
   `list[enum[RouteChoice]]` and members are generated from the candidate set: two
   `Agent` siblings give `Agent_alpha` / `Agent_beta`, a lone one gives `Agent`. An
   index retries three times and then raises `OutputConversionError`.
5. **Spawn on the node you just made**, never from `root`. `root` accumulates across
   tests in a file. Per-test subgraphs stay isolated as long as you do not walk from
   the root, and you should not assert on `[root -->]`.

Also: `Jac.jac_import` returns a **cached** module and does not re-execute it. State
carries over between calls, so every test must assign its own fake and must not rely on
fresh module state.

## Assertions

Assert on values. Do not grep stdout.

| instead of | write |
|---|---|
| `assert "X_PASS" in stdout_value` | the fixture's own asserts, moved into the test, on returned values |
| `assert "Tool called with 12" in stdout` | `assert llm.sent("tools")[0][0]["function"]["name"] == "add"` and the tool's return value |
| slicing a dict out of a log line and `yaml.safe_load`ing it | `params = llm.seen[0]; assert "temperature" not in params` |

A stdout match cannot tell a wrong answer from a missing `print`, it reports nothing
useful when it fails, and it cannot see the request at all.

**Asserts inside a fixture are invisible to the runner.** 66 of this suite's assertions
still live in fixture files, guarded by 10 sentinel greps. If you delete such a fixture,
move every assert into the test first. `test_guard.jac` keeps a floor on the total count
because the test count alone will not notice.

## Adding to the guard's budgets

`test_guard.jac` is a ratchet, not a wall. Every number is today's measured count.

- **Cleaning up?** Lower the ceiling or raise the floor in the same PR. That is the
  intended direction and needs no explanation.
- **Genuinely need a new fixture?** Raise `FIXTURE_BUDGET` in the same PR and say why in
  the description.
- **A number moved the wrong way and you did not mean it?** The failure message names
  the file, the delta and the fix.

## PR checklist

Every PR that touches this directory carries this table:

| | before | after |
|---|---|---|
| test blocks | | |
| table rows / cases | | |
| assert statements (test files) | | |
| assert statements (fixtures) | | |
| tests skipped | | |
| tests newly red, with issue number | | |

Plus one line per deleted test naming the surviving row or assert, and one line per
dropped assert naming why.
