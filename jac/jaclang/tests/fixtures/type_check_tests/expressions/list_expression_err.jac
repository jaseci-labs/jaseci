def func1() -> list[str]{
    return [];
}

def func2(b: list[int]) -> list[str]{
    b.append("1");
    b.append(1);
    return b;
}

with entry {
    a: list[int] = [1, 2, 3];
    a.append(1.5);
    a.append(1);
    a.append([1, 2]);

    b = func1();
    b = False;
    b.append('1');
    b.append(1.6);
}