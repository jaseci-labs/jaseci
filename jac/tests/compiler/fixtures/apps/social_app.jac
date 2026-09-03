"""File-rooted `social` service app: the provider side of every bridge below."""

obj Profile {
    has name: str,
        score: int = 0;
}

walker Greet {
    has name: str;

    can go with Root entry {
        report Profile(name=self.name);
    }
}

def:pub greet(name: str) -> Profile {
    return Profile(name=name);
}

def hidden(name: str) -> str {
    return name;
}
