# Triage report: `conv_unpack_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_unpack.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+3 quarantined of 5 extracted)

| pin | result | got |
|---|---|---|
| TestCornerCases.test_extended_oparg_not_ignored | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC ValueError 'not enough values to unpack (expected 400, got 0)'"> |
| unpack.doctests:doctests | GUEST-WRONG-OUTPUT | RUN<'ValueError: not enough values to unpack (expected 3, got 0)'> |

## Quarantined at conversion

| test | reason |
|---|---|
| unpack.doctests:doctests.ex29 | doctest-module-qualified-expected |
| unpack.doctests:doctests.ex30 | doctest-module-qualified-expected |
| unpack.doctests:doctests.ex41 | doctest-depends-on-dropped:['d'] |

## Expected vs got

### TestCornerCases.test_extended_oparg_not_ignored (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC ValueError 'not enough values to unpack (expected 400, got 0)'">

### unpack.doctests:doctests (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'ValueError: not enough values to unpack (expected 3, got 0)'>
