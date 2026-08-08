"""Test fixture pinning FFI decode of native `list[str]` values.

Exercises the string cases the marshal layer has to survive: an empty list,
empty strings, multi-byte UTF-8, static string literals (whose length rides
the RC sentinel) next to heap strings (whose length rides the header magic),
slices whose payload is not NUL bounded, a string carrying an interior NUL,
a long list, and a `list[str]` held as an object field rather than returned
directly.
"""

obj Bag {
    has tags: list[str],
        note: str;
}

def make_empty -> list[str] {
    out: list[str] = [];
    return out;
}

def make_literals -> list[str] {
    return ["", "a", "über", "日本語", "x" * 64];
}

def make_sliced -> list[str] {
    src = "abcdefghij";
    out: list[str] = [];
    out.append(src[0:3]);
    out.append(src[3:7]);
    out.append(src[7:10]);
    return out;
}

def make_interior_nul -> list[str] {
    out: list[str] = [];
    out.append("a\x00b");
    out.append("plain");
    return out;
}

def make_long(n: int) -> list[str] {
    out: list[str] = [];
    i = 0;
    while i < n {
        out.append("item-" + str(i));
        i = i + 1;
    }
    return out;
}

def make_bag -> Bag {
    return Bag(tags=["alpha", "", "ßeta"], note="über");
}

def bag_tags -> list[str] {
    return make_bag().tags;
}

def bag_note -> str {
    return make_bag().note;
}

def make_tag_map -> dict[str, str] {
    return {"k": "a\x00b", "ü": "ß"};
}

glob x = 0;
