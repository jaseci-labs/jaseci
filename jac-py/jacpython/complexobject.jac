# P3.2c — complex core (hash, repr, string parsing).
#
# Lift: Objects/_lifted/complexobject_core.jac. Pure-arithmetic pieces live in
# objects.jac next to the PyComplex slots; this module adds what needs float
# formatting / text scanning, mirroring CPython 3.14 byte-for-byte.
import from objects { PyComplex, PyInt, PyObj, _signed_hash, }
import from pyhash { float_hash_value, _U64, }

glob _PyHASH_IMAG: int = 1000003;

def complex_hash_combine(hashreal: int, hashimag: int) -> int {
    if hashreal == -1 or hashimag == -1 {
        return -1;
    }
    combined = hashreal + _PyHASH_IMAG * hashimag;
    if combined == -1 {
        return -2;
    }
    return combined;
}

def complex_imag_is_zero(c: PyComplex) -> bool {
    return c.imag == 0.0;
}

# CPython complex_hash: hash(real) + _PyHASH_IMAG * hash(imag), masked to
# 64 bits and folded so the all-ones pattern reports as -2. NaN parts take
# the object-pointer hash (float_hash_value), matching _Py_HashDouble.
def complex_hash_obj(v: PyComplex) -> PyObj {
    hr = float_hash_value(v.real, id(v));
    hi = float_hash_value(v.imag, id(v));
    m = (hr + _PyHASH_IMAG * hi) & _U64;
    if m == _U64 {
        return PyInt(t="int", val=-2);
    }
    return PyInt(t="int", val=_signed_hash(m));
}

# ---------------- repr / str ----------------
# Shortest round-trip digits via the floatobject idiom (smallest %.Ne that
# re-parses), rendered WITHOUT float's forced ".0" and with complex's own
# fixed/exponential switch (decpt <= -4 or > 16), exponent >= 2 digits.

def _cpx_shortest_digits(d: float) -> tuple[str, int] {
    # Returns (digit string without sign/point, decimal exponent of the first
    # digit). d must be finite and nonzero.
    p = 0;
    best = "";
    while p <= 17 {
        candidate = f"{d:.{p}e}";
        if float(candidate) == d {
            best = candidate;
            break;
        }
        p = p + 1;
    }
    if best == "" {
        p = 17;
        best = f"{d:.17e}";
    }
    epos = -1;
    i = 0;
    while i < len(best) {
        if best[i] == "e" {
            epos = i;
            break;
        }
        i = i + 1;
    }
    mant = "";
    i = 0;
    while i < epos {
        c = best[i];
        if c != "." and c != "-" and c != "+" {
            mant = mant + c;
        }
        i = i + 1;
    }
    expo = int(best[epos + 1:len(best)]);
    return (mant, expo);
}

# CPython's complex formatter for one component (PyOS_double_to_string 'r'
# style minus the ADD_DOT_0 flag): integral values print bare ("4", "-0").
def _cpx_float_text(d: float) -> str {
    if d != d {
        return "nan";
    }
    if d * 0.0 != 0.0 {
        if d < 0.0 {
            return "-inf";
        }
        return "inf";
    }
    neg = False;
    s0 = str(d);
    if d < 0.0 or (len(s0) > 0 and s0[0] == "-") {
        neg = True;
    }
    if d == 0.0 {
        if neg {
            return "-0";
        }
        return "0";
    }
    ad = d;
    if ad < 0.0 {
        ad = -ad;
    }
    (mant, expo) = _cpx_shortest_digits(ad);
    decpt = expo + 1;
    if decpt <= -4 or decpt > 16 {
        out = mant[0:1];
        if len(mant) > 1 {
            out = out + "." + mant[1:len(mant)];
        }
        e = expo;
        esign = "+";
        if e < 0 {
            esign = "-";
            e = -e;
        }
        pad = "";
        if e < 10 {
            pad = "0";
        }
        out = out + "e" + esign + pad + str(e);
    } elif decpt <= 0 {
        out = "0.";
        zeros = 0 - decpt;
        while zeros > 0 {
            out = out + "0";
            zeros = zeros - 1;
        }
        out = out + mant;
    } elif decpt >= len(mant) {
        out = mant;
        zeros = decpt - len(mant);
        while zeros > 0 {
            out = out + "0";
            zeros = zeros - 1;
        }
    } else {
        out = mant[0:decpt] + "." + mant[decpt:len(mant)];
    }
    if neg {
        return "-" + out;
    }
    return out;
}

