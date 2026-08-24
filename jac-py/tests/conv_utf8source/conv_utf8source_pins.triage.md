# Triage report: `conv_utf8source_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_utf8source.py
- guest leg: 0/3 marks
- pins: **2 passed** / 3 run (+0 quarantined of 3 extracted)

| pin | result | got |
|---|---|---|
| PEP3120Test.test_pep3120 | PASS | |
| PEP3120Test.test_badsyntax | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC ModuleNotFoundError "No module named \'test.tokenizedata\'"'> |
| BuiltinCompileTests.test_latin1 | PASS | |

## Expected vs got

### PEP3120Test.test_badsyntax (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC ModuleNotFoundError "No module named \'test.tokenizedata\'"'>
