# Triage report: `conv_index_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_index.py
- guest leg: 0/10 marks
- pins: **5 passed** / 10 run (+10 quarantined of 20 extracted)

| pin | result | got |
|---|---|---|
| BaseTestCase.test_basic | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'newstyle\' object cannot be interpreted as an integer"'> |
| BaseTestCase.test_slice | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (0, 0, 0), (1, 1, 1))"'> |
| BaseTestCase.test_wrappers | PASS | |
| BaseTestCase.test_error | PASS | |
| BaseTestCase.test_int_subclass_with_index | PASS | |
| ListTestCase.test_setdelitem | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'list indices must be integers or slices, not newstyle'"> |
| ListTestCase.test_inplace_repeat | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'newstyle\' object cannot be interpreted as an integer"'> |
| OverflowTestCase.test_large_longs | PASS | |
| OverflowTestCase.test_getitem | GUEST-WRONG-OUTPUT | RUN<'AttributeError: MAX_Py_ssize_t'> |
| OverflowTestCase.test_sequence_repeat | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| BaseTestCase.test_subclasses | unresolved-name:TrapInt |
| BaseTestCase.test_index_returns_int_subclass | uses-self.assertWarns |
| SeqTestCase.test_subclasses | unresolved-name:TrapInt |
| RangeTestCase.test_range | unresolved-name:newstyle |
| SeqTestCase.test_index | host-raised:AttributeError: '_SelfNS' object has no attribute 'seq' |
| SeqTestCase.test_slice | host-raised:AttributeError: '_SelfNS' object has no attribute 'seq' |
| SeqTestCase.test_slice_bug7532 | host-raised:AttributeError: '_SelfNS' object has no attribute 'seq' |
| SeqTestCase.test_repeat | host-raised:AttributeError: '_SelfNS' object has no attribute 'seq' |
| SeqTestCase.test_wrappers | host-raised:AttributeError: '_SelfNS' object has no attribute 'seq' |
| SeqTestCase.test_error | host-raised:AttributeError: '_SelfNS' object has no attribute 'seq' |

## Expected vs got

### BaseTestCase.test_basic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'newstyle\' object cannot be interpreted as an integer"'>

### BaseTestCase.test_slice (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (0, 0, 0), (1, 1, 1))"'>

### ListTestCase.test_inplace_repeat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'newstyle\' object cannot be interpreted as an integer"'>

### ListTestCase.test_setdelitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'list indices must be integers or slices, not newstyle'">

### OverflowTestCase.test_getitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: MAX_Py_ssize_t'>
