# Product-path facade for _csv (wave 17): reader, writer, dialects.
#
# Staged ``jac-py/Modules/_csv.{c,jac}`` remain the wave-17 c2jac corpus
# oracle pair (staging=lift); this module carries the runtime truth.
# Semantics mirror CPython 3.14 ``Modules/_csv.c`` on the pinned host,
# verified against the host stdlib ``_csv`` at authoring time.
#
# Lib/csv.py stays out of scope: the Sniffer class lives in the Python
# layer, not the C accelerator, and the dialect registry starts empty
# (excel/excel-tab/unix registrations are csv.py's doing).
#
# Error mapping: CPython raises ``_csv.Error`` (an Exception subclass);
# this facade declares csv.Error/_csv.Error in the bridge-table
# module-exception registry (exceptions_core.jac) at import. Builtin
# TypeError/ValueError/OverflowError keep their builtin types exactly,
# matching which PyErr type each C site uses.
#
# Characters are carried as ints with the C sentinels NOT_SET (-1) and
# EOL (-2); the reader machine keeps the two legal fall-throughs of
# parse_process_char duplicated inline, verbatim otherwise.

glob QUOTE_MINIMAL: int = 0;
glob QUOTE_ALL: int = 1;
glob QUOTE_NONNUMERIC: int = 2;
glob QUOTE_NONE: int = 3;
glob QUOTE_STRINGS: int = 4;
glob QUOTE_NOTNULL: int = 5;

# ParserState values (Modules/_csv.c).
glob _ST_START_RECORD: int = 0;
glob _ST_START_FIELD: int = 1;
glob _ST_ESCAPED_CHAR: int = 2;
glob _ST_IN_FIELD: int = 3;
glob _ST_IN_QUOTED_FIELD: int = 4;
glob _ST_ESCAPE_IN_QUOTED_FIELD: int = 5;
glob _ST_QUOTE_IN_QUOTED_FIELD: int = 6;
glob _ST_EAT_CRNL: int = 7;
glob _ST_AFTER_ESCAPED_CRNL: int = 8;

# Module state boxed in a dict so rebinding stays unnecessary:
# _csvstate.field_limit (128 * 1024) and the dialect registry.
glob _state: dict = {"field_limit": 131072, "dialects": {}};

# "Keyword not given" marker; distinct from every legal value including
# None (quotechar=None/escapechar=None disable those characters).
obj _Unset {}
glob _UNSET: _Unset = _Unset();

glob _NOT_SET: int = -1;
glob _EOL: int = -2;


def _csv_error(msg: str) {
    raise Exception(msg);
}


def _tp_name(v: any) -> str {
    return type(v).__name__;
}


def _set_bool(v: any) -> bool {
    return bool(v);
}


# _set_int: PyLong_CheckExact (bool is rejected), then int coercion.
def _set_int_exact(name: str, v: any) -> int {
    if type(v) is not int {
        raise TypeError(
            '"' + name + '" must be an integer, not ' + _tp_name(v));
    }
    return v as int;
}


# _set_char: one-character str, None not allowed.
def _set_char(name: str, v: any) -> int {
    if not isinstance(v, str) {
        raise TypeError(
            '"' + name + '" must be a unicode character, not '
            + _tp_name(v));
    }
    s = v as str;
    n = len(s);
    if n != 1 {
        raise TypeError(
            '"' + name + '" must be a unicode character, not a string '
            + "of length " + str(n));
    }
    return ord(s);
}


# _set_char_or_none: like _set_char but None maps to NOT_SET.
def _set_char_or_none(name: str, v: any) -> int {
    if v is None {
        return _NOT_SET;
    }
    if not isinstance(v, str) {
        raise TypeError(
            '"' + name + '" must be a unicode character or None, not '
            + _tp_name(v));
    }
    s = v as str;
    n = len(s);
    if n != 1 {
        raise TypeError(
            '"' + name + '" must be a unicode character or None, not a '
            + "string of length " + str(n));
    }
    return ord(s);
}


