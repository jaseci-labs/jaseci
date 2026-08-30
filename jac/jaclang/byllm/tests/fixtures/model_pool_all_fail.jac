"""Test ModelPool exception propagation when all deployments fail.

Verifies that when the LiteLLM Router raises (all deployments exhausted)
the exception propagates to the caller rather than being swallowed.
"""
import from jaclang.byllm.lib { MockLLM, ModelPool }
import from litellm.exceptions { RateLimitError }

"""Identity cast that keeps duck-typed test payloads out of nominal checks."""
def _as_any(v: any) -> any {
    return v;
}

glob model1 = MockLLM(model_name="gpt-3.5-turbo", config={"outputs": []}),
     model2 = MockLLM(model_name="gpt-4", config={"outputs": []}),
     pool = ModelPool(models=[model1, model2], strategy="fallback");

def get_answer(question: str) -> str by pool();

def mock_completion(**_kwargs: object) -> object {
    raise RateLimitError(
        message="All deployments exhausted",
        model="gpt-3.5-turbo",
        llm_provider="openai",
    );
}

with entry {
    _as_any(pool._router).completion = mock_completion;

    try {
        result = get_answer("test");
        print(f"UNEXPECTED: {result}");
    } except Exception as e {
        print(f"EXPECTED_ERROR: {type(e).__name__}");
    }
}
