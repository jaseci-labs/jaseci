"""freeze transfers the region handle: the imm result crosses flow freely."""

obj Cell {
    has v: int = 0;
}

def reader(r: imm Region) -> int {
    return 1;
}

with entry {
    r: own Region = Region();
    in r {
        c = Cell(v=4);
        print(c.v);
    }
    fr: imm Region = freeze(r);
    h = flow reader(fr) ;
    print(wait h );
}
