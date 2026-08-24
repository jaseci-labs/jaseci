# Triage report: `conv_descrtut_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_descrtut.py
- guest leg: 0/7 marks
- pins: **4 passed** / 7 run (+1 quarantined of 8 extracted)

| pin | result | got |
|---|---|---|
| descrtut.doctests:tut1 | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |
| descrtut.doctests:tut2 | PASS | |
| descrtut.doctests:tut4 | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |
| descrtut.doctests:tut5 | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |
| descrtut.doctests:tut6 | PASS | |
| descrtut.doctests:tut7 | PASS | |
| descrtut.doctests:tut8 | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| descrtut.doctests:tut3 | harness-error:AssertionError: ('doctest', 7, '', "['**add**',\n '**class**',\n '**class_getitem**',\n '**contains**',\n '**delattr**', |

## Expected vs got

### descrtut.doctests:tut1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>

### descrtut.doctests:tut4 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>

### descrtut.doctests:tut5 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>
