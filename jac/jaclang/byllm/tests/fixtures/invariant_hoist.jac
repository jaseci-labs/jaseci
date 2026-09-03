"""Abilities whose prompt components are all fixed by program text."""

import from jaclang.byllm.lib { MockLLM }

obj Person {
    has name: str,
        age: int;
}

sem Person = "A person entity.";
sem Person.name = "The person's name.";
sem Person.age = "The person's age.";

glob hoist_llm = MockLLM(
         model_name="mockllm",
         config={"outputs": [Person(name="Test", age=30)], "verbose": False}
     );

def generate_person(criteria: str, seed: int) -> Person by hoist_llm();

sem generate_person = "Generate a person matching criteria.";
sem generate_person.criteria = "Description of the person to generate.";
sem generate_person.seed = "Deterministic seed for generation.";

def add_numbers(a: int, b: int) -> int {
    return a + b;
}

sem add_numbers = "Add two integers.";

def solve(question: str) -> str by hoist_llm(tools=[add_numbers]);

sem solve = "Answer the question using tools.";
sem solve.question = "The question to answer.";

def greet(name: str) -> str by hoist_llm(system_prompt="Be terse.");

sem greet = "Greet the named person.";

def build_prompt -> str {
    return "Be loud.";
}

def shout(name: str) -> str by hoist_llm(system_prompt=build_prompt);

sem shout = "Shout at the named person.";

glob tool_bag: list = [add_numbers];

def dispatch(question: str) -> str by hoist_llm(tools=tool_bag);

sem dispatch = "Answer using a dynamically chosen tool list.";

"""A report document."""
obj Report {
    has title: str;

    def summarize(detail: str) -> str by hoist_llm();
}

sem Report = "A report document.";
sem Report.summarize = "Summarize the report.";

def catchphrase -> str by hoist_llm();

sem catchphrase = "Produce a catchphrase.";
