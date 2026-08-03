import from jaclang.byllm.lib { MockLLM }

glob llm = MockLLM(
         model_name="mockllm",
         config={
             "outputs": ["Good morning, Ada — take it easy today."],
             "verbose": True,
             "show_params": False
         }
     );

node SubAgent {
    static def describe() -> SubAgentDesc {
        return SubAgentDesc(name="", description="", capabilities="");
    }
    def handle(task: str, ticket: Ticket) -> str {
        return "This desk cannot act on this request; nothing was done.";
    }
}

obj Ticket {
    has user_name: str;            # customer reference extracted at intake
    has issue: str;                # raw ticket body as the customer wrote it
    has order_ref: str = "";       # order reference; empty when none is mentioned
    has urgency: str = "medium";   # low | medium | high
}
sem Ticket.user_name = "The customer's username, copied verbatim from the ticket.";
sem Ticket.issue = "The raw ticket body exactly as the customer wrote it.";
sem Ticket.order_ref = "The order id mentioned in the ticket, empty when none is mentioned.";
sem Ticket.urgency = "One of 'low', 'medium', 'high', judged from tone and stakes.";

obj SubAgentDesc{
    has name: str;
    has description: str;
    has capabilities: str;
}
sem SubAgentDesc.name = "The subagent's unique short name.";
sem SubAgentDesc.description = "What kind of customer problem this subagent is responsible for.";
sem SubAgentDesc.capabilities = "Exactly what this subagent can and cannot do, named by its tools.";


node RescheduleAppointment(SubAgent){
    static def describe() -> SubAgentDesc {
        return SubAgentDesc(
            name="reschedule_appointment",
            description="Scheduling: moving a customer's appointment to a new slot.",
            capabilities="Can list a customer's appointments and move one to a free slot (list_appointments, reschedule). Cannot book new or cancel appointments; cannot touch payments, orders, or credentials."
        );
    }
    def handle(task: str, ticket: Ticket) -> str by llm(tools=[], max_react_iterations=6, temperature=0.0);
}
sem RescheduleAppointment.handle = "Move the appointment the task names to the requested slot, using ONLY the scheduling tools. Look up the customer's appointments before moving one. If a tool rejects the move (no such appointment, slot taken), or the task asks for something else, take NO further action and say so. ALWAYS end with a short reply to the customer stating what was done or why nothing was done.";
sem RescheduleAppointment.handle.task = "The single task the triage center delegated to this subagent.";
sem RescheduleAppointment.handle.ticket = "The full intake-parsed ticket, for context.";


with entry{
    RescheduleAppointment().handle(
        task="Reschedule my appointment from 2024-06-15 10:00 to 2024-06-20 14:00",
        ticket=Ticket(
            user_name="Ada Lovelace",
            issue="I need to move my appointment to a later date.",
            order_ref="",
            urgency="medium"
        )
    );
}
