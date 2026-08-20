class Meta(type) {
    def __mul__(cls: type, other: int) -> type {
        return cls;
    }
}

class Plain(metaclass=Meta) {}

with entry {
    t = Plain * 3;
}
