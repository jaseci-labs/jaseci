# Triage report: `conv_unicode_identifiers_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_unicode_identifiers.py
- guest leg: 0/3 marks
- pins: **2 passed** / 3 run (+0 quarantined of 3 extracted)

| pin | result | got |
|---|---|---|
| PEP3131Test.test_valid | PASS | |
| PEP3131Test.test_non_bmp_normalized | PASS | |
| PEP3131Test.test_invalid | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC ModuleNotFoundError "No module named \'test.tokenizedata\'"'> |

## Expected vs got

### PEP3131Test.test_invalid (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC ModuleNotFoundError "No module named \'test.tokenizedata\'"'>
