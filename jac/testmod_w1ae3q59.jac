obj Box {
    has fmt: type = lambda (s: str) -> str { up = s.upper(); up + "!" };

    def greet(msg: str) -> str {
        return self.fmt(msg);
    }
}

with entry {
    b = Box();
    print(b.greet("hi"));
}
