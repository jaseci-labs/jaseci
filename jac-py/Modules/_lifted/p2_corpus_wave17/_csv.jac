glob Py_ssize_t = int;


@__jac_value__
obj csv_parse_step {
    has state: int = 0;
    has unquoted_field: int = 0;
    has field_len: int = 0;
    has action: int = 0;
    has emit: int = 0;
    has status: int = 0;
}


@__jac_value__
obj csv_dialect_cfg {
    has quoting: int = 0;
    has doublequote: int = 0;
    has skipinitialspace: int = 0;
    has strict: int = 0;
    has delimiter: int = 0;
    has quotechar: int = 0;
    has escapechar: int = 0;
}

def csv_in_chars(c: int, `set: object, set_len: int) -> int {
    i: int = 0;
    for i = 0 while i < set_len with i += 1 {
        if (`set[i] == c) {
            return 1;
        }
    }

    return 0;
}


def csv_parse_save_is_none(unquoted_field: int, field_len: int, quoting: int) -> int {
    if ((unquoted_field and (field_len == 0)) and ((quoting == 5) or (quoting == 4))) {
        return 1;
    }
    return 0;
}


def csv_parse_process_char(
    state: int,
    unquoted_field: int,
    field_len: int,
    dia: csv_dialect_cfg,
    field_limit: int,
    c: int
) -> csv_parse_step {
    r: csv_parse_step = csv_parse_step();
    r.state = state;
    r.unquoted_field = unquoted_field;
    r.field_len = field_len;
    r.action = 0;
    r.emit = 0;
    r.status = 0;

    if (state == 0) {
        if (c == -2) {
            return r;
        }

        if ((c == 10) or (c == 13)) {
            r.state = 7;
            return r;
        }

        state = 1;
        unquoted_field = r.unquoted_field;
    }

    if (state == 1) {
        r.state = 1;
        r.unquoted_field = 1;
        if (((c == 10) or (c == 13)) or (c == -2)) {
            r.action = 2;
            if (c == -2) {
                r.state = 0;
            } else {
                r.state = 7;
            }
        } elif ((c == dia.quotechar) and (dia.quoting != 3)) {
            r.unquoted_field = 0;
            r.state = 4;
        } elif (c == dia.escapechar) {
            r.state = 2;
        } elif ((c == 32) and dia.skipinitialspace) {
            ;
        } elif (c == dia.delimiter) {
            r.action = 2;
        } else {
            if (field_len >= field_limit) {
                r.status = -1;
                return r;
            }
            r.action = 1;
            r.emit = c;
            r.field_len = field_len + 1;
            r.state = 3;
        }

        return r;
    }

    if (state == 2) {
        if ((c == 10) or (c == 13)) {
            if (field_len >= field_limit) {
                r.status = -1;
                return r;
            }

            r.action = 1;
            r.emit = c;
            r.field_len = field_len + 1;
            r.state = 8;
            return r;
        }

        if (c == -2) {
            c = 10;
        }
        if (field_len >= field_limit) {
            r.status = -1;
            return r;
        }

        r.action = 1;
        r.emit = c;
        r.field_len = field_len + 1;
        r.state = 3;
        return r;
    }

    if ((state == 8) and (c == -2)) {
        return r;
    }

    if ((state == 8) or (state == 3)) {
        if (((c == 10) or (c == 13)) or (c == -2)) {
            r.action = 2;
            if (c == -2) {
                r.state = 0;
            } else {
                r.state = 7;
            }
        } elif (c == dia.escapechar) {
            r.state = 2;
        } elif (c == dia.delimiter) {
            r.action = 2;
            r.state = 1;
        } else {
            if (field_len >= field_limit) {
                r.status = -1;
                return r;
            }
            r.action = 1;
            r.emit = c;
            r.field_len = field_len + 1;
        }

        return r;
    }

    if (state == 4) {
        if (c == -2) {
            ;
        } elif (c == dia.escapechar) {
            r.state = 5;
        } elif ((c == dia.quotechar) and (dia.quoting != 3)) {
            if dia.doublequote {
                r.state = 6;
            } else {
                r.state = 3;
            }
        } else {
            if (field_len >= field_limit) {
                r.status = -1;
                return r;
            }
            r.action = 1;
            r.emit = c;
            r.field_len = field_len + 1;
        }

        return r;
    }

    if (state == 5) {
        if (c == -2) {
            c = 10;
        }
        if (field_len >= field_limit) {
            r.status = -1;
            return r;
        }

        r.action = 1;
        r.emit = c;
        r.field_len = field_len + 1;
        r.state = 4;
        return r;
    }

    if (state == 6) {
        if ((dia.quoting != 3) and (c == dia.quotechar)) {
            if (field_len >= field_limit) {
                r.status = -1;
                return r;
            }

            r.action = 1;
            r.emit = c;
            r.field_len = field_len + 1;
            r.state = 4;
        } elif (c == dia.delimiter) {
            r.action = 2;
            r.state = 1;
        } elif (((c == 10) or (c == 13)) or (c == -2)) {
            r.action = 2;
            if (c == -2) {
                r.state = 0;
            } else {
                r.state = 7;
            }
        } elif not dia.strict {
            if (field_len >= field_limit) {
                r.status = -1;
                return r;
            }
            r.action = 1;
            r.emit = c;
            r.field_len = field_len + 1;
            r.state = 3;
        } else {
            r.status = -2;
        }

        return r;
    }

    if (state == 7) {
        if ((c == 10) or (c == 13)) {
            ;
        } elif (c == -2) {
            r.state = 0;
        } else {
            r.status = -3;
        }

        return r;
    }

    return r;
}


