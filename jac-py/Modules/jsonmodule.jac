# c2jac: 15 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L127 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L128 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L129 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L130 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L135 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L136 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L137 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L138 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L152 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L153 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L171 [W4201] cast to `Py_UCS1` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L293 [W4201] cast to `Py_UCS4` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L309 [W4201] cast to `Py_UCS4` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L400 [W4201] cast to `Py_UCS4` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L400 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied

glob Py_ssize_t = int;
glob Py_UCS4 = int;
glob Py_UCS1 = int;


def json_is_whitespace(c: Py_UCS4) -> int {
    return ((((c == 32) or (c == 9)) or (c == 10)) or (c == 13));
}


def json_s_char(c: Py_UCS4) -> int {
    return ((((c >= 32) and (c <= 126)) and (c != 92)) and (c != 34));
}

def json_is_digit(c: Py_UCS4) -> int {
    return ((c >= 48) and (c <= 57));
}

def json_is_hexdigit(digit: Py_UCS4) -> int {
    if (
        (((digit >= 48) and (digit <= 57)) or ((digit >= 97) and (digit <= 102)))
        or ((digit >= 65) and (digit <= 70))
    ) {
        return 1;
    }
    return 0;
}

def json_hex_value(digit: Py_UCS4) -> int {
    if ((digit >= 48) and (digit <= 57)) {
        return (digit - 48);
    }
    if ((digit >= 97) and (digit <= 102)) {
        return ((digit - 97) + 10);
    }
    if ((digit >= 65) and (digit <= 70)) {
        return ((digit - 65) + 10);
    }
    return -1;
}


def json_escape_char_size(c: Py_UCS4) -> int {
    if json_s_char(c) {
        return 1;
    }
    if c == 92 or c == 34 or c == 8 or c == 12 or c == 10 or c == 13 or c == 9 {
        return 2;
    } else {
        return 12 if (c >= 65536) else 6;
    }
}

def json_high_surrogate(c: Py_UCS4) -> Py_UCS4 {
    return (55296 + ((c - 65536) >> 10));
}

def json_low_surrogate(c: Py_UCS4) -> Py_UCS4 {
    return (56320 + ((c - 65536) & 1023));
}

def json_is_high_surrogate(c: Py_UCS4) -> int {
    return ((c >= 55296) and (c <= 56319));
}

def json_is_low_surrogate(c: Py_UCS4) -> int {
    return ((c >= 56320) and (c <= 57343));
}

def json_join_surrogates(h: Py_UCS4, l: Py_UCS4) -> Py_UCS4 {
    return (65536 + (((h - 55296) << 10) | (l - 56320)));
}


def json_ascii_escape_unichar(c: Py_UCS4, output: Py_UCS1, chars: int) -> int {
    output[(chars := chars + 1 - 1)] = 92;
    if c == 92 {
        output[(chars := chars + 1 - 1)] = 92;
    } elif c == 34 {
        output[(chars := chars + 1 - 1)] = 34;
    } elif c == 8 {
        output[(chars := chars + 1 - 1)] = 98;
    } elif c == 12 {
        output[(chars := chars + 1 - 1)] = 102;
    } elif c == 10 {
        output[(chars := chars + 1 - 1)] = 110;
    } elif c == 13 {
        output[(chars := chars + 1 - 1)] = 114;
    } elif c == 9 {
        output[(chars := chars + 1 - 1)] = 116;
    } else {
        if (c >= 65536) {
            v: Py_UCS4 = json_high_surrogate(c);
            output[(chars := chars + 1 - 1)] = 117;
            output[(chars := chars + 1 - 1)] = (v >> 12) & 15;
            output[(chars := chars + 1 - 1)] = (v >> 8) & 15;
            output[(chars := chars + 1 - 1)] = (v >> 4) & 15;
            output[(chars := chars + 1 - 1)] = v & 15;
            c = json_low_surrogate(c);
            output[(chars := chars + 1 - 1)] = 92;
        }
        output[(chars := chars + 1 - 1)] = 117;
        output[(chars := chars + 1 - 1)] = (c >> 12) & 15;
        output[(chars := chars + 1 - 1)] = (c >> 8) & 15;
        output[(chars := chars + 1 - 1)] = (c >> 4) & 15;
        output[(chars := chars + 1 - 1)] = c & 15;
    }

    return chars;
}


def json_ascii_escape_size(buf: Py_UCS4, len: int) -> int {
    i: int = 0;
    output_size: int = 0;
    output_size = 2;
    for i = 0 while i < len with i += 1 {
        d: int = json_escape_char_size(buf[i]);
        if (output_size > (9223372036854775807 - d)) {
            return -1;
        }
        output_size += d;
    }

    return output_size;
}


def json_ascii_escape_fill(buf: Py_UCS4, len: int, output: Py_UCS1) -> int {
    i: int = 0;
    chars: int = 0;
    output[(chars := chars + 1 - 1)] = 34;
    for i = 0 while i < len with i += 1 {
        c: Py_UCS4 = buf[i];
        if json_s_char(c) {
            output[(chars := chars + 1 - 1)] = c;
        } else {
            chars = json_ascii_escape_unichar(c, output, chars);
        }
    }

    output[(chars := chars + 1 - 1)] = 34;
    return chars;
}


