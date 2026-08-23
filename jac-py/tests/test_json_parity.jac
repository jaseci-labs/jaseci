"""P2 wave 15 facade parity: native _json scanner/encoder vs host stdlib.

jac-py/Modules/jsonmodule.{c,jac} stay the staged c2jac corpus pair
(staging=lift); this file gates the product-path facade semantics in
jac-py/jacpython/_jsonmodule.jac against the pinned host oracle.
Expected values and error strings were verified against the host
CPython 3.14.6 ``_json`` C accelerator (and Lib/json glue) at
authoring time.

The scanner/encoder halves mirror the C accelerator's contract; the
loads/dumps-style drivers below replicate only the Lib/json glue
(whitespace skipping, StopIteration -> "Expecting value", extra-data
check, indent int -> spaces) needed to exercise them end to end.
"""

import from _jsonmodule {
    encode_basestring_ascii,
    encode_basestring,
    scanstring,
    make_scanner,
    make_encoder,
}


# Minimal JSONDecoder attribute context (Lib/json defaults).
obj _Ctx {
    has strict: bool = True,
        object_hook: any = None,
        object_pairs_hook: any = None,
        parse_float: any = None,
        parse_int: any = None,
        parse_constant: any = None;
}

glob _CONSTANTS: dict = {"NaN": float("nan"),
                         "Infinity": float("inf"),
                         "-Infinity": float("-inf")};

# JSONDecodeError.__init__ rendering of (msg, doc, pos): byte-exact.
def _decode_err_msg(msg: str, doc: str, pos: int) -> str {
    lineno = doc.count("\n", 0, pos) + 1;
    colno = pos - doc.rfind("\n", 0, pos);
    return msg + ": line " + str(lineno) + " column " + str(colno)
        + " (char " + str(pos) + ")";
}

def _default_ctx() -> _Ctx {
    c = _Ctx();
    c.parse_float = float;
    c.parse_int = int;
    def _parse_constant(name: str) -> float {
        return _CONSTANTS[name];
    }
    c.parse_constant = _parse_constant;
    return c;
}

def _raw_decode(s: str, idx: int) -> tuple[any, int] {
    sc = make_scanner(_default_ctx());
    return sc(s, idx);
}

# Lib/json JSONDecoder.decode() glue over the raw scanner.
def _loads(s: str) -> any {
    i = 0;
    while i < len(s) and s[i] in " \t\n\r" {
        i = i + 1;
    }
    try {
        (val, end) = _raw_decode(s, i);
    } except StopIteration as e {
        raise Exception(_decode_err_msg("Expecting value", s,
                                        e.value as int));
    }
    while end < len(s) and s[end] in " \t\n\r" {
        end = end + 1;
    }
    if end != len(s) {
        raise Exception(_decode_err_msg("Extra data", s, end));
    }
    return val;
}

