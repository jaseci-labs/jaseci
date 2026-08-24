# Triage report: `conv_tuple_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_tuple.py
- guest leg: 0/8 marks
- pins: **6 passed** / 8 run (+13 quarantined of 21 extracted)

| pin | result | got |
|---|---|---|
| TupleTest.test_getitem_error | PASS | |
| TupleTest.test_keyword_args | PASS | |
| TupleTest.test_keywords_in_subclass | PASS | |
| TupleTest.test_tupleresizebug | PASS | |
| TupleTest.test_hash_exact | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'"> |
| TupleTest.test_hash_optional | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'"> |
| TupleTest.test_repr_large | PASS | |
| TupleTest.test_no_comdat_folding | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TupleTest.test_track_literals | decorator:support.cpython_only |
| TupleTest.test_track_dynamic | decorator:support.cpython_only |
| TupleTest.test_track_subtypes | decorator:support.cpython_only |
| TupleTest.test_bug7466 | decorator:support.cpython_only |
| TupleTest.test_repr | uses-self.type2test |
| TupleTest.test_iterator_pickle | uses-self.type2test |
| TupleTest.test_reversed_pickle | uses-self.type2test |
| TupleTest.test_lexicographic_ordering | uses-self.type2test |
| TupleTest.test_constructors | host-raised:RuntimeError: super(): no arguments |
| TupleTest.test_truth | host-raised:RuntimeError: super(): no arguments |
| TupleTest.test_len | host-raised:RuntimeError: super(): no arguments |
| TupleTest.test_iadd | host-raised:RuntimeError: super(): no arguments |
| TupleTest.test_imul | host-raised:RuntimeError: super(): no arguments |

## Expected vs got

### TupleTest.test_hash_exact (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'">

### TupleTest.test_hash_optional (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'">
