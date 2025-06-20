# social_hello.jac
# Define a Person node
node Person {
    has name: str;
    has joined: str;
}

# Define a Knows edge
edge Knows {
    has since: str;
}

# Define a Greeter walker
walker Greeter {
    has greeting_count: int = 0;

    # Ability triggered when entering a Person node
    can greet with Person entry;

    # Ability triggered when walker finishes
    can summarize with `root exit {
        print(f"Greeted {self.greeting_count} people total!");
    }
}

impl Greeter.greet {
    print(f"Hello, {here.name}! You joined on {here.joined}");
    self.greeting_count += 1;

    # Visit all people this person knows
    visit [->:Knows:->];
}

# Main program
with entry {
    # Create a small social network
    person1 = Person(name="Alice", joined="2024-01-15");
    person2 = Person(name="Bob", joined="2024-02-20");
    person3 = Person(name="Charlie", joined="2024-03-10");

    # Create relationships
    person1 +>:Knows(since="2024-02-01"):+> person2;
    person2 +>:Knows(since="2024-03-01"):+> person3;

    # Spawn walker to greet everyone
    greeter = Greeter();
    greeter spawn person1;
}