def _set_str(name: str, v: any) -> str {
    if not isinstance(v, str) {
        raise TypeError(
            '"' + name + '" must be a string, not ' + _tp_name(v));
    }
    return v as str;
}


# ---------------------------------------------------------------------------
# Dialect
#

obj _Dialect {
    has delimiter: int = 44;             # ','
    has doublequote: bool = True;
    has escapechar: int = -1;            # NOT_SET
    has lineterminator: str = "\r\n";
    has quotechar: int = 34;             # '"'
    has quoting: int = 0;                # QUOTE_MINIMAL
    has skipinitialspace: bool = False;
    has strict: bool = False;

    def __repr__ -> str {
        return "<_csv.Dialect object>";
    }
}


# DIALECT_GETATTR for plain objects: missing attributes fall back to
# the default (GetAttrString + PyErr_Clear).
def _get_attr_default(src: any, name: str) -> any {
    try {
        return getattr(src, name);
    } except Exception {
        return _UNSET;
    }
}


# Convert a _Dialect field back to its user-facing form when copying
# from a base Dialect instance: chars become one-character strings,
# NOT_SET becomes None.
def _dialect_attr_param(c: int) -> any {
    if c == _NOT_SET {
        return None;
    }
    return chr(c);
}


# dialect_check_char: BAD_VALUE(-1) / BAD_LINETERM(-2) verdict.
def _check_dialect_char(name: str, c: int, allowspace: bool,
                        lineterminator: str) {
    if c == 13 or c == 10 or (c == 32 and not allowspace) {
        raise ValueError("bad " + name + " value");
    }
    if c != _NOT_SET and (lineterminator as str).find(chr(c)) >= 0 {
        raise ValueError("bad " + name + " or lineterminator value");
    }
}


def _check_dialect_chars(name1: str, name2: str, c1: int, c2: int) {
    if c1 == c2 and c1 != _NOT_SET {
        raise ValueError("bad " + name1 + " or " + name2 + " value");
    }
}


def _is_unset(v: any) -> bool {
    return v is _UNSET;
}


