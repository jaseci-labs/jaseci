# Triage report: `conv_setcomps_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_setcomps.py
- guest leg: 0/1 marks
- pins: **0 passed** / 1 run (+3 quarantined of 4 extracted)

| pin | result | got |
|---|---|---|
| setcomps.doctests:doctests | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |

## Quarantined at conversion

| test | reason |
|---|---|
| setcomps.doctests:doctests.ex12 | doctest-options:[32] |
| setcomps.doctests:doctests.ex13 | doctest-options:[32] |
| SetComprehensionTest.test_exception_locations | host-raised:AssertionError: ('assertEqual', ' in BrokenIter(init_raises=T', 'BrokenIter(init_raises=True)') |

## Expected vs got

### setcomps.doctests:doctests (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>
