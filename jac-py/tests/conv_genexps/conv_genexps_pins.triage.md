# Triage report: `conv_genexps_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_genexps.py
- guest leg: 0/1 marks
- pins: **0 passed** / 1 run (+0 quarantined of 1 extracted)

| pin | result | got |
|---|---|---|
| genexps.doctests:doctests | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |

## Expected vs got

### genexps.doctests:doctests (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>
