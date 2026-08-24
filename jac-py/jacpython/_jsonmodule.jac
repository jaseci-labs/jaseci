# --------------------------- Lib/json glue ---------------------------------
# dumps()/loads() semantics from Lib/json/__init__.py over make_encoder /
# make_scanner: default separators (', ', ': '; trailing ',' with indent),
# indent int -> spaces, check_circular markers, allow_nan, skipkeys,
# sort_keys, default= fallback and the parse_*/object*_hook decoder knobs.
# Decode failures raise ValueError with the byte-exact JSONDecodeError
# rendering; JSONDecodeError subclasses ValueError in Lib/json.

def _parse_const_default(name: str) -> any {
    if name == "NaN" {
        return float("nan");
    }
    if name == "-Infinity" {
        return float("-inf");
    }
    return float("inf");
}

# JSONEncoder.default when no default= was supplied.
def _default_not_serializable(v: any) -> any {
    raise TypeError("Object of type " + _type_name(v)
                    + " is not JSON serializable");
}

obj _DecoderCtx {
    has strict: bool = True,
        object_hook: any = None,
        object_pairs_hook: any = None,
        parse_float: any = None,
        parse_int: any = None,
        parse_constant: any = None;
}

def loads(sval: any, object_hook: any = None, parse_float: any = None,
          parse_int: any = None, parse_constant: any = None,
          object_pairs_hook: any = None) -> any {
    text: str;
    if isinstance(sval, str) {
        text = sval as str;
    } elif isinstance(sval, bytes) or isinstance(sval, bytearray) {
        # Lib/json detect_encoding() resolves utf-8/16/32 from a BOM or the
        # first four bytes; plain utf-8 covers every non-BOM input and BOMed
        # input is rejected by CPython too ("Unexpected UTF-8 BOM"). Decode
        # explicitly so the error surfaces identically for bad bytes.
        text = bytes(sval).decode("utf-8");
    } else {
        raise TypeError("the JSON object must be str, bytes or bytearray, not "
                        + _type_name(sval));
    }

    ctx = _DecoderCtx();
    ctx.object_hook = object_hook;
    ctx.object_pairs_hook = object_pairs_hook;
    ctx.parse_float = float if parse_float is None else parse_float;
    ctx.parse_int = int if parse_int is None else parse_int;
    ctx.parse_constant = (_parse_const_default if parse_constant is None
                          else parse_constant);

    idx = 0;
    length = len(text);
    while idx < length and _is_ws_char(ord(text[idx])) {
        idx = idx + 1;
    }
    scanner = make_scanner(ctx);
    try {
        (rval, end_idx) = scanner(text, idx);
    } except StopIteration as e {
        raise ValueError(_decode_error_msg("Expecting value", text,
                                           e.value as int));
    }
    while end_idx < length and _is_ws_char(ord(text[end_idx])) {
        end_idx = end_idx + 1;
    }
    if end_idx != length {
        raise ValueError(_decode_error_msg("Extra data", text, end_idx));
    }
    return rval;
}

import from exceptions_core { register_module_exception }


def dumps(obj_val: any, skipkeys: bool = False, ensure_ascii: bool = True,
          check_circular: bool = True, allow_nan: bool = True,
          indent: any = None, separators: any = None, `default: any = None,
          sort_keys: bool = False) -> str {
    ind = indent;
    if ind is not None and not isinstance(ind, str) {
        ind = " " * (ind as int);
    }
    item_sep = ", ";
    key_sep = ": ";
    if separators is not None {
        item_sep = separators[0];
        key_sep = separators[1];
    } elif ind is not None {
        item_sep = ",";
    }
    enc_str = encode_basestring_ascii if ensure_ascii else encode_basestring;
    dflt = (_default_not_serializable if `default is None
            else `default);
    markers: any = {} if check_circular else None;
    enc = make_encoder(markers, dflt, enc_str, ind, key_sep, item_sep,
                       sort_keys, skipkeys, allow_nan);
    return enc(obj_val, None)[0];
}

with entry {
    # Module-exception declaration (bridge-table registry, exceptions_core):
    # JSONDecodeError subclasses ValueError per CPython exception hierarchy.
    register_module_exception("json.JSONDecodeError", "ValueError");
}
