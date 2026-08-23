# Converted CPython numeric-suite coverage: differential replay pins.
#
# Source corpus: reference/cpython/Lib/test/{test_int,test_float,test_long,
# test_range}.py -- behavioral assertions only (unittest scaffolding, mocks,
# pickling internals, int-max-str-digits DoS-limit configuration, and
# whitelisted-box internals dropped).
#
# Mechanism (test_hash_convert.jac idiom, extended to live differential):
# each case is a (setup, expr) pair. The wrapper
#     <setup>
#     try:
#         r = (<expr>)
#     except BaseException as e:
#         r = type(e).__name__ + ': ' + str(e)
# is compiled by the host-oracle CPython (JACPYTHON_CPYTHON-pinned 3.14 via
# host_compile_marshal), then `r` is computed TWICE -- once by jacpython's
# ceval (exec_code over the unmarshaled PyCode) and once by a batched eval
# under the same pinned host interpreter -- and the two outcome strings
# (repr of the value, or "Type: message") must match byte-exact. Signed-zero,
# NaN, and precision-sensitive cases go through repr so sign and digit
# fidelity are pinned, not just equality-class.

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, PyError, is_error }

import os;
import shutil;
import subprocess;
import json;

# Host side of the differential: read a JSON array of wrapped sources, exec
# each, print a JSON array of outcome strings. Mirrors _vm_outcome exactly.
glob _HOST_DRIVER = (
    "import sys, json\n"
    "out = []\n"
    "for s in json.loads(sys.stdin.read()):\n"
    "    ns = {'__name__': '__main__'}\n"
    "    try:\n"
    "        exec(compile(s, '<conv>', 'exec'), ns)\n"
    "        res = repr(ns.get('r'))\n"
    "    except BaseException as e:\n"
    "        res = type(e).__name__ + ': ' + str(e)\n"
    "    out.append(res)\n"
    "print(json.dumps(out))\n"
);

def _cpython_exe() -> str {
    env = os.environ.get("JACPYTHON_CPYTHON");
    if env {
        return env;
    }
    found = shutil.which("python3.14");
    if found {
        return found;
    }
    return "python3";
}

def _wrap(setup: str, expr: str) -> str {
    return setup + "\ntry:\n    r = (" + expr + ")\n"
        + "except BaseException as e:\n"
        + "    r = type(e).__name__ + ': ' + str(e)\n";
}

def _vm_outcome(src: str) -> str {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<conv_numeric>", "exec")), [], ns
    );
    if is_error(outcome) {
        exc = (outcome as PyError).exception;
        return exc.type_name + ": " + exc.message;
    }
    return repr(to_host(ns["r"]));
}

def _host_outcomes(srcs: list[str]) -> list[str] {
    proc = subprocess.run(
        [_cpython_exe(), "-c", _HOST_DRIVER],
        input=json.dumps(srcs), capture_output=True, text=True, check=True
    );
    return json.loads(proc.stdout);
}

# Differential core: every (setup, expr) pair must produce the identical
# outcome string on ceval and on the pinned host CPython.
def diff_cases(cases: list[list[str]]) {
    srcs: list[str] = [];
    for c in cases {
        srcs.append(_wrap(c[0], c[1]));
    }
    host = _host_outcomes(srcs);
    assert len(host) == len(cases), "host driver lost cases";
    i = 0;
    while i < len(cases) {
        got = _vm_outcome(srcs[i]);
        assert got == host[i],
            "case: " + cases[i][1] + "\n  vm   = " + got + "\n  host = "
            + host[i];
        i = i + 1;
    }
}

# ---- stem: test_int.py ------------------------------------------------------

test "conv/int: parsing (basics, whitespace, unicode digits)" {
    diff_cases([
        ["", "int('10')"],
        ["", "int('-10')"],
        ["", "int('+10')"],
        ["", "int(' 10 ')"],
        ["", "int('-0')"],
        ["", "int('00')"],
        ["", "int()"],
        ["", "int('١٢٣٤٥٦٧٨٩٠')"],
        ["", "int('१२३४५६७८९०1234567890')"],
        ["", "int('１２３')"],
    ]);
}

test "conv/int: parse errors (invalid signs, literals, float strings)" {
    diff_cases([
        ["", "int('+')"],
        ["", "int('-')"],
        ["", "int('- 1')"],
        ["", "int('+ 1')"],
        ["", "int(' + 1 ')"],
        ["", "int('a')"],
        ["", "int('1.5')"],
        ["", "int('1e1')"],
        ["", "int('')"],
        ["", "int(' ')"],
    ]);
}

test "conv/int: underscore literals" {
    diff_cases([
        ["", "int('1_00', 3)"],
        ["", "int('0_100')"],
        ["", "int(b'1_00')"],
        ["", "int('_100')"],
        ["", "int('+_100')"],
        ["", "int('1__00')"],
        ["", "int('100_')"],
    ]);
}