def json_scanstring(
    buf: Py_UCS4,
    len: int,
    end: int,
    strict: int,
    out: Py_UCS4,
    out_cap: int,
    next_end_ptr: object,
    err_pos: object
) -> int {
    begin: int = end - 1;
    next: int = 0;
    chars: int = 0;

    if ((end < 0) or (len < end)) {
        err_pos = 0;
        next_end_ptr = -1;
        return -5;
    }

    while 1 {
        c: Py_UCS4 = 0;

        d: Py_UCS4 = 0;
        for next = end while next < len with next += 1 {
            d = buf[next];
            if ((d == 34) or (d == 92)) {
                break;
            }
            if ((d <= 31) and strict) {
                err_pos = next;
                next_end_ptr = -1;
                return -1;
            }
        }

        c = d;

        if (c == 34) {
            ;
        } elif (c != 92) {
            err_pos = begin;
            next_end_ptr = -1;
            return -2;
        }

        if (next != end) {
            k: int = 0;
            if ((chars + (next - end)) > out_cap) {
                err_pos = 0;
                next_end_ptr = -1;
                return -6;
            }

            for k = end while k < next with k += 1 {
                out[(chars := chars + 1 - 1)] = buf[k];
            }
        }

        next += 1;
        if (c == 34) {
            next_end_ptr = next;
            return chars;
        }

        if (next == len) {
            err_pos = begin;
            next_end_ptr = -1;
            return -2;
        }

        c = buf[next];
        if (c != 117) {
            end = next + 1;
            if c == 34 {
                ;
            } elif c == 92 {
                ;
            } elif c == 47 {
                ;
            } elif c == 98 {
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
                c = 0;
            }

            if (c == 0) {
                err_pos = end - 2;
                next_end_ptr = -1;
                return -3;
            }
        } else {
            c2: Py_UCS4 = Py_UCS4();
            uesc_end: int = 0;
            c = 0;
            next += 1;
            uesc_end = next + 4;
            end = uesc_end;
            if (uesc_end >= len) {
                err_pos = next - 1;
                next_end_ptr = -1;
                return -4;
            }
            while (next < uesc_end) {
                hv: int = json_hex_value(buf[next]);
                if (hv < 0) {
                    err_pos = uesc_end - 5;
                    next_end_ptr = -1;
                    return -4;
                }

                c = (c << 4) | hv;
                next += 1;
            }
            if (
                (
                    (json_is_high_surrogate(c) and ((uesc_end + 6) < len))
                    and (buf[next] == 92)
                )
                and (buf[(next + 1)] == 117)
            ) {
                next += 2;
                uesc_end += 6;
                end = uesc_end;
                c2 = 0;
                while (next < uesc_end) {
                    hv: int = json_hex_value(buf[next]);
                    if (hv < 0) {
                        err_pos = uesc_end - 5;
                        next_end_ptr = -1;
                        return -4;
                    }

                    c2 = (c2 << 4) | hv;
                    next += 1;
                }

                if json_is_low_surrogate(c2) {
                    c = json_join_surrogates(c, c2);
                } else {
                    uesc_end -= 6;
                    end = uesc_end;
                }
            }
        }

        if ((chars + 1) > out_cap) {
            err_pos = 0;
            next_end_ptr = -1;
            return -6;
        }

        out[(chars := chars + 1 - 1)] = c;
    }

    err_pos = 0;
    next_end_ptr = -1;
    return -6;
}


def json_match_number(buf: Py_UCS4, len: int, start: int, next_idx_ptr: object) -> int {
    end_idx: int = len - 1;
    idx: int = start;
    is_float: int = 0;

    if ((idx <= end_idx) and (buf[idx] == 45)) {
        idx += 1;
        if (idx > end_idx) {
            return -1;
        }
    }

    if (((idx <= end_idx) and (buf[idx] >= 49)) and (buf[idx] <= 57)) {
        idx += 1;
        while ((idx <= end_idx) and json_is_digit(buf[idx])) {
            idx += 1;
        }
    } elif ((idx <= end_idx) and (buf[idx] == 48)) {
        idx += 1;
    } else {
        return -1;
    }

    if (((idx < end_idx) and (buf[idx] == 46)) and json_is_digit(buf[(idx + 1)])) {
        is_float = 1;
        idx += 2;
        while ((idx <= end_idx) and json_is_digit(buf[idx])) {
            idx += 1;
        }
    }

    if ((idx < end_idx) and ((buf[idx] == 101) or (buf[idx] == 69))) {
        e_start: int = idx;
        idx += 1;
        if ((idx < end_idx) and ((buf[idx] == 45) or (buf[idx] == 43))) {
            idx += 1;
        }
        while ((idx <= end_idx) and json_is_digit(buf[idx])) {
            idx += 1;
        }
        if json_is_digit(buf[(idx - 1)]) {
            is_float = 1;
        } else {
            idx = e_start;
        }
    }

    next_idx_ptr = idx;
    return is_float;
}


def json_match_const(buf: Py_UCS4, len: int, idx: int, word: str, wlen: int) -> int {
    k: int = 0;
    if (((idx + wlen) - 1) >= len) {
        return 0;
    }
    for k = 0 while k < wlen with k += 1 {
        if (word[k] != buf[(idx + k)]) {
            return 0;
        }
    }

    return 1;
}