# CPython complex_repr == complex_str: a +0 real prints only the imaginary
# part bare ("0j", "-2j", "nanj"); every other value is parenthesized with
# both parts even when imag is +0 ("(1+0j)", "(-0-0j)"), joined by "+" unless
# the imaginary text already carries its own "-".
def complex_repr_text(c: PyComplex) -> str {
    re = c.real;
    im = c.imag;
    if re == 0.0 {
        # Signbit check without division (Jac '/' traps on zero): str(-0.0)
        # carries the leading '-', same idiom as floatobject.
        s0 = str(re);
        if len(s0) == 0 or s0[0] != "-" {
            return _cpx_float_text(im) + "j";
        }
    }
    it = _cpx_float_text(im);
    joiner = "+";
    if len(it) > 0 and it[0] == "-" {
        joiner = "";
    }
    return "(" + _cpx_float_text(re) + joiner + it + "j)";
}

# ---------------- complex(str) parsing ----------------
# CPython complex_from_string_grammar: outer whitespace stripped; an optional
# single parenthesized form; NO internal whitespace; one or two components
# [sign] (number | word | empty-with-j); a j/J suffix makes the component the
# imaginary part and ends the parse. Two ValueError texts exist: structural
# damage is "complex() arg is a malformed string"; underscore misuse comes
# from the float layer as "could not convert string to complex: '<s>'".

def _cpx_is_space(c: str) -> bool {
    return c == " " or c == "\t" or c == "\n" or c == "\r" or c == "\v" or c == "\f";
}

def _cpx_strip_ws(s: str) -> str {
    i = 0;
    j = len(s);
    while i < j and _cpx_is_space(s[i]) {
        i = i + 1;
    }
    while j > i and _cpx_is_space(s[j - 1]) {
        j = j - 1;
    }
    return s[i:j];
}

def _cpx_is_digit(c: str) -> bool {
    return c >= "0" and c <= "9";
}

# Underscores are legal only between digits anywhere in the scanned span
# (checked against the ORIGINAL string, so signs/exponents bound correctly).
def _cpx_scan_digits(s: str, j: int, found: bool) -> tuple[int, bool, bool] {
    # Returns (next index, digits-seen, underscore-error).
    n = len(s);
    while j < n {
        c = s[j];
        if _cpx_is_digit(c) {
            found = True;
        } elif c == "_" {
            if j == 0 or not _cpx_is_digit(s[j - 1]) {
                return (j, found, True);
            }
            if j + 1 >= n or not _cpx_is_digit(s[j + 1]) {
                return (j, found, True);
            }
        } else {
            break;
        }
        j = j + 1;
    }
    return (j, found, False);
}

def _cpx_underscores_removed(text: str) -> str {
    out = "";
    for ch in text {
        if ch != "_" {
            out = out + ch;
        }
    }
    return out;
}

