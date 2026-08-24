# Triage report: `conv_float_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_float.py
- guest leg: 0/24 marks
- pins: **19 passed** / 24 run (+30 quarantined of 54 extracted)

| pin | result | got |
|---|---|---|
| GeneralFloatCases.test_noargs | PASS | |
| GeneralFloatCases.test_underscores | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "argument of type \'bool\' is not a container or iterable"'> |
| GeneralFloatCases.test_float_memoryview | PASS | |
| GeneralFloatCases.test_keyword_args | PASS | |
| GeneralFloatCases.test_keywords_in_subclass | PASS | |
| GeneralFloatCases.test_is_integer | PASS | |
| GeneralFloatCases.test_floatasratio | GUEST-WRONG-OUTPUT | RUN<'AttributeError: register'> |
| GeneralFloatCases.test_float_containment | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIn\', nan, [nan])"'> |
| GeneralFloatCases.test_float_floor | PASS | |
| GeneralFloatCases.test_float_ceil | PASS | |
| GeneralFloatCases.test_hash | PASS | |
| GeneralFloatCases.test_hash_nan | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 8748298040793, 8748298116451)"'> |
| GeneralFloatCases.test_issue_gh143006 | PASS | |
| FormatTestCase.test_format | PASS | |
| FormatTestCase.test_issue5864 | PASS | |
| FormatTestCase.test_issue35560 | PASS | |
| InfNanTest.test_inf_from_str | PASS | |
| InfNanTest.test_inf_as_str | PASS | |
| InfNanTest.test_nan_from_str | PASS | |
| InfNanTest.test_nan_as_str | PASS | |
| InfNanTest.test_inf_signs | PASS | |
| InfNanTest.test_nan_signs | PASS | |
| HexFloatTestCase.test_invalid_inputs | PASS | |
| HexFloatTestCase.test_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIs\', <class \'float\'>, <class \'**main**.F\'>)"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| GeneralFloatCases.test_float_with_comma | decorator:support.run_with_locale |
| GeneralFloatCases.test_float_mod | decorator:support.requires_IEEE_754 |
| GeneralFloatCases.test_float_pow | decorator:support.requires_IEEE_754 |
| FormatFunctionsTestCase.test_getformat | decorator:unittest.skipUnless |
| IEEEFormatTestCase.test_double_specials_do_unpack | decorator:support.requires_IEEE_754 |
| IEEEFormatTestCase.test_float_specials_do_unpack | decorator:support.requires_IEEE_754 |
| IEEEFormatTestCase.test_serialized_float_rounding | decorator:support.requires_IEEE_754 |
| FormatTestCase.test_format_testfile | decorator:support.requires_IEEE_754 |
| ReprTestCase.test_short_repr | decorator:unittest.skipUnless |
| RoundTestCase.test_inf_nan | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_inf_nan_ndigits | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_large_n | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_small_n | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_overflow | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_previous_round_bugs | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_matches_float_format | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_format_specials | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_None_ndigits | decorator:support.requires_IEEE_754 |
| RoundTestCase.test_round_with_none_arg_direct_call | decorator:support.requires_IEEE_754 |
| GeneralFloatCases.test_float | assertRaisesRegex call form |
| GeneralFloatCases.test_non_numeric_input_types | uses-self.subTest |
| GeneralFloatCases.test_error_message | unresolved-name:cm |
| GeneralFloatCases.test_floatconversion | uses-self.assertWarns |
| GeneralFloatCases.test_from_number | unresolved-name:FloatLike |
| GeneralFloatCases.test_from_number_subclass | self.test_from_number |
| ReprTestCase.test_repr | unresolved-name:**file** |
| HexFloatTestCase.test_ends | helper:identical(self.assertFloatsAreIdentical) |
| HexFloatTestCase.test_whitespace | helper:identical(self.assertFloatsAreIdentical) |
| HexFloatTestCase.test_from_hex | helper:identical(self.assertFloatsAreIdentical) |
| HexFloatTestCase.test_roundtrip | helper:identical(self.assertFloatsAreIdentical) |

## Expected vs got

### GeneralFloatCases.test_float_containment (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIn\', nan, [nan])"'>

### GeneralFloatCases.test_floatasratio (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: register'>

### GeneralFloatCases.test_hash_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 8748298040793, 8748298116451)"'>

### GeneralFloatCases.test_underscores (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "argument of type \'bool\' is not a container or iterable"'>

### HexFloatTestCase.test_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIs\', <class \'float\'>, <class \'**main**.F\'>)"'>
