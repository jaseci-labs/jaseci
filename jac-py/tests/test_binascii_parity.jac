"""P2 wave 16 facade parity: native binascii vs host stdlib.

Staged ``jac-py/Modules/binasciimodule.{c,jac}`` stay the c2jac corpus
pair (staging=lift); this file gates the product-path facade semantics in
jac-py/jacpython/binasciimodule.jac against the pinned host oracle.
Expected values and error messages were verified against the host stdlib
``binascii`` (the pinned CPython on this LP64 little-endian host) at
authoring time.
"""

import from binasciimodule {
    a2b_hex,
    b2a_hex,
    hexlify,
    unhexlify,
}


def _b(*vals: list) -> bytes {
    return bytes(list(vals));
}


def _expect_unhex_error(label: str, arg: any, want_type: str, want_msg: str) {
    raised = False;
    got = "";
    got_type = "";
    try {
        unhexlify(arg);
    } except Exception as e {
        raised = True;
        got = str(e);
        got_type = type(e).__name__;
    }
    assert raised , label + ": expected an error";
    assert got == want_msg , (label, got, want_msg);
    assert got_type == want_type , (label, got_type, want_type);
}


def _expect_sep_error(label: str, sep: any, bps: int, want_type: str,
                      want_msg: str) {
    raised = False;
    got = "";
    got_type = "";
    try {
        hexlify(b"a", sep, bps);
    } except Exception as e {
        raised = True;
        got = str(e);
        got_type = type(e).__name__;
    }
    assert raised , label + ": expected an error";
    assert got == want_msg , (label, got, want_msg);
    assert got_type == want_type , (label, got_type, want_type);
}


test "wave16 hexlify round trips" {
    assert hexlify(_b()) == _b() , "empty";
    # b'\xb9\x01\xef' -> b'b901ef' (host oracle)
    assert hexlify(_b(0xB9, 0x01, 0xEF)) == b"b901ef";
    assert hexlify(b"abc") == b"616263";
    assert b2a_hex(_b(0x00, 0xFF)) == b"00ff";
    assert unhexlify(b"616263") == b"abc";
    assert unhexlify("616263") == b"abc";
    assert unhexlify("ABCDEF") == _b(0xAB, 0xCD, 0xEF);
    assert unhexlify(hexlify(b"The quick brown fox")) == b"The quick brown fox";
}


test "wave16 hexlify separator scheduling" {
    data = _b(0xB9, 0x01, 0xEF);
    assert hexlify(data, ":") == b"b9:01:ef";
    assert b2a_hex(data, b"_", 2) == b"b9_01ef";
    # Negative counts from the left; positive from the right (host pins).
    assert b2a_hex(b"abcdef", b"-", -2) == b"6162-6364-6566";
    assert b2a_hex(b"abcdef", b"-", 2) == b"6162-6364-6566";
    assert b2a_hex(b"abcdef", b".", 3) == b"616263.646566";
    # abs(bytes_per_sep) >= arglen disables grouping entirely.
    assert b2a_hex(b"abc", b"-", 5) == b"616263";
    assert b2a_hex(b"", b"-", 1) == b"";
}


test "wave16 separator errors match host" {
    _expect_sep_error("sep len 2", b"--", 1, "ValueError",
                      "sep must be length 1.");
    _expect_sep_error("sep empty", b"", 1, "ValueError",
                      "sep must be length 1.");
    _expect_sep_error("sep non-ascii str", "\xff", 1, "ValueError",
                      "sep must be ASCII.");
    _expect_sep_error("sep int", 5, 1, "TypeError",
                      "object of type 'int' has no len()");
    _expect_sep_error("sep list", [48], 1, "TypeError",
                      "sep must be str or bytes.");
}


test "wave16 unhexlify errors match host" {
    _expect_unhex_error("odd length", "abc", "Exception",
                        "Odd-length string");
    _expect_unhex_error("non-hex digit", "zz", "Exception",
                        "Non-hexadecimal digit found");
    _expect_unhex_error("non-hex tail", b"61zz", "Exception",
                        "Non-hexadecimal digit found");
    _expect_unhex_error("non-ascii str", "\xff", "ValueError",
                        "string argument should contain only ASCII characters");
    _expect_unhex_error("int arg", 5, "TypeError",
                        "argument should be bytes, buffer or ASCII string, not 'int'");
}
