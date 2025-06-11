def foo(num:int) -> tuple[int, int]{
    return (num, num + 1);
}

with entry {
    result = foo(5);
    print(result);
}