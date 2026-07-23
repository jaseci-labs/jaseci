# REAL EVAL: does parameter info improve accuracy? Needs a live model.
#   export OPENAI_API_KEY=sk-...   (or swap model_name/config for your provider)
#   jac run dummy_test/param_info_eval.jac
#
# Ablation: identical task + identical enum shape, the ONLY difference is whether
# the semantic descriptions are present. Opaque member names (TIER_1/2/3) force
# the model to rely on the sem strings for meaning, so any accuracy gap is
# attributable to the parameter info alone.
import from jaclang.byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini", config={"temperature": 0.0});

# ---- RICH: meaning supplied via sem strings ----
enum Priority { TIER_1 = 1, TIER_2 = 2, TIER_3 = 3 }
sem Priority = "Support-ticket urgency tier.";
sem Priority.TIER_1 = "Critical: production down or data loss; page on-call immediately.";
sem Priority.TIER_2 = "High: a major feature is broken with no workaround, service still up.";
sem Priority.TIER_3 = "Low: cosmetic issue, general question, or feature request.";

def triage_rich(ticket: str) -> Priority by llm();
sem triage_rich = "Assign the correct urgency tier to the support ticket.";
sem triage_rich.ticket = "The raw text of the customer's support ticket.";

# ---- BARE: same shape, zero semantic descriptions ----
enum PriorityBare { TIER_1 = 1, TIER_2 = 2, TIER_3 = 3 }
def triage_bare(ticket: str) -> PriorityBare by llm();

# ---- Labeled dataset (ticket, gold tier) ----
glob DATASET = [
    ("Entire site returns HTTP 500 for all users; nobody can checkout.", 1),
    ("Database is corrupted and we lost yesterday's orders.", 1),
    ("SSO login is completely broken; no user can sign in.", 1),
    ("CSV export produces an empty file; no workaround, but the app works.", 2),
    ("Avatar upload fails for every user; rest of the app is fine.", 2),
    ("Search shows stale results for ~20 min after an edit.", 2),
    ("The footer still says Copyright 2023.", 3),
    ("Typo in the onboarding email: 'recieve'.", 3),
    ("Could you add a dark-mode toggle someday?", 3),
    ("Dashboard legend colors are a bit hard to read.", 3),
];

with entry {
    rich_ok = 0;
    bare_ok = 0;
    n = len(DATASET);
    print("gold | rich | bare | ticket");
    for (ticket, gold) in DATASET {
        pr = triage_rich(ticket).value;
        pb = triage_bare(ticket).value;
        rich_ok += 1 if pr == gold else 0;
        bare_ok += 1 if pb == gold else 0;
        print(f"  {gold}  |  {pr}{'  ' if pr == gold else ' X'} |  {pb}{'  ' if pb == gold else ' X'} | {ticket}");
    }
    print("-" * 60);
    print(f"RICH param-info accuracy: {rich_ok}/{n}");
    print(f"BARE param-info accuracy: {bare_ok}/{n}");
    print("(Run at temperature>0 across several trials and average for a robust read.)");
}
