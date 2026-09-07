"""Invariant generic arguments reject unsound container substitutions."""

obj Animal {}
obj Dog(Animal) {}

def accept_float(values: list[float]) -> None {}
def accept_animal(values: list[Animal]) -> None {}

with entry {
    ints: list[int] = [1];
    accept_float(ints);

    dogs: list[Dog] = [];
    accept_animal(dogs);
}
