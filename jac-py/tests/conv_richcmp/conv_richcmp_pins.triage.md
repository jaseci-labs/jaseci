# Triage report: `conv_richcmp_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_richcmp.py
- guest leg: 0/7 marks
- pins: **4 passed** / 7 run (+4 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| NumberTest.test_values | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'int\' and \'Number\'"'> |
| MiscTest.test_not | PASS | |
| MiscTest.test_exception_message | PASS | |
| DictTest.test_dicts | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'seed\'"'> |
| ListTest.test_coverage | PASS | |
| ListTest.test_badentry | PASS | |
| ListTest.test_goodentry | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'Good\' and \'Good\'"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| MiscTest.test_recursion | decorator:support.no_tracing |
| VectorTest.test_mixed | unresolved-name:Vector |
| NumberTest.test_basic | unresolved-name:Number |
| MiscTest.test_misbehavin | uses-self.fail |

## Expected vs got

### DictTest.test_dicts (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'seed\'"'>

### ListTest.test_goodentry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'Good\' and \'Good\'"'>

### NumberTest.test_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'int\' and \'Number\'"'>
