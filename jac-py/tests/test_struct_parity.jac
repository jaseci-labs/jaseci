"""P2 wave 13 facade parity: native _struct pack/unpack/calcsize vs host stdlib.

jac-py/Modules/structmodule.{c,jac} stay the staged c2jac corpus pair
(staging=lift); this file gates the product-path facade semantics in
jac-py/jacpython/_structmodule.jac against the pinned host oracle.
Expected values were verified against the host stdlib ``struct`` (the
pinned CPython on this LP64 little-endian host) at authoring time.
"""

import from _structmodule {
    calcsize,
    compile,
    iter_unpack,
    pack,
    pack_into,
    unpack,
    unpack_from,
}


def _expect_pack_error(label: str, f: str, v: any, want_msg: str) {
    raised = False;
    got = "";
    try {
        pack(f, v);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised , label + ": expected an error";
    assert got == want_msg , (label, got, want_msg);
}


def _expect_compile_error(label: str, f: any, want_msg: str) {
    raised = False;
    got = "";
    try {
        compile(f);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised , label + ": expected an error";
    assert got == want_msg , (label, got, want_msg);
}


def _expect_iter_error(label: str, f: any, buf: any, want_msg: str) {
    raised = False;
    got = "";
    try {
        iter_unpack(f, buf);
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised , label + ": expected an error";
    assert got == want_msg , (label, got, want_msg);
}


def _collect(it: any) -> list {
    out: list = [];
    while True {
        try {
            out.append(it.__next__());
        } except StopIteration {
            return out;
        }
    }
}


test "wave13 calcsize covers std and native tables" {
    # Standard sizes (<, >, =, !): no alignment.
    for f in ["<b", "<B", "<c", "<?", "<s", "<p", "<x"] {
        assert calcsize(f) == 1 , f;
    }
    for f in ["<h", "<H", "<e", ">h", "=h", "!e"] {
        assert calcsize(f) == 2 , f;
    }
    for f in ["<i", "<I", "<l", "<L", "<f", ">i", "=l"] {
        assert calcsize(f) == 4 , f;
    }
    for f in ["<q", "<Q", "<d", ">d", "=q"] {
        assert calcsize(f) == 8 , f;
    }
    # Native (@): LP64 host -- long/size_t/pointer are 8 bytes, aligned.
    assert calcsize("@b") == 1 and calcsize("@h") == 2 , "native scalars";
    assert calcsize("@i") == 4 and calcsize("@l") == 8 , "native i/l";
    assert calcsize("@q") == 8 and calcsize("@n") == 8 , "native q/n";
    assert calcsize("@N") == 8 and calcsize("@P") == 8 , "native N/P";
    assert calcsize("@?") == 1 and calcsize("@f") == 4 and calcsize("@d") == 8;
    # n/N/P are native-only; standard tables reject them.
    for f in ["<n", "<N", ">P", "=N"] {
        _expect_compile_error("native-only " + f, f,
                              "bad char in struct format");
    }
    # Alignment: @ pads to natural boundaries, standard modes do not.
    assert calcsize("@h i") == 8 , "h then aligned i";
    assert calcsize("@i h") == 6 , "aligned i then trailing h";
    assert calcsize("@b d") == 16 , "byte then aligned double";
    assert calcsize("<h i") == 6 , "std mode never aligns";
    assert calcsize(">bi") == 5 , "big-endian packed";
    # Repeat counts, pad bytes, whitespace, empty format.
    assert calcsize("<3i2xh") == 16 and calcsize(">5s") == 5 , "repeats";
    assert calcsize("< i h") == 6 , "interior whitespace ignored";
    assert calcsize("") == 0 and calcsize("   ") == 0 , "empty formats";
}


test "wave13 integer round trips all widths" {
    cases: list = [
        ("<b", [-128, -1, 0, 1, 127]),
        ("<B", [0, 1, 255]),
        ("<h", [-32768, -1, 0, 32767]),
        ("<H", [0, 65535]),
        ("<i", [-2147483648, -1, 0, 2147483647]),
        ("<I", [0, 4294967295]),
        ("<q", [-9223372036854775808, -1, 0, 9223372036854775807]),
        ("<Q", [0, 18446744073709551615]),
        (">b", [-128, 127]),
        (">H", [4660, 65535]),
        ("=i", [-123456789, 123456789]),
        ("!q", [-250010590250959011]),
    ];
    for (f, vals) in cases {
        width = calcsize(f);
        for v in vals {
            data = pack(f, v);
            assert len(data) == width , (f, v);
            assert unpack(f, data) == (v,) , (f, v, data);
        }
    }
    # Native long is 8 bytes here; its range matches q/Q exactly.
    assert unpack("@l", pack("@l", -1)) == (-1,) , "native long -1";
    assert unpack("@L", pack("@L", 18446744073709551615)) == (
        18446744073709551615,) , "native ulong max";
    # Repeat counts fan one value per code slot.
    assert unpack("<2i", pack("<2i", 258, -258)) == (258, -258) , "repeat";
    assert unpack("@2l", pack("@2l", -1, -2)) == (-1, -2) , "native repeat";
    # bool packs by truthiness, unpacks to bool.
    assert pack("<??", [], 7) == b"\x00\x01" , "bool truthiness";
    assert unpack("3?", b"\x01\x00\xff") == (True, False, True), "bool unpack";
    # __index__-less / non-int arguments are rejected with the exact message.
    _expect_pack_error("float into i", "<i", 1.5,
                       "required argument is not an integer");
}


test "wave13 range errors match the oracle messages" {
    cases: list = [
        ("<b", 128, "'b' format requires -128 <= number <= 127"),
        ("<b", -129, "'b' format requires -128 <= number <= 127"),
        ("<B", -1, "'B' format requires 0 <= number <= 255"),
        ("<h", 32768, "'h' format requires -32768 <= number <= 32767"),
        ("<H", 65536, "'H' format requires 0 <= number <= 65535"),
        ("<i", 2147483648, "'i' format requires -2147483648 <= number <= 2147483647"),
        ("<I", -1, "'I' format requires 0 <= number <= 4294967295"),
        ("<l", 2147483648, "'l' format requires -2147483648 <= number <= 2147483647"),
        ("<q", 9223372036854775808,
         "'q' format requires -9223372036854775808 <= number <= 9223372036854775807"),
        ("<Q", -1, "'Q' format requires 0 <= number <= 18446744073709551615"),
        ("@l", 9223372036854775808,
         "'l' format requires -9223372036854775808 <= number <= 9223372036854775807"),
        ("@n", 9223372036854775808,
         "'n' format requires -9223372036854775808 <= number <= 9223372036854775807"),
        ("@N", -1,
         "'N' format requires 0 <= number <= 18446744073709551615"),
    ];
    for (f, v, msg) in cases {
        lbl: str = "range " + str(f) + ":" + str(v);
        _expect_pack_error(lbl, f, v, msg);
    }
}


test "wave13 float packing is bit-exact" {
    assert pack("<d", 1.0) == b"\x00\x00\x00\x00\x00\x00\xf0\x3f" , "1.0 LE";
    assert pack(">d", 1.0) == b"\x3f\xf0\x00\x00\x00\x00\x00\x00" , "1.0 BE";
    assert pack("<f", 3.5) == b"\x00\x00\x60\x40" , "3.5f";
    assert pack("<d", float("inf")) == (
        b"\x00\x00\x00\x00\x00\x00\xf0\x7f") , "+inf d";
    assert pack(">d", float("-inf")) == b"\xff\xf0" + bytes(6) , "-inf d BE";
    z = 0.0;
    nz = -z;
    assert pack("<d", nz) == b"\x00\x00\x00\x00\x00\x00\x00\x80" , "-0.0";
    assert pack("<f", nz) == b"\x00\x00\x00\x80" , "-0.0f";
    # Round-to-nearest-even double -> float32 boundary cases (host-checked).
    assert pack("<f", 8388609.0) == b"\x01\x00\x00\x4b" , "odd tie rounds up";
    assert unpack("<f", b"\x00\x00\x80\x3f") == (1.0,) , "read back 1.0f";
    # Half floats: max finite half, subnormal half, exact halves.
    assert pack("<e", 65504.0) == b"\xff\x7b" , "half max";
    assert unpack("<e", b"\x00\x3c") == (1.0,) , "half 1.0";
    assert unpack("<e", b"\x01\x00") == (5.960464477539063e-08,), "half subnorm";
    # int widens to double like PyFloat_AsDouble.
    assert unpack("<d", pack("<d", 3)) == (3.0,) , "int into d";
    # Overflow raises OverflowError with the CPython message.
    _expect_pack_error("f overflow", "<f", 1e300,
                       "float too large to pack with f format");
    _expect_pack_error("e overflow", "<e", 70000.0,
                       "float too large to pack with e format");
    # Non-floatable arguments fail with struct.error text.
    _expect_pack_error("str into d", "<d", "x",
                       "required argument is not a float");
}


test "wave13 s/p/c fill rules" {
    assert pack("5s", b"ab") == b"ab\x00\x00\x00" , "s zero-pads right";
    assert pack("3s", b"abcdef") == b"abc" , "s truncates";
    assert unpack("4s", b"ab\x00\x00") == (b"ab\x00\x00",) , "s raw unpack";
    assert pack("3p", b"abc") == b"\x02ab" , "p count caps at size-1";
    assert pack("5p", b"abcd") == b"\x04abcd" , "p fills size-1";
    assert unpack("3p", b"\xffxy") == (b"xy",) , "p span clamps to size-1";
    assert unpack("5p", b"\x02abc\x00") == (b"ab",) , "p honors count byte";
    assert pack("<p", b"").hex() == "00" , "empty pascal string";
    assert pack("2c", b"a", b"b") == b"ab" , "two chars";
    assert unpack("<2c", b"ab") == (b"a", b"b") , "char round trip";
    assert pack("4s", bytearray(b"abc")) == b"abc\x00" , "bytearray ok for s";
    _expect_pack_error("str into s", "4s", "abc",
                       "argument for 's' must be a bytes object");
    _expect_pack_error("long c", "c", b"ab",
                       "char format requires a bytes object of length 1");
    _expect_pack_error("int c", "c", 65,
                       "char format requires a bytes object of length 1");
}


test "wave13 composite formats, offsets, iteration" {
    fmt = "<h i d 3s ?";
    st = compile(fmt);
    assert st.size == 18 and calcsize(fmt) == 18 , st.size;
    data = pack(fmt, -2, 7, 1.5, b"xy", True);
    assert unpack(fmt, data) == (-2, 7, 1.5, b"xy\x00", True) , "composite";
    assert repr(st) == "Struct('<h i d 3s ?')" , repr(st);
    assert st.fmt == "<h i d 3s ?" , "format preserved verbatim";

    buf = bytearray(10);
    pack_into("<h", buf, 8, 258);
    assert bytes(buf) == bytes(8) + b"\x02\x01" , "pack_into placement";
    assert unpack_from("<h", buf, 8) == (258,) , "unpack_from offset";
    assert unpack_from("<h", b"\xff\xff\x02\x01", -2) == (258,), "negative offset";
    tail = bytearray(b"\xee" * 6);
    pack_into("<i", tail, -4, 5);
    assert bytes(tail) == b"\xee\xee\x05\x00\x00\x00" , "negative offset write";

    records = _collect(iter_unpack("<h", b"\x01\x00\x02\x00\x03\x00"));
    assert records == [(1,), (2,), (3,)] , records;
    assert _collect(iter_unpack("2x", b"\x00\x00")) == [()] , "pad-only record";
    assert _collect(iter_unpack("x", b"")) == [] , "no full record";
    _expect_iter_error("iter empty struct", "", b"",
                       "cannot iteratively unpack with a struct of length 0");
    _expect_iter_error("iter non multiple", "<h", b"\x01",
                       "iterative unpacking requires a buffer of a multiple of 2 bytes");

    # pack/unpack arity and bounds errors carry oracle wording.
    raised = False;
    try {
        unpack("i", b"abc");
    } except Exception as e {
        raised = True;
        assert str(e) == "unpack requires a buffer of 4 bytes" , str(e);
    }
    assert raised , "short unpack buffer must raise";
    raised = False;
    try {
        pack("i");
    } except Exception as e {
        raised = True;
        assert str(e) == "pack expected 1 items for packing (got 0)" , str(e);
    }
    assert raised , "pack arity mismatch must raise";
    raised = False;
    try {
        unpack_from("<h", b"\x01");
    } except Exception as e {
        raised = True;
        assert str(e) == (
            "unpack_from requires a buffer of at least 2 bytes for "
            "unpacking 2 bytes at offset 0 (actual buffer size is 1)") , str(e);
    }
    assert raised , "unpack_from underflow must raise";
    raised = False;
    try {
        unpack_from("<h", b"\x01", -4);
    } except Exception as e {
        raised = True;
        assert str(e) == "offset -4 out of range for 1-byte buffer" , str(e);
    }
    assert raised , "unpack_from bad negative offset must raise";
    raised = False;
    try {
        pack_into("<q", bytearray(4), 0, 1);
    } except Exception as e {
        raised = True;
        assert str(e) == (
            "pack_into requires a buffer of at least 8 bytes for "
            "packing 8 bytes at offset 0 (actual buffer size is 4)") , str(e);
    }
    assert raised , "pack_into overflow must raise";
    raised = False;
    try {
        pack_into("<i", bytearray(4), -10, 1);
    } except Exception as e {
        raised = True;
        assert str(e) == "offset -10 out of range for 4-byte buffer" , str(e);
    }
    assert raised , "pack_into bad negative offset must raise";
}


test "wave13 malformed formats raise oracle messages" {
    _expect_compile_error("repeat without code", "3",
                          "repeat count given without format specifier");
    _expect_compile_error("bad char", "q!", "bad char in struct format");
    _expect_compile_error("trailing digits after ws", "i 3",
                          "repeat count given without format specifier");
    _expect_compile_error("embedded null byte", b"i\x00",
                          "embedded null character");
    raised = False;
    try {
        compile(42);
    } except Exception as e {
        raised = True;
        assert "Struct() argument 1 must be a str or bytes object" in str(e), (
            str(e));
    }
    assert raised , "non-format input must raise TypeError";
    # Zero repeats drop items entirely but still parse.
    assert calcsize("<0i") == 0 and pack("<0i") == b"" , "zero repeat";
    assert unpack("<0i", b"") == () , "zero repeat unpack";
}
