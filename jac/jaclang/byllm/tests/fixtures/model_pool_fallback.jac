"""Test ModelPool fallback strategy with LiteLLM Router.

Verifies the full dispatch pipeline works end-to-end by replacing the
router's completion method with a plain function that returns a canned
response -- no real API call is made.
"""
import from jaclang.byllm.lib { MockLLM, ModelPool }

"""Identity cast that keeps duck-typed test payloads out of nominal checks."""
def _as_any(v: any) -> any {
    return v;
}

glob model1 = MockLLM(model_name="gpt-3.5-turbo", config={"outputs": []}),
     model2 = MockLLM(model_name="gpt-4", config={"outputs": []}),
     pool = ModelPool(models=[model1, model2], strategy="fallback");

def get_answer(question: str) -> str by pool();

def mock_completion(**_kwargs: object) -> dict {
    return {
        "model": "mock-pool-model",
        "choices": [
            {
                "message": {
                    "content": "fallback_success",
                    "role": "assistant",
                    "tool_calls": None,

                },
                "finish_reason": "stop",
                "index": 0,

            }
        ],

    };
}

with entry {
    _as_any(pool._router).completion = mock_completion;
    result = get_answer("test question");
    print(result);
}
