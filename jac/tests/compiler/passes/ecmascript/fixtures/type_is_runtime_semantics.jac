"""Fixture: `type(x) is T` exact-type semantics on the client (#6149).

`type() is` is an exact match in Python: no subclass folding (bool is not
int) and archetype subclasses are not instances of the base under
`type() is`, unlike isinstance.
"""

obj Animal {
    has name: str = "";
}

obj Dog(Animal) {
    has breed: str = "";
}

def int_is_int -> bool {
    return type(42) is int;
}

def bool_is_int -> bool {
    return type(True) is int;
}

def int_not_str -> bool {
    return type(42) is not str;
}

def float_is_int -> bool {
    return type(1.5) is int;
}

def list_is_list -> bool {
    return type([1, 2]) is list;
}

def dict_is_dict -> bool {
    return type({"k": 1}) is dict;
}

def arch_is_animal -> bool {
    a: Animal = Animal(name="generic");
    return type(a) is Animal;
}

def dog_is_animal -> bool {
    d: Animal = Dog(name="rex", breed="lab");
    return type(d) is Animal;
}

def type_is_axes -> dict {
    return {
        "int_is_int": int_is_int(),
        "bool_is_int": bool_is_int(),
        "int_not_str": int_not_str(),
        "float_is_int": float_is_int(),
        "list_is_list": list_is_list(),
        "dict_is_dict": dict_is_dict(),
        "arch_is_animal": arch_is_animal(),
        "dog_is_animal": dog_is_animal()
    };
}
