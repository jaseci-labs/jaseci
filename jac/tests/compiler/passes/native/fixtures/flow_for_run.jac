"""flow for runtime semantics: per-element body over lent collections,
join at the closing brace; deterministic output, identical across
backends and gc modes."""

obj P {
    has x: int = 0;
}

with entry {
    ps: list[P] = [P(x=1), P(x=2), P(x=3)];
    flow for m in &mut ps {
        m.x = m.x * 10;
    }
    flow for m in &ps {
        print(m.x);
    }
}

glob xs = [4, 5],
     k = 2;

with entry {
    flow for v in &xs {
        print(v * k);
    }
    print("end");
}
