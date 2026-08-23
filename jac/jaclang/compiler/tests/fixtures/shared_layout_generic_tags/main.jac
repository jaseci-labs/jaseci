import from foo { Foo }

obj Bar {
    has direct: Foo;
    has items: list[Foo] = [];
}
