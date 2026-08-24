# Triage report: `conv_generator_stop_pins.jac`

- source: reference/cpython/Lib/test/test_generator_stop.py
- guest leg: 0/2 marks
- pins: **1 passed** / 2 run (+0 quarantined of 2 extracted)

| pin | result | got |
|---|---|---|
| TestPEP479.test_stopiteration_wrapping | PASS | |
| TestPEP479.test_stopiteration_wrapping_context | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |

## Expected vs got

### TestPEP479.test_stopiteration_wrapping_context (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">
