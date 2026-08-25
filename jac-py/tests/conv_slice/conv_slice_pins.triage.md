# Triage report: `conv_slice_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_slice.py
- guest leg: 0/10 marks
- pins: **6 passed** / 10 run (+1 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| SliceTest.test_constructor | PASS | |
| SliceTest.test_repr | PASS | |
| SliceTest.test_hash | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'slice\' object has no attribute \'**hash**\'"'> |
| SliceTest.test_cmp | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Exc ''"> |
| SliceTest.test_members | PASS | |
| SliceTest.test_setslice_without_getslice | PASS | |
| SliceTest.test_pickle | PASS | |
| SliceTest.test_copy | PASS | |
| SliceTest.test_deepcopy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| SliceTest.test_cycle | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'gc_collect'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| SliceTest.test_indices | unresolved-name:MyIndexable |

## Expected vs got

### SliceTest.test_cmp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Exc ''">

### SliceTest.test_cycle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'gc_collect'">

### SliceTest.test_deepcopy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### SliceTest.test_hash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'slice\' object has no attribute \'**hash**\'"'>
