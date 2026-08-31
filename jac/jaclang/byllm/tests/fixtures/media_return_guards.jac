"""A media return type rejects tools and streaming up front.

Neither combination can work: tool results come back through finish_tool as
JSON, and generated media arrives as one payload rather than as tokens. Both
raise at call time instead of degrading into a silently text-only answer.
"""

import from jaclang.byllm.lib { Audio, Image, MockLLM, Model }
import from jaclang.byllm.exceptions { ConfigurationError }

glob llm = MockLLM(model_name="mockllm", config={"outputs": ["unused"]}),
     text_only = Model(model_name="gpt-4o");

"""Look up a brand's palette."""
def palette(brand: str) -> str {
    return "red, white";
}

"""Draw a logo for the brief."""
def draw_logo(brief: str) -> Image by llm(tools=[palette]);

"""Read the text aloud."""
def narrate(text: str) -> Audio by llm(stream=True);

"""Read the text aloud on a model that cannot speak."""
def narrate_text_only(text: str) -> Audio by text_only();

with entry {
    try {
        draw_logo("a red fox");
        print("TOOLS_GUARD_FAIL");
    } except ConfigurationError as e {
        print(f"TOOLS_GUARD_PASS:{'finish_tool' in str(e)}");
    }
    try {
        narrate("hello there");
        print("STREAM_GUARD_FAIL");
    } except ConfigurationError as e {
        print(f"STREAM_GUARD_PASS:{'token stream' in str(e)}");
    }
    try {
        narrate_text_only("hello there");
        print("ROUTE_GUARD_FAIL");
    } except ConfigurationError as e {
        print(f"ROUTE_GUARD_PASS:{'gpt-audio' in str(e)}");
    }
}
