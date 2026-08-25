# Triage report: `conv_strtod_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_strtod.py
- guest leg: 0/8 marks
- pins: **2 passed** / 8 run (+1 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| StrtodTests.test_short_halfway_cases | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| StrtodTests.test_halfway_cases | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| StrtodTests.test_boundaries | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| StrtodTests.test_underflow_boundary | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| StrtodTests.test_bigcomp | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| StrtodTests.test_parsing | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| StrtodTests.test_large_exponents | PASS | |
| StrtodTests.test_particular | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| StrtodTests.test_oversized_digit_strings | unresolved-name:maxsize |

## Expected vs got

### StrtodTests.test_bigcomp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### StrtodTests.test_boundaries (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### StrtodTests.test_halfway_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### StrtodTests.test_parsing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### StrtodTests.test_short_halfway_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### StrtodTests.test_underflow_boundary (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">