test "conv/int: constructor arity, keywords, base limits and types" {
    diff_cases([
        ["", "int(None)"],
        ["", "int('100', base=2)"],
        ["", "int(x=1.2)"],
        ["", "int(x='100', base=2)"],
        ["", "int(base=10)"],
        ["", "int('0', 5)"],
        ["", "int('0', 36)"],
        ["", "int('0', 1)"],
        ["", "int('0', 37)"],
        ["", "int('0', -909)"],
        ["", "int('0', base=2**234)"],
        ["", "int('0', base=-(2**234))"],
        ["", "int('0', 5.5)"],
        ["", "int('0', 5.0)"],
        ["", "int('43', base=2**100)"],
    ]);
}

test "conv/int: truncation from float/bool and big-int identity" {
    diff_cases([
        ["", "int(1.9)"],
        ["", "int(-1.9)"],
        ["", "int(2.5)"],
        ["", "int(-2.5)"],
        ["", "int(True)"],
        ["", "int(False)"],
        ["", "int(10**30)"],
    ]);
}

test "conv/int: arithmetic (floordiv/mod negatives, pow, divmod)" {
    diff_cases([
        ["", "divmod(-7, 2)"],
        ["", "-7 // 2"],
        ["", "-7 % 2"],
        ["", "17 // -5"],
        ["", "2 ** 10"],
        ["", "(-2) ** 3"],
        ["", "0 ** 0"],
        ["", "pow(2, 100, 7)"],
        ["", "round(-25, -1)"],
        ["", "round(7, None)"],
    ]);
}

test "conv/int: methods (bit_length, bit_count, to/from_bytes)" {
    diff_cases([
        ["", "(1024).bit_length()"],
        ["", "(-1024).bit_length()"],
        ["", "(255).bit_count()"],
        ["", "(0).bit_count()"],
        ["", "(1024).to_bytes(4, 'little')"],
        ["", "(1024).to_bytes(2, 'big')"],
        ["", "(0).to_bytes(0, 'big')"],
        ["", "int.from_bytes(b'\\x01\\x00', 'little')"],
        ["", "(2**64).to_bytes(9, 'little')"],
    ]);
}

# ---- stem: test_float.py ----------------------------------------------------

test "conv/float: parsing (literals, underscores, specials, bytes)" {
    diff_cases([
        ["", "float('1.5')"],
        ["", "float('.5')"],
        ["", "float('5.')"],
        ["", "float('-0.0')"],
        ["", "float('1_000.5')"],
        ["", "float('inf')"],
        ["", "float('-Infinity')"],
        ["", "float('+iNf')"],
        ["", "float('nan')"],
        ["", "float('1e310')"],
        ["", "float(' 3.14 ')"],
        ["", "float(b'1.2')"],
        ["", "float()"],
        ["", "float(None)"],
        ["", "float('')"],
        ["", "float(' ')"],
        ["", "float('_1.5')"],
        ["", "float('1_.5')"],
    ]);
}

test "conv/float: arithmetic repr fidelity (overflow, division, sqrt)" {
    diff_cases([
        ["", "repr(1e308 * 10)"],
        ["", "repr(-1e308 * 10)"],
        ["", "repr(1.0 / 3)"],
        ["", "repr(0.1 + 0.2)"],
        ["", "repr(2.0 ** 0.5)"],
        ["", "repr((-2.0) ** 3)"],
        ["", "repr(0.0 ** 0.0)"],
        ["", "repr(float('nan') ** 0)"],
        ["", "repr(1.0 ** float('nan'))"],
        ["", "repr((-1.0) ** 0.5)"],
        ["", "0.0 ** -1"],
        ["", "2.0 ** 10000"],
    ]);
}

test "conv/float: % special-case sign-of-zero table (F.9.4.4-style)" {
    diff_cases([
        ["", "repr((-1.0) % 1.0)"],
        ["", "repr((-1e-100) % 1.0)"],
        ["", "repr((-0.0) % 1.0)"],
        ["", "repr(0.0 % 1.0)"],
        ["", "repr(1e-100 % 1.0)"],
        ["", "repr(1.0 % 1.0)"],
        ["", "repr((-1.0) % (-1.0))"],
        ["", "repr((-1e-100) % (-1.0))"],
        ["", "repr((-0.0) % (-1.0))"],
        ["", "repr(0.0 % (-1.0))"],
        ["", "repr(1e-100 % (-1.0))"],
        ["", "repr(1.0 % (-1.0))"],
    ]);
}

