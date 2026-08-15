"""`abc.ABC` and `@abstractmethod` are compile-time information.

Jac already models abstractness itself: a bodiless ability is abstract, and
the server lane synthesizes `@abstractmethod` from that fact rather than
reading it. The Python spelling therefore adds nothing a native unit needs at
runtime, so both names erase and the archetype keeps its ordinary layout.
"""

import from abc { ABC, abstractmethod }


obj Shape(ABC) {
    has n: int = 3;

    @abstractmethod
    def area -> int;
}


obj Square(Shape) {
    def area -> int {
        return self.n * self.n;
    }
}


def run -> int {
    return Square(n=5).area();
}
