"""Regression test for variance checks on identical generic classes.

Mutable built-in containers use invariant type parameters. A list[Dog] must
not be assignable to list[Animal], even though Dog is an Animal.
"""

obj Animal {}
obj Dog(Animal) {}

def take_animals(items: list[Animal]) -> None {}

with entry {
    dogs: list[Dog] = [Dog()];

    animals: list[Animal] = dogs;  # Error: list is invariant
    take_animals(dogs);  # Error: list is invariant
}
