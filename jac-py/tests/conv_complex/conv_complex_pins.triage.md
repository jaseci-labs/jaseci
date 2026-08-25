# Triage report: `conv_complex_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_complex.py
- guest leg: 0/20 marks
- pins: **15 passed** / 20 run (+17 quarantined of 37 extracted)

| pin | result | got |
|---|---|---|
| ComplexTest.test_truediv_zero_division | PASS | |
| ComplexTest.test_floordiv | PASS | |
| ComplexTest.test_floordiv_zero_division | PASS | |
| ComplexTest.test_richcompare | PASS | |
| ComplexTest.test_richcompare_boundaries | PASS | |
| ComplexTest.test_mod | PASS | |
| ComplexTest.test_mod_zero_division | PASS | |
| ComplexTest.test_divmod | PASS | |
| ComplexTest.test_divmod_zero_division | PASS | |
| ComplexTest.test_pow_with_small_integer_exponents | PASS | |
| ComplexTest.test_boolcontext | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ComplexTest.test_conjugate | PASS | |
| ComplexTest.test___complex__ | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (3+4j), (3+4j))"'> |
| ComplexTest.test_constructor_negative_nans_from_string | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 1.0, -1.0)"'> |
| ComplexTest.test_underscores | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "argument of type \'bool\' is not a container or iterable"'> |
| ComplexTest.test_hash | PASS | |
| ComplexTest.test_pos | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <**main**.ComplexSubclass object at 0x7f41d00dad50>, (1+6j))"'> |
| ComplexTest.test_neg | PASS | |
| ComplexTest.test_getnewargs | PASS | |
| ComplexTest.test_format | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| ComplexTest.test_constructor_special_numbers | decorator:support.requires_IEEE_754 |
| ComplexTest.test_negative_zero_repr_str | decorator:support.requires_IEEE_754 |
| ComplexTest.test_plus_minus_0j | decorator:support.requires_IEEE_754 |
| ComplexTest.test_negated_imaginary_literal | decorator:support.requires_IEEE_754 |
| ComplexTest.test_overflow | decorator:support.requires_IEEE_754 |
| ComplexTest.test_repr_roundtrip | decorator:support.requires_IEEE_754 |
| ComplexTest.test_truediv | self.assertComplexesAreIdentical |
| ComplexTest.test_add | self.assertComplexesAreIdentical |
| ComplexTest.test_sub | self.assertComplexesAreIdentical |
| ComplexTest.test_mul | self.assertComplexesAreIdentical |
| ComplexTest.test_constructor | self.assertFloatsAreIdentical |
| ComplexTest.test_constructor_from_string | self.assertFloatsAreIdentical |
| ComplexTest.test_from_number | unresolved-name:cls |
| ComplexTest.test_from_number_subclass | self.test_from_number |
| ComplexTest.test_pow | host-raised:NameError: name 'self' is not defined |
| ComplexTest.test_abs | host-raised:NameError: name 'self' is not defined |
| ComplexTest.test_repr_str | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |

## Expected vs got

### ComplexTest.test___complex__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (3+4j), (3+4j))"'>

### ComplexTest.test_boolcontext (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ComplexTest.test_constructor_negative_nans_from_string (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 1.0, -1.0)"'>

### ComplexTest.test_pos (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <**main**.ComplexSubclass object at 0x7f41d00dad50>, (1+6j))"'>

### ComplexTest.test_underscores (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "argument of type \'bool\' is not a container or iterable"'>
