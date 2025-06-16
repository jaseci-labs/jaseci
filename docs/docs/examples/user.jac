obj User {
    has name: str, email: str, age: int = 0;

    def validate_email() -> bool;
    def get_display_name() -> str;
}

impl User.validate_email {
    return "@" in self.email;
}

impl User.get_display_name() -> str {
    return f"{self.name} ({self.email})";
}

with entry {
    user = User("John", "john@gmail.com", 23);
    print(user.validate_email());
    print(user.get_display_name());
}