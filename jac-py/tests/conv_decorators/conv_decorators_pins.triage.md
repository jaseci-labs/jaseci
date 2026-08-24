# Triage report: `conv_decorators_pins.jac`

- source: reference/cpython/Lib/test/test_decorators.py
- guest leg: 0/11 marks
- pins: **10 passed** / 11 run (+5 quarantined of 16 extracted)

| pin | result | got |
|---|---|---|
| TestDecorators.test_single | PASS | |
| TestDecorators.test_argforms | PASS | |
| TestDecorators.test_memoize | PASS | |
| TestDecorators.test_errors | PASS | |
| TestDecorators.test_expressions | PASS | |
| TestDecorators.test_double | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'abc'"> |
| TestDecorators.test_order | PASS | |
| TestDecorators.test_bound_function_inside_classmethod | PASS | |
| TestClassDecorators.test_simple | PASS | |
| TestClassDecorators.test_double | PASS | |
| TestClassDecorators.test_order | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestDecorators.test_staticmethod | uses-self.check_wrapper_attrs |
| TestDecorators.test_classmethod | uses-self.check_wrapper_attrs |
| TestDecorators.test_dotted | unresolved-name:MiscDecorators |
| TestDecorators.test_dbcheck | unresolved-name:DbcheckError |
| TestDecorators.test_eval_order | uses-self.index |

## Expected vs got

### TestDecorators.test_double (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'abc'">
