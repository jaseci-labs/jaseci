"""Dynamic extent is per thread (#8913): a flow body under an open runs on
worker threads that start with no current region, so the join sees the
region-resident elements it mutated and the open still tears down once."""

obj P {
    has x: int = 0;
}

def scenario -> int {
    total = 0;
    r: own Region = Region();
    in r {
        ps: list[P] = [P(x=1), P(x=2), P(x=3)];
        flow for m in &mut ps {
            m.x = m.x * 10;
        }
        for p in ps {
            total = total + p.x;
        }
    }
    return total;
}