# dialect_new(): builds a validated _Dialect from an optional base
# dialect (instance or registered name) plus overriding parameters.
def _build_dialect(dialect: any, delimiter: any, doublequote: any,
                   escapechar: any, lineterminator: any, quotechar: any,
                   quoting: any, skipinitialspace: any,
                   strict: any) -> _Dialect {
    quotechar_given_none = False;
    if not _is_unset(quotechar) and quotechar is None {
        quotechar_given_none = True;
    }

    src: any = None;
    if not _is_unset(dialect) {
        if isinstance(dialect, str) {
            reg = _state["dialects"] as dict;
            if not (dialect as str in reg) {
                _csv_error("unknown dialect");
            }
            src = reg[dialect as str];
        }
        else {
            src = dialect;
        }
        # Reuse a Dialect instance when nothing overrides it.
        if (
            isinstance(src, _Dialect)
            and _is_unset(delimiter) and _is_unset(doublequote)
            and _is_unset(escapechar) and _is_unset(lineterminator)
            and _is_unset(quotechar) and _is_unset(quoting)
            and _is_unset(skipinitialspace) and _is_unset(strict)
        ) {
            return src as _Dialect;
        }
        if isinstance(src, _Dialect) {
            # Internal instance: copy fields back to user-facing forms.
            if _is_unset(delimiter) {
                delimiter = _dialect_attr_param((src as _Dialect).delimiter);
            }
            if _is_unset(doublequote) {
                doublequote = (src as _Dialect).doublequote;
            }
            if _is_unset(escapechar) {
                escapechar = _dialect_attr_param(
                    (src as _Dialect).escapechar);
            }
            if _is_unset(lineterminator) {
                lineterminator = (src as _Dialect).lineterminator;
            }
            if _is_unset(quotechar) {
                quotechar = _dialect_attr_param((src as _Dialect).quotechar);
            }
            if _is_unset(quoting) {
                quoting = (src as _Dialect).quoting;
            }
            if _is_unset(skipinitialspace) {
                skipinitialspace = (src as _Dialect).skipinitialspace;
            }
            if _is_unset(strict) {
                strict = (src as _Dialect).strict;
            }
        } else {
            if _is_unset(delimiter) {
                delimiter = _get_attr_default(src, "delimiter");
            }
            if _is_unset(doublequote) {
                doublequote = _get_attr_default(src, "doublequote");
            }
            if _is_unset(escapechar) {
                escapechar = _get_attr_default(src, "escapechar");
            }
            if _is_unset(lineterminator) {
                lineterminator = _get_attr_default(src, "lineterminator");
            }
            if _is_unset(quotechar) {
                quotechar = _get_attr_default(src, "quotechar");
            }
            if _is_unset(quoting) {
                quoting = _get_attr_default(src, "quoting");
            }
            if _is_unset(skipinitialspace) {
                skipinitialspace = _get_attr_default(
                    src, "skipinitialspace");
            }
            if _is_unset(strict) {
                strict = _get_attr_default(src, "strict");
            }
        }
    }

    self = _Dialect();
    # DIASET order: delimiter, doublequote, escapechar, lineterminator,
    # quotechar, quoting, skipinitialspace, strict.
    if _is_unset(delimiter) {
        self.delimiter = 44;
    } else {
        self.delimiter = _set_char("delimiter", delimiter);
    }
    if _is_unset(doublequote) {
        self.doublequote = True;
    } else {
        self.doublequote = _set_bool(doublequote);
    }
    if _is_unset(escapechar) {
        self.escapechar = _NOT_SET;
    } else {
        self.escapechar = _set_char_or_none("escapechar", escapechar);
    }
    if _is_unset(lineterminator) {
        self.lineterminator = "\r\n";
    } else {
        self.lineterminator = _set_str("lineterminator", lineterminator);
    }
    if _is_unset(quotechar) {
        self.quotechar = 34;
    } else {
        self.quotechar = _set_char_or_none("quotechar", quotechar);
    }
    if _is_unset(quoting) {
        self.quoting = 0;
    } else {
        self.quoting = _set_int_exact("quoting", quoting);
    }
    if _is_unset(skipinitialspace) {
        self.skipinitialspace = False;
    } else {
        self.skipinitialspace = _set_bool(skipinitialspace);
    }
    if _is_unset(strict) {
        self.strict = False;
    } else {
        self.strict = _set_bool(strict);
    }

    # Validate options (order mirrors dialect_new).
    if self.quoting < 0 or self.quoting > 5 {
        raise TypeError('bad "quoting" value');
    }
    if quotechar_given_none and _is_unset(quoting) {
        self.quoting = QUOTE_NONE;
    }
    if self.quoting != QUOTE_NONE and self.quotechar == _NOT_SET {
        raise TypeError("quotechar must be set if quoting enabled");
    }
    lt = self.lineterminator;
    _check_dialect_char("delimiter", self.delimiter, True, lt);
    _check_dialect_char(
        "escapechar", self.escapechar, not self.skipinitialspace, lt);
    _check_dialect_char(
        "quotechar", self.quotechar, not self.skipinitialspace, lt);
    _check_dialect_chars(
        "delimiter", "escapechar", self.delimiter, self.escapechar);
    _check_dialect_chars(
        "delimiter", "quotechar", self.delimiter, self.quotechar);
    _check_dialect_chars(
        "escapechar", "quotechar", self.escapechar, self.quotechar);
    return self;
}


# ---------------------------------------------------------------------------
# Reader
#

