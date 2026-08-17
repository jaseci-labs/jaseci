"""Membership over a container the emitter only sees as a bare pointer.

`CoalesceBBPass.enter_node` searches `bbs['bb_stmts']` -- a `list[UniCFGNode]`
reached through a `dict[int, dict[str, list[...]]]`, whose inner value arrives
as an untyped `i8*` even though its declared type names the element exactly.
The membership emitter used to accept any two pointers and hand them to
`strstr`: a `str` needle then read the list header's bytes as a NUL-terminated
string (silently wrong), and an object needle raised a raw llvmlite TypeError
that demoted the whole method. The declared type is enough to recover the list
layout, so both shapes lower here.
"""

obj Tag {
    has n: int = 0;
}

obj Bag {
    has words: dict[int, dict[str, list[str]]] = {},
        tags: dict[int, dict[str, list[Tag]]] = {};

    def seed_words -> None {
        self.words[0] = {'items': ["alpha", "beta"]};
    }

    def seed_tags(t: Tag) -> None {
        self.tags[0] = {'items': [t]};
    }

    def has_word(w: str) -> int {
        for bucket in self.words.values() {
            if w in bucket['items'] {
                return 1;
            }
        }
        return 0;
    }

    def lacks_word(w: str) -> int {
        for bucket in self.words.values() {
            if w not in bucket['items'] {
                return 1;
            }
        }
        return 0;
    }

    def has_tag(t: Tag) -> int {
        for bucket in self.tags.values() {
            if t in bucket['items'] {
                return 1;
            }
        }
        return 0;
    }
}

def in_erased_py -> dict {
    b = Bag();
    t1 = Tag(n=1);
    t2 = Tag(n=2);
    b.seed_words();
    b.seed_tags(t1);
    return {
        "has_alpha": b.has_word("alpha"),
        "has_beta": b.has_word("beta"),
        "has_zeta": b.has_word("zeta"),
        "lacks_zeta": b.lacks_word("zeta"),
        "lacks_alpha": b.lacks_word("alpha"),
        "has_t1": b.has_tag(t1),
        "has_t2": b.has_tag(t2)
    };
}

def in_erased_cl -> dict {
    b = Bag();
    t1 = Tag(n=1);
    t2 = Tag(n=2);
    b.seed_words();
    b.seed_tags(t1);
    return {
        "has_alpha": b.has_word("alpha"),
        "has_beta": b.has_word("beta"),
        "has_zeta": b.has_word("zeta"),
        "lacks_zeta": b.lacks_word("zeta"),
        "lacks_alpha": b.lacks_word("alpha"),
        "has_t1": b.has_tag(t1),
        "has_t2": b.has_tag(t2)
    };
}

def in_erased_na -> dict[str, any] {
    b = Bag();
    t1 = Tag(n=1);
    t2 = Tag(n=2);
    b.seed_words();
    b.seed_tags(t1);
    return {
        "has_alpha": b.has_word("alpha"),
        "has_beta": b.has_word("beta"),
        "has_zeta": b.has_word("zeta"),
        "lacks_zeta": b.lacks_word("zeta"),
        "lacks_alpha": b.lacks_word("alpha"),
        "has_t1": b.has_tag(t1),
        "has_t2": b.has_tag(t2)
    };
}
