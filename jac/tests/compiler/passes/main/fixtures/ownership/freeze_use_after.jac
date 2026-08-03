"""freeze consumes its argument: reading it afterwards is E1301."""

obj Buffer {
    has n: int = 0;
}

with entry {
    a: own Buffer = Buffer(n=7);
    d: imm Buffer = freeze(a);
    print(a.n);
}
