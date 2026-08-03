import from jaclang.byllm.lib { MockLLM }

glob llm = MockLLM(
         model_name="mockllm",
         config={
             "outputs": ["Good morning, Ada — take it easy today."],
             "verbose": True,
             "show_params": False
         }
     );


enum Verdict {
    ENTAILED = "ENTAILED",
    CONTRADICTED = "CONTRADICTED",
    NOT_ENOUGH_INFO = "NOT ENOUGH INFO"
}
sem Verdict.ENTAILED = "The evidence answers the claim and agrees with it.";
sem Verdict.CONTRADICTED = "The evidence gives a different answer than the claim, so the claim is false.";
sem Verdict.NOT_ENOUGH_INFO = "The evidence is not related to the claim, or it is insufficient to answer the claim.";

def decide_fact_verdict(claimed_fact: str, question: str, evidence: str) -> Verdict by llm();


with entry{
    decide_fact_verdict(
        claimed_fact="Ada Lovelace was born in 1815.",
        question="When was Ada Lovelace born?",
        evidence="Ada Lovelace was born on December 10, 1906."
    );
}
