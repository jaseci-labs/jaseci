# Fixture for null-safe string comparison and enum-class type lowering (#7851).

enum Mode { OFF = "off", ON = "on" }

# An enum-class-typed parameter and return value must lower cleanly (to i64).
def flip(m: Mode) -> Mode {
    if m == Mode.OFF {
        return Mode.ON;
    }
    return Mode.OFF;
}

def mode_is_on(m: Mode) -> int {
    if m == Mode.ON {
        return 1;
    }
    return 0;
}

obj Box {
    has label: str | None = None;
}

# Comparing a possibly-null string must not segfault. Equality follows Python:
# with a null operand, == / != are pointer identity (None == "" is False,
# None == None is True); ordering ops coalesce null to the empty string.
def null_eq_empty -> int {
    b = Box();
    if b.label == "" {
        return 1;
    }
    return 0;
}

def null_eq_null -> int {
    a = Box();
    b = Box();
    if a.label == b.label {
        return 1;
    }
    return 0;
}

def null_ne_empty -> int {
    b = Box();
    if b.label != "" {
        return 1;
    }
    return 0;
}

def null_lt_word -> int {
    b = Box();
    if b.label < "hi" {
        return 1;
    }
    return 0;
}

def null_ne_word -> int {
    b = Box();
    if b.label == "hi" {
        return 1;
    }
    return 0;
}

def set_then_eq -> int {
    b = Box(label="hi");
    if b.label == "hi" {
        return 1;
    }
    return 0;
}
