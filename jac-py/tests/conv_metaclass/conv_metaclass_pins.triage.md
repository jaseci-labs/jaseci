# Triage report: `conv_metaclass_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_metaclass.py
- guest leg: 0/1 marks
- pins: **0 passed** / 1 run (+10 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| metaclass.doctests:doctests | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |

## Quarantined at conversion

| test | reason |
|---|---|
| metaclass.doctests:doctests.ex38 | doctest-module-qualified-expected |
| metaclass.doctests:doctests.ex39 | doctest-depends-on-dropped:['C'] |
| metaclass.doctests:doctests.ex40 | doctest-depends-on-dropped:['C'] |
| metaclass.doctests:doctests.ex46 | doctest-module-qualified-expected |
| metaclass.doctests:doctests.ex48 | doctest-module-qualified-expected |
| metaclass.doctests:doctests.ex49 | doctest-depends-on-dropped:['C'] |
| metaclass.doctests:doctests.ex50 | doctest-module-qualified-expected |
| metaclass.doctests:doctests.ex53 | doctest-module-qualified-expected |
| metaclass.doctests:doctests.ex57 | doctest-depends-on-dropped:['C'] |
| metaclass.doctests:doctests.ex61 | doctest-module-qualified-expected |

## Expected vs got

### metaclass.doctests:doctests (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>