# One numeric literal at position i (sign already consumed): returns
# (next_index, value); next_index -1 = malformed, -2 = underscore error.
def _cpx_scan_number(s: str, i: int) -> tuple[int, float] {
    n = len(s);
    j = i;
    (j, seen, uerr) = _cpx_scan_digits(s, j, False);
    if uerr {
        return (-2, 0.0);
    }
    if j < n and s[j] == "." {
        j = j + 1;
        (j, seen2, uerr2) = _cpx_scan_digits(s, j, False);
        if uerr2 {
            return (-2, 0.0);
        }
        seen = seen or seen2;
    }
    if not seen {
        return (-1, 0.0);
    }
    if j < n and (s[j] == "e" or s[j] == "E") {
        k = j + 1;
        if k < n and (s[k] == "+" or s[k] == "-") {
            k = k + 1;
        }
        (k, edig, uerr3) = _cpx_scan_digits(s, k, False);
        if uerr3 or not edig {
            if uerr3 {
                return (-2, 0.0);
            }
            return (-1, 0.0);
        }
        j = k;
    }
    text = _cpx_underscores_removed(s[i:j]);
    return (j, float(text));
}

# Case-insensitive inf/infinity/nan at position i; (-1, 0) when absent.
def _cpx_scan_word(s: str, i: int) -> tuple[int, float] {
    low = s[i:len(s)].lower();
    if low.startswith("infinity") {
        return (i + 8, float("inf"));
    }
    if low.startswith("inf") {
        return (i + 3, float("inf"));
    }
    if low.startswith("nan") {
        return (i + 3, float("nan"));
    }
    return (-1, 0.0);
}

# One [sign](word|number|empty-j) component; (next, is_imag, val, err) where
# err: "" ok, "malformed" structural, "underscore" float-layer error.
def _cpx_scan_component(s: str, i: int) -> tuple[int, bool, float, str] {
    n = len(s);
    sign = 1.0;
    if i < n and (s[i] == "+" or s[i] == "-") {
        if s[i] == "-" {
            sign = -1.0;
        }
        i = i + 1;
    }
    if i < n and (s[i] == "j" or s[i] == "J") {
        # Empty number directly before j means +-1 ("+j", "1+j").
        return (i + 1, True, sign, "");
    }
    (wi, wv) = _cpx_scan_word(s, i);
    if wi >= 0 {
        val = wv * sign;
        if wi < n and (s[wi] == "j" or s[wi] == "J") {
            return (wi + 1, True, val, "");
        }
        return (wi, False, val, "");
    }
    (ni, nv) = _cpx_scan_number(s, i);
    if ni == -2 {
        return (ni, False, 0.0, "underscore");
    }
    if ni == -1 {
        return (ni, False, 0.0, "malformed");
    }
    val = nv * sign;
    if ni < n and (s[ni] == "j" or s[ni] == "J") {
        return (ni + 1, True, val, "");
    }
    return (ni, False, val, "");
}

def complex_parse_text(src: str) -> tuple[bool, str, float, float] {
    # (ok, error_message, real, imag)
    malformed = "complex() arg is a malformed string";
    s = _cpx_strip_ws(src);
    if len(s) >= 2 and s[0] == "(" and s[len(s) - 1] == ")" {
        # Single parenthesized form only -- no nesting -- re-stripped inside.
        s = _cpx_strip_ws(s[1:len(s) - 1]);
    }
    if s == "" {
        return (False, malformed, 0.0, 0.0);
    }
    (i, im1, v1, err) = _cpx_scan_component(s, 0);
    if err == "underscore" {
        return (
            False,
            "could not convert string to complex: '" + src + "'",
            0.0,
            0.0,
        );
    }
    if err != "" {
        return (False, malformed, 0.0, 0.0);
    }
    if im1 {
        # Imaginary first component ENDS the parse ("1j2j" is malformed).
        if i != len(s) {
            return (False, malformed, 0.0, 0.0);
        }
        return (True, "", 0.0, v1);
    }
    if i >= len(s) {
        # Real-only component ("3", "inf").
        return (True, "", v1, 0.0);
    }
    # First component was real; expect [sign]second-component ending in j.
    (i, im2, v2, err) = _cpx_scan_component(s, i);
    if err == "underscore" {
        return (
            False,
            "could not convert string to complex: '" + src + "'",
            0.0,
            0.0,
        );
    }
    if err != "" or not im2 or i != len(s) {
        return (False, malformed, 0.0, 0.0);
    }
    return (True, "", v1, v2);
}
