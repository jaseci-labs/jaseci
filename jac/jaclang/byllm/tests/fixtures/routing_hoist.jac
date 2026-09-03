"""Captures the messages a `visit ... by llm` routing call actually sends."""

import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.types { CompletionResult }
import from jaclang.byllm.mtir { MTRuntime }

glob seen_messages: list = [];

obj RouteCaptureMock(MockLLM) {
    """Records the routing prompt instead of pretending to answer it."""
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        seen_messages.clear();
        seen_messages.extend(mt_run.get_msg_list());
        return CompletionResult(output=[0], tool_calls=[], usage={});
    }
}

glob route_llm: RouteCaptureMock = RouteCaptureMock(
         model_name="mockllm", config={"outputs": []}
     );

node Desk {}

node Agent {
    has tag: str = "x";
}

walker dispatcher {
    can route with Desk entry {
        visit [-->] by route_llm(select=1, intent="pick an agent");
    }
}

def run_route -> list {
    desk = root ++> Desk();
    desk ++> Agent(tag="alpha");
    dispatcher() spawn desk;
    return list(seen_messages);
}
