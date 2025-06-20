def func1() -> dict[str, str]{
    return [];
}

def func2(b: dict[int, list[int]]) -> list[int]{
    b.append("1");
    b[1] = [1, 2, 3, 5.5];
    return b[9];
}

with entry {
    a = {1: "1", 2: 2.2, 3: False};
    a = False;
    a['1'] = 1;
    a[1] = True;
    a = func1();
    a = func2(a);
}