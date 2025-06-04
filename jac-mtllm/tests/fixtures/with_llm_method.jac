import from mtllm.llms { BaseLLM }

obj model(BaseLLM) {
    def init {
        super.__init__();
    }

    def __infer__(meaning_in: str, **kwargs: dict) {
        print(meaning_in);
        return "[Output] Personality.INTROVERT";
    }
}

glob llm = model();

class PersonalityIndex {
    has index: int;
}

enum Personality {
    INTROVERT,
    EXTROVERT
}

glob personality_examples: dict[str, Personality | None] = {
    Personality.INTROVERT,
    Personality.EXTROVERT
};

obj Person {
    has name:  str,
        age: int;
}

obj outer {
    obj inner {
        has diary_entries: list[str];

        def get_personality(person: list[Person]) -> dict[Personality, PersonalityIndex] by llm(
            method="Reason",
            incl_info=(personality_examples, self.diary_entries)
        );
    }
}

with entry {
    obj1 = outer.inner(
        ["I won noble prize in Physics", "I am popular for my theory of relativity"]
    );
    pp = Person('Albert Einstein', 76);
    print(type(obj1.get_personality(pp)));
}
