# Triage report: `conv_enumerate_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_enumerate.py
- guest leg: 0/7 marks
- pins: **3 passed** / 7 run (+14 quarantined of 21 extracted)

| pin | result | got |
|---|---|---|
| TestReversed.test_simple | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC StopIteration ''"> |
| TestReversed.test_range_optimization | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <class \'range_iterator\'>, <class \'callable_iterator\'>)"'> |
| TestReversed.test_len | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'SeqWithWeirdLen\' object is not reversible"'> |
| TestReversed.test_gc | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Seq\' object is not reversible"'> |
| TestReversed.test_args | PASS | |
| TestReversed.test_objmethods | PASS | |
| TestReversed.test_pickle | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| EnumerateTestCase.test_tuple_reuse | decorator:support.cpython_only |
| EnumerateTestCase.test_enumerate_result_gc | decorator:support.cpython_only |
| TestReversed.test_bug1229429 | decorator:unittest.skipUnless |
| EnumerateTestCase.test_basicfunction | uses-self.enum |
| EnumerateTestCase.test_pickle | uses-self.enum |
| EnumerateTestCase.test_getitemseqn | uses-self.enum |
| EnumerateTestCase.test_iteratorseqn | uses-self.enum |
| EnumerateTestCase.test_iteratorgenerator | uses-self.enum |
| EnumerateTestCase.test_noniterable | uses-self.enum |
| EnumerateTestCase.test_illformediterable | uses-self.enum |
| EnumerateTestCase.test_exception_propagation | uses-self.enum |
| EnumerateTestCase.test_argumentcheck | uses-self.enum |
| EnumerateTestCase.test_kwargs | uses-self.enum |
| EnumerateStartTestCase.test_basicfunction | uses-self.enum |

## Expected vs got

### TestReversed.test_gc (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Seq\' object is not reversible"'>

### TestReversed.test_len (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'SeqWithWeirdLen\' object is not reversible"'>

### TestReversed.test_range_optimization (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <class \'range_iterator\'>, <class \'callable_iterator\'>)"'>

### TestReversed.test_simple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC StopIteration ''">
