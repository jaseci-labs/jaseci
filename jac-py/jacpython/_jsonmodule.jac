# Product-path facade for _json (wave 15): the C accelerator's surface —
# scanstring, encode_basestring(_ascii), make_scanner (JSONDecoder
# raw_decode paths) and make_encoder (JSONEncoder iterencode one-shot
# semantics).
# Staged ``jac-py/Modules/jsonmodule.{c,jac}`` remain the wave-15 c2jac
# corpus oracle pair (staging=lift); this module carries the runtime truth.
# Semantics mirror CPython 3.14 ``Modules/_json.c`` on the pinned host,
# verified against the host stdlib ``_json``/``json``.
#
# Error mapping: scanner failures raise ``ValueError`` carrying the exact
# JSONDecodeError rendering ``"<msg>: line L column C (char P)"``
# (JSONDecodeError subclasses ValueError in Lib/json, so guest code catches
# decode failures with ``except ValueError``). No-value scans raise
# ``StopIteration(idx)`` exactly like the C scanner so loads() glue can
# produce "Expecting value" at the right position.

glob _HEX: str = "0123456789abcdef";

def _type_name(v: any) -> str {
    return type(v).__name__;
}

def _hex_value(digit: int) -> int {
    if digit >= 48 and digit <= 57 {
        return digit - 48;
    }
    if digit >= 97 and digit <= 102 {
        return digit - 87;
    }
    if digit >= 65 and digit <= 70 {
        return digit - 55;
    }
    return -1;
}

# IS_WHITESPACE(c)
def _is_ws_char(c: int) -> bool {
    return c == 32 or c == 9 or c == 10 or c == 13;
}

# S_CHAR(c): characters emitted verbatim by the ASCII encoder.
def _s_char(c: int) -> bool {
    return c >= 32 and c <= 126 and c != 92 and c != 34;
}

# JSONDecodeError.__init__ rendering of (msg, doc, pos): byte-exact.
def _decode_error_msg(msg: str, doc: str, pos: int) -> str {
    lineno = doc.count("\n", 0, pos) + 1;
    colno = pos - doc.rfind("\n", 0, pos);
    return msg + ": line " + str(lineno) + " column " + str(colno)
        + " (char " + str(pos) + ")";
}

def _decode_error(msg: str, doc: str, pos: int) {
    raise ValueError(_decode_error_msg(msg, doc, pos));
}

# --------------------------- string escaping -------------------------------

def _escape_short(c: int) -> any {
    if c == 92 {
        return "\\\\";
    }
    if c == 34 {
        return "\\\"";
    }
    if c == 8 {
        return "\\b";
    }
    if c == 12 {
        return "\\f";
    }
    if c == 10 {
        return "\\n";
    }
    if c == 13 {
        return "\\r";
    }
    if c == 9 {
        return "\\t";
    }
    return None;
}

def _hex4(v: int) -> str {
    return "" + _HEX[(v >> 12) & 0xF] + _HEX[(v >> 8) & 0xF]
        + _HEX[(v >> 4) & 0xF] + _HEX[v & 0xF];
}

# ascii_escape_unichar(): one escaped unit for encode_basestring_ascii.
def _ascii_escape_unichar(c: int) -> str {
    short = _escape_short(c);
    if short is not None {
        return short as str;
    }
    if c >= 0x10000 {
        # UTF-16 surrogate pair
        hi = 0xD800 + ((c - 0x10000) >> 10);
        lo = 0xDC00 + ((c - 0x10000) & 0x3FF);
        return "\\u" + _hex4(hi) + "\\u" + _hex4(lo);
    }
    return "\\u" + _hex4(c);
}

# escape_unicode(): non-ASCII passes through (encode_basestring).
def _plain_escape_unichar(c: int) -> str {
    short = _escape_short(c);
    if short is not None {
        return short as str;
    }
    if c <= 0x1F {
        return "\\u00" + _HEX[(c >> 4) & 0xF] + _HEX[c & 0xF];
    }
    return chr(c);
}

def _check_string_arg(pystr: any) {
    if not isinstance(pystr, str) {
        raise TypeError("first argument must be a string, not "
                        + _type_name(pystr));
    }
}

