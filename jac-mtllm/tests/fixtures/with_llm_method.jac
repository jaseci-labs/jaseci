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

class'Personality Index of a Person'
PersonalityIndex {
    has index: 'Personality Index': int;
}

enum 'Personality of the Person'
Personality {
    INTROVERT: 'Person who is shy and reticent',
    EXTROVERT: 'Person who is outgoing and socially confident'
}

glob personality_examples: 'Personality Information of Famous People': dict[str, Personality | None] = {
    'Albert Einstein': Personality.INTROVERT,
    'Barack Obama': Personality.EXTROVERT
};

obj 'Person'
Person {
    has name: 'Name of the Person': str,
        age: 'Age of the Person': int;
}

obj 'main object '
outer {
    obj 'inner object'
    inner {
        has diary_entries: 'Diary Entries': list[str];

        def 'Get Personality of the Person'
        get_personality(person: 'Person Object': list[Person]) -> 'Personality of the Person': dict[Personality, PersonalityIndex] by llm(
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