def _expect_error(label: str, fn: any, want_msg: str) {
    raised = False;
    got = "";
    try {
        fn();
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised , label + ": expected an error";
    assert got == want_msg , (label, got, want_msg);
}

def _dumps(val: any, markers: dict = {}, default_fn: any = None,
           indent: any = None, sort_keys: bool = False,
           skipkeys: bool = False, allow_nan: bool = True,
           item_sep: str = ", ", key_sep: str = ": ") -> str {
    enc = make_encoder(markers, default_fn, encode_basestring_ascii,
                       indent, key_sep, item_sep, sort_keys, skipkeys,
                       allow_nan);
    got = enc(val, 0)[0];
    return got as str;
}

def _default_raises(o: any) -> any {
    # Mirrors the Lib/json default() for unserializable types.
    raise TypeError("Object of type " + type(o).__name__
                    + " is not JSON serializable");
}


test "wave15 string escaping matches the oracle" {
    assert encode_basestring_ascii("a\"b\\c\n\x01é𝄞") == (
        "\"a\\\"b\\\\c\\n\\u0001\\u00e9\\ud834\\udd1e\"") , "ascii escapes";
    assert encode_basestring("a\"b\\c\n\x01é𝄞") == (
        "\"a\\\"b\\\\c\\n\\u0001é𝄞\"") , "plain keeps non-ascii literal";
    # Short escapes and control-character range.
    assert encode_basestring_ascii("\b\f\n\r\t") == (
        "\"\\b\\f\\n\\r\\t\"") , "short escapes";
    assert encode_basestring_ascii("\x00\x1f\x20~\x7f") == (
        "\"\\u0000\\u001f ~\\u007f\"") , "control range boundaries";
    # Uppercase/lowercase hex digits round trip through ord arithmetic.
    assert encode_basestring_ascii("") == "\"\"" , "empty string";
    _expect_error("esc-ascii type int",
                  lambda { encode_basestring_ascii(42); },
                  "first argument must be a string, not int");
    _expect_error("esc-plain type bytes",
                  lambda { encode_basestring(b"x"); },
                  "first argument must be a string, not bytes");
}


test "wave15 scanstring decodes all escape forms" {
    assert scanstring("\"ab\\u00e9c\\\"z\"", 1) == ("abéc\"z", 14) , "unicode + quote escapes";
    assert scanstring("\"a\\/bc\"", 1) == ("a/bc", 7) , "slash escape";
    assert scanstring("\"\\ud834\\udd1e\"", 1) == ("𝄞", 14) , "surrogate pair joins";
    # Lone surrogates survive (Python strings are UCS4 internally).
    # NOTE: lone-surrogate literals in .jac source crash the compiler's
    # jcir_gen_pass (UnicodeEncodeError), so build them via chr() here.
    assert scanstring("\"\\ud800A\"", 1)[0] == chr(0xD800) + "A" , "lone high";
    assert scanstring("\"\\udc00\"", 1)[0] == chr(0xDC00) , "lone low";
    # High surrogate followed by a non-low escape rescans as literal.
    assert scanstring("\"\\ud800\\n\"", 1)[0] == chr(0xD800) + "\n" , "high then newline escape";
    # next_end is a raw index after the closing quote.
    assert scanstring("\"\"", 1) == ("", 2) , "empty string";

    _expect_error("unterminated", lambda { scanstring('"abc', 1); },
                  "Unterminated string starting at: line 1 column 1"
                  + " (char 0)");
    _expect_error("bad short escape", lambda { scanstring('"a\\qb"', 1); },
                  "Invalid \\escape: line 1 column 3 (char 2)");
    _expect_error("bad hex digit", lambda { scanstring("\"\\udzzz\"", 1); },
                  "Invalid \\uXXXX escape: line 1 column 3 (char 2)");
    _expect_error("bad pair hex digit",
                  lambda { scanstring("\"\\ud834\\uxzzz\"", 1); },
                  "Invalid \\uXXXX escape: line 1 column 9 (char 8)");
    _expect_error("truncated uescape",
                  lambda { scanstring('"a\\u12"', 1); },
                  "Invalid \\uXXXX escape: line 1 column 4 (char 3)");
    _expect_error("control char strict",
                  lambda { scanstring('"a\x01b"', 1); },
                  "Invalid control character at: line 1 column 3 (char 2)");
    # strict=False allows literal control characters.
    assert scanstring("\"a\x01b\"", 1, False)[0] == "a\x01b" , "non-strict control char";
    _expect_error("end out of bounds", lambda { scanstring('"abc"', 99); },
                  "end is out of bounds");
    _expect_error("end negative", lambda { scanstring('"abc"', -1); },
                  "end is out of bounds");
    _expect_error("scanstring type", lambda { scanstring(42, 1); },
                  "first argument must be a string, not int");
}


test "wave15 scanner value grammar is host exact" {
    # Numbers: ints, floats with fractions/exponents/signs, big ints.
    assert _loads("[1, -2, 0, -0]") == [1, -2, 0, 0] , "int forms";
    assert repr(_raw_decode("123456789012345678901234567890", 0)[0]) == (
        "123456789012345678901234567890") , "big int exact digits";
    assert repr(_raw_decode("5e-324", 0)[0]) == "5e-324" , "subnormal";
    assert repr(_raw_decode("-2.5e+3", 0)[0]) == "-2500.0" , "signed exp";
    assert repr(_raw_decode("1E2", 0)[0]) == "100.0" , "capital E";
    # Grammar rejections surface as StopIteration(start) through the
    # decoder glue's "Expecting value".
    for bad in ["-", "x", "+1", ".5", "tru", "nul"] {
        lbl: str = "reject " + bad;
        _expect_error(lbl, lambda { _loads(bad); },
                      _decode_err_msg("Expecting value", bad, 0));
    }
    # Partial-number forms stop mid-string instead (Extra data).
    for partial in ["01", "1.", "1e"] {
        lbl2: str = "partial " + partial;
        _expect_error(lbl2, lambda { _loads(partial); },
                      _decode_err_msg("Extra data", partial, 1));
    }
    # Constants.
    vals = _loads("[null, true, false, NaN, Infinity, -Infinity]");
    assert vals[0] is None and vals[1] is True and vals[2] is False , "const identity";
    assert repr(vals[3]) == "nan" and repr(vals[4]) == "inf" and repr(vals[5]) == "-inf" , "float constants";
    # Nesting with whitespace everywhere.
    assert _loads(" { \"x\" : [ 1 , { \"y\" : 2 } ] } ") == (
        {"x": [1, {"y": 2}]}) , "whitespace tolerance";
    # Duplicate keys: last wins (memo interns the key object).
    assert _loads("{\"k\": 1, \"k\": 2}") == {"k": 2} , "duplicate keys";
    # Strings decode surrogate pairs inside containers too.
    assert _loads("{\"a\": \"\\ud834\\udd1e\"}") == {"a": "𝄞"} , "pair in container";
}


test "wave15 decoder glue raises oracle positions" {
    _expect_error("object prop name", lambda { _loads("{"); },
                  "Expecting property name enclosed in double quotes:"
                  + " line 1 column 2 (char 1)");
    _expect_error("colon delimiter", lambda { _loads('{"a"'); },
                  "Expecting ':' delimiter: line 1 column 5 (char 4)");
    _expect_error("value after colon", lambda { _loads('{"a":}'); },
                  "Expecting value: line 1 column 6 (char 5)");
    _expect_error("array comma", lambda { _loads("[1,"); },
                  "Expecting value: line 1 column 4 (char 3)");
    _expect_error("array close", lambda { _loads("[1 2]"); },
                  "Expecting ',' delimiter: line 1 column 4 (char 3)");
    _expect_error("trailing comma array", lambda { _loads("[1,]"); },
                  "Illegal trailing comma before end of array:"
                  + " line 1 column 3 (char 2)");
    _expect_error("trailing comma object", lambda { _loads('{"a":1,}'); },
                  "Illegal trailing comma before end of object:"
                  + " line 1 column 7 (char 6)");
    _expect_error("extra data", lambda { _loads("01"); },
                  "Extra data: line 1 column 2 (char 1)");
    # Multi-line docs count newlines for line/column.
    _expect_error("multiline value", lambda { _loads('{\n  "a": x}'); },
                  "Expecting value: line 2 column 8 (char 9)");
    _expect_error("multiline delimiter", lambda { _loads('[\n 1,\n 2'); },
                  "Expecting ',' delimiter: line 3 column 3 (char 8)");
    _expect_error("multiline control char", lambda { _loads('{\n"a\nb": 1}'); },
                  "Invalid control character at: line 2 column 3 (char 4)");
    # strict=False passes literal control characters through.
    assert _loads_ctx_strict_false("\"a\x01b\"") == "a\x01b" , "decoder strict=False";
}

def _loads_ctx_strict_false(s: str) -> any {
    c = _Ctx();
    c.strict = False;
    c.parse_float = float;
    c.parse_int = int;
    def _pc(name: str) -> float {
        return _CONSTANTS[name];
    }
    c.parse_constant = _pc;
    sc = make_scanner(c);
    return sc(s, 0)[0];
}


test "wave15 parse hooks receive raw text and pairs" {
    # parse_int / parse_string hooks get the raw substring.
    ctx = _Ctx();
    def _parse_int(s: str) -> str {
        return "int<" + s + ">";
    }
    def _parse_float(s: str) -> str {
        return "float<" + s + ">";
    }
    ctx.parse_int = _parse_int;
    ctx.parse_float = _parse_float;
    def _pc(name: str) -> str {
        return name;
    }
    ctx.parse_constant = _pc;
    got = make_scanner(ctx)("{\"k\": 42, \"m\": [7.5, NaN]}", 0)[0];
    assert got["k"] == "int<42>" and got["m"][0] == "float<7.5>" and got["m"][1] == "NaN" , ("hooks", got);

    # object_pairs_hook replaces the dict build entirely.
    pctx = _Ctx();
    def _pairs(pairs: list) -> list {
        keys: list = [];
        for kv in pairs {
            keys.append(kv[0]);
        }
        return keys;
    }
    pctx.object_pairs_hook = _pairs;
    pctx.parse_float = float;
    pctx.parse_int = int;
    assert make_scanner(pctx)("{\"b\": 2, \"a\": 1}", 0)[0] == ["b", "a"] , "pairs hook order";

    # object_hook post-processes the decoded dict.
    hctx = _Ctx();
    def _hook(d: dict) -> int {
        return len(d);
    }
    hctx.object_hook = _hook;
    hctx.parse_float = float;
    hctx.parse_int = int;
    assert make_scanner(hctx)("{\"a\": 1, \"b\": 2}", 0)[0] == 2 , "object hook";
}


test "wave15 encoder core semantics match the oracle" {
    assert _dumps([1, 2.5, True, False, None, "s\"x"]) == (
        "[1, 2.5, true, false, null, \"s\\\"x\"]") , "basic types";
    # Float repr parity: shortest-repr, exponents, signed zero.
    assert _dumps([3.0, 1e100, -0.0, 1e-05, 0.1, 5e-324]) == (
        "[3.0, 1e+100, -0.0, 1e-05, 0.1, 5e-324]") , "float repr";
    assert _dumps(-7.0) == "-7.0" , "negative integral float";
    assert _dumps([123456789012345678901234567890]) == (
        "[123456789012345678901234567890]") , "big int";
    # Non-finite floats per allow_nan.
    assert _dumps([float("inf"), float("-inf"), float("nan")]) == (
        "[Infinity, -Infinity, NaN]") , "allow_nan literals";
    _expect_error("allow_nan false",
                  lambda { _dumps(float("nan"), allow_nan=False); },
                  "Out of range float values are not JSON compliant: nan");
    _expect_error("allow_nan false inf",
                  lambda { _dumps(float("inf"), allow_nan=False); },
                  "Out of range float values are not JSON compliant: inf");
    # Tuples encode as arrays.
    assert _dumps((1, ("two",))) == "[1, [\"two\"]]" , "tuple nesting";
    # Separators flow through verbatim.
    assert _dumps([[1, {"x": []}]], item_sep="", key_sep="") == (
        "[[1{\"x\"[]}]]") , "empty separators";
    # sort_keys sorts items by key.
    assert _dumps({"b": 1, "a": 2}, sort_keys=True) == (
        "{\"a\": 2, \"b\": 1}") , "sort_keys";
}


test "wave15 encoder key coercion rules" {
    assert _dumps({None: 0, False: 1, True: 2, 3: 3, 4.5: 4}) == (
        "{\"null\": 0, \"false\": 1, \"true\": 2, \"3\": 3, \"4.5\": 4}") , "coercible keys";
    assert _dumps({float("nan"): 1}) == "{\"NaN\": 1}" , "nan key";
    _expect_error("bad key type", lambda { _dumps({(1, 2): "a"}); },
                  "keys must be str, int, float, bool or None, not tuple");
    _expect_error("bad key type bytes", lambda { _dumps({b"x": 1}); },
                  "keys must be str, int, float, bool or None, not bytes");
    assert _dumps({(1, 2): "a", "ok": 1}, skipkeys=True) == (
        "{\"ok\": 1}") , "skipkeys drops bad keys";
}


test "wave15 encoder default hook and circular references" {
    def _listify(o: any) -> any {
        return [];
    }
    assert _dumps(_Widget(), default_fn=_listify) == "[]" , "default hook result is encoded recursively";
    w = _Widget();
    _expect_error("custom obj unserializable",
                  lambda { _dumps(w, default_fn=_widget_default); },
                  "Object of type _Widget is not JSON serializable");

    l: list = [];
    l.append(l);
    _expect_error("self referential list", lambda { _dumps(l); },
                  "Circular reference detected");
    d: dict = {};
    d["self"] = d;
    _expect_error("self referential dict", lambda { _dumps(d); },
                  "Circular reference detected");
    inner: list = [];
    outer: list = [inner];
    inner.append(outer);
    _expect_error("mutually nested", lambda { _dumps(outer); },
                  "Circular reference detected");
    # Repeated but non-circular sharing is fine without markers.
    shared: list = [1];
    assert _dumps([shared, shared], markers={}) == "[[1], [1]]" , "shared subtree ok";
    # markers=None disables detection entirely (host contract); a
    # self-referential encode there recurses until RecursionError, so
    # it is not exercised here.
}

obj _Widget {
    has x: int = 0;
}

def _widget_default(o: any) -> any {
    raise TypeError("Object of type _Widget is not JSON serializable");
}


test "wave15 indent layout matches the oracle" {
    assert _dumps([[1, 2], {"a": 3}], indent="  ",
                  item_sep=",") == ("[\n  [\n    1,\n    2\n  ],\n"
                                    "  {\n    \"a\": 3\n  }\n]") , "indent 2 spaces";
    assert _dumps([], indent="..") == "[]" , "empty list no indent";
    assert _dumps({}, indent="..") == "{}" , "empty dict no indent";
    assert _dumps([[[]]], indent="ab") == "[\nab[\nabab[]\nab]\n]" , "custom indent unit";
    # Initial indent level shifts the cache baseline (encoder_call arg).
    enc_l1 = make_encoder({}, _default_raises, encode_basestring_ascii,
                          "..", ":", ",", False, False, True);
    assert enc_l1([1], 1)[0] == "[\n....1\n..]" , "initial level 1";
    # Indented dicts put each pair on its own line.
    got = _dumps({"a": 1, "b": 2}, indent="  ", item_sep=",");
    assert got == "{\n  \"a\": 1,\n  \"b\": 2\n}" , ("indent dict", got);
}


test "wave15 make_encoder argument validation" {
    _expect_error("markers type", _make_encoder_bad_markers,
                  "make_encoder() argument 1 must be dict or None, not list");
}

def _make_encoder_bad_markers() {
    make_encoder([], _default_raises, encode_basestring_ascii,
                 None, ":", ",", False, False, True);
}
