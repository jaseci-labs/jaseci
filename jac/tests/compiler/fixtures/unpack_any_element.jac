glob BARE_TUPLE: tuple = (("a", int), ("b", str));
glob BARE_LIST: list = [(1, "x"), (2, "y")];

def takes_type(t: type) -> str {
    return t.__name__;
}

def loop_unpack_tuple -> str {
    out = "";
    for (nm, ty) in BARE_TUPLE {
        out += nm + takes_type(ty);
    }
    return out;
}

def loop_unpack_list -> str {
    out = "";
    for (num, label) in BARE_LIST {
        out += str(num) + label;
    }
    return out;
}
