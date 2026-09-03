"""`type(x) is <T>` cross-backend lock (issue #6149).

`type()` must yield the value's *type object*, not a name for it, so that
`is` / `is not` against a builtin type is an ordinary identity comparison.
The ES lane used to lower `type(x)` to JS `typeof x` -- a string tag -- while
the bare type name lowered to the runtime type object, so every comparison
was between two different kinds of value and silently answered `false`
(`is not`: always `true`).

`bool_not_int` and `bool_is_bool` are the rows that pin exact-type semantics:
`isinstance(True, int)` is true in Python but `type(True) is int` is not, so a
lowering that reached for isinstance would fail here.
"""

obj Tagged {
    has x: int = 0;
}

def _classify_py(x: any) -> str {
    if type(x) is str {
        return "str";
    } elif type(x) is int {
        return "int";
    } elif type(x) is not dict {
        return "notdict";
    }
    return "dict";
}

def type_identity_py -> dict {
    inst = Tagged(x=1);
    return {
        "cls_str": _classify_py("hello"),
        "cls_int": _classify_py(42),
        "cls_float": _classify_py(3.14),
        "cls_dict": _classify_py({"a": 1}),
        "is_str": 1 if type("s") is str else 0,
        "is_int": 1 if type(7) is int else 0,
        "is_float": 1 if type(3.14) is float else 0,
        "is_list": 1 if type([1, 2]) is list else 0,
        "is_dict": 1 if type({"a": 1}) is dict else 0,
        "is_bool": 1 if type(True) is bool else 0,
        "str_not_int": 1 if type("s") is not int else 0,
        "int_not_dict": 1 if type(7) is not dict else 0,
        "bool_not_int": 1 if type(True) is not int else 0,
        "same_type": 1 if type(1) is type(2) else 0,
        "diff_type": 1 if type(1) is type("a") else 0,
        "arch_is": 1 if type(inst) is Tagged else 0,
        "arch_not_str": 1 if type(inst) is not str else 0,
        "none_same": 1 if type(None) is type(None) else 0,
        "name_int": type(42).__name__,
        "name_str": type("hi").__name__,
        "name_list": type([]).__name__,
        "name_dict": type({"a": 1}).__name__,
        "name_arch": type(inst).__name__,
        "isinstance_dict": 1 if isinstance({"a": 1}, dict) else 0,
        "isinstance_list": 1 if isinstance([1], list) else 0
    };
}

def _classify_cl(x: any) -> str {
    if type(x) is str {
        return "str";
    } elif type(x) is int {
        return "int";
    } elif type(x) is not dict {
        return "notdict";
    }
    return "dict";
}

def type_identity_cl -> dict {
    inst = Tagged(x=1);
    return {
        "cls_str": _classify_cl("hello"),
        "cls_int": _classify_cl(42),
        "cls_float": _classify_cl(3.14),
        "cls_dict": _classify_cl({"a": 1}),
        "is_str": 1 if type("s") is str else 0,
        "is_int": 1 if type(7) is int else 0,
        "is_float": 1 if type(3.14) is float else 0,
        "is_list": 1 if type([1, 2]) is list else 0,
        "is_dict": 1 if type({"a": 1}) is dict else 0,
        "is_bool": 1 if type(True) is bool else 0,
        "str_not_int": 1 if type("s") is not int else 0,
        "int_not_dict": 1 if type(7) is not dict else 0,
        "bool_not_int": 1 if type(True) is not int else 0,
        "same_type": 1 if type(1) is type(2) else 0,
        "diff_type": 1 if type(1) is type("a") else 0,
        "arch_is": 1 if type(inst) is Tagged else 0,
        "arch_not_str": 1 if type(inst) is not str else 0,
        "none_same": 1 if type(None) is type(None) else 0,
        "name_int": type(42).__name__,
        "name_str": type("hi").__name__,
        "name_list": type([]).__name__,
        "name_dict": type({"a": 1}).__name__,
        "name_arch": type(inst).__name__,
        "isinstance_dict": 1 if isinstance({"a": 1}, dict) else 0,
        "isinstance_list": 1 if isinstance([1], list) else 0
    };
}


def type_identity_na -> dict[str, any] {
    return {};
}
