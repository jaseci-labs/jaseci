obj Base {
    has tag: str = "base";
}

obj Sub(Base) {
    has extra: int = 7;
}

def looks_sub(nd: (Base | None)) -> TypeGuard[Sub] {
    return isinstance(nd, Sub);
}

def probe_guard(nd: (Base | None)) -> str {
    if looks_sub(nd) {
        return f"guard:{nd.extra}";
    }
    return "guard:none";
}

obj Holder {
    static def looks_sub_static(nd: (Base | None)) -> TypeGuard[Sub] {
        return isinstance(nd, Sub);
    }

    def looks_sub_method(nd: (Base | None)) -> TypeGuard[Sub] {
        return isinstance(nd, Sub);
    }
}

with entry {
    s = Sub();
    b = Base();

    print(probe_guard(s));
    print(probe_guard(b));
    print(probe_guard(None));

    print(looks_sub(s));
    print(looks_sub(b));

    print(Holder.looks_sub_static(s));
    print(Holder.looks_sub_static(b));

    h = Holder();
    print(h.looks_sub_method(s));
    print(h.looks_sub_method(b));

    if Holder.looks_sub_static(s) {
        print(f"static:{s.extra}");
    }
}