def encode_basestring_ascii(pystr: any) -> str {
    # Return an ASCII-only JSON representation of a Python string
    _check_string_arg(pystr);
    pieces: list = ["\""];
    for ch in pystr {
        c = ord(ch);
        if _s_char(c) {
            pieces.append(ch);
        } else {
            pieces.append(_ascii_escape_unichar(c));
        }
    }
    pieces.append("\"");
    return "".join(pieces);
}

def encode_basestring(pystr: any) -> str {
    # Return a JSON representation of a Python string (non-ASCII literal)
    _check_string_arg(pystr);
    pieces: list = ["\""];
    for ch in pystr {
        c = ord(ch);
        if _s_char(c) {
            pieces.append(ch);
        } else {
            pieces.append(_plain_escape_unichar(c));
        }
    }
    pieces.append("\"");
    return "".join(pieces);
}

# ------------------------------ scanstring ---------------------------------

def _scanstring_unicode(s: str, end: int, strict: bool) -> tuple[any, int] {
    # Port of scanstring_unicode(); returns (decoded, next_end).
    begin = end - 1;
    length = len(s);
    writer: list = [];
    if end < 0 or length < end {
        raise ValueError("end is out of bounds");
    }
    while True {
        # Find the end of the string or the next escape
        next_i = end;
        d = 0;
        while next_i < length {
            d = ord(s[next_i]);
            if d == 34 or d == 92 {
                break;
            }
            if d <= 0x1F and strict {
                _decode_error("Invalid control character at", s, next_i);
            }
            next_i = next_i + 1;
        }
        c = d;

        if c != 34 and c != 92 {
            _decode_error("Unterminated string starting at", s, begin);
        }

        # Pick up this chunk if it's not zero length
        if next_i != end {
            writer.append(s[end:next_i]);
        }
        next_i = next_i + 1;
        if c == 34 {
            return ("".join(writer), next_i);
        }
        if next_i == length {
            _decode_error("Unterminated string starting at", s, begin);
        }
        c = ord(s[next_i]);
        if c != 117 {
            # Non-unicode backslash escapes
            end = next_i + 1;
            if c == 98 {
                c = 8;
            } elif c == 102 {
                c = 12;
            } elif c == 110 {
                c = 10;
            } elif c == 114 {
                c = 13;
            } elif c == 116 {
                c = 9;
            } else {
                if c != 34 and c != 92 and c != 47 {
                    c = 0;
                }
            }
            if c == 0 {
                _decode_error("Invalid \\escape", s, end - 2);
            }
        } else {
            c = 0;
            next_i = next_i + 1;
            uesc_end = next_i + 4;
            end = uesc_end;
            if uesc_end >= length {
                _decode_error("Invalid \\uXXXX escape", s, next_i - 1);
            }
            # Decode 4 hex digits
            while next_i < uesc_end {
                digit = ord(s[next_i]);
                hv = _hex_value(digit);
                if hv < 0 {
                    _decode_error("Invalid \\uXXXX escape", s, uesc_end - 5);
                }
                c = (c << 4) | hv;
                next_i = next_i + 1;
            }
            # Surrogate pair
            if c >= 0xD800 and c <= 0xDBFF and uesc_end + 6 < length
               and s[next_i] == "\\" and s[next_i + 1] == "u" {
                next_i = next_i + 2;
                uesc_end = uesc_end + 6;
                end = uesc_end;
                c2 = 0;
                while next_i < uesc_end {
                    digit = ord(s[next_i]);
                    hv = _hex_value(digit);
                    if hv < 0 {
                        _decode_error("Invalid \\uXXXX escape", s,
                                      uesc_end - 5);
                    }
                    c2 = (c2 << 4) | hv;
                    next_i = next_i + 1;
                }
                if c2 >= 0xDC00 and c2 <= 0xDFFF {
                    c = 0x10000 + (((c - 0xD800) << 10) | (c2 - 0xDC00));
                } else {
                    uesc_end = uesc_end - 6;
                    end = uesc_end;
                }
            }
        }
        writer.append(chr(c));
    }
}

def scanstring(pystr: any, end: any, strict: bool = True) -> tuple {
    # scanstring(string, end, strict=True) -> (string, end)
    _check_string_arg(pystr);
    (rval, next_end) = _scanstring_unicode(pystr as str, end as int, strict);
    return (rval, next_end);
}

# ------------------------------- scanner -----------------------------------

