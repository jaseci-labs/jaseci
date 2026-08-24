# Triage report: `conv_utf8source_pins.jac`

- source: reference/cpython/Lib/test/test_utf8source.py
- guest leg: 0/2 marks
- pins: **1 passed** / 2 run (+1 quarantined of 3 extracted)

| pin | result | got |
|---|---|---|
| PEP3120Test.test_pep3120 | PASS | |
| BuiltinCompileTests.test_latin1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'u\'"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| PEP3120Test.test_badsyntax | host-raised:ModuleNotFoundError: No module named 'test' |

## Expected vs got

### BuiltinCompileTests.test_latin1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'u\'"'>
