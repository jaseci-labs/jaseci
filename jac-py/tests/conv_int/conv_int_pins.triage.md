# Triage report: `conv_int_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_int.py
- guest leg: 0/15 marks
- pins: **13 passed** / 15 run (+27 quarantined of 42 extracted)

| pin | result | got |
|---|---|---|
| IntTestCases.test_basic | PASS | |
| IntTestCases.test_invalid_signs | PASS | |
| IntTestCases.test_unicode | PASS | |
| IntTestCases.test_underscores | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "argument of type \'bool\' is not a container or iterable"'> |
| IntTestCases.test_no_args | PASS | |
| IntTestCases.test_keyword_args | PASS | |
| IntTestCases.test_int_base_limits | PASS | |
| IntTestCases.test_int_base_bad_types | PASS | |
| IntTestCases.test_int_base_indexable | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'MyIndexable\' object cannot be interpreted as an integer"'> |
| IntTestCases.test_int_memoryview | PASS | |
| IntTestCases.test_string_float | PASS | |
| IntTestCases.test_intconversion | PASS | |
| IntTestCases.test_int_subclass_with_index | PASS | |
| IntTestCases.test_int_subclass_with_int | PASS | |
| IntTestCases.test_issue31619 | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| IntTestCases.test_small_ints | decorator:support.cpython_only |
| IntTestCases.test_round_with_none_arg_direct_call | decorator:support.cpython_only |
| PyLongModuleTests.test_pylong_int_to_decimal_2 | decorator:support.requires_resource |
| PyLongModuleTests.test_pylong_int_divmod_crash | decorator:support.cpython_only |
| PyLongModuleTests.test_pylong_misbehavior_error_path_to_str | decorator:support.cpython_only |
| PyLongModuleTests.test_pylong_misbehavior_error_path_from_str | decorator:support.cpython_only |
| PyLongModuleTests.test_pylong_roundtrip_huge | decorator:support.requires_resource |
| PyLongModuleTests.test_whitebox_dec_str_to_int_inner_failsafe | decorator:support.requires_resource |
| PyLongModuleTests.test_whitebox_dec_str_to_int_inner_monster | decorator:unittest.skipUnless |
| PyLongModuleTests.test_pylong_compute_powers | decorator:unittest.skipUnless |
| IntTestCases.test_non_numeric_input_types | uses-self.subTest |
| IntTestCases.test_int_returns_int_subclass | uses-self.assertWarns |
| IntTestCases.test_error_message | unresolved-name:cm |
| IntStrDigitLimitsTests.test_disabled_limit | uses-self.int_class |
| IntStrDigitLimitsTests.test_max_str_digits | helper:check(uses-self.int_class) |
| IntStrDigitLimitsTests.test_denial_of_service_prevented_int_to_str | uses-self.assertRaises |
| IntStrDigitLimitsTests.test_denial_of_service_prevented_str_to_int | uses-self.assertRaises |
| IntStrDigitLimitsTests.test_power_of_two_bases_unlimited | self.int_class |
| IntStrDigitLimitsTests.test_underscores_ignored | helper:check(uses-self.int_class) |
| IntStrDigitLimitsTests.test_int_from_other_bases | uses-self.subTest |
| PyLongModuleTests.test_pylong_roundtrip | self.assertNotStartsWith |
| IntStrDigitLimitsTests.test_max_str_digits_edge_cases | host-raised:RuntimeError: super(): no arguments |
| IntStrDigitLimitsTests.test_sign_not_counted | host-raised:RuntimeError: super(): no arguments |
| IntStrDigitLimitsTests.test_int_max_str_digits_is_per_interpreter | host-raised:RuntimeError: super(): no arguments |
| PyLongModuleTests.test_pylong_int_to_decimal | host-raised:RuntimeError: super(): no arguments |
| PyLongModuleTests.test_pylong_int_divmod | host-raised:RuntimeError: super(): no arguments |
| PyLongModuleTests.test_pylong_str_to_int | host-raised:RuntimeError: super(): no arguments |

## Expected vs got

### IntTestCases.test_int_base_indexable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'MyIndexable\' object cannot be interpreted as an integer"'>

### IntTestCases.test_underscores (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "argument of type \'bool\' is not a container or iterable"'>
