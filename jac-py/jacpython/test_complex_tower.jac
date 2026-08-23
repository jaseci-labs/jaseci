# Complex numeric tower fidelity (Lane C).
#
# Every assert literal below was captured verbatim from the pinned host
# python3 (3.14): repr() of the result value, or Type-plus-message strings
# when CPython raises. The vm_* helpers exec the probe through ceval
# exactly like test_ordering_typeerror_messages.jac.

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<complex_tower>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(expr: str) -> str {
    ns = vm_exec(
        "try:\n"
        "    r = repr(" + expr + ")\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    );
    return to_host(ns["r"]) as str;
}

test "complex tower: arithmetic -- add sub mul div over the tower incl inf propagation" {
    assert vm_str("(1+2j)+(3+4j)") == "(4+6j)";
    assert vm_str("(1+2j)-(3+4j)") == "(-2-2j)";
    assert vm_str("(1+2j)*(3+4j)") == "(-5+10j)";
    assert vm_str("(1+2j)/(3+4j)") == "(0.44+0.08j)";
    assert vm_str("(1e300+0j)*(1e300+0j)") == "(inf+0j)";
    assert vm_str("2-(1+2j)") == "(1-2j)";
    assert vm_str("6/(3+0j)") == "(2-0j)";
    assert vm_str("1/1j") == "-1j";
    assert vm_str("(1+2j)+2") == "(3+2j)";
    assert vm_str("True+(1+1j)") == "(2+1j)";
    assert vm_str("2*(1+2j)") == "(2+4j)";
    assert vm_str("2.5*(1+2j)") == "(2.5+5j)";
    assert vm_str("1e308*10+0j") == "(inf+0j)";
    assert vm_str("(1+2j)/0") == "ZeroDivisionError: division by zero";
    assert vm_str("(1+2j)/(0j)") == "ZeroDivisionError: division by zero";
    assert vm_str("(1+2j)//2") == "TypeError: unsupported operand type(s) for //: 'complex' and 'int'";
    assert vm_str("(1e300+0j)**2") == "OverflowError: complex exponentiation";
    assert vm_str("(1+2j)**2.5") == "(-6.960664459571901+2.7296244647840084j)";
}

test "complex tower: division-zero -- true divide by any zero raises plain division by zero" {
    assert vm_str("complex(5,5)/complex(0,0)") == "ZeroDivisionError: division by zero";
}

test "complex tower: floormod -- floor-div mod raise CPython generic binop TypeError; divmod likewise" {
    assert vm_str("2//(1+2j)") == "TypeError: unsupported operand type(s) for //: 'int' and 'complex'";
    assert vm_str("(1+2j)%2.5") == "TypeError: unsupported operand type(s) for %: 'complex' and 'float'";
    assert vm_str("divmod(1+2j,2)") == "TypeError: unsupported operand type(s) for divmod(): 'complex' and 'int'";
    assert vm_str("(3+4j)//(0+1j)") == "TypeError: unsupported operand type(s) for //: 'complex' and 'complex'";
}

test "complex tower: pow -- integer-exponent repeated squaring natively; zero and overflow rules exact" {
    assert vm_str("(1j)**2") == "(-1+0j)";
    assert vm_str("(0j)**0") == "(1+0j)";
    assert vm_str("(0j)**-1") == "ZeroDivisionError: zero to a negative or complex power";
    assert vm_str("(1+1j)**10") == "32j";
    assert vm_str("2**(3+0j)") == "(8+0j)";
    assert vm_str("(3+0j)**(-0.5)") == "(0.5773502691896257-0j)";
    assert vm_str("(2+0j)**99") == "(6.338253001141147e+29+0j)";
}

test "complex tower: comparisons -- eq ne numeric across int float bool; ordering TypeErrors" {
    assert vm_str("(1+2j)==(1+2j)") == "True";
    assert vm_str("(1+2j)!=(3+4j)") == "True";
    assert vm_str("1+0j==1") == "True";
    assert vm_str("(2+0j)==2.0") == "True";
    assert vm_str("(1+0j)==True") == "True";
    assert vm_str("(1+2j)=='a'") == "False";
    assert vm_str("(1+2j)<(3+4j)") == "TypeError: '<' not supported between instances of 'complex' and 'complex'";
    assert vm_str("(1+2j)<=1") == "TypeError: '<=' not supported between instances of 'complex' and 'int'";
    assert vm_str("complex(float('nan'),0)==float('nan')") == "False";
    assert vm_str("complex(float('nan'),0)!=float('nan')") == "True";
}

test "complex tower: hashing -- hash of complex matches host where complex equals float or int" {
    assert vm_str("hash(3+0j)==hash(3)==hash(3.0)") == "True";
    assert vm_str("hash(complex(2.5,0))==hash(2.5)") == "True";
    assert vm_str("hash(1j)") == "1000003";
    assert vm_str("hash(complex(float('inf'),0))==hash(float('inf'))") == "True";
    assert vm_str("hash(complex(-float('inf'),1))") == "685844";
    assert vm_str("hash(2+3j)") == "3000011";
}

test "complex tower: repr-str -- byte-exact str repr incl paren rules and signed zeros" {
    assert vm_str("repr(1+2j)") == "'(1+2j)'";
    assert vm_str("repr(1j)") == "'1j'";
    assert vm_str("str(3+4j)") == "'(3+4j)'";
    assert vm_str("repr(-1-2j)") == "'(-1-2j)'";
    assert vm_str("repr(1+0j)") == "'(1+0j)'";
    assert vm_str("str(1+0j)") == "'(1+0j)'";
    assert vm_str("repr(0j)") == "'0j'";
    assert vm_str("repr(-0j)") == "'(-0-0j)'";
    assert vm_str("repr(complex(0,-2))") == "'-2j'";
    assert vm_str("repr(-(1+2j))") == "'(-1-2j)'";
    assert vm_str("repr(complex(float('inf'),1))") == "'(inf+1j)'";
    assert vm_str("repr(complex(1,float('nan')))") == "'(1+nanj)'";
    assert vm_str("repr(complex(0,float('nan')))") == "'nanj'";
    assert vm_str("repr(1e-7+0j)") == "'(1e-07+0j)'";
    assert vm_str("repr(1e16+0j)") == "'(1e+16+0j)'";
    assert vm_str("repr(complex(-0.0,-0.0))") == "'(-0-0j)'";
    assert vm_str("repr(complex(-0.0,1))") == "'(-0+1j)'";
    assert vm_str("repr(9007199254740992.0+0j)") == "'(9007199254740992+0j)'";
    assert vm_str("repr(1500+0j)") == "'(1500+0j)'";
}

test "complex tower: parsing-valid -- complex str parsing j suffix parens words underscores" {
    assert vm_str("complex('3+4j')") == "(3+4j)";
    assert vm_str("complex('-2J')") == "-2j";
    assert vm_str("complex('1j')") == "1j";
    assert vm_str("complex('+j')") == "1j";
    assert vm_str("complex('1_000j')") == "1000j";
    assert vm_str("complex('1.5e-3j')") == "0.0015j";
    assert vm_str("complex('(1+2j)')") == "(1+2j)";
    assert vm_str("complex('( -1j )')") == "-1j";
    assert vm_str("complex('inf')") == "(inf+0j)";
    assert vm_str("complex('-Infinity')") == "(-inf+0j)";
    assert vm_str("complex('nan')") == "(nan+0j)";
    assert vm_str("complex('1+j')") == "(1+1j)";
}

test "complex tower: parsing-errors -- exact ValueError texts for malformed strings" {
    assert vm_str("complex('abc')") == "ValueError: complex() arg is a malformed string";
    assert vm_str("complex('')") == "ValueError: complex() arg is a malformed string";
    assert vm_str("complex('  1 + 2j ')") == "ValueError: complex() arg is a malformed string";
    assert vm_str("complex('_1j')") == "ValueError: could not convert string to complex: '_1j'";
    assert vm_str("complex('1_j')") == "ValueError: could not convert string to complex: '1_j'";
    assert vm_str("complex('1++2j')") == "ValueError: complex() arg is a malformed string";
    assert vm_str("complex('3j+2')") == "ValueError: complex() arg is a malformed string";
    assert vm_str("complex('0x1j')") == "ValueError: complex() arg is a malformed string";
    assert vm_str("complex('1j2j')") == "ValueError: complex() arg is a malformed string";
    assert vm_str("complex('((1j))')") == "ValueError: complex() arg is a malformed string";
}

test "complex tower: constructor-types -- numeric promotion and TypeError shapes" {
    assert vm_str("complex(3)") == "(3+0j)";
    assert vm_str("complex(3,4)") == "(3+4j)";
    assert vm_str("complex(3.5)") == "(3.5+0j)";
    assert vm_str("complex(True)") == "(1+0j)";
    assert vm_str("complex(2,3).conjugate()") == "(2-3j)";
    assert vm_str("complex(1+2j, 3)") == "(1+5j)";
    assert vm_str("complex(None)") == "TypeError: complex() argument must be a string or a number, not NoneType";
    assert vm_str("complex(b'1j')") == "TypeError: complex() argument must be a string or a number, not bytes";
    assert vm_str("complex('1+2j','2')") == "TypeError: complex() argument 'real' must be a real number, not str";
    assert vm_str("complex(1,2,3)") == "TypeError: complex() takes at most 2 arguments (3 given)";
}

test "complex tower: attrs-methods -- real imag floats conjugate truthiness" {
    assert vm_str("(1+2j).real") == "1.0";
    assert vm_str("(1+2j).imag") == "2.0";
    assert vm_str("(1+2j).conjugate()") == "(1-2j)";
    assert vm_str("(3).imag") == "0";
    assert vm_str("bool(0j)") == "False";
    assert vm_str("bool(1j)") == "True";
}

test "complex tower: unary-abs -- unary minus plus and abs" {
    assert vm_str("-(3+4j)") == "(-3-4j)";
    assert vm_str("+(3+4j)") == "(3+4j)";
    assert vm_str("abs(3+4j)") == "5.0";
}

test "complex tower: key-collapse -- dict set keys collapse with int float like CPython" {
    assert vm_str("{3:'x'}[3+0j]") == "'x'";
    assert vm_str("(3+0j) in {3}") == "True";
    assert vm_str("({1j:1})[1j]") == "1";
    assert vm_str("len({1+0j, 1.0, 1})") == "1";
    assert vm_str("len({2j, 2j})") == "1";
}
