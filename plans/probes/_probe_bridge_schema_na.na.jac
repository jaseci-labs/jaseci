import json;

def _check(label: str, ok: bool) {
    if ok {
        print("PASS " + label);
    } else {
        print("FAIL " + label);
    }
}

glob wire: str = (
         "{\"schema_id\": \"jac.ai_tui.bridge.v1\", \"kind\": \"session_event_batch\", " + "\"epoch\": 2, \"first_seq\": 1, \"last_seq\": 1, \"mutations\": [" + "{\"kind\": \"diagnostic\", \"text\": \"émoji 😀\"}]}"
     ),
     data: dict[str, any] = json.loads(wire),
     again: str = json.dumps(data);

with entry {
    _check("na_loads_dict", isinstance(data, dict));
    _check("na_roundtrip_stable", json.dumps(json.loads(again)) == again);
    _check("na_wire_has_schema", "jac.ai_tui.bridge.v1" in again);
    _check("na_wire_has_emoji", "😀" in again);
}

glob bad_wire: str = "{\"schema_id\": \"x\", \"kind\": \"ui_snapshot\"}",
     bad: dict[str, any] = json.loads(bad_wire);

with entry {
    _check("na_malformed_loads", isinstance(bad, dict));
    _check("na_malformed_differs", "jac.ai_tui.bridge.v1" not in json.dumps(bad));
}