obj _Reader {
    has input_iter: any = None;
    has dialect: any = None;
    has fields: list = [];
    has state: int = 0;
    has field: list[int] = [];
    has unquoted_field: bool = False;
    has line_num: int = 0;

    def __iter__ -> any {
        return self;
    }

    # parse_save_field: None-vs-string branch plus float() conversion.
    def _save_field {
        quoting = (self.dialect as _Dialect).quoting;
        if (
            self.unquoted_field and len(self.field) == 0
            and (quoting == QUOTE_NOTNULL or quoting == QUOTE_STRINGS)
        ) {
            self.fields.append(None);
            return;
        }
        s: any = "".join([chr(x) for x in self.field]);
        if (
            self.unquoted_field and len(self.field) != 0
            and (quoting == QUOTE_NONNUMERIC or quoting == QUOTE_STRINGS)
        ) {
            s = float(s);
        }
        self.field.clear();
        self.fields.append(s);
    }

    # parse_add_char's field_size_limit guard.
    def _add_char(c: int) {
        if len(self.field) >= (_state["field_limit"] as int) {
            _csv_error(
                "field larger than field limit ("
                + str(_state["field_limit"] as int) + ")");
        }
        self.field.append(c);
    }

    # parse_process_char: one input character (or EOL). Mutates
    # state/field/unquoted_field; raises byte-exact csv.Error strings.
    def _process_char(c: int) {
        dia = self.dialect as _Dialect;
        state = self.state;

        # START_RECORD falls through into START_FIELD on a normal
        # character; AFTER_ESCAPED_CRNL falls through into IN_FIELD.
        if state == _ST_START_RECORD {
            if c == _EOL {
                return;  # empty line - return []
            }
            if c == 10 or c == 13 {
                self.state = _ST_EAT_CRNL;
                return;
            }
            self.state = _ST_START_FIELD;
            state = _ST_START_FIELD;
        }

        if state == _ST_START_FIELD {
            self.unquoted_field = True;
            if c == 10 or c == 13 or c == _EOL {
                self._save_field();
                if c == _EOL {
                    self.state = _ST_START_RECORD;
                } else {
                    self.state = _ST_EAT_CRNL;
                }
                return;
            }
            if c == dia.quotechar and dia.quoting != QUOTE_NONE {
                self.unquoted_field = False;
                self.state = _ST_IN_QUOTED_FIELD;
                return;
            }
            if c == dia.escapechar {
                self.state = _ST_ESCAPED_CHAR;
                return;
            }
            if c == 32 and dia.skipinitialspace {
                return;  # ignore spaces at start of field
            }
            if c == dia.delimiter {
                self._save_field();
                return;
            }
            self._add_char(c);
            self.state = _ST_IN_FIELD;
            return;
        }

        if state == _ST_ESCAPED_CHAR {
            if c == 10 or c == 13 {
                self._add_char(c);
                self.state = _ST_AFTER_ESCAPED_CRNL;
                return;
            }
            if c == _EOL {
                c = 10;
            }
            self._add_char(c);
            self.state = _ST_IN_FIELD;
            return;
        }

        if state == _ST_AFTER_ESCAPED_CRNL and c == _EOL {
            return;
        }

        if state == _ST_AFTER_ESCAPED_CRNL or state == _ST_IN_FIELD {
            if c == 10 or c == 13 or c == _EOL {
                self._save_field();
                if c == _EOL {
                    self.state = _ST_START_RECORD;
                } else {
                    self.state = _ST_EAT_CRNL;
                }
                return;
            }
            if c == dia.escapechar {
                self.state = _ST_ESCAPED_CHAR;
                return;
            }
            if c == dia.delimiter {
                self._save_field();
                self.state = _ST_START_FIELD;
                return;
            }
            self._add_char(c);
            return;
        }

        if state == _ST_IN_QUOTED_FIELD {
            if c == _EOL {
                return;  # embedded newline
            }
            if c == dia.escapechar {
                self.state = _ST_ESCAPE_IN_QUOTED_FIELD;
                return;
            }
            if c == dia.quotechar and dia.quoting != QUOTE_NONE {
                if dia.doublequote {
                    self.state = _ST_QUOTE_IN_QUOTED_FIELD;
                } else {
                    self.state = _ST_IN_FIELD;
                }
                return;
            }
            self._add_char(c);
            return;
        }

        if state == _ST_ESCAPE_IN_QUOTED_FIELD {
            if c == _EOL {
                c = 10;
            }
            self._add_char(c);
            self.state = _ST_IN_QUOTED_FIELD;
            return;
        }

        if state == _ST_QUOTE_IN_QUOTED_FIELD {
            if dia.quoting != QUOTE_NONE and c == dia.quotechar {
                self._add_char(c);
                self.state = _ST_IN_QUOTED_FIELD;
                return;
            }
            if c == dia.delimiter {
                self._save_field();
                self.state = _ST_START_FIELD;
                return;
            }
            if c == 10 or c == 13 or c == _EOL {
                self._save_field();
                if c == _EOL {
                    self.state = _ST_START_RECORD;
                } else {
                    self.state = _ST_EAT_CRNL;
                }
                return;
            }
            if not dia.strict {
                self._add_char(c);
                self.state = _ST_IN_FIELD;
                return;
            }
            _csv_error(
                "'" + chr(dia.delimiter) + "' expected after '"
                + chr(dia.quotechar) + "'");
            return;
        }

        if state == _ST_EAT_CRNL {
            if c == 10 or c == 13 {
                return;
            }
            if c == _EOL {
                self.state = _ST_START_RECORD;
                return;
            }
            _csv_error(
                "new-line character seen in unquoted field - do you "
                + "need to open the file with newline=''?");
        }
    }

    # Reader_iternext_lock_held: pull lines until a full record parsed.
    def __next__ -> list {
        self.fields = [];
        self.field.clear();
        self.state = _ST_START_RECORD;
        self.unquoted_field = False;
        while True {
            lineobj: any = None;
            eof = False;
            try {
                lineobj = self.input_iter.__next__();
            } except StopIteration {
                eof = True;
            }
            if eof {
                # End of input OR exception
                if len(self.field) != 0
                    or self.state == _ST_IN_QUOTED_FIELD
                {
                    if (self.dialect as _Dialect).strict {
                        _csv_error("unexpected end of data");
                    }
                    self._save_field();
                    break;
                }
                raise StopIteration();
            }
            if not isinstance(lineobj, str) {
                _csv_error(
                    "iterator should return strings, not "
                    + _tp_name(lineobj)
                    + " (the file should be opened in text mode)");
            }
            self.line_num = self.line_num + 1;
            for ch in lineobj as str {
                self._process_char(ord(ch));
            }
            self._process_char(_EOL);
            if self.state == _ST_START_RECORD {
                break;
            }
        }
        fields = self.fields;
        self.fields = [];
        return fields;
    }
}


