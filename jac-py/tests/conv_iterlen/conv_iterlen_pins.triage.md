# Triage report: `conv_iterlen_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_iterlen.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+4 quarantined of 6 extracted)

| pin | result | got |
|---|---|---|
| TestList.test_mutation | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 0, 8)"'> |
| TestListReversed.test_mutation | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 8, 0)"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestTemporarilyImmutable.test_immutable_during_iteration | self.mutate |
| TestLengthHintExceptions.test_issue1242657 | unresolved-name:BadLen |
| TestLengthHintExceptions.test_invalid_hint | unresolved-name:NoneLengthHint |
| TestInvariantWithoutMutations.test_invariant | host-raised:AttributeError: '_SelfNS' object has no attribute 'it' |

## Expected vs got

### TestList.test_mutation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 0, 8)"'>

### TestListReversed.test_mutation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 8, 0)"'>
