# Stdlib delegation registry pins (jac-py/jacpython/ceval.jac delegate_modules).
#
# Guest snippets run inside jacpython's ceval (layer_p2_libtest harness) and
# resolve `import re` / `from datetime import ...` through the delegation
# registry: no native facade exists for these modules, so the registry imports
# the HOST module once and snapshots its dir() surface into a native PyModule
# -- scalars natively, callables/classes as transparent host proxies.
#
# Every expected value is captured byte-exact from the host CPython 3.14
# oracle (probes generated against python3 3.14.7), including error texts:
# re.error / zlib.error / binascii.Error messages cross the boundary verbatim
# and guest except-handlers match them by the delegated class proxies.

import from layer_p2_libtest { p2_libtest_expect_ok }

test "stdlib_delegate: re_named_group_backref matches python3 oracle" {
    snippet = (
        "import re\n"
        "out = []\n"
        "m = re.match(r'(?P<w>\\w+)=(?P<v>\\d+)\\1', 'ab=12ab')\n"
        "out.append(m.group('w')); out.append(m.group('v'))\n"
        "out.append(str(m.group(0))); out.append(str(m.groups()))\n"
        "out.append(str(m.span())); out.append(str(m.start()) + ',' + str(m.end()))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="ab|12|ab=12ab|('ab', '12')|(0, 7)|0,7");
    assert ok , detail;
}

test "stdlib_delegate: re_compile_object_flags matches python3 oracle" {
    snippet = (
        "import re\n"
        "out = []\n"
        "c = re.compile(r'a+', re.IGNORECASE)\n"
        "out.append(c.pattern); out.append(str(c.flags == re.I))\n"
        "out.append(c.match('AAA').group(0).lower())\n"
        "d = re.compile(r'x', re.I | re.M)\n"
        "out.append(str(d.flags & (re.I | re.M) == re.I | re.M))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="a+|False|aaa|True");
    assert ok , detail;
}

test "stdlib_delegate: re_search_findall_split matches python3 oracle" {
    snippet = (
        "import re\n"
        "out = []\n"
        "out.append(re.search(r'b+', 'abbba').span().__str__())\n"
        "out.append(str(re.findall(r'\\d+', 'a1b22c333')))\n"
        "out.append(str(re.split(r'[,\\s]+', 'a, b,  c,d')))\n"
        "out.append(str(re.findall(r'(\\w)(\\d)', 'x1 y2')))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="(1, 4)|['1', '22', '333']|['a', 'b', 'c', 'd']|[('x', '1'), ('y', '2')]");
    assert ok , detail;
}

test "stdlib_delegate: re_sub_backrefs matches python3 oracle" {
    snippet = (
        "import re\n"
        "out = []\n"
        "out.append(re.sub(r'(\\d+)-(\\d+)', r'\\2-\\1', '12-34 5-6'))\n"
        "out.append(re.sub(r'(?P<a>x+)y', r'\\g<a>z', 'xxy xyy'))\n"
        "out.append(re.subn(r'o', '0', 'foo boo')[0].__str__())\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="34-12 6-5|xxz xzy|f00 b00");
    assert ok , detail;
}

test "stdlib_delegate: re_fullmatch_multiline_dotall matches python3 oracle" {
    snippet = (
        "import re\n"
        "out = []\n"
        "out.append(str(re.fullmatch(r'ab+', 'abbb') is not None))\n"
        "out.append(str(re.findall(r'^\\w+', 'one two\\nthree', re.M)))\n"
        "out.append(re.findall(r'a.b', 'a\\nb', re.S).__str__())\n"
        "out.append(str(re.match(r'a', 'a').lastindex if re.match(r'(a)', 'a') else None))\n"
        "out.append(str(bool(re.match(r'(a)(b)?', 'a').group(2) is None)))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="True|['one', 'three']|['a\\nb']|None|True");
    assert ok , detail;
}

test "stdlib_delegate: re_word_boundary_classes matches python3 oracle" {
    snippet = (
        "import re\n"
        "out = []\n"
        "out.append(str(re.findall(r'\\bcat\\b', 'cat catalog cat')))\n"
        "out.append(str(re.match(r'[a-f\\d]+$', 'deadbeef') is not None))\n"
        "out.append(str(re.sub(r'\\s', '_', 'a b\\tc') == 'a_b_c'))\n"
        "out.append(str(bool(re.fullmatch(r'(?:ab)+', 'ababab'))))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="['cat', 'cat']|True|True|True");
    assert ok , detail;
}

test "stdlib_delegate: re_error_text matches python3 oracle" {
    snippet = (
        "import re\n"
        "try:\n"
        "    re.compile('*bad')\n"
        "    print('no error')\n"
        "except re.error as e:\n"
        "    print(str(e))\n"
        "except Exception as e:\n"
        "    print('wrong:' + type(e).__name__)\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="nothing to repeat at position 0");
    assert ok , detail;
}

test "stdlib_delegate: datetime_date_arithmetic_isoformat matches python3 oracle" {
    snippet = (
        "from datetime import date, timedelta\n"
        "out = []\n"
        "d = date(2024, 1, 1) + timedelta(days=45)\n"
        "out.append(d.isoformat())\n"
        "out.append(d.strftime('%d/%m/%Y'))\n"
        "out.append(str(d.weekday()))\n"
        "e = d - timedelta(weeks=7)\n"
        "out.append(e.isoformat())\n"
        "out.append(str((d - e).days))\n"
        "out.append(d.replace(year=2025).isoformat())\n"
        "out.append(str(date(2024, 2, 15) < date(2024, 3, 1)))\n"
        "out.append(str(date.fromisoformat('2024-02-15') == d))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="2024-02-15|15/02/2024|3|2023-12-28|49|2025-02-15|True|True");
    assert ok , detail;
}

test "stdlib_delegate: datetime_datetime_timedelta matches python3 oracle" {
    snippet = (
        "from datetime import datetime, timedelta\n"
        "out = []\n"
        "dt = datetime(2024, 2, 29, 12, 30, 45)\n"
        "out.append(dt.isoformat())\n"
        "u = dt + timedelta(hours=13, minutes=31)\n"
        "out.append(u.isoformat(sep=' '))\n"
        "out.append(u.strftime('%Y%m%dT%H%M%S'))\n"
        "td = u - dt\n"
        "out.append(str(td.total_seconds()))\n"
        "out.append(str(td))\n"
        "out.append(str(dt.year) + ',' + str(dt.month) + ',' + str(dt.second))\n"
        "out.append(str(datetime(2024, 2, 29, 12, 30, 46) > dt))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="2024-02-29T12:30:45|2024-03-01 02:01:45|20240301T020145|48660.0|13:31:00|2024,2,45|True");
    assert ok , detail;
}

test "stdlib_delegate: hashlib_digests_update_pbkdf2 matches python3 oracle" {
    snippet = (
        "import hashlib\n"
        "out = []\n"
        "h = hashlib.sha256()\n"
        "h.update(b'a'); h.update(b'bc')\n"
        "out.append(h.hexdigest())\n"
        "out.append(hashlib.md5(b'abc').hexdigest())\n"
        "out.append(hashlib.sha1(b'abc').hexdigest()[:20])\n"
        "out.append(hashlib.sha256(b'abc').digest().hex()[:16])\n"
        "out.append(hashlib.pbkdf2_hmac('sha256', b'pw', b'salt', 2, dklen=8).hex())\n"
        "out.append(hashlib.sha224(b'abc').hexdigest()[:16])\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad|900150983cd24fb0d6963f7d28e17f72|a9993e364706816aba3e|ba7816bf8f01cfea|061df616343cb988|23097d223405d822");
    assert ok , detail;
}

test "stdlib_delegate: base64_variants_roundtrip matches python3 oracle" {
    snippet = (
        "import base64\n"
        "out = []\n"
        "out.append(base64.b64encode(b'hello world').decode())\n"
        "out.append(base64.b64decode('aGVsbG8gd29ybGQ=').decode())\n"
        "out.append(base64.urlsafe_b64encode(b'i\\xfb~?o?').decode())\n"
        "out.append(base64.b32encode(b'secret').decode())\n"
        "out.append(base64.b16encode(b'BW').decode())\n"
        "out.append(base64.b64encode(b'any carnal pleasure.').decode())\n"
        "out.append(base64.decodebytes(b'aGVsbG8=').decode())\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="aGVsbG8gd29ybGQ=|hello world|aft-P28_|ONSWG4TFOQ======|4257|YW55IGNhcm5hbCBwbGVhc3VyZS4=|hello");
    assert ok , detail;
}

test "stdlib_delegate: binascii_hexlify_base64_error matches python3 oracle" {
    snippet = (
        "import binascii, base64\n"
        "out = []\n"
        "out.append(binascii.hexlify(b'ABcd').decode())\n"
        "out.append(binascii.unhexlify('6869').decode())\n"
        "out.append(binascii.a2b_base64(b'SGVsbG8=').decode())\n"
        "out.append(binascii.crc_hqx(b'123456789', 0).__str__())\n"
        "try:\n"
        "    base64.b64decode('!!!not-base64!!!', validate=True)\n"
        "    out.append('no error')\n"
        "except binascii.Error as e:\n"
        "    out.append(str(e))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="41426364|hi|Hello|12739|Only base64 data is allowed");
    assert ok , detail;
}

test "stdlib_delegate: zlib_roundtrip_crc_adler matches python3 oracle" {
    snippet = (
        "import zlib\n"
        "out = []\n"
        "blob = b'the quick brown fox jumps over the lazy dog' * 10\n"
        "packed = zlib.compress(blob, 6)\n"
        "out.append(str(zlib.decompress(packed) == blob))\n"
        "out.append(str(zlib.crc32(blob)))\n"
        "out.append(str(zlib.adler32(blob)))\n"
        "co = zlib.compressobj(9)\n"
        "part = co.compress(blob[:20]) + co.flush()\n"
        "out.append(str(zlib.decompress(part) == blob[:20]))\n"
        "do = zlib.decompressobj()\n"
        "out.append(str(do.decompress(zlib.compress(blob)) == blob))\n"
        "out.append(str(do.unused_data == b''))\n"
        "out.append(str(len(packed) < len(blob)))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="True|608211498|2394136507|True|True|True|True");
    assert ok , detail;
}

test "stdlib_delegate: zlib_error_text matches python3 oracle" {
    snippet = (
        "import zlib\n"
        "try:\n"
        "    zlib.decompress(b'not really zlib data here')\n"
        "    print('no error')\n"
        "except zlib.error as e:\n"
        "    print(str(e))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="Error -3 while decompressing data: incorrect header check");
    assert ok , detail;
}

test "stdlib_delegate: binascii_error_except_lane matches python3 oracle" {
    # binascii.Error subclasses ValueError on the host; until the typed
    # boundary table's module-exception registry lands (exceptions_core
    # qualified parent links), the bare name "Error" cannot match a guest
    # `except ValueError` lane -- the class-proxy lane below is the supported
    # path today. str(e) is still byte-exact across the boundary.
    snippet = (
        "import binascii\n"
        "out = []\n"
        "try:\n"
        "    binascii.unhexlify('zz')\n"
        "    out.append('no error')\n"
        "except binascii.Error as e:\n"
        "    out.append(str(e))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="Non-hexadecimal digit found");
    assert ok , detail;
}

test "stdlib_delegate: uuid_deterministic_api matches python3 oracle" {
    snippet = (
        "import uuid\n"
        "out = []\n"
        "u = uuid.uuid5(uuid.NAMESPACE_DNS, 'example.com')\n"
        "out.append(str(u))\n"
        "v = uuid.uuid3(uuid.NAMESPACE_DNS, 'example.com')\n"
        "out.append(str(v))\n"
        "n = uuid.UUID('12345678123456781234567812345678')\n"
        "out.append(n.hex)\n"
        "out.append(str(n.fields[0]))\n"
        "out.append(str(int(u) == int(u.hex, 16)))\n"
        "out.append(str(uuid.UUID(int=0).int))\n"
        "out.append(str(u.version) + ',' + str(v.version))\n"
        "out.append(str(uuid.uuid5(uuid.NAMESPACE_URL, 'http://x') == uuid.uuid5(uuid.NAMESPACE_URL, 'http://x')))\n"
        "print('|'.join(out))\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet, expect_stdout="cfbff0d1-9375-5685-968c-48ce8b15ae17|9073926b-929f-31c2-abc9-fad77ae3e8eb|12345678123456781234567812345678|305419896|True|0|5,3|True");
    assert ok , detail;
}
