# Triage report: `conv_bool_pins.jac`

- source: reference/cpython/Lib/test/test_bool.py
- guest leg: 0/27 marks
- pins: **25 passed** / 27 run (+4 quarantined of 31 extracted)

| pin | result | got |
|---|---|---|
| BoolTest.test_subclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'bool should not be subclassable'"> |
| BoolTest.test_repr | PASS | |
| BoolTest.test_str | PASS | |
| BoolTest.test_int | PASS | |
| BoolTest.test_float | PASS | |
| BoolTest.test_complex | PASS | |
| BoolTest.test_convert | PASS | |
| BoolTest.test_keyword_args | PASS | |
| BoolTest.test_format | PASS | |
| BoolTest.test_hasattr | PASS | |
| BoolTest.test_callable | PASS | |
| BoolTest.test_isinstance | PASS | |
| BoolTest.test_issubclass | PASS | |
| BoolTest.test_contains | PASS | |
| BoolTest.test_string | PASS | |
| BoolTest.test_fileclosed | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'TextIOWrapper.**enter**() takes no arguments (1 given)'"> |
| BoolTest.test_types | PASS | |
| BoolTest.test_operator | PASS | |
| BoolTest.test_marshal | PASS | |
| BoolTest.test_pickle | PASS | |
| BoolTest.test_picklevalues | PASS | |
| BoolTest.test_interpreter_convert_to_bool_raises | PASS | |
| BoolTest.test_from_bytes | PASS | |
| BoolTest.test_sane_len | PASS | |
| BoolTest.test_blocked | PASS | |
| BoolTest.test_real_and_imag | PASS | |
| BoolTest.test_bool_new | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| BoolTest.test_math | uses-self.assertWarns |
| BoolTest.test_boolean | self.assertNotIsInstance |
| BoolTest.test_convert_to_bool | uses-self.assertRaises |
| BoolTest.test_bool_called_at_least_once | uses-self.count |

## Expected vs got

### BoolTest.test_fileclosed (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'TextIOWrapper.**enter**() takes no arguments (1 given)'">

### BoolTest.test_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'bool should not be subclassable'">
