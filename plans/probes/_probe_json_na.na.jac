import json;

def _tags -> list[any] {
    t: list[any] = [];
    t.append("alpha");
    t.append("beta");
    return t;
}

def _deep -> list[any] {
    d: list[any] = [];
    d.append(1);
    d.append(2);
    d.append(99);
    return d;
}

def _sample -> dict[str, any] {
    nested: dict[str, any] = {"deep": _deep(), "neg": -7, "zero": 0};
    return {
        "id": "evt_001",
        "seq": 42,
        "ratio": 3.14,
        "active": True,
        "note": None,
        "tags": _tags(),
        "multiline": "line1\nline2\t\"quoted\" émoji 😀",
        "nested": nested
    };
}

def _check(label: str, ok: bool) {
    if ok {
        print("PASS " + label);
    } else {
        print("FAIL " + label);
    }
}

glob s: dict[str, any] = _sample(),
     encoded: str = json.dumps(s);

with entry {
    _check("na_dumps_returns_str", isinstance(encoded, str));
    _check("na_loads_returns_dict", isinstance(json.loads(encoded), dict));
}

glob re: str = json.dumps(json.loads(encoded));
with entry {
    _check("na_dumps_loads_dumps_idempotent", re == encoded);

    _check("na_repeatable_dump", json.dumps(_sample()) == encoded);
}

glob arr_src: str = "[1, 2, {\"x\": false, \"y\": 2.5}]";
with entry {
    _check("na_array_roundtrip", json.dumps(json.loads(arr_src)) == arr_src);

    _check("na_empty_dict", json.dumps(json.loads("{}")) == "{}");
    _check("na_empty_list", json.dumps(json.loads("[]")) == "[]");
    _check("na_none_roundtrip", json.dumps(json.loads("null")) == "null");

    print("WIRE " + encoded);
}
