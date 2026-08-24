# Triage report: `conv_pep646_syntax_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_pep646_syntax.py
- guest leg: 0/1 marks
- pins: **0 passed** / 1 run (+0 quarantined of 1 extracted)

| pin | result | got |
|---|---|---|
| pep646_syntax.doctests:doctests | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |

## Expected vs got

### pep646_syntax.doctests:doctests (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>
