# Triage report: `conv_tstring_pins.jac`

- source: reference/cpython/Lib/test/test_tstring.py
- guest leg: 0/3 marks
- pins: **1 passed** / 3 run (+9 quarantined of 12 extracted)

| pin | result | got |
|---|---|---|
| TestTString.test_string_representation | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 2'"> |
| TestTString.test_nested_templates | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 45'"> |
| TestTString.test_runtime_errors | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestTString.test_interpolation_basics | self.assertTStringEqual |
| TestTString.test_format_specifiers | self.assertTStringEqual |
| TestTString.test_conversions | self.assertTStringEqual |
| TestTString.test_debug_specifier | self.assertTStringEqual |
| TestTString.test_raw_tstrings | self.assertTStringEqual |
| TestTString.test_template_concatenation | self.assertTStringEqual |
| TestTString.test_syntax_errors | uses-self.subTest |
| TestTString.test_literal_concatenation | self.assertTStringEqual |
| TestTString.test_triple_quoted | self.assertTStringEqual |

## Expected vs got

### TestTString.test_nested_templates (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 45'">

### TestTString.test_string_representation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 2'">
