import from mtllm.llms { OpenAI }
import from mtllm.tools.wikipedia_utils { wikipedia_summary }

glob llm = OpenAI(model_name="gpt-4o-mini");

def ask_opponent(statement: str) -> str {
    user_input = input(f"AI -> {statement} ");
    return f"Opponents Answer -> {user_input}";
}

def state_facts(information: str) -> None {
    print(f"AI -> {information}");
}

def debate_agent(topic: str) -> str by llm(
    method='ReAct',
    tools=[wikipedia_summary, ask_opponent, state_facts],
    context=[
        "You have to defend the given topic while the opponent is defending the counter topic",
        "If you dont know about the topic or you want to verify the opponents claims use the given tools",
        "You can ask opponent counter questions",
        "You are a humorous, cunning, very arrogant debater."
    ]
);

with entry {
    debate_agent('Merlin the Wizard is still alive.');
}