# ---------------------------------------------------------------------------
# Writer
#

obj _Writer {
    has write_fn: any = None;
    has dialect: any = None;
    has num_fields: int = 0;
    has _pending: list[str] = [];

    # One join_append_data() character pass. mode 1 counts/validates
    # (updating quoted), mode 2 copies into out. Returns the updated
    # running length delta contribution via out list append.
    def _join_chars(s: str, quoted_flag: list[int],
                    out: list[str] | None) -> int {
        dia = self.dialect as _Dialect;
        added = 0;
        for ch in s {
            c = ord(ch);
            special = (
                c == dia.delimiter or c == dia.escapechar
                or c == dia.quotechar or c == 10 or c == 13
                or (dia.lineterminator as str).find(ch) >= 0
            );
            if special {
                want_escape = False;
                if dia.quoting == QUOTE_NONE {
                    want_escape = True;
                } else {
                    if c == dia.quotechar {
                        if dia.doublequote {
                            if out is not None {
                                out.append(chr(dia.quotechar));
                            }
                            added = added + 1;
                        } else {
                            want_escape = True;
                        }
                    } elif c == dia.escapechar {
                        want_escape = True;
                    }
                    if not want_escape {
                        quoted_flag[0] = 1;
                    }
                }
                if want_escape {
                    if dia.escapechar == _NOT_SET {
                        _csv_error("need to escape, but no escapechar set");
                    }
                    if out is not None {
                        out.append(chr(dia.escapechar));
                    }
                    added = added + 1;
                }
            }
            if out is not None {
                out.append(ch);
            }
            added = added + 1;
        }
        return added;
    }

    # join_append(): append one field (None = NULL field).
    def _join_append(field_val: any, quoted_in: int) -> int {
        dia = self.dialect as _Dialect;
        s = "";
        if field_val is not None {
            s = field_val as str;
        }
        quoted = quoted_in;
        if len(s) == 0 and dia.delimiter == 32 and dia.skipinitialspace {
            if (
                dia.quoting == QUOTE_NONE
                or (field_val is None
                    and (dia.quoting == QUOTE_STRINGS
                         or dia.quoting == QUOTE_NOTNULL))
            ) {
                _csv_error(
                    "empty field must be quoted if delimiter is a space "
                    + "and skipinitialspace is true");
            }
            quoted = 1;
        }
        # Count/validate pass, then copy pass (mirrors the C two-phase
        # join_append_data; errors surface from the first pass exactly
        # like the C counting phase).
        qflag: list[int] = [quoted];
        self._join_chars(s, qflag, None);
        quoted = qflag[0];
        out: list[str] = [];
        if self.num_fields > 0 {
            out.append(chr(dia.delimiter));
        }
        if quoted != 0 {
            out.append(chr(dia.quotechar));
        }
        added = self._join_chars(s, qflag, out);
        if quoted != 0 {
            out.append(chr(dia.quotechar));
            added = added + 2;
        }
        self.num_fields = self.num_fields + 1;
        self._pending.extend(out);
        return added;
    }

    def writerow(seq: any) -> any {
        dia = self.dialect as _Dialect;
        it: any = None;
        try {
            it = seq.__iter__();
        } except Exception as e {
            if type(e).__name__ == "TypeError"
                or type(e).__name__ == "AttributeError"
            {
                _csv_error("iterable expected, not " + _tp_name(seq));
            }
            raise e;
        }
        self._pending.clear();
        self.num_fields = 0;
        null_field = False;
        while True {
            field: any = None;
            try {
                field = it.__next__();
            } except StopIteration {
                break;
            }
            is_number = _number_check(field);
            is_str = isinstance(field, str);
            is_none = field is None;
            quoted: int = 0;
            if dia.quoting == QUOTE_NONNUMERIC {
                quoted = 0 if is_number else 1;
            } elif dia.quoting == QUOTE_ALL {
                quoted = 1;
            } elif dia.quoting == QUOTE_STRINGS {
                quoted = 1 if is_str else 0;
            } elif dia.quoting == QUOTE_NOTNULL {
                quoted = 0 if is_none else 1;
            }
            null_field = is_none;
            if is_str {
                self._join_append(field, quoted);
            } elif is_none {
                self._join_append(None, quoted);
            } else {
                self._join_append(str(field), quoted);
            }
        }
        rec_len = "".join(self._pending);
        if self.num_fields > 0 and len(rec_len) == 0 {
            if (
                dia.quoting == QUOTE_NONE
                or (null_field
                    and (dia.quoting == QUOTE_STRINGS
                         or dia.quoting == QUOTE_NOTNULL))
            ) {
                _csv_error("single empty field record must be quoted");
            }
            self.num_fields = self.num_fields - 1;
            self._join_append(None, 1);
        }
        # Line terminator.
        self._pending.append(dia.lineterminator);
        line = "".join(self._pending);
        return self.write_fn(line);
    }

    def writerows(rows: any) -> None {
        row_iter: any = rows.__iter__();
        while True {
            row: any = None;
            try {
                row = row_iter.__next__();
            } except StopIteration {
                break;
            }
            self.writerow(row);
        }
        return;
    }
}