test "conv/float: floordiv and banker's rounding table" {
    diff_cases([
        ["", "repr(1.75 // 0.5)"],
        ["", "repr((-1.75) // 0.5)"],
        ["", "repr(1.75 // (-0.5))"],
        ["", "repr(round(0.5))"],
        ["", "repr(round(1.5))"],
        ["", "repr(round(2.5))"],
        ["", "repr(round(-0.5))"],
        ["", "repr(round(25.0, -1))"],
        ["", "repr(round(35.0, -1))"],
        ["", "repr(round(45.0, -1))"],
        ["", "repr(round(55.0, -1))"],
        ["", "repr(round(65.0, -1))"],
        ["", "repr(round(75.0, -1))"],
        ["", "repr(round(85.0, -1))"],
        ["", "repr(round(95.0, -1))"],
        ["", "repr(round(562949953421312.5, 1))"],
        ["", "repr(round(2.675, 2))"],
    ]);
}

test "conv/float: round specials (inf/nan, bad ndigits)" {
    diff_cases([
        ["", "round(float('inf'))"],
        ["", "round(float('-inf'))"],
        ["", "round(float('nan'))"],
        ["", "round(float('inf'), 0.0)"],
        ["", "round(float('nan'), 'x')"],
        ["", "repr(round(float('inf'), 0))"],
        ["", "repr(round(float('-inf'), 0))"],
        ["", "round(1.6e308, -308)"],
    ]);
}

test "conv/float: methods (as_integer_ratio, hex, is_integer)" {
    diff_cases([
        ["", "repr((2.5).as_integer_ratio())"],
        ["", "repr((0.0).as_integer_ratio())"],
        ["", "repr((-0.0).as_integer_ratio())"],
        ["", "float('inf').as_integer_ratio()"],
        ["", "(1.5).hex()"],
        ["", "float.fromhex((1.5).hex()) == 1.5"],
        ["", "repr(float.fromhex('inf'))"],
        ["", "(2.0).is_integer()"],
        ["", "(2.1).is_integer()"],
    ]);
}

test "conv/float: short-repr roundtrip digits (test_short_repr sample)" {
    diff_cases([
        ["", "repr(float('0.03'))"],
        ["", "repr(float('1e+16'))"],
        ["", "repr(float('-1e+16'))"],
        ["", "repr(float('1e-05'))"],
        ["", "repr(float('9.999999999999e-05'))"],
        ["", "repr(float('8.72293771110361e+25'))"],
        ["", "repr(float('1000000000000000.0'))"],
    ]);
}

test "conv/float: formatting (%-style and format())" {
    diff_cases([
        ["", "format(1.5, '.2f')"],
        ["", "format(1e300, '.3g')"],
        ["", "format(0.000001, 'e')"],
        ["", "'%e' % 1.5"],
        ["", "'%.2e' % 1234.5678"],
    ]);
}

# ---- stem: test_long.py (big-int semantics survive in int) ------------------

test "conv/long: huge-int arithmetic, shifts, bitwise, divmod" {
    diff_cases([
        ["", "repr(2**100)"],
        ["", "repr((2**100) * (2**100))"],
        ["", "repr((2**101) // 3)"],
        ["", "repr((2**101) % 3)"],
        ["", "repr(divmod(2**101, 3))"],
        ["", "repr(1 << 200)"],
        ["", "1 << (-1)"],
        ["", "repr((-(2**150)) >> 70)"],
        ["", "repr((2**100) >> 100)"],
        ["", "repr((2**100) | (2**50))"],
        ["", "repr((2**100) & ((2**50) - 1))"],
        ["", "repr(~0)"],
        ["", "repr(~(2**64))"],
        ["", "repr((-2) ** 69)"],
    ]);
}

test "conv/long: conversions (str/hex/oct/bin roundtrip, truediv, hash)" {
    diff_cases([
        ["", "repr(pow(3, 5, 13))"],
        ["", "pow(2, 100, 0)"],
        ["", "repr(abs(-(2**64)))"],
        ["", "repr(bool(2**64))"],
        ["", "repr(hex(2**68))"],
        ["", "repr(oct(64))"],
        ["", "repr(bin(10))"],
        ["", "repr(int(hex(2**100), 16))"],
        ["", "repr(str(-(2**100)))"],
        ["", "repr((2**100) / 3)"],
        ["", "repr(min(2**64, 2**63))"],
        ["", "repr(hash(2**100))"],
    ]);
}

# ---- stem: test_range.py ----------------------------------------------------

