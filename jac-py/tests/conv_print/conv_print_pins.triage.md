# Triage report: `conv_print_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_print.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+7 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| TestPrint.test_print_flush | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'\', \'123\\\\n\')"'> |
| TestPrint.test_gh130163 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'swap_attr'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestPrint.test_print | unresolved-name:ClassWith__str__ |
| TestPy2MigrationHint.test_normal_string | unresolved-name:context |
| TestPy2MigrationHint.test_string_with_soft_space | unresolved-name:context |
| TestPy2MigrationHint.test_string_with_excessive_whitespace | unresolved-name:context |
| TestPy2MigrationHint.test_string_with_leading_whitespace | unresolved-name:context |
| TestPy2MigrationHint.test_string_with_semicolon | unresolved-name:context |
| TestPy2MigrationHint.test_string_in_loop_on_same_line | unresolved-name:context |

## Expected vs got

### TestPrint.test_gh130163 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'swap_attr'">

### TestPrint.test_print_flush (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'\', \'123\\\\n\')"'>