# PyNumber_Check mirror: nb_float/nb_index providers only (3.14 dropped
# plain __int__ classes from the number protocol).
def _number_check(v: any) -> bool {
    t = type(v);
    if t is int or t is float or t is complex {
        return True;
    }
    return hasattr(t, "__float__") or hasattr(t, "__index__");
}


# ---------------------------------------------------------------------------
# Module-level API
#

def reader(iterable: any, dialect: any = _UNSET, delimiter: any = _UNSET,
           doublequote: any = _UNSET, escapechar: any = _UNSET,
           lineterminator: any = _UNSET, quotechar: any = _UNSET,
           quoting: any = _UNSET, skipinitialspace: any = _UNSET,
           strict: any = _UNSET) -> _Reader {
    if iterable is _UNSET {
        raise TypeError("reader expected at least 1 argument, got 0");
    }
    it: any = None;
    try {
        it = iterable.__iter__();
    } except Exception as e {
        if type(e).__name__ == "TypeError"
            or type(e).__name__ == "AttributeError"
        {
            raise TypeError("'" + _tp_name(iterable)
                            + "' object is not iterable");
        }
        raise e;
    }
    d = _build_dialect(dialect, delimiter, doublequote, escapechar,
                       lineterminator, quotechar, quoting,
                       skipinitialspace, strict);
    r = _Reader();
    r.input_iter = it;
    r.dialect = d;
    return r;
}


