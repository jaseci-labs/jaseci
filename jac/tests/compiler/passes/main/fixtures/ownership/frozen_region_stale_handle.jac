"""freeze consumes the owned handle: reopening the source is E1301."""

obj Cell {
    has v: int = 0;
}

with entry {
    r: own Region = Region();
    fr: imm Region = freeze(r);
    in r {
        c = Cell(v=4);
        print(c.v);
    }
}
