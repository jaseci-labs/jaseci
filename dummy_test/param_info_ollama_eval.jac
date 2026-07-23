"""Quality ablation on a LOCAL model (Ollama gemma4:e4b).

Does the parameter info byLLM injects (function/param/enum sem strings) improve
answer quality? We hold the task + enum shape constant and toggle ONLY the sems.
Small local models are grounding-hungry, so the effect is pronounced here.

Prereqs: `ollama serve` running, `gemma4:e4b` pulled. Then:
    jac run dummy_test/param_info_ollama_eval.jac
    OLLAMA_MODEL=gemma4:e4b jac run dummy_test/param_info_ollama_eval.jac   # explicit
"""

import os;
import from jaclang.byllm.lib { Model }

glob llm: Model = Model(
    model_name=f"ollama_chat/{os.getenv('OLLAMA_MODEL', 'gemma4:e4b')}",
    config={"base_url": os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")},
    api_key="ollama",
    call_params={"temperature": 0.0}
);

# ================= USE CASE A: coded enum (meaning lives only in sems) =========
# Member NAMES are opaque codes, so the rubric is inferable only from the sems.
enum Queue { Q_ALPHA = 1, Q_BETA = 2, Q_GAMMA = 3 }
sem Queue = "Internal routing queue for an incoming customer message.";
sem Queue.Q_ALPHA = "Billing: payments, refunds, invoices, or subscription charges.";
sem Queue.Q_BETA = "Technical: bugs, errors, crashes, outages, or login failures.";
sem Queue.Q_GAMMA = "Feedback: feature requests, praise, or complaints needing no action.";

def route_rich(message: str) -> Queue by llm();
sem route_rich = "Route the customer message to the correct internal queue.";
sem route_rich.message = "The raw text of the customer's message.";

# Same shape, ZERO sems: model sees only Q_ALPHA/Q_BETA/Q_GAMMA with no meaning.
enum QueueBare { Q_ALPHA = 1, Q_BETA = 2, Q_GAMMA = 3 }
def route_bare(message: str) -> QueueBare by llm();

glob DATA_A: list[tuple[str, int]] = [
    ("I was charged twice for my subscription this month, please refund one.", 1),
    ("Can you send an invoice for last quarter's payments?", 1),
    ("The app crashes every time I tap the export button.", 2),
    ("I can't log in - it says 'invalid token' on every attempt.", 2),
    ("Please add a dark mode, my eyes hurt at night.", 3),
    ("Just wanted to say your new dashboard looks fantastic!", 3),
];

# ============ USE CASE B: numeric thresholds + units (non-monotonic) ==========
# Colored names carry a weak prior (red=bad), but the EXACT ranges + the mg/dL
# unit + the fact that LOW is also critical live only in the sems. A bare
# "bigger number = worse" heuristic misfires on borderline-high and low values.
enum Status { GREEN = 1, AMBER = 2, RED = 3 }
sem Status = "Clinical alert level for a blood-glucose reading.";
sem Status.GREEN = "In range: 70 to 140 mg/dL. No action needed.";
sem Status.AMBER = "Borderline: 141 to 200 mg/dL, or 54 to 69 mg/dL. Monitor closely.";
sem Status.RED = "Critical: above 200 mg/dL, or below 54 mg/dL. Escalate immediately.";

def assess_rich(reading: int) -> Status by llm();
sem assess_rich = "Classify a blood-glucose reading into an alert level.";
sem assess_rich.reading = "Blood-glucose measurement, in mg/dL.";

enum StatusBare { GREEN = 1, AMBER = 2, RED = 3 }
def assess_bare(reading: int) -> StatusBare by llm();

glob DATA_B: list[tuple[int, int]] = [
    (95, 1),    # solidly in range
    (130, 1),   # in range (upper end)
    (165, 2),   # borderline HIGH -> AMBER  (bare prior likely says RED)
    (60, 2),    # borderline LOW  -> AMBER  (bare prior likely says GREEN)
    (215, 3),   # critical high
    (48, 3),    # critical LOW    -> RED    (bare prior likely says GREEN)
];

with entry {
    print(f"MODEL: {llm.model_name}\n");

    # ---- Use Case A ----
    ra = 0;
    ba = 0;
    na = len(DATA_A);
    print("=== USE CASE A: coded queues (meaning only in sem strings) ===");
    print("gold | rich | bare | message");
    for (msg, gold) in DATA_A {
        pr = -1;
        pb = -1;
        try { pr = route_rich(msg).value; } except Exception as e { pr = -1; }
        try { pb = route_bare(msg).value; } except Exception as e { pb = -1; }
        ra += 1 if pr == gold else 0;
        ba += 1 if pb == gold else 0;
        print(f"  {gold}  |  {pr}{'  ' if pr == gold else ' X'} |  {pb}{'  ' if pb == gold else ' X'} | {msg[:50]}");
    }
    print(f"--> A  RICH {ra}/{na}   BARE {ba}/{na}\n");

    # ---- Use Case B ----
    rb = 0;
    bb = 0;
    nb = len(DATA_B);
    print("=== USE CASE B: glucose thresholds (units + ranges only in sems) ===");
    print("gold | rich | bare | reading (mg/dL)");
    for (val, gold) in DATA_B {
        pr = -1;
        pb = -1;
        try { pr = assess_rich(val).value; } except Exception as e { pr = -1; }
        try { pb = assess_bare(val).value; } except Exception as e { pb = -1; }
        rb += 1 if pr == gold else 0;
        bb += 1 if pb == gold else 0;
        print(f"  {gold}  |  {pr}{'  ' if pr == gold else ' X'} |  {pb}{'  ' if pb == gold else ' X'} | {val}");
    }
    print(f"--> B  RICH {rb}/{nb}   BARE {bb}/{nb}\n");

    tot = na + nb;
    print("================= SUMMARY =================");
    print(f"RICH (with parameter info): {ra + rb}/{tot}");
    print(f"BARE (no parameter info):   {ba + bb}/{tot}");
    print("(gemma4:e4b is stochastic even at temp 0; run 3-5x to confirm the gap.)");
}