def writer(fileobj: any, dialect: any = _UNSET, delimiter: any = _UNSET,
           doublequote: any = _UNSET, escapechar: any = _UNSET,
           lineterminator: any = _UNSET, quotechar: any = _UNSET,
           quoting: any = _UNSET, skipinitialspace: any = _UNSET,
           strict: any = _UNSET) -> _Writer {
    if fileobj is _UNSET {
        raise TypeError("writer expected at least 1 argument, got 0");
    }
    w = _Writer();
    try {
        w.write_fn = getattr(fileobj, "write");
    } except Exception {
        w.write_fn = None;
    }
    if w.write_fn is None or not callable(w.write_fn) {
        raise TypeError('argument 1 must have a "write" method');
    }
    w.dialect = _build_dialect(dialect, delimiter, doublequote, escapechar,
                               lineterminator, quotechar, quoting,
                               skipinitialspace, strict);
    return w;
}


def register_dialect(name: any, dialect: any = _UNSET,
                     delimiter: any = _UNSET, doublequote: any = _UNSET,
                     escapechar: any = _UNSET, lineterminator: any = _UNSET,
                     quotechar: any = _UNSET, quoting: any = _UNSET,
                     skipinitialspace: any = _UNSET,
                     strict: any = _UNSET) -> None {
    if not isinstance(name, str) {
        raise TypeError("dialect name must be a string");
    }
    d = _build_dialect(dialect, delimiter, doublequote, escapechar,
                       lineterminator, quotechar, quoting,
                       skipinitialspace, strict);
    (_state["dialects"] as dict)[name as str] = d;
    return;
}


def unregister_dialect(name: any) -> None {
    reg = _state["dialects"] as dict;
    if not (name in reg) {
        _csv_error("unknown dialect");
    }
    reg.pop(name);
    return;
}


def get_dialect(name: any) -> _Dialect {
    reg = _state["dialects"] as dict;
    if not (name in reg) {
        _csv_error("unknown dialect");
    }
    return reg[name] as _Dialect;
}


def list_dialects() -> list {
    return list((_state["dialects"] as dict).keys());
}


def field_size_limit(new_limit: any = _UNSET) -> int {
    old = _state["field_limit"] as int;
    if not _is_unset(new_limit) {
        if type(new_limit) is not int {
            raise TypeError("limit must be an integer");
        }
        _state["field_limit"] = new_limit as int;
    }
    return old;
}

import from exceptions_core { register_module_exception }

with entry {
    # Module-exception declaration (bridge-table registry, exceptions_core):
    # declared AT IMPORT so boundary matching/minting knows this exception's
    # hierarchy without bare getattr(builtins, ...) lookups.
    register_module_exception("csv.Error", "Exception");
    register_module_exception("_csv.Error", "Exception");
}