test "conv/range: construction and materialization" {
    diff_cases([
        ["", "list(range(3))"],
        ["", "list(range(1, 5))"],
        ["", "list(range(0))"],
        ["", "list(range(-3))"],
        ["", "list(range(1, 10, 3))"],
        ["", "list(range(5, -5, -3))"],
        ["", "list(range(10, 12))"],
        ["", "list(range(12, 10, -1))"],
        ["", "list(range(14, 10, -2))"],
        ["", "repr(range(1, 10, 3))"],
        ["", "repr(range(4))"],
        ["", "repr(range(0))"],
        ["", "repr(range(10, 0, -3))"],
        ["", "(range(2, 10, 3)).start"],
        ["", "(range(2, 10, 3)).stop"],
        ["", "(range(2, 10, 3)).step"],
        ["", "repr(bool(range(0)))"],
        ["", "repr(bool(range(1)))"],
    ]);
}

test "conv/range: constructor errors (arity, zero step, bad types)" {
    diff_cases([
        ["", "range()"],
        ["", "range(1, 2, 3, 4, 5, 6)"],
        ["", "range(1, 2, 0)"],
        ["", "range(0.0, 2, 1)"],
        ["", "range(1, 2.0, 1)"],
        ["", "range(1, 2, 1.0)"],
        ["", "range(1e100, 1e101, 1e101)"],
        ["", "range(0, 'spam')"],
        ["", "range('spam')"],
        ["", "range(None)"],
    ]);
}

test "conv/range: len over large operands" {
    diff_cases([
        ["", "len(range(10**20, 10**20 + 10, 3))"],
        ["", "len(range(10**20 + 10, 10**20, 3))"],
        ["", "len(range(10**20, 10**20 + 10, -3))"],
        ["", "len(range(0, 2**63, 2**63 - 1))"],
        ["", "len(range(0, -(2**100), -(2**50)))"],
        ["", "repr(not range(10**20 + 10, 10**20, 3))"],
    ]);
}

test "conv/range: contains and index/count" {
    diff_cases([
        ["", "repr(5.0 in range(10))"],
        ["", "repr(5.1 in range(10))"],
        ["", "repr(-1 in range(10))"],
        ["", "repr(10 in range(10))"],
        ["", "repr('' in range(10))"],
        ["", "repr(0 in range(9, -1, -1))"],
        ["", "repr(5.0 in range(0, 10, 2))"],
        ["", "repr(1 in range(9, -1, -2))"],
        ["", "range(10).index(3)"],
        ["", "range(10).index(10)"],
        ["", "range(10).count(5)"],
        ["", "range(10).count(5.5)"],
        ["", "range(10).count('s')"],
        ["", "range(0, 10, 2).count(4)"],
    ]);
}

test "conv/range: slicing and reversed iteration" {
    diff_cases([
        ["", "list(range(10)[2:8:2])"],
        ["", "list(range(10)[0:20])"],
        ["", "list(range(10)[20:30])"],
        ["", "list(range(10)[-30:-20])"],
        ["", "list(range(10)[-1:100:2])"],
        ["", "list(range(10)[0:-1])"],
        ["", "list(range(10)[-1:-3:-1])"],
        ["", "list(range(8, 0, -3)[-1:-3:-1])"],
        ["", "len(range(1, 9, 3)[:])"],
        ["", "list(reversed(range(10)))"],
        ["", "list(reversed(range(8, 0, -3)))"],
        ["", "list(reversed(range(0)))"],
    ]);
}

test "conv/range: equality/hash semantics and order-comparison refusal" {
    diff_cases([
        ["", "repr(range(0) == range(0))"],
        ["", "repr(range(0, 2) == range(0, 3, 2))"],
        ["", "repr(range(0, 2**100 - 1, 2) == range(0, 2**100, 2))"],
        ["", "repr(hash(range(0, 2**100 - 1, 2)) == hash(range(0, 2**100, 2)))"],
        ["", "repr(range(2**200, 2**201 - 2**99, 2**100) == range(2**200, 2**201, 2**100))"],
        ["", "repr(range(0) == ())"],
        ["", "repr(() == range(0))"],
        ["", "repr(range(2) == [0, 1])"],
        ["", "range(0) < range(0)"],
        ["", "range(0) > range(0)"],
        ["", "range(0) <= range(0)"],
        ["", "range(0) >= range(0)"],
    ]);
}

test "conv/range: iterator protocol through exhaustion" {
    setup =
        "def drain(it):\n"
        "    out = []\n"
        "    try:\n"
        "        while True:\n"
        "            out.append(next(it))\n"
        "    except StopIteration:\n"
        "        pass\n"
        "    return out\n";
    diff_cases([
        [setup, "drain(iter(range(3)))"],
        [setup, "drain(iter(range(0)))"],
        [setup, "drain(iter(range(2, 10, 3)))"],
        [setup, "drain(reversed(range(4)))"],
        [setup, "drain(iter(range(10**20, 10**20 + 10, 3)))"],
        [setup, "next(iter(range(5, -5, -3)))"],
    ]);
}
