# _json facade pins (wave 15 product path): jac-py/jacpython/_jsonmodule.jac
# against the host CPython 3.14 oracle.
#
# Two legs per pin family:
#   - direct: native calls into _jsonmodule.dumps()/loads()/scanstring/
#     encode_basestring(_ascii) with expected values captured byte-exact
#     from the host oracle at authoring time;
#   - libtest: ``import json`` snippets through the layer_p2_libtest shim
#     module (P2LibtestJsonDumpsFn/P2LibtestJsonLoadsFn), which exercises
#     the kwargs bridge and the py_error conversion of decode failures.
#
# Decode-error expectations are the exact JSONDecodeError renderings
# "<msg>: line L column C (char P)"; JSONDecodeError subclasses ValueError,
# so guest snippets catch them with except ValueError.

import from _jsonmodule {
    dumps,
    loads,
    scanstring,
    encode_basestring_ascii,
    encode_basestring,
}
import from layer_p2_libtest { p2_libtest_expect_ok }

# ------------------------- encoder: structure ------------------------------

test "json_facade: dumps basic containers matches oracle" {
    got = dumps({"a": [1, 2.5, None, True, False], "s": "x"});
    assert got == '{"a": [1, 2.5, null, true, false], "s": "x"}', got;
    assert dumps((1, "t")) == '[1, "t"]';
    assert dumps(10**30) == "1000000000000000000000000000000";
}

test "json_facade: dumps key coercion str/int/float/bool/None" {
    # bool key collides with 1 in the dict (last value wins), matching the host.
    got = dumps({1: "i", 2.5: "f", True: "b", None: "n"});
    assert got == '{"1": "b", "2.5": "f", "null": "n"}', got;
}

test "json_facade: dumps NaN Infinity both directions" {
    assert dumps(float("nan")) == "NaN";
    assert dumps(float("inf")) == "Infinity";
    assert dumps(float("-inf")) == "-Infinity";
    nan_list = loads("[NaN, Infinity, -Infinity]");
    assert nan_list[0] != nan_list[0];
    assert nan_list[1] == float("inf");
    assert nan_list[2] == float("-inf");
}

test "json_facade: dumps separators and sort_keys" {
    assert dumps([1, 2], separators=(",", ":")) == "[1,2]";
    got = dumps({"b": 1, "a": 2}, sort_keys=True, separators=(",", ":"));
    assert got == '{"a":2,"b":1}', got;
}

test "json_facade: dumps indent int expands to spaces" {
    got = dumps({"k": [1, {"in": 2}]}, indent=2);
    want = '{\n  "k": [\n    1,\n    {\n      "in": 2\n    }\n  ]\n}';
    assert got == want, got;
    got_t = dumps({"k": [1]}, indent="\t");
    assert got_t == '{\n\t"k": [\n\t\t1\n\t]\n}', got_t;
}

