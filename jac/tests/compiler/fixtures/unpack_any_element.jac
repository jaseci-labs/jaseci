glob ANY_PAIRS: set = {("a", int), ("b", str)};
glob ANY_NUMS: set = {(1, "x"), (2, "y")};

def takes_type(t: type) -> str {
    return t.__name__;
}

def loop_unpack_pairs -> str {
    out = "";
    for (nm, ty) in ANY_PAIRS {
        out += nm + takes_type(ty);
    }
    return out;
}

def loop_unpack_nums -> str {
    out = "";
    for (num, label) in ANY_NUMS {
        out += str(num) + label;
    }
    return out;
}
