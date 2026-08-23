# Numeric method + conversion surface pins (int/float/bool lane).
#
# Pins the int/float method surface, constructor parsing, and conversion edges
# against host CPython wording, plus the lane's gap fixes:
#   - int << huge-shift raises guest OverflowError "too many digits in
#     integer" instead of a fatal runtime error (PyInt.nb_binop guard),
#   - 0 ** -negative uses the INT ZeroDivisionError wording ("zero to a
#     negative power"), not the float slot's "0.0 cannot be raised...",
#   - bool vs float equality is a real value compare (True == 1.0,
#     False == -0.0), never the identity fallback,
#   - explicit-base int(x, base) carries builtin-mixin operands across with
#     their boxed base value (int(str_sub('ff'), 16) == 255).

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<num_methods>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(expr: str) -> str {
    ns = vm_exec(
        "try:\n"
        "    r = " + expr + "\n"
        "except Exception as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    );
    return repr(to_host(ns["r"]));
}

def vm_val(expr: str) -> any {
    ns = vm_exec("r = " + expr + "\n");
    return to_host(ns["r"]);
}

test "num: int bit_length and bit_count" {
    assert vm_val("(5).bit_length()") == 3;
    assert vm_val("(0).bit_length()") == 0;
    assert vm_val("(-5).bit_length()") == 3;
    assert vm_val("(2**100).bit_length()") == 101;
    assert vm_val("(5).bit_count()") == 2;
    assert vm_val("(-1).bit_count()") == 1;
    assert vm_val("(2**64 - 1).bit_count()") == 64;
}

test "num: int.to_bytes arg forms and overflow" {
    assert vm_val("(256).to_bytes(2, 'little')") == bytes([0, 1]);
    assert vm_val("(1024).to_bytes(2)") == bytes([4, 0]);
    assert vm_val("(5).to_bytes(length=2, byteorder='big')") == bytes([0, 5]);
    assert vm_val("(-1).to_bytes(2, 'little', signed=True)") == bytes([0xff, 0xff]);
    assert vm_val("(-128).to_bytes(1, 'big', signed=True)") == bytes([0x80]);
    assert vm_str("(256).to_bytes(1, 'big')")
        == "'OverflowError: int too big to convert'";
    assert vm_str("(130).to_bytes(1, 'big', signed=True)")
        == "'OverflowError: int too big to convert'";
}

test "num: int.from_bytes classmethod forms" {
    assert vm_val("int.from_bytes(b'\\x01\\x00', 'little')") == 1;
    assert vm_val("int.from_bytes(b'\\x00\\x01')") == 1;
    assert vm_val("int.from_bytes(b'\\xff\\xff', 'big', signed=True)") == -1;
    assert vm_val("int.from_bytes(b'')") == 0;
    assert vm_val("int.from_bytes(bytearray(b'\\x02'))") == 2;
    assert vm_val("int.from_bytes([1, 0], 'little')") == 1;
    assert vm_val("int.from_bytes(bytes=b'\\x01\\x00', byteorder='little')") == 1;
}

test "num: bad byteorder ValueError text is byte-exact" {
    assert vm_str("(5).to_bytes(2, 'middle')")
        == "\"ValueError: byteorder must be either 'little' or 'big'\"";
    assert vm_str("int.from_bytes(b'\\x01', 'middle')")
        == "\"ValueError: byteorder must be either 'little' or 'big'\"";
}

test "num: __index__, conjugate, numeric attributes" {
    assert vm_val("'abcdef'[True]") == "b";
    assert vm_val("__import__('operator').index(7)") == 7;
    assert vm_val("(-5).conjugate()") == -5;
    assert vm_val("(5).numerator") == 5;
    assert vm_val("(5).denominator") == 1;
    assert vm_val("(5).imag") == 0;
    assert vm_val("(2.5).real") == 2.5;
    assert vm_val("(2.5).imag") == 0.0;
}

test "num: float.hex / fromhex round trips" {
    assert vm_val("(255.0).hex()") == "0x1.fe00000000000p+7";
    assert vm_val("(-0.0).hex()") == "-0x0.0p+0";
    assert vm_val("(5e-324).hex()") == "0x0.0000000000001p-1022";
    assert vm_val("(2.2250738585072014e-308).hex()")
        == "0x1.0000000000000p-1022";
    assert vm_val("float.fromhex((2.5).hex()) == 2.5");
    assert vm_val("float.fromhex('-Infinity')") == float("-inf");
    assert vm_val("str(float.fromhex('nan'))") == "nan";
    assert vm_val("float.fromhex('-0x1.8p+1')") == -3.0;
    assert vm_val("float.fromhex('0x1.fffffffffffffp+1023')")
        == 1.7976931348623157e+308;
}

test "num: float as_integer_ratio and is_integer" {
    assert vm_val("(3.75).as_integer_ratio()") == (15, 4);
    assert vm_val("(0.0).as_integer_ratio()") == (0, 1);
    assert vm_val("(-2.5).as_integer_ratio()") == (-5, 2);
    assert vm_str("float('inf').as_integer_ratio()")
        == "'OverflowError: cannot convert Infinity to integer ratio'";
    assert vm_str("float('nan').as_integer_ratio()")
        == "'ValueError: cannot convert NaN to integer ratio'";
    assert vm_val("(2.0).is_integer()");
    assert not vm_val("(2.5).is_integer()");
    assert vm_val("(-0.0).is_integer()");
}

test "num: int() parsing bases, prefixes, underscores" {
    assert vm_val("int('0b101', 2)") == 5;
    assert vm_val("int('0b101', 0)") == 5;
    assert vm_val("int('0o17', 0)") == 15;
    assert vm_val("int('ff', 16)") == 255;
    assert vm_val("int('z', 36)") == 35;
    assert vm_val("int('1_000')") == 1000;
    assert vm_val("int('1_0_1', 2)") == 5;
    assert vm_val("int(b'a', 16)") == 10;
    assert vm_val("int('  42  ')") == 42;
    assert vm_str("int('_100')")
        == "\"ValueError: invalid literal for int() with base 10: '_100'\"";
    assert vm_str("int('12', 37)")
        == "'ValueError: int() base must be >= 2 and <= 36, or 0'";
    assert vm_str("int('08', 0)")
        == "\"ValueError: invalid literal for int() with base 0: '08'\"";
    assert vm_str("int(True, 2)")
        == "\"TypeError: int() can't convert non-string with explicit base\"";
}

test "num: float() parsing inf/nan forms and underscores" {
    assert vm_val("float('1_000.5')") == 1000.5;
    assert vm_val("float('+inF')") == float("inf");
    assert vm_val("float('-NAN') != float('-NAN')");
    assert vm_val("float('.5')") == 0.5;
    assert vm_val("float('1e400')") == float("inf");
    assert vm_val("float(b'2.5')") == 2.5;
    assert vm_str("float('_1.5')")
        == "\"ValueError: could not convert string to float: '_1.5'\"";
    assert vm_str("float(None)")
        == "\"TypeError: float() argument must be a string or a real number,"
        " not 'NoneType'\"";
}

test "num: int(float) truncation and boundary errors" {
    assert vm_val("int(3.99)") == 3;
    assert vm_val("int(-3.99)") == -3;
    assert vm_val("int(2**53 + 1.0)") == 9007199254740992;
    assert vm_str("int(float('inf'))")
        == "'OverflowError: cannot convert float infinity to integer'";
    assert vm_str("int(float('nan'))")
        == "'ValueError: cannot convert float NaN to integer'";
    assert vm_val("int(10**400) if False else "
        "(float(10**308) * 10 == float('inf'))");
}

test "num: huge left shift raises guest OverflowError" {
    # Was a fatal runtime error before the nb_binop shift-bound guard.
    assert vm_str("1 << 2**70")
        == "'OverflowError: too many digits in integer'";
    assert vm_val("(2**64) >> 2**70") == 0;
}

test "num: 0 ** negative uses the int ZeroDivisionError wording" {
    assert vm_str("0 ** -2")
        == "'ZeroDivisionError: zero to a negative power'";
    assert vm_str("0 ** -1")
        == "'ZeroDivisionError: zero to a negative power'";
}

test "num: bool vs float equality is a value compare" {
    assert vm_val("True == 1.0");
    assert vm_val("False == -0.0");
    assert vm_val("False == 0.0");
    assert vm_val("True != 2.5");
    assert vm_val("1.0 == True");
    assert vm_val("-0.0 == False");
    assert vm_val("True <= 1.0");
    assert vm_val("True >= 1.0");
    assert not vm_val("True < 1.0");
}

test "num: bool-as-int arithmetic stays int-valued" {
    assert vm_val("True + True") == 2;
    assert vm_val("type(True + True).__name__") == "int";
    assert vm_val("type(True * 1).__name__") == "int";
    assert vm_val("type(True / 1).__name__") == "float";
    assert vm_val("True.bit_length()") == 1;
    assert vm_val("True.to_bytes(1, 'big')") == bytes([1]);
    assert vm_val("hash(True) == hash(1) == hash(1.0)");
}

test "num: explicit-base int over builtin-mixin subclass carries the base" {
    ns = vm_exec(
        "class S(str):\n"
        "    pass\n"
        "r1 = int(S('ff'), 16)\n"
        "class I(int):\n"
        "    pass\n"
        "try:\n"
        "    r2 = int(I(7), 10)\n"
        "except TypeError as e:\n"
        "    r2 = 'TypeError: ' + str(e)\n"
        "r3 = int(S('101'), base=2)\n"
    );
    assert to_host(ns["r1"]) == 255;
    assert to_host(ns["r2"])
        == "TypeError: int() can't convert non-string with explicit base";
    assert to_host(ns["r3"]) == 5;
}