test "json_facade: dumps default hook serializes unknown types" {
    def dflt(o: any) -> any {
        return 7;
    }
    assert dumps([object()], `default=dflt) == "[7]";
}

test "json_facade: dumps without default raises oracle TypeError" {
    try {
        dumps(set());
    } except TypeError as e {
        assert str(e) == "Object of type set is not JSON serializable", str(e);
    } else {
        raise AssertionError("no TypeError for unserializable object");
    }
}

test "json_facade: dumps skipkeys drops non-scalar keys" {
    got = dumps({object(): 1, "ok": 2}, skipkeys=True);
    assert got == '{"ok": 2}', got;
    try {
        dumps({object(): 1});
    } except TypeError as e {
        assert str(e)
            == "keys must be str, int, float, bool or None, not object", str(e);
    } else {
        raise AssertionError("no TypeError for non-scalar key");
    }
}

test "json_facade: dumps allow_nan=False raises oracle ValueError" {
    try {
        dumps(float("nan"), allow_nan=False);
    } except ValueError as e {
        assert str(e)
            == "Out of range float values are not JSON compliant: nan", str(e);
    } else {
        raise AssertionError("no ValueError for allow_nan=False");
    }
}

test "json_facade: dumps circular reference detection" {
    l = [1];
    l.append(l);
    try {
        dumps(l);
    } except ValueError as e {
        assert str(e) == "Circular reference detected", str(e);
    } else {
        raise AssertionError("no ValueError for circular reference");
    }
}

# ----------------------- encoder: string escaping ---------------------------

test "json_facade: ensure_ascii escapes byte-exact incl surrogate pairs" {
    assert dumps("\u00e9") == "\"\\u00e9\"";
    assert dumps("\U0001f600") == "\"\\ud83d\\ude00\"";
    assert dumps("\u0000\t\n") == "\"\\u0000\\t\\n\"";
}

test "json_facade: ensure_ascii=False keeps literals, escapes controls" {
    assert dumps("\u00e9", ensure_ascii=False) == "\"\u00e9\"";
    assert dumps("\x01", ensure_ascii=False) == "\"\\u0001\"";
}

test "json_facade: encode_basestring_ascii / encode_basestring surface" {
    assert encode_basestring_ascii("a\x00b\u00e9\U0001f600")
        == '"a\\u0000b\\u00e9\\ud83d\\ude00"';
    assert encode_basestring("a\x00b\u00e9") == '"a\\u0000b\u00e9"';
}

# ------------------------------ decoder ------------------------------------

test "json_facade: loads round-trips scalars and containers" {
    assert loads('{"a": [1, 2.5, null, true, false]}')
        == {"a": [1, 2.5, None, True, False]};
    assert loads('"\\u0000"') == "\u0000";
    assert loads('"\\ud83d\\ude00"') == "\U0001f600";
    assert loads("1000000000000000000000000000000") == 10**30;
    assert loads('{"dup": 1, "dup": 2}') == {"dup": 2};
    assert loads(" \t\r\n[1] \r\n\t ") == [1];
}

test "json_facade: loads accepts bytes input" {
    assert loads(b"[1, 2]") == [1, 2];
    try {
        loads(42);
    } except TypeError as e {
        assert str(e)
            == "the JSON object must be str, bytes or bytearray, not int", str(e);
    } else {
        raise AssertionError("no TypeError for int input");
    }
}

test "json_facade: parse hooks receive raw text spans" {
    def pf(sval: str) -> any {
        return ("PF", sval);
    }
    assert loads("[1E+2]", parse_float=pf) == [("PF", "1E+2")];

    def pi(sval: str) -> any {
        return ("PI", sval);
    }
    assert loads("[12]", parse_int=pi) == [("PI", "12")];

    def pc(name: str) -> any {
        return name + "!";
    }
    assert loads("[NaN, Infinity, -Infinity]", parse_constant=pc)
        == ["NaN!", "Infinity!", "-Infinity!"];
}

test "json_facade: object_hook applies bottom-up at every level" {
    def oph(dval: any) -> any {
        return sorted(dval.items());
    }
    got = loads('{"b": 1, "a": 2}', object_hook=oph);
    assert got == [("a", 2), ("b", 1)], got;

    def keys(dval: any) -> any {
        return sorted(dval.keys());
    }
    # inner hook result feeds the outer call: {"outer": ["a","z"]} -> ["outer"]
    assert loads('{"outer": {"z": 1, "a": 2}}', object_hook=keys) == ["outer"];
}

test "json_facade: object_pairs_hook receives pair lists" {
    def pairs(pairs_val: any) -> any {
        return dict(pairs_val);
    }
    assert loads('{"a": 1}', object_pairs_hook=pairs) == {"a": 1};
    assert loads("[1,2]", object_pairs_hook=pairs) == [1, 2];
}

# ------------------- decoder errors: byte-exact positions -------------------

def _expect_decode_error(doc: str, want: str) {
    try {
        loads(doc);
    } except ValueError as e {
        assert str(e) == want, str(e);
    } else {
        raise AssertionError("no decode error for " + repr(doc));
    }
}

test "json_facade: Expecting value positions match oracle" {
    _expect_decode_error("", "Expecting value: line 1 column 1 (char 0)");
    _expect_decode_error("nul", "Expecting value: line 1 column 1 (char 0)");
    _expect_decode_error("-", "Expecting value: line 1 column 1 (char 0)");
    _expect_decode_error("nan", "Expecting value: line 1 column 1 (char 0)");
    _expect_decode_error("[1,", "Expecting value: line 1 column 4 (char 3)");
    _expect_decode_error('{\n  "a": x\n}',
                         "Expecting value: line 2 column 8 (char 9)");
}

test "json_facade: Extra data positions match oracle" {
    _expect_decode_error('{"a":1}x', "Extra data: line 1 column 8 (char 7)");
    _expect_decode_error("01", "Extra data: line 1 column 2 (char 1)");
}

test "json_facade: string scan errors match oracle" {
    _expect_decode_error('"abc',
                         "Unterminated string starting at:"
                         + " line 1 column 1 (char 0)");
    _expect_decode_error('"a\x01b"',
                         "Invalid control character at: line 1 column 3 (char 2)");
    _expect_decode_error('"a\\qb"', "Invalid \\escape: line 1 column 3 (char 2)");
    _expect_decode_error('"a\\u12"',
                         "Invalid \\uXXXX escape: line 1 column 4 (char 3)");
    _expect_decode_error('"\\uZZZZ"',
                         "Invalid \\uXXXX escape: line 1 column 3 (char 2)");
}

test "json_facade: delimiter errors match oracle" {
    _expect_decode_error("[1,]",
                         "Illegal trailing comma before end of array:"
                         + " line 1 column 3 (char 2)");
    _expect_decode_error('{"a":1,}',
                         "Illegal trailing comma before end of object:"
                         + " line 1 column 7 (char 6)");
    _expect_decode_error('{"a" 1}',
                         "Expecting ':' delimiter: line 1 column 6 (char 5)");
    _expect_decode_error("{1:2}",
                         "Expecting property name enclosed in double quotes:"
                         + " line 1 column 2 (char 1)");
    _expect_decode_error("[1 2]",
                         "Expecting ',' delimiter: line 1 column 4 (char 3)");
}

# --------------------------- libtest shim leg -------------------------------

test "layer_p2_libtest: json_roundtrip snippet prints ok on JacPython" {
    snippet = (
        "import json\n"
        "assert json.loads(json.dumps([1, {'a': None}, 'x']))"
        " == [1, {'a': None}, 'x']\n"
        "n = 10 ** 30\n"
        "assert json.loads(json.dumps(n)) == n\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: json_encode_kwargs snippet prints ok on JacPython" {
    snippet = (
        "import json\n"
        "r = json.dumps('\u00e9\U0001f600')\n"
        "assert r == '\"\\\\u00e9\\\\ud83d\\\\ude00\"', r\n"
        "r = json.dumps({'b': 1, 'a': 2}, sort_keys=True,"
        " separators=(',', ':'))\n"
        "assert r == '{\"a\":2,\"b\":1}', r\n"
        "r = json.dumps([1], indent=2)\n"
        "assert r == '[\\n  1\\n]', repr(r)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: json_hooks snippet prints ok on JacPython" {
    snippet = (
        "import json\n"
        "def pf(s):\n"
        "    return ('PF', s)\n"
        "def oh(d):\n"
        "    return sorted(d.items())\n"
        "r = json.loads('[1.5]', parse_float=pf)\n"
        "assert r == [('PF', '1.5')], r\n"
        "q = json.loads('{\"b\": 1, \"a\": 2}', object_hook=oh)\n"
        "assert q == [('a', 2), ('b', 1)], q\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: json_decode_errors snippet prints caught on JacPython" {
    snippet = (
        "import json\n"
        "try:\n"
        "    json.loads('{\"a\":1}x')\n"
        "except ValueError as e:\n"
        "    assert str(e) == 'Extra data: line 1 column 8 (char 7)', str(e)\n"
        "    print('caught')\n"
        "else:\n"
        "    raise AssertionError('no error')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, "caught");
    assert ok , detail;
}

test "layer_p2_libtest: json_expecting_value snippet prints caught on JacPython" {
    snippet = (
        "import json\n"
        "try:\n"
        "    json.loads('')\n"
        "except ValueError as e:\n"
        "    assert str(e) == 'Expecting value: line 1 column 1 (char 0)',"
        " str(e)\n"
        "    print('caught')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, "caught");
    assert ok , detail;
}

test "layer_p2_libtest: json_nan snippet prints ok on JacPython" {
    snippet = (
        "import json\n"
        "v = json.loads('[NaN, Infinity]')\n"
        "assert v[0] != v[0] and v[1] == float('inf')\n"
        "r = json.dumps(float('-inf'))\n"
        "assert r == '-Infinity', r\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "json_facade: scanstring returns decoded span and next index" {
    assert scanstring('"hello"', 1) == ("hello", 7);
    assert scanstring('"\\u0041\\t"', 1) == ("A\t", 10);
}
