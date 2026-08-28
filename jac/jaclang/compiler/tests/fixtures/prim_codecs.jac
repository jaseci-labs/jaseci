"""Bundled native ``codecs`` cross-backend equivalence fixture.

The SAME ``import from codecs { decode, getincrementaldecoder, lookup }``
binds CPython's ``codecs`` on the sv (Python) backend and the bundled
``na_stdlib/codecs.jac`` Mechanism-B module on the na (native LLVM) backend.

Pinned surface: one-shot ``decode``, ``lookup`` (UTF-8 only on na), and
``getincrementaldecoder`` returning the ``IncrementalDecoder`` class
(instantiate then ``decode`` on sv; na helpers construct ``IncrementalDecoder``
directly because calling the factory return value does not lower yet).
Non-ASCII decode results are compared as scalar code points because the
ctypes harness decodes returned native strings as UTF-8 bytes. Invalid-byte ``replace`` is pinned via one-shot ``decode`` on sv; na
incremental ``IncrementalDecoder(errors=...)`` constructor kwargs do not lower
reliably yet, so na pins the same invalid byte under ``strict`` via
``strict_err`` instead. DIVERGENCES: na ``lookup``
answers bool ``True``/``False`` (CPython returns a truthy ``CodecInfo``), so
``lookup_latin1`` uses ``lookup(...) is True`` to pin na's ``False`` without
treating CPython's ``CodecInfo`` as boolean ``True``; na ``decode`` takes an
extra ``final`` keyword on incremental decoders; UTF-8 only on na. ES/JS opts out.
"""

import from codecs { decode, getincrementaldecoder, lookup, IncrementalDecoder }


def codecs_py() -> dict {
    dec_cls = getincrementaldecoder("utf-8");
    dec = dec_cls(errors="replace");
    inc1: str = dec.decode(b"\xc3");
    inc2: str = dec.decode(b"\xa9");
    inc3: str = dec.decode(b"", True);
    strict_err: int = 0;
    try {
        decode(b"\xff", "utf-8", "strict");
    } except ValueError {
        strict_err = 1;
    }
    dec2 = dec_cls();
    gid_ok: int = 1 if dec2.decode(b"hello") == "hello" else 0;
    return {
        "dec_hello": decode(b"hello"),
        "dec_eacute_cp": ord(decode(b"\xc3\xa9")),
        "oneshot_replace": 1 if len(decode(b"\xff", "utf-8", "replace")) == 1 else 0,
        "strict_err": strict_err,
        "inc1": inc1,
        "inc2_cp": ord(inc2),
        "inc3": inc3,
        "lookup_utf8": 1 if lookup("utf-8") else 0,
        "lookup_latin1": 1 if lookup("latin-1") is True else 0,
        "gid_ok": gid_ok
    };
}


def codecs_cl() -> dict {
    return {};
}


def _oneshot_na(r: dict[str, any]) {
    r["dec_hello"] = decode(b"hello", "utf-8");
    r["dec_eacute_cp"] = ord(decode(b"\xc3\xa9", "utf-8"));
}


def _incremental_na(r: dict[str, any]) {
    dec: IncrementalDecoder = IncrementalDecoder(errors="strict");
    r["inc1"] = dec.decode(b"\xc3");
    inc2: str = dec.decode(b"\xa9");
    r["inc2_cp"] = ord(inc2);
    r["inc3"] = dec.decode(b"", final=True);
}


def _strict_na(r: dict[str, any]) {
    strict_err: int = 0;
    try {
        IncrementalDecoder(errors="strict").decode(b"\xff", final=True);
    } except ValueError {
        strict_err = 1;
    }
    r["strict_err"] = strict_err;
}


def _lookup_na(r: dict[str, any]) {
    r["lookup_utf8"] = 1 if lookup("utf-8") else 0;
    r["lookup_latin1"] = 1 if lookup("latin-1") is True else 0;
}


def _factory_na(r: dict[str, any]) {
    dec2: IncrementalDecoder = IncrementalDecoder(errors="strict");
    r["gid_ok"] = 1 if dec2.decode(b"hello") == "hello" else 0;
}


def codecs_na() -> dict[str, any] {
    r: dict[str, any] = {};
    _oneshot_na(r);
    _incremental_na(r);
    _strict_na(r);
    _lookup_na(r);
    _factory_na(r);
    return r;
}
