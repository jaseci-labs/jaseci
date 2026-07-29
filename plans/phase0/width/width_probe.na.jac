glob _ESC_BYTE: int = 27,
     _BEL_BYTE: int = 7,
     _CSI_INTRO: int = 91,
     _OSC_INTRO: int = 93,
     _APC_INTRO: int = 95,
     _ST_BACKSLASH: int = 92,
     _ASCII_PRINT_LO: int = 32,
     _ASCII_PRINT_HI: int = 126,
     _CSI_FINAL_LO: int = 64,
     _CSI_FINAL_HI: int = 126,
     _UTF8_LEAD_MIN: int = 194,
     _UTF8_LEAD_4: int = 240,
     _UTF8_LEAD_3: int = 224,
     _UTF8_LEAD_2: int = 192,
     _TRUNC_MARK: str = "~";

def _is_csi_final(c: int) -> bool {
    return c >= _CSI_FINAL_LO and c <= _CSI_FINAL_HI;
}

def _utf8_seq_len(lead: int) -> int {
    if lead >= _UTF8_LEAD_4 {
        return 4;
    }
    if lead >= _UTF8_LEAD_3 {
        return 3;
    }
    if lead >= _UTF8_LEAD_2 {
        return 2;
    }
    return 1;
}

def _skip_ansi_at(s: str, i: int) -> int {
    n = len(s);
    if i + 1 >= n {
        return i + 1;
    }
    intro = ord(s[i + 1]);
    if intro == _CSI_INTRO {
        j = i + 2;
        while j < n and not _is_csi_final(ord(s[j])) {
            j += 1;
        }
        return j + 1;
    }
    if intro == _OSC_INTRO or intro == _APC_INTRO {
        j = i + 2;
        while j < n {
            bc = ord(s[j]);
            if bc == _BEL_BYTE {
                return j + 1;
            }
            if bc == _ESC_BYTE and j + 1 < n and ord(s[j + 1]) == _ST_BACKSLASH {
                return j + 2;
            }
            j += 1;
        }
        return j;
    }
    return i + 2;
}

def visible_width(s: str) -> int {
    n = len(s);
    if n == 0 {
        return 0;
    }
    w: int = 0;
    i: int = 0;
    while i < n {
        c = ord(s[i]);
        if c == _ESC_BYTE {
            i = _skip_ansi_at(s, i);
            continue;
        }
        if c >= _ASCII_PRINT_LO and c <= _ASCII_PRINT_HI {
            w += 1;
            i += 1;
            continue;
        }
        if c >= _UTF8_LEAD_MIN {
            w += 1;
            i += _utf8_seq_len(c);
            continue;
        }
        i += 1;
    }
    return w;
}

def ansi_trunc(s: str, width: int) -> str {
    if width <= 0 {
        return "";
    }
    if visible_width(s) <= width {
        return s;
    }
    target = width - 1;
    parts: list[str] = [];
    vis: int = 0;
    i: int = 0;
    n = len(s);
    while i < n and vis < target {
        c = ord(s[i]);
        if c == _ESC_BYTE {
            j = _skip_ansi_at(s, i);
            parts.append(s[i:j]);
            i = j;
            continue;
        }
        if c >= _ASCII_PRINT_LO and c <= _ASCII_PRINT_HI {
            parts.append(s[i]);
            vis += 1;
            i += 1;
            continue;
        }
        if c >= _UTF8_LEAD_MIN {
            end_j = min(i + _utf8_seq_len(c), n);
            parts.append(s[i:end_j]);
            vis += 1;
            i = end_j;
            continue;
        }
        i += 1;
    }
    return "".join(parts) + _TRUNC_MARK;
}

def ansi_pad(s: str, width: int) -> str {
    vw = visible_width(s);
    if vw >= width {
        return s;
    }
    return s + " " * (width - vw);
}

def _check(label: str, ok: bool) {
    if ok {
        print("PASS " + label);
    } else {
        print("FAIL " + label);
    }
}

with entry {
    _check("W1_empty", visible_width("") == 0);
    _check("W2_ascii", visible_width("abc") == 3);
}

glob colored = "a" + "\x1b[31m" + "b" + "\x1b[0m" + "c";
with entry {
    _check("W3_ansi_skipped", visible_width(colored) == 3);
}
glob trunc = ansi_trunc("hello", 3);
with entry {
    _check("W4_trunc", trunc == "he~" and visible_width(trunc) == 3);
}
glob padded = ansi_pad("hi", 5);
with entry {
    _check("W5_pad", padded == "hi   " and visible_width(padded) == 5);
    _check("W6_emoji_one_cell", visible_width("😀") == 1);
}

glob t40 = ansi_trunc("abcdefghijklmnopqrstuvwxyz", 10);
with entry {
    _check("W7_trunc_bound", visible_width(t40) <= 10);
}
