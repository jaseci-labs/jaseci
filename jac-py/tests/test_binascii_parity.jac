"""P2 wave 16 facade parity: native binascii vs host stdlib.

Staged ``jac-py/Modules/binasciimodule.{c,jac}`` stay the c2jac corpus
pair (staging=lift); this file gates the product-path facade semantics in
jac-py/jacpython/binasciimodule.jac against the pinned host oracle.
Expected values and error messages were verified against the host stdlib
``binascii`` (the pinned CPython on this LP64 little-endian host) at
authoring time.
"""

import from binasciimodule {
    a2b_base64,
    a2b_hex,
    a2b_qp,
    a2b_uu,
    b2a_base64,
    b2a_hex,
    b2a_qp,
    b2a_uu,
    crc32,
    crc_hqx,
    hexlify,
    unhexlify,
}


def _b(*vals: int) -> bytes {
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


def _expect_b64_error(label: str, arg: any, strict_mode: bool,
                      want_msg: str) {
    raised = False;
    got = "";
    try {
        a2b_base64(arg, strict_mode);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised , label + ": expected an error";
    assert got == want_msg , (label, got, want_msg);
}


test "wave16 base64 round trips" {
    assert b2a_base64(b"b") == b"Yg==\n" , "single byte + newline";
    assert b2a_base64(b"b", False) == b"Yg==";
    assert b2a_base64(b"") == b"\n";
    assert b2a_base64(b"abc", False) == b"YWJj";
    assert b2a_base64(b"abcd") == b"YWJjZA==\n";
    assert a2b_base64(b"Yg==\n") == b"b";
    assert a2b_base64(b"") == b"";
    # Newlines are insignificant on decode (host pin).
    assert a2b_base64(b"YWJj\nZEFk") == _b(0x61, 0x62, 0x63, 0x64, 0x41, 0x64);
    assert a2b_base64(b"YWJjZA==\n") == b"abcd";
    # Non-strict mode ignores non-alphabet bytes and excess pads.
    assert a2b_base64(b"Yg===") == b"b";
    assert a2b_base64(b"Yg==YQ") == _b(0x62, 0x06, 0x10);
}


test "wave16 base64 strict mode matches host" {
    _expect_b64_error("leading pad", b"=Yg==", True,
                      "Leading padding not allowed");
    _expect_b64_error("excess pad", b"Yg===", True,
                      "Excess padding not allowed");
    _expect_b64_error("excess pad long", b"Yg====", True,
                      "Excess padding not allowed");
    _expect_b64_error("non-alpha", b"Yg!*", True,
                      "Only base64 data is allowed");
    _expect_b64_error("excess data after pad", b"Yg==YQ", True,
                      "Excess data after padding");
    # 'Y=g=': the '=' at quad_pos 1 breaks the loop; final validation
    # reports the len-1 message with 0 emitted bytes -> count 1.
    _expect_b64_error("discontinuous pad", b"Y=g=", True,
                      "Invalid base64-encoded string: number of data characters"
                      " (1) cannot be 1 more than a multiple of 4");
}


test "wave16 base64 decode length errors match host" {
    _expect_b64_error("one char", b"Y", False,
                      "Invalid base64-encoded string: number of data characters"
                      " (1) cannot be 1 more than a multiple of 4");
    _expect_b64_error("two chars", b"Yg", False, "Incorrect padding");
    _expect_b64_error("ignored junk two chars", b"Yg*", False,
                      "Incorrect padding");
}


test "wave16 uuencode matches host" {
    assert b2a_uu(b"hello world")
        == _b(43, 58, 38, 53, 76, 59, 38, 92, 64, 61, 86, 93, 82, 59, 38, 48, 32, 10);
    assert b2a_uu(b"") == _b(32, 10);
    assert b2a_uu(b"", True) == _b(96, 10);
    assert a2b_uu(b"+:&5L;&\\@=V]R;&0 \n") == b"hello world";
    # Empty length byte ('\n' = 10) declares (10-32)&077 = 42 zero bytes.
    assert len(a2b_uu(b"\n")) == 42;
    assert a2b_uu(b"%\n") == _b(0, 0, 0, 0, 0);
}


test "wave16 uuencode errors match host" {
    raised = False;
    got = "";
    try {
        a2b_uu(_b());
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised and got == "Missing length byte" , got;

    raised = False;
    try {
        b2a_uu("x" * 46);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised and got == "At most 45 bytes at once" , got;

    raised = False;
    try {
        a2b_uu(b"\x01abc");
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised and got == "Illegal char" , got;

    raised = False;
    try {
        a2b_uu(b"#abc!\n");
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    # 'a' (97) exceeds ' ' + 64.
    assert raised and got == "Illegal char" , got;

    raised = False;
    try {
        a2b_uu(b"&9FIO\n\`\n");
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert not raised , got;

    raised = False;
    try {
        a2b_uu(b"&9FIO\nx");
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    # 'x' (120) exceeds ' ' + 64 inside the data run.
    assert raised and got == "Illegal char" , got;

    raised = False;
    try {
        a2b_uu(b"! \`\n\n\nz");
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised and got == "Trailing garbage" , got;
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


def _expect_qp_decode(label: str, arg: any, header: bool, want: bytes) {
    got = a2b_qp(arg, header);
    assert got == want , (label, got, want);
}


test "wave16 quoted-printable decode matches host" {
    _expect_qp_decode("hex pairs", b"a=3Db=20c\nd=ZZ", False, b"a=b c\nd=ZZ");
    _expect_qp_decode("soft lf", b"a=\nb", False, b"ab");
    _expect_qp_decode("soft crlf", b"a=\r\nb", False, b"ab");
    _expect_qp_decode("double eq", b"a==b", False, b"a=b");
    _expect_qp_decode("trailing eq", b"ab=", False, b"ab");
    _expect_qp_decode("lowercase hex", b"=ff", False, _b(0xFF));
    _expect_qp_decode("header underscore", b"a_b", True, b"a b");
}


test "wave16 quoted-printable encode matches host" {
    assert b2a_qp(b"hello world\r\n") == b"hello world\r\n";
    assert b2a_qp(b"a\tb c\t") == b"a\tb c=09";
    assert b2a_qp(b"a\tb c\t", True) == b"a=09b=20c=09";
    assert b2a_qp(b"a=b") == b"a=3Db";
    assert b2a_qp(_b(0xE9)) == b"=E9";
    assert b2a_qp(b"a b", False, True, True) == b"a_b";
    assert b2a_qp(b"ab \n") == b"ab=20\n";
    assert b2a_qp(b"ab \n", False, False) == b"ab =0A";
    assert len(b2a_qp("x" * 100)) == 102;
}


test "wave16 crc functions match host" {
    # Host pins: crc_hqx(b'123456789', 0) == 12739, etc.
    assert crc_hqx(b"123456789", 0) == 12739;
    assert crc_hqx(b"", 0x11223344) == 13124;  # crc masked to 16 bits
    assert crc32(b"123456789") == 3421780262;
    assert crc32(b"", -1) == 4294967295;  # bitwise converter masks negatives
    assert crc32(b"123456789", 255) == 2193306989;
    # Incremental chaining identity.
    a = crc32(b"hello ");
    assert crc32(b"world", a) == crc32(b"hello world");
    h = crc_hqx(b"ab", 0);
    assert crc_hqx(b"cd", h) == crc_hqx(b"abcd", 0);
}
