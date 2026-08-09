"""flow for runtime semantics: per-element body over lent collections,
join at the closing brace; deterministic output, identical across
backends and gc modes."""

obj P {
    has x: int = 0;
}

obj N {
    has v: int = 0;
}

with entry {
    ps: list[P] = [P(x=1), P(x=2), P(x=3)];
    flow for m in &mut ps {
        m.x = m.x * 10;
    }
    for m in ps {
        print(m.x);
    }
}

glob nums = [N(v=4), N(v=5)],
     k = 2;

with entry {
    flow for n in &mut nums {
        n.v = n.v * k;
    }
    for n in nums {
        print(n.v);
    }
    print("end");
}
