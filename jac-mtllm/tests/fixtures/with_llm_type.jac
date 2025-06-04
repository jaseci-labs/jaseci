import from mtllm.llms { BaseLLM }

obj model(BaseLLM) {
    def init(output_str: str) {
        super.__init__();
        self.output_str = output_str;
    }

    def __infer__(meaning_in: str, **kwargs: dict) {
        print("Meaning in: ", meaning_in);
        return f"[Output] {self.output_str}";
    }
}

glob llm1 = model(
    output_str="Person(name='Albert Einstein', dob='14/03/1879', age=76)"
);

obj Person {
    has name: str,
        dob: str,
        age: int;
}

with entry {
    einstein: Person = Person(name="Albert Einstein" by llm1());
    print(einstein.dob); #14/03/1879
}

glob llm2 = model(
    output_str="University.Department(name='Computer Science', head=Person(name='Jason Mars', dob='1994-01-01', age=30))"
);

obj University {
    has name: str,
        location: str,
        departments: list[self.Department] = [];

    obj Department {
        has name: str,
            head: Person;
    }
}

with entry {
    umich: University = University(
        name="University of Michigan",
        location="Ann Arbor, Michigan"
    );
    cs_department: University.Department = University.Department(name="Computer Science" by llm2(incl_info=(umich)));
    print(cs_department.head); # Person(name='Jason Mars', dob='1994-01-01', age=30)
    umich.departments.append(
        umich.Department(name="Computer Science" by llm2())
    );
    print(umich.departments[0].head); # Person(name='Jason Mars', dob='1994-01-01', age=30)
}
