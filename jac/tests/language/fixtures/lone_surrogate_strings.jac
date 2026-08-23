with entry {
    # lone surrogate literal compiles and survives to runtime
    lone = "\ud800";
    print(len(lone));
    print(lone == chr(0xD800));

    # paired surrogate escapes keep Python semantics (two chars, not joined)
    pair = "\ud83d\ude00";
    print(len(pair));
    print(pair == chr(0xD83D) + chr(0xDE00));

    # lone surrogate mixed with regular text
    mixed = "a\ud800b";
    print(len(mixed));
    print(mixed[1] == chr(0xD800));

    # normal literals are unaffected
    plain = "hello";
    print(plain == "hello");

    # non-BMP characters still work
    emoji = "\U0001F600";
    print(emoji == chr(0x1F600));
}
