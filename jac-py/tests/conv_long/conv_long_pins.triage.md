# Triage report: `conv_long_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_long.py
- guest leg: 0/33 marks
- pins: **30 passed** / 33 run (+14 quarantined of 47 extracted)

| pin | result | got |
|---|---|---|
| LongTest.test_karatsuba | PASS | |
| LongTest.test_format | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| LongTest.test_long | PASS | |
| LongTest.test_conversion | PASS | |
| LongTest.test_float_overflow | PASS | |
| LongTest.test_logs | PASS | |
| LongTest.test__format__ | PASS | |
| LongTest.test_nan_inf | PASS | |
| LongTest.test_mod_division | PASS | |
| LongTest.test_true_division | PASS | |
| LongTest.test_floordiv | PASS | |
| LongTest.test_negative_shift_count | PASS | |
| LongTest.test_lshift_of_zero | PASS | |
| LongTest.test_huge_rshift | PASS | |
| LongTest.test_small_rshift | PASS | |
| LongTest.test_medium_rshift | PASS | |
| LongTest.test_big_rshift | PASS | |
| LongTest.test_small_lshift | PASS | |
| LongTest.test_medium_lshift | PASS | |
| LongTest.test_big_lshift | PASS | |
| LongTest.test_small_ints | PASS | |
| LongTest.test_bit_length | PASS | |
| LongTest.test_bit_count | PASS | |
| LongTest.test_round | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| LongTest.test_to_bytes | PASS | |
| LongTest.test_from_bytes | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIs\', <class \'int\'>, <class \'**main**.myint\'>)"'> |
| LongTest.test_is_integer | PASS | |
| LongTest.test_access_to_nonexistent_digit_0 | PASS | |
| LongTest.test_shift_bool | PASS | |
| LongTest.test_as_integer_ratio | PASS | |
| LongTest.test_square | PASS | |
| LongTest.test___sizeof__ | PASS | |
| LongTest.test_hash | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| LongTest.test_float_conversion | decorator:support.requires_IEEE_754 |
| LongTest.test_float_conversion_huge_integer | decorator:support.requires_IEEE_754 |
| LongTest.test_mixed_compares_huge_integer | decorator:support.requires_IEEE_754 |
| LongTest.test_correctly_rounded_true_division | decorator:support.requires_IEEE_754 |
| LongTest.test_huge_lshift_of_zero | decorator:support.cpython_only |
| LongTest.test_huge_lshift | decorator:support.cpython_only |
| LongTest.test_huge_rshift_of_huge | decorator:support.cpython_only |
| LongTest.test_small_ints_in_huge_calculation | decorator:support.cpython_only |
| LongTest.test_pow_uses_cached_small_ints | decorator:support.cpython_only |
| LongTest.test_divmod_uses_cached_small_ints | decorator:support.cpython_only |
| LongTest.test_from_bytes_small | decorator:support.cpython_only |
| LongTest.test_mixed_compares | uses-self._cmp__ |
| LongTest.test_division | host-raised:NameError: name 'self' is not defined |
| LongTest.test_bitop_identities | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### LongTest.test_format (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### LongTest.test_from_bytes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIs\', <class \'int\'>, <class \'**main**.myint\'>)"'>

### LongTest.test_round (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">
