# Triage report: `conv_unpack_ex_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_unpack_ex.py
- guest leg: 0/1 marks
- pins: **0 passed** / 1 run (+8 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| unpack_ex.doctests:doctests | GUEST-WRONG-OUTPUT | RUN<"TypeError: 'CrazyDict' object is not a mapping"> |

## Quarantined at conversion

| test | reason |
|---|---|
| unpack_ex.doctests:doctests.ex66 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex67 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex68 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex69 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex70 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex76 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex81 | doctest-depends-on-dropped:['a'] |
| unpack_ex.doctests:doctests.ex83 | doctest-depends-on-dropped:['a'] |

## Expected vs got

### unpack_ex.doctests:doctests (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: 'CrazyDict' object is not a mapping">