obj _Scanner {
    has strict: bool = True,
        object_hook: any = None,
        object_pairs_hook: any = None,
        parse_float: any = None,
        parse_int: any = None,
        parse_constant: any = None;

    # scanner_call(string, idx) -> (rval, idx)
    def __call__(pystr: any, idx: any) -> tuple {
        _check_string_arg(pystr);
        memo: dict = {};
        (rval, next_idx) = self.scan_once(memo, pystr as str, idx as int);
        return (rval, next_idx);
    }

    # scan_once_unicode(): returns (value, next_idx); raises
    # StopIteration(start) when no value starts at idx.
    def scan_once(memo: dict, s: str, idx: int) -> tuple[any, int] {
        length = len(s);
        if idx < 0 {
            raise ValueError("idx cannot be negative");
        }
        if idx >= length {
            raise StopIteration(idx);
        }
        c = ord(s[idx]);
        if c == 34 {
            return _scanstring_unicode(s, idx + 1, self.strict);
        }
        if c == 123 {
            return self._parse_object(memo, s, idx + 1);
        }
        if c == 91 {
            return self._parse_array(memo, s, idx + 1);
        }
        if c == 110 and self._match_const(s, idx, "null") {
            return (None, idx + 4);
        }
        if c == 116 and self._match_const(s, idx, "true") {
            return (True, idx + 4);
        }
        if c == 102 and self._match_const(s, idx, "false") {
            return (False, idx + 5);
        }
        if c == 78 and self._match_const(s, idx, "NaN") {
            return self._parse_constant("NaN", idx);
        }
        if c == 73 and self._match_const(s, idx, "Infinity") {
            return self._parse_constant("Infinity", idx);
        }
        if c == 45 and self._match_const(s, idx, "-Infinity") {
            return self._parse_constant("-Infinity", idx);
        }
        # Didn't find a string, object, array, or named constant.
        return self._match_number(s, idx);
    }

    # Bounds-exact constant prefix match (idx + K < length guards).
    def _match_const(s: str, idx: int, word: str) -> bool {
        if idx + len(word) - 1 >= len(s) {
            return False;
        }
        k = 0;
        while k < len(word) {
            if s[idx + k] != word[k] {
                return False;
            }
            k = k + 1;
        }
        return True;
    }

    def _parse_constant(constant: str, idx: int) -> tuple[any, int] {
        rval = self.parse_constant(constant);
        return (rval, idx + len(constant));
    }

    # _match_number_unicode(): grammar here, numeric conversion per
    # parse_int/parse_float hooks (default int()/float(), bit-exact).
    def _match_number(s: str, start: int) -> tuple[any, int] {
        length = len(s);
        end_idx = length - 1;
        idx = start;
        is_float = False;

        # read a sign if it's there, make sure it's not the end
        if idx <= end_idx and s[idx] == "-" {
            idx = idx + 1;
            if idx > end_idx {
                raise StopIteration(start);
            }
        }

        # integer digits; a leading 0 stands alone
        if idx <= end_idx and s[idx] >= "1" and s[idx] <= "9" {
            idx = idx + 1;
            while idx <= end_idx and s[idx] >= "0" and s[idx] <= "9" {
                idx = idx + 1;
            }
        } elif idx <= end_idx and s[idx] == "0" {
            idx = idx + 1;
        } else {
            raise StopIteration(start);
        }

        # '.' must be followed by a digit
        if idx < end_idx and s[idx] == "." and s[idx + 1] >= "0"
           and s[idx + 1] <= "9" {
            is_float = True;
            idx = idx + 2;
            while idx <= end_idx and s[idx] >= "0" and s[idx] <= "9" {
                idx = idx + 1;
            }
        }

        # optional exponent; backtrack when it has no digits
        if idx < end_idx and (s[idx] == "e" or s[idx] == "E") {
            e_start = idx;
            idx = idx + 1;
            if idx < end_idx and (s[idx] == "-" or s[idx] == "+") {
                idx = idx + 1;
            }
            while idx <= end_idx and s[idx] >= "0" and s[idx] <= "9" {
                idx = idx + 1;
            }
            last = s[idx - 1];
            if last >= "0" and last <= "9" {
                is_float = True;
            } else {
                idx = e_start;
            }
        }

        numstr = s[start:idx];
        if is_float and self.parse_float != float {
            return ((self.parse_float)(numstr), idx);
        }
        if not is_float and self.parse_int != int {
            return ((self.parse_int)(numstr), idx);
        }
        if is_float {
            return (float(numstr), idx);
        }
        return (int(numstr), idx);
    }

    def _parse_object(memo: dict, s: str, idx: int) -> tuple[any, int] {
        end_idx = len(s) - 1;
        has_pairs = self.object_pairs_hook is not None;
        rlist: list = [];
        rdict: dict = {};
        # skip whitespace after {
        while idx <= end_idx and _is_ws_char(ord(s[idx])) {
            idx = idx + 1;
        }
        # only loop if the object is non-empty
        if idx > end_idx or s[idx] != "}" {
            while True {
                # read key
                if idx > end_idx or s[idx] != "\"" {
                    _decode_error(
                        "Expecting property name enclosed in double quotes",
                        s, idx);
                }
                (key, next_idx) = _scanstring_unicode(s, idx + 1, self.strict);
                memokey = memo.setdefault(key, key);
                key = memokey;
                idx = next_idx;

                # skip ws between key and :, read :, skip ws
                while idx <= end_idx and _is_ws_char(ord(s[idx])) {
                    idx = idx + 1;
                }
                if idx > end_idx or s[idx] != ":" {
                    _decode_error("Expecting ':' delimiter", s, idx);
                }
                idx = idx + 1;
                while idx <= end_idx and _is_ws_char(ord(s[idx])) {
                    idx = idx + 1;
                }

                # read any JSON term
                (val, next_idx) = self.scan_once(memo, s, idx);

                if has_pairs {
                    rlist.append((key, val));
                } else {
                    rdict[key] = val;
                }
                idx = next_idx;

                # skip whitespace before } or ,
                while idx <= end_idx and _is_ws_char(ord(s[idx])) {
                    idx = idx + 1;
                }
                # bail if the object is closed or we didn't get the ,
                if idx <= end_idx and s[idx] == "}" {
                    break;
                }
                if idx > end_idx or s[idx] != "," {
                    _decode_error("Expecting ',' delimiter", s, idx);
                }
                comma_idx = idx;
                idx = idx + 1;

                # skip whitespace after ,
                while idx <= end_idx and _is_ws_char(ord(s[idx])) {
                    idx = idx + 1;
                }
                if idx <= end_idx and s[idx] == "}" {
                    _decode_error(
                        "Illegal trailing comma before end of object",
                        s, comma_idx);
                }
            }
        }
        if has_pairs {
            return ((self.object_pairs_hook)(rlist), idx + 1);
        }
        if self.object_hook is not None {
            return ((self.object_hook)(rdict), idx + 1);
        }
        return (rdict, idx + 1);
    }

    def _parse_array(memo: dict, s: str, idx: int) -> tuple[any, int] {
        end_idx = len(s) - 1;
        rval: list = [];
        # skip whitespace after [
        while idx <= end_idx and _is_ws_char(ord(s[idx])) {
            idx = idx + 1;
        }
        # only loop if the array is non-empty
        if idx > end_idx or s[idx] != "]" {
            while True {
                # read any JSON term
                (val, next_idx) = self.scan_once(memo, s, idx);
                rval.append(val);
                idx = next_idx;

                # skip whitespace between term and ,
                while idx <= end_idx and _is_ws_char(ord(s[idx])) {
                    idx = idx + 1;
                }
                # bail if the array is closed or we didn't get the ,
                if idx <= end_idx and s[idx] == "]" {
                    break;
                }
                if idx > end_idx or s[idx] != "," {
                    _decode_error("Expecting ',' delimiter", s, idx);
                }
                comma_idx = idx;
                idx = idx + 1;

                # skip whitespace after ,
                while idx <= end_idx and _is_ws_char(ord(s[idx])) {
                    idx = idx + 1;
                }
                if idx <= end_idx and s[idx] == "]" {
                    _decode_error(
                        "Illegal trailing comma before end of array",
                        s, comma_idx);
                }
            }
        }
        # verify that idx < end_idx, s[idx] should be ']'
        if idx > end_idx or s[idx] != "]" {
            _decode_error("Expecting value", s, end_idx);
        }
        return (rval, idx + 1);
    }
}

