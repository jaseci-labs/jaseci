# Triage report: `conv_decorators_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_decorators.py
- guest leg: 0/14 marks
- pins: **11 passed** / 14 run (+2 quarantined of 16 extracted)

| pin | result | got |
|---|---|---|
| TestDecorators.test_single | PASS | |
| TestDecorators.test_staticmethod | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**wrapped**'"> |
| TestDecorators.test_classmethod | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**wrapped**'"> |
| TestDecorators.test_argforms | PASS | |
| TestDecorators.test_memoize | PASS | |
| TestDecorators.test_errors | PASS | |
| TestDecorators.test_expressions | PASS | |
| TestDecorators.test_double | PASS | |
| TestDecorators.test_order | PASS | |
| TestDecorators.test_eval_order | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'NameLookupTracer() takes no arguments'"> |
| TestDecorators.test_bound_function_inside_classmethod | PASS | |
| TestClassDecorators.test_simple | PASS | |
| TestClassDecorators.test_double | PASS | |
| TestClassDecorators.test_order | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestDecorators.test_dotted | unresolved-name:MiscDecorators |
| TestDecorators.test_dbcheck | unresolved-name:DbcheckError |

## Expected vs got

### TestDecorators.test_classmethod (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**wrapped**'">

### TestDecorators.test_eval_order (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'NameLookupTracer() takes no arguments'">

### TestDecorators.test_staticmethod (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**wrapped**'">
