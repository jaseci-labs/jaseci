# Triage report: `conv_dictcomps_pins.jac`

- source: /var/tmp/sp4-wt/reference/cpython/Lib/test/test_dictcomps.py
- guest leg: 0/9 marks
- pins: **8 passed** / 9 run (+1 quarantined of 10 extracted)

| pin | result | got |
|---|---|---|
| DictComprehensionTest.test_basics | PASS | |
| DictComprehensionTest.test_scope_isolation | PASS | |
| DictComprehensionTest.test_scope_isolation_from_global | PASS | |
| DictComprehensionTest.test_global_visibility | PASS | |
| DictComprehensionTest.test_local_visibility | PASS | |
| DictComprehensionTest.test_illegal_assignment | PASS | |
| DictComprehensionTest.test_evaluation_order | PASS | |
| DictComprehensionTest.test_assignment_idiom_in_comprehensions | PASS | |
| DictComprehensionTest.test_star_expression | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {}, {0: 0, 1: 1, 2: 4, 3: 9})"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| DictComprehensionTest.test_exception_locations | uses-self.subTest |

## Expected vs got

### DictComprehensionTest.test_star_expression (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {}, {0: 0, 1: 1, 2: 4, 3: 9})"'>
