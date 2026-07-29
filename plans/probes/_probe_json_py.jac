import json;
import subprocess;

glob NATIVE_BIN: str = "plans/probes/_probe_json_na";


def _sample -> dict {
    return {
        "id": "evt_001",
        "seq": 42,
        "ratio": 3.14,
        "active": True,
        "note": None,
        "tags": ["alpha", "beta"],
        "multiline": "line1\nline2\t\"quoted\" émoji 😀",
        "nested": {"deep": [1, 2, 99], "neg": -7, "zero": 0},

    };
}


def _check(label: str, ok: bool) {
    if ok {
        print("PASS " + label);
    } else {
        print("FAIL " + label);
    }
}


glob out: str = subprocess.check_output([NATIVE_BIN]).decode("utf-8"),
     wire: str = "";

with entry {
    for line in out.split("\n") {
        if line.startswith("WIRE ") {
            wire = line[5:];
        }
    }
    _check("py_captured_native_wire", wire != "");
}

glob native_fails: int = 0;
with entry {
    for line in out.split("\n") {
        if line.startswith("FAIL ") {
            native_fails += 1;
        }
    }
    _check("py_native_zero_failures", native_fails == 0);
}

glob decoded: dict = json.loads(wire);
with entry {
    _check("py_loads_native_wire", isinstance(decoded, dict));
}

glob s: dict = _sample();
with entry {
    _check("py_field_id", decoded.get("id") == s["id"]);
    _check("py_field_seq", decoded.get("seq") == s["seq"]);
    _check("py_field_ratio", decoded.get("ratio") == s["ratio"]);
    _check("py_field_active", decoded.get("active") == s["active"]);
    _check("py_field_note", decoded.get("note") == s["note"]);
    _check("py_field_tags", decoded.get("tags") == s["tags"]);
    _check("py_field_multiline", decoded.get("multiline") == s["multiline"]);
    _check("py_field_nested", decoded.get("nested") == s["nested"]);
    _check("py_deep_equality", decoded == s);
}

glob py_wire_ascii: str = json.dumps(s),
     py_wire_utf8: str = json.dumps(s, ensure_ascii=False);

with entry {
    _check("py_ascii_reparses_equal", json.loads(py_wire_ascii) == s);
    _check("py_utf8_reparses_equal", json.loads(py_wire_utf8) == s);

    print("PYWIRE_ASCII " + py_wire_ascii);
    print("PYWIRE_UTF8   " + py_wire_utf8);
}
