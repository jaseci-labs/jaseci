import from mtllm.llms { FakeLLM }

glob llm = FakeLLM(
    print_prompt=True,
    default='[Output] Something',
);

glob emoji_examples: list[dict[str, str]] = [
    {
        "input": "I love tp drink pina coladas",
        "output": "👤 ❤️ 🥤 🍍🥥"
    },
    {"input": "Mime Person", "output": "👤🤲🚷"}
];

def get_emoji(input: str) -> str by llm(
    temperature=0.7,
    incl_info=(emoji_examples),
    excl_info=()
);

with entry {
    print(get_emoji('Lets move to paris'));
}