def csv_reader_eof_verdict(state: int, field_len_nonzero: int, strict: int) -> int {
    if (field_len_nonzero or (state == 4)) {
        if strict {
            return 1;
        }
        return 2;
    }

    return 0;
}


def csv_check_quoting(quoting: int) -> int {
    if ((quoting >= 0) and (quoting <= 5)) {
        return 0;
    }
    return -1;
}


def csv_dialect_check_char(
    c: int, allowspace: int, lineterm: object, lineterm_len: int
) -> int {
    if (((c == 13) or (c == 10)) or ((c == 32) and not allowspace)) {
        return -1;
    }
    if csv_in_chars(c, lineterm, lineterm_len) {
        return -2;
    }
    return 0;
}


def csv_dialect_check_chars(c1: int, c2: int) -> int {
    if ((c1 == c2) and (c1 != -1)) {
        return -1;
    }
    return 0;
}


@__jac_value__
obj csv_join_step {
    has rec_len: int = 0;
    has quoted: int = 0;
    has n_emit: int = 0;
    has emit0: int = 0;
    has emit1: int = 0;
    has status: int = 0;
}


def csv_join_char_step(
    rec_len: int,
    quoted: int,
    quoting: int,
    doublequote: int,
    delimiter: int,
    quotechar: int,
    escapechar: int,
    in_lineterm: int,
    c: int
) -> csv_join_step {
    r: csv_join_step = csv_join_step();
    want_escape: int = 0;
    r.rec_len = rec_len;
    r.quoted = quoted;
    r.n_emit = 1;
    r.emit0 = 0;
    r.emit1 = c;
    r.status = 0;

    if (
        (
            ((((c == delimiter) or (c == escapechar)) or (c == quotechar)) or (c == 10))
            or (c == 13)
        )
        or in_lineterm
    ) {
        if (quoting == 3) {
            want_escape = 1;
        } else {
            if (c == quotechar) {
                if doublequote {
                    r.rec_len = rec_len + 1;
                    r.emit0 = quotechar;
                    r.n_emit = 2;
                } else {
                    want_escape = 1;
                }
            } elif (c == escapechar) {
                want_escape = 1;
            }
            if not want_escape {
                r.quoted = 1;
            }
        }

        if want_escape {
            if (escapechar == -1) {
                r.status = -1;
                return r;
            }

            r.rec_len = rec_len + 1;
            r.emit0 = escapechar;
            r.n_emit = 2;
        }
    }

    r.rec_len = r.rec_len + 1;
    return r;
}


def csv_writer_quoted_flag(
    quoting: int, is_number: int, is_str: int, is_none: int
) -> int {
    if (quoting == 2) {
        return not is_number;
    }
    if (quoting == 1) {
        return 1;
    }
    if (quoting == 4) {
        return is_str;
    }
    if (quoting == 5) {
        return not is_none;
    }
    return 0;
}


def csv_join_empty_space_guard(
    field_len_nonzero: int,
    null_field: int,
    quoting: int,
    delimiter_is_space: int,
    skipinitialspace: int
) -> int {
    if ((not field_len_nonzero and delimiter_is_space) and skipinitialspace) {
        if ((quoting == 3) or (null_field and ((quoting == 4) or (quoting == 5)))) {
            return 2;
        }
        return 1;
    }

    return 0;
}


def csv_join_empty_record_guard(
    num_fields: int, rec_len: int, null_field: int, quoting: int
) -> int {
    if ((num_fields > 0) and (rec_len == 0)) {
        if ((quoting == 3) or (null_field and ((quoting == 4) or (quoting == 5)))) {
            return 2;
        }
        return 1;
    }

    return 0;
}
