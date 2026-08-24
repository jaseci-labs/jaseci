# Triage report: `conv_unpack_pins.jac`

- source: reference/cpython/Lib/test/test_unpack.py
- guest leg: 0/1 marks
- pins: **0 passed** / 1 run (+0 quarantined of 1 extracted)

| pin | result | got |
|---|---|---|
| TestCornerCases.test_extended_oparg_not_ignored | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'unpack_400\'"'> |

## Expected vs got

### TestCornerCases.test_extended_oparg_not_ignored (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'unpack_400\'"'>
