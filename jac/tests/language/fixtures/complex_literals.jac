"""Complex literal spellings and host-semantics arithmetic."""

with entry {
    print(1j);
    print(0.5j);
    print((1e-3j).imag);
    print(10_000j);
    print(0J.real);
    print(-2j);
    m = 3 + 4j;
    print(m * 1j);
}
