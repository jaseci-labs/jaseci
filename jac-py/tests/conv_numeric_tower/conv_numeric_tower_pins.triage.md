# Triage report: `conv_numeric_tower_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_numeric_tower.py
- guest leg: 0/8 marks
- pins: **2 passed** / 8 run (+1 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| HashTest.test_bools | PASS | |
| HashTest.test_integers | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| HashTest.test_binary_floats | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| HashTest.test_complex | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 0.0, -0j)"'> |
| HashTest.test_decimals | PASS | |
| HashTest.test_hash_normalization | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'> |
| ComparisonTest.test_mixed_comparisons | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'float\' and \'host\'"'> |
| ComparisonTest.test_complex | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 1, (1+0j))"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| HashTest.test_fractions | unresolved-name:DummyIntegral |

## Expected vs got

### ComparisonTest.test_complex (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 1, (1+0j))"'>

### ComparisonTest.test_mixed_comparisons (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'float\' and \'host\'"'>

### HashTest.test_binary_floats (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### HashTest.test_complex (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 0.0, -0j)"'>

### HashTest.test_hash_normalization (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'>

### HashTest.test_integers (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">
