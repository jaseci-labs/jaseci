import from mtllm.llms { OpenAI }

glob llm = OpenAI();

obj PunclineJokes {
    has jokes: 'Jokes with Punchlines': list[dict] = [
        {
            "joke": "How does a penguin build its house?",
            "punchline": "Igloos it together."
        },
        {
            "joke": "Which knight invented King Arthur's Round Table?",
            "punchline": "Sir Cumference."
        }
    ];

    def generate_joke -> dict by llm(incl_info=(self.jokes), temperature=0.0);
    def generate {
        joke_punchline = self.generate_joke();
        self.jokes.append(joke_punchline);
    }
}

with entry {
    joke_gen = PunclineJokes();
    for i in range(5) {
        joke_gen.generate();
    }
    print(joke_gen.jokes);
}