def make_scanner(context: any) -> _Scanner {
    # All of these fail "gracefully" in C; require them here.
    s = _Scanner();
    s.strict = bool(context.strict);
    s.object_hook = context.object_hook;
    s.object_pairs_hook = context.object_pairs_hook;
    s.parse_float = context.parse_float;
    s.parse_int = context.parse_int;
    s.parse_constant = context.parse_constant;
    return s;
}

# ------------------------------- encoder -----------------------------------

obj _Encoder {
    has markers: any = None,
        defaultfn: any = None,
        encoder: any = None,
        indent: any = None,
        key_separator: str = ": ",
        item_separator: str = ", ",
        sort_keys: bool = False,
        skipkeys: bool = False,
        allow_nan: bool = True,
        seen: list = [],
        indent_cache: list = [];

    # encoder_call(): returns (encoded_str,)
    def __call__(enc_obj: any, indent_level: any = None) -> tuple {
        level = 0 if indent_level is None else (indent_level as int);
        writer: list = [];
        if self.indent is not None {
            # create_indent_cache()
            first = "\n";
            if level {
                first = first + (self.indent as str) * level;
            }
            self.indent_cache = [first];
        } else {
            self.indent_cache = [];
        }
        self._listencode_obj(writer, enc_obj, 0);
        return ("".join(writer),);
    }

    # get_item_separator() with update_indent_cache() growth policy:
    # cache[2k]   = "\n" + indent * k
    # cache[2k-1] = item_separator + cache[2k]
    def _item_separator_for(indent_level: int) -> str {
        cache = self.indent_cache;
        while indent_level * 2 >= len(cache) {
            # prev newline lives at index (L-1)*2 == len(cache)-1
            prev: str = cache[len(cache) - 1];
            newline_indent = prev + (self.indent as str);
            separator_indent = self.item_separator + newline_indent;
            cache.append(separator_indent);
            cache.append(newline_indent);
        }
        return cache[indent_level * 2 - 1];
    }

    def _write_newline_indent(writer: list, indent_level: int) {
        writer.append(self.indent_cache[indent_level * 2]);
    }

    # markers identity tracking (C uses a dict keyed by id(); a list of
    # marked containers with `is` checks is observably equivalent).
    def _mark(tracked: any) {
        for item in self.seen {
            if item is tracked {
                raise ValueError("Circular reference detected");
            }
        }
        self.seen.append(tracked);
    }

    def _unmark(tracked: any) {
        i = len(self.seen) - 1;
        while i >= 0 {
            if self.seen[i] is tracked {
                self.seen.pop(i);
                return;
            }
            i = i - 1;
        }
    }

    # encoder_encode_float()
    def _encode_float(v: float) -> str {
        if v != v or v == float("inf") or v == float("-inf") {
            if not self.allow_nan {
                raise ValueError("Out of range float values are not JSON"
                                 + " compliant: " + repr(v));
            }
            if v == float("inf") {
                return "Infinity";
            }
            if v == float("-inf") {
                return "-Infinity";
            }
            return "NaN";
        }
        return repr(v);
    }

    # encoder_encode_string(): the C fast-path skips the str check only
    # when encoder is encode_basestring(_ascii), which always returns
    # str; calling through the callable with the check is equivalent.
    def _encode_string(sval: any) -> str {
        encoded = (self.encoder)(sval);
        if not isinstance(encoded, str) {
            raise TypeError("encoder() must return a string, not "
                            + _type_name(encoded));
        }
        return encoded as str;
    }

    # _encoded_const()
    def _encoded_const(cval: any) -> str {
        if cval is None {
            return "null";
        }
        if cval is True {
            return "true";
        }
        if cval is False {
            return "false";
        }
        raise ValueError("not a const");
    }

    # encoder_listencode_obj()
    def _listencode_obj(writer: list, val: any, indent_level: int) {
        if val is None {
            writer.append("null");
        } elif val is True {
            writer.append("true");
        } elif val is False {
            writer.append("false");
        } elif isinstance(val, str) {
            writer.append(self._encode_string(val));
        } elif isinstance(val, int) {
            writer.append(repr(val));
        } elif isinstance(val, float) {
            writer.append(self._encode_float(val as float));
        } elif isinstance(val, list) or isinstance(val, tuple) {
            self._listencode_list(writer, val, indent_level);
        } elif isinstance(val, dict) {
            self._listencode_dict(writer, val, indent_level);
        } else {
            marked = False;
            if self.markers is not None {
                marked = True;
                self._mark(val);
            }
            newval = (self.defaultfn)(val);
            try {
                self._listencode_obj(writer, newval, indent_level);
            } finally {
                if marked {
                    self._unmark(val);
                }
            }
        }
    }

    # encoder_encode_key_value(); first_ref[0] boxes the "first item"
    # flag. Returns False when skipkeys dropped the entry.
    def _encode_key_value(writer: list, dct: any, key: any, value: any,
                          indent_level: int, separator: str,
                          first_ref: list) -> bool {
        keystr: str;
        if isinstance(key, str) {
            keystr = key as str;
        } elif isinstance(key, float) {
            keystr = self._encode_float(key as float);
        } elif key is True or key is False or key is None {
            # must come before the int check: True/False are also 1/0
            keystr = self._encoded_const(key);
        } elif isinstance(key, int) {
            keystr = repr(key);
        } elif self.skipkeys {
            return False;
        } else {
            raise TypeError("keys must be str, int, float, bool or None, not "
                            + _type_name(key));
        }

        if first_ref[0] {
            first_ref[0] = False;
            if self.indent is not None {
                self._write_newline_indent(writer, indent_level);
            }
        } else {
            writer.append(separator);
        }

        writer.append(self._encode_string(keystr));
        writer.append(self.key_separator);
        self._listencode_obj(writer, value, indent_level);
        return True;
    }

    # encoder_listencode_dict()
    def _listencode_dict(writer: list, dct: dict, indent_level: int) {
        if len(dct) == 0 {
            writer.append("{}");
            return;
        }
        marked = False;
        if self.markers is not None {
            marked = True;
            self._mark(dct);
        }
        try {
            writer.append("{");
            separator = self.item_separator;
            level = indent_level;
            if self.indent is not None {
                level = level + 1;
                separator = self._item_separator_for(level);
            }
            first_ref: list = [True];
            items: list = [];
            for kv in dct.items() {
                items.append(kv);
            }
            if self.sort_keys {
                items.sort();
            }
            for kv in items {
                self._encode_key_value(writer, dct, kv[0], kv[1], level,
                                       separator, first_ref);
            }
            if self.indent is not None and not first_ref[0] {
                self._write_newline_indent(writer, level - 1);
            }
            writer.append("}");
        } finally {
            if marked {
                self._unmark(dct);
            }
        }
    }

    # encoder_listencode_list()
    def _listencode_list(writer: list, seq: any, indent_level: int) {
        items: list = [];
        for item in seq {
            items.append(item);
        }
        if len(items) == 0 {
            writer.append("[]");
            return;
        }
        marked = False;
        if self.markers is not None {
            marked = True;
            self._mark(seq);
        }
        try {
            writer.append("[");
            separator = self.item_separator;
            level = indent_level;
            if self.indent is not None {
                level = level + 1;
                separator = self._item_separator_for(level);
                self._write_newline_indent(writer, level);
            }
            i = 0;
            for val in items {
                if i {
                    writer.append(separator);
                }
                self._listencode_obj(writer, val, level);
                i = i + 1;
            }
            if self.indent is not None {
                self._write_newline_indent(writer, level - 1);
            }
            writer.append("]");
        } finally {
            if marked {
                self._unmark(seq);
            }
        }
    }
}

def make_encoder(markers: any, defaultfn: any, encoder: any, indent: any,
                 key_separator: str, item_separator: str, sort_keys: bool,
                 skipkeys: bool, allow_nan: bool) -> _Encoder {
    if markers is not None and not isinstance(markers, dict) {
        raise TypeError("make_encoder() argument 1 must be dict or None, not "
                        + _type_name(markers));
    }
    e = _Encoder();
    e.markers = markers;
    e.defaultfn = defaultfn;
    e.encoder = encoder;
    e.indent = indent;
    e.key_separator = key_separator;
    e.item_separator = item_separator;
    e.sort_keys = sort_keys;
    e.skipkeys = skipkeys;
    e.allow_nan = allow_nan;
    e.seen = [];
    e.indent_cache = [];
    return e;
}

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
