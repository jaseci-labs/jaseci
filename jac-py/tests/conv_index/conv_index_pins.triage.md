# Triage report: `conv_index_pins.jac`

- source: reference/cpython/Lib/test/test_index.py
- guest leg: 0/1 marks
- pins: **1 passed** / 1 run (+19 quarantined of 20 extracted)

| pin | result | got |
|---|---|---|
| BaseTestCase.test_int_subclass_with_index | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| BaseTestCase.test_basic | uses-self.o |
| BaseTestCase.test_slice | uses-self.o |
| BaseTestCase.test_wrappers | uses-self.o |
| BaseTestCase.test_subclasses | unresolved-name:TrapInt |
| BaseTestCase.test_error | uses-self.o |
| BaseTestCase.test_index_returns_int_subclass | uses-self.assertWarns |
| SeqTestCase.test_index | uses-self.o |
| SeqTestCase.test_slice | uses-self.o |
| SeqTestCase.test_slice_bug7532 | uses-self.seq |
| SeqTestCase.test_repeat | uses-self.o |
| SeqTestCase.test_wrappers | uses-self.o |
| SeqTestCase.test_subclasses | uses-self.seq |
| SeqTestCase.test_error | uses-self.o |
| ListTestCase.test_setdelitem | uses-self.o |
| ListTestCase.test_inplace_repeat | uses-self.o |
| RangeTestCase.test_range | unresolved-name:newstyle |
| OverflowTestCase.test_large_longs | uses-self.pos |
| OverflowTestCase.test_getitem | uses-self.pos |
| OverflowTestCase.test_sequence_repeat | uses-self.pos |
