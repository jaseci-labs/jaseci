import from mtllm.llms { FakeLLM }

glob llm1 = FakeLLM(
    print_prompt=True,
    default="[Output] Person(name='Albert Einstein', dob='14/03/1879', age=76)",
);


glob llm2 = FakeLLM(
    print_prompt=True,
    default="[Output] University.Department(name='Computer Science', head=Person(name='Jason Mars', dob='1994-01-01', age=30))"
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
