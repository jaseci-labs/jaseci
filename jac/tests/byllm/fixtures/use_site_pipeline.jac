"""Producer/consumer pipeline used by the use-site rendering tests."""

import from jaclang.byllm.lib { MockLLM }

obj Claim {
    has text: str,
        cited_span: str;
}

glob llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": [
            [Claim(text="the sky is blue", cited_span="line 3")] for _i in range(8)
        ],
        "verbose": False
    }
);

def verify(claims: list[Claim], sources: list[str]) -> bool {
    return len(claims) > 0 and len(sources) >= 0;
}

def extract_claims(doc: str) -> list[Claim] by llm();

def run_pipeline(doc: str) -> bool {
    claims = extract_claims(doc);
    span = claims[0].cited_span;
    body = claims[0].text;
    return verify(claims, [span, body]);
}

sem verify = "Checks each claim against the provided sources.";
sem verify.claims = "list of verifiable factual assertions";
sem verify.sources = "the sources to check against";
sem extract_claims = "Extract the claims made in a document.";
sem extract_claims.doc = "source document";
