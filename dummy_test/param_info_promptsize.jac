# OFFLINE: measures the token COST of parameter info. No API key needed.
# MockLLM records every rendered prompt in `seen_prompts`, so we can diff the
# exact bytes the two variants send to a provider.
import from jaclang.byllm.lib { MockLLM, MockRawResponse }

glob llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": [MockRawResponse('{"schema_object_wrapper": 1}') for _ in range(10)],
        "verbose": False
    }
);

# ---- RICH: opaque member names, real meaning lives in the sem strings ----
enum Priority { TIER_1 = 1, TIER_2 = 2, TIER_3 = 3 }
sem Priority = "Support-ticket urgency tier.";
sem Priority.TIER_1 = "Critical: production down or data loss; page on-call immediately.";
sem Priority.TIER_2 = "High: a major feature is broken with no workaround, service still up.";
sem Priority.TIER_3 = "Low: cosmetic issue, general question, or feature request.";

def triage_rich(ticket: str) -> Priority by llm();
sem triage_rich = "Assign the correct urgency tier to the support ticket.";
sem triage_rich.ticket = "The raw text of the customer's support ticket.";

# ---- BARE: identical shape, NO sem strings anywhere ----
enum PriorityBare { TIER_1 = 1, TIER_2 = 2, TIER_3 = 3 }
def triage_bare(ticket: str) -> PriorityBare by llm();

with entry {
    ticket = "The whole site returns HTTP 500 for every user; checkout is dead.";

    triage_rich(ticket);
    rich = llm.seen_prompts[-1];
    triage_bare(ticket);
    bare = llm.seen_prompts[-1];

    print("================ RICH prompt ================");
    print(rich);
    print("================ BARE prompt ================");
    print(bare);
    print("=============================================");
    print(f"RICH : {len(rich)} chars  (~{len(rich)//4} tokens)");
    print(f"BARE : {len(bare)} chars  (~{len(bare)//4} tokens)");
    print(f"param-info overhead: +{len(rich)-len(bare)} chars  (~{(len(rich)-len(bare))//4} tokens/call)");
}
