# Triage report: `conv_fractions_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_fractions.py
- guest leg: 0/36 marks
- pins: **19 passed** / 36 run (+14 quarantined of 50 extracted)

| pin | result | got |
|---|---|---|
| FractionTest.testInit | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'both arguments should be Rational instances'"> |
| FractionTest.testInitFromFloat | PASS | |
| FractionTest.testInitFromDecimal | PASS | |
| FractionTest.testFromString | PASS | |
| FractionTest.testImmutable | PASS | |
| FractionTest.testFromFloat | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'Fraction.from_float() only takes floats, not 10 (int)'"> |
| FractionTest.testFromDecimal | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'Fraction.from_decimal() only takes Decimals, not 10 (int)'"> |
| FractionTest.test_is_integer | PASS | |
| FractionTest.test_as_integer_ratio | PASS | |
| FractionTest.testLimitDenominator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'"> |
| FractionTest.testConversions | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "type Fraction doesn\'t define **trunc** method"'> |
| FractionTest.testBoolGuarateesBoolReturn | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'argument should be a string or a Rational instance or have the as_integer_ratio() method'"> |
| FractionTest.testRound | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "type Fraction doesn\'t define **round** method"'> |
| FractionTest.testArithmetic | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for /: \'Fraction\' and \'Fraction\'"'> |
| FractionTest.testLargeArithmetic | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for divmod(): \'Fraction\' and \'Fraction\'"'> |
| FractionTest.testMixedArithmetic | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (1.1+0j), (1.1+0j))"'> |
| FractionTest.testMixingWithDecimal | PASS | |
| FractionTest.testComparisons | PASS | |
| FractionTest.testMixedLess | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'int\' and \'Fraction\'"'> |
| FractionTest.testMixedLessEqual | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'>=\' not supported between instances of \'Fraction\' and \'Fraction\'"'> |
| FractionTest.testBigFloatComparisons | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'>\' not supported between instances of \'Fraction\' and \'Fraction\'"'> |
| FractionTest.testBigComplexComparisons | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'> |
| FractionTest.testMixedEqual | PASS | |
| FractionTest.testStringification | PASS | |
| FractionTest.testHash | PASS | |
| FractionTest.testApproximatePi | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'>\' not supported between instances of \'int\' and \'Fraction\'"'> |
| FractionTest.testApproximateCos1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bad operand type for abs(): \'Fraction\'"'> |
| FractionTest.test_slots | PASS | |
| FractionTest.test_int_subclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'both arguments should be Rational instances'"> |
| FractionTest.test_format_no_presentation_type | PASS | |
| FractionTest.test_format_e_presentation_type | PASS | |
| FractionTest.test_format_f_presentation_type | PASS | |
| FractionTest.test_format_g_presentation_type | PASS | |
| FractionTest.test_invalid_formats | PASS | |
| FractionTest.test_complex_handling | PASS | |
| FractionTest.test_three_argument_pow | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| FractionTest.testInitFromIntegerRatio | assertRaisesRegex call form |
| FractionTest.test_limit_int | assertRaisesRegex call form |
| FractionTest.testFromNumber | unresolved-name:DummyFraction |
| FractionTest.testFromNumber_subclass | self.testFromNumber |
| FractionTest.testMixedMultiplication | unresolved-name:DummyFraction |
| FractionTest.testMixedDivision | unresolved-name:DummyFraction |
| FractionTest.testMixedIntegerDivision | unresolved-name:DummyFraction |
| FractionTest.testMixedPower | unresolved-name:Polar |
| FractionTest.testComparisonsDummyRational | unresolved-name:DummyRational |
| FractionTest.testComparisonsDummyFloat | unresolved-name:DummyFloat |
| FractionTest.test_copy_deepcopy_pickle | unresolved-name:DummyFraction |
| FractionTest.testSupportsInt | harness-error:SyntaxError: invalid syntax |
| FractionTest.testIntGuaranteesIntReturn | harness-error:SyntaxError: invalid syntax |
| FractionTest.test_float_format_testfile | host-raised:FileNotFoundError: [Errno 2] No such file or directory: '/tmp/conv_suite_h5u84sdp/mathdata/formatfloat_testcases.txt' |

## Expected vs got

### FractionTest.testApproximateCos1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bad operand type for abs(): \'Fraction\'"'>

### FractionTest.testApproximatePi (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'>\' not supported between instances of \'int\' and \'Fraction\'"'>

### FractionTest.testArithmetic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for /: \'Fraction\' and \'Fraction\'"'>

### FractionTest.testBigComplexComparisons (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'>

### FractionTest.testBigFloatComparisons (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'>\' not supported between instances of \'Fraction\' and \'Fraction\'"'>

### FractionTest.testBoolGuarateesBoolReturn (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'argument should be a string or a Rational instance or have the as_integer_ratio() method'">

### FractionTest.testConversions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "type Fraction doesn\'t define **trunc** method"'>

### FractionTest.testFromDecimal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'Fraction.from_decimal() only takes Decimals, not 10 (int)'">

### FractionTest.testFromFloat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'Fraction.from_float() only takes floats, not 10 (int)'">

### FractionTest.testInit (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'both arguments should be Rational instances'">

### FractionTest.testLargeArithmetic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for divmod(): \'Fraction\' and \'Fraction\'"'>

### FractionTest.testLimitDenominator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'">

### FractionTest.testMixedArithmetic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (1.1+0j), (1.1+0j))"'>

### FractionTest.testMixedLess (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'int\' and \'Fraction\'"'>

### FractionTest.testMixedLessEqual (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'>=\' not supported between instances of \'Fraction\' and \'Fraction\'"'>

### FractionTest.testRound (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "type Fraction doesn\'t define **round** method"'>

### FractionTest.test_int_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'both arguments should be Rational instances'">
