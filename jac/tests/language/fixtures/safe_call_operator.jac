obj Name {
    has value: str;

    def change(new_value: str) -> str {
        self.value = new_value;
        return self.value;
    }
}

obj User {
    has name: Name;

    def greet -> str {
        return "Hello, " + self.name.value;
    }
}

with entry {
    user = User(Name("Alice"));
}
glob ghost = None;
with entry {
    print(ghost?.name?.value);
    print(user?.name?.value);
    print(user?.item?.value);
    print(user?.name?.items);
}

glob mylist = [1, 2, 3];
with entry {
    print(mylist?[2]);
    print(mylist?[10]);
    print(mylist?[-1]);
    print(mylist?[-10]);
    print(mylist?[1:3]);
    print(mylist?[10:20]);
}

glob none_list = None;
with entry {
    print(none_list?[0]);
    print(none_list?[1:3]);
}
