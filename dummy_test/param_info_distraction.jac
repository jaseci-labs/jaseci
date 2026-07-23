"""Distraction ablation on a LOCAL model (Ollama gemma4:e4b).

Shows the DOWNGRADE case: adding parameter info can HURT. Both variants describe
the same task with the same enum shape; the only difference is that NOISY sems
carry (a) a plausible-but-biased heuristic ("when unsure, prefer BILLING") and
(b) irrelevant padding. The dataset plants trap words (account / usage / billing)
in non-billing tickets, so the bias systematically misroutes them.

    jac run dummy_test/param_info_distraction.jac
"""

import os;
import from jaclang.byllm.lib { Model }

glob llm: Model = Model(
    model_name=f"ollama_chat/{os.getenv('OLLAMA_MODEL', 'gemma4:e4b')}",
    config={"base_url": os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")},
    api_key="ollama",
    call_params={"temperature": 0.0}
);

# ===================== CLEAN: short, accurate sems =====================
enum Route { BILLING = 1, TECHNICAL = 2, GENERAL = 3 }
sem Route = "Support queue for an incoming customer message.";
sem Route.BILLING = "Payments, refunds, invoices, or subscription charges.";
sem Route.TECHNICAL = "Bugs, errors, crashes, login failures, or outages.";
sem Route.GENERAL = "Feedback, praise, or general questions needing no action.";

def route_clean(message: str) -> Route by llm();
sem route_clean = "Route the customer message to the correct support queue.";
sem route_clean.message = "The customer's message.";

# ============ NOISY: accurate text + distracting bias + padding ============
enum RouteNoisy { BILLING = 1, TECHNICAL = 2, GENERAL = 3 }
sem RouteNoisy =
    "Support queue for an incoming customer message. Our company was founded in "
    "2009 and handles millions of tickets a year across dozens of teams; billing "
    "is historically by far our highest-volume category, so it deserves special "
    "attention when triaging anything financially adjacent.";
sem RouteNoisy.BILLING =
    "Payments, refunds, invoices, or subscription charges. IMPORTANT: billing is "
    "the most common category, so any message that mentions an account, a plan, "
    "usage, money, or a charge in any way should almost always be routed here; "
    "when in doubt, prefer BILLING.";
sem RouteNoisy.TECHNICAL =
    "Bugs, errors, crashes, login failures, or outages. Note that many technical "
    "reports also reference the user's account or usage, but those references are "
    "usually incidental context rather than the core issue.";
sem RouteNoisy.GENERAL =
    "Feedback, praise, or general questions needing no action. Customers often "
    "phrase praise or questions in ways that mention product areas like the "
    "billing dashboard or account page purely as a subject, not as a request.";

def route_noisy(message: str) -> RouteNoisy by llm();
sem route_noisy =
    "Route the customer message to the correct support queue. Remember that our "
    "triage guidelines emphasize catching billing-related issues early because "
    "they have the largest revenue impact of any category we handle.";
sem route_noisy.message =
    "The customer's message. Read it carefully and weigh every financial or "
    "account-related signal before deciding.";

# Trap words (account / usage / billing) sit in NON-billing tickets on purpose.
glob DATA: list[tuple[str, int]] = [
    ("I was double-charged for my subscription, please refund one charge.", 1),  # BILLING
    ("My latest invoice is missing several line items.", 1),                      # BILLING
    ("I can't log into my account - the login button does nothing.", 2),         # TECH (trap: account)
    ("The app crashes whenever I open the account settings page.", 2),           # TECH (trap: account)
    ("Error 403 when I try to view my usage statistics page.", 2),               # TECH (trap: usage)
    ("The dashboard just spins forever and never loads.", 2),                     # TECH (control)
    ("Just wanted to say your new billing dashboard looks great - nice work!", 3),# GENERAL (trap: billing)
    ("Do you have an Android app? Just curious.", 3),                             # GENERAL (control)
];

with entry {
    print(f"MODEL: {llm.model_name}\n");
    print("gold | clean | noisy | message");
    ok_clean = 0;
    ok_noisy = 0;
    n = len(DATA);
    for (msg, gold) in DATA {
        pc = -1;
        pn = -1;
        try { pc = route_clean(msg).value; } except Exception as e { pc = -1; }
        try { pn = route_noisy(msg).value; } except Exception as e { pn = -1; }
        ok_clean += 1 if pc == gold else 0;
        ok_noisy += 1 if pn == gold else 0;
        print(f"  {gold}  |   {pc}{'  ' if pc == gold else ' X'}  |   {pn}{'  ' if pn == gold else ' X'}  | {msg[:52]}");
    }
    print("-" * 64);
    print(f"CLEAN (minimal accurate sems): {ok_clean}/{n}");
    print(f"NOISY (biased + padded sems):  {ok_noisy}/{n}");
    print("Expectation: NOISY over-routes the trap tickets (account/usage/billing) to BILLING (1).");
}
