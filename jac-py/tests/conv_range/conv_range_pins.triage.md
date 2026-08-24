# Triage report: `conv_range_pins.jac`

- source: reference/cpython/Lib/test/test_range.py
- guest leg: 0/22 marks
- pins: **16 passed** / 22 run (+7 quarantined of 29 extracted)

| pin | result | got |
|---|---|---|
| RangeTest.test_range | PASS | |
| RangeTest.test_range_constructor_error_messages | PASS | |
| RangeTest.test_large_operands | PASS | |
| RangeTest.test_large_range | PASS | |
| RangeTest.test_invalid_invocation | PASS | |
| RangeTest.test_index | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'ALWAYS_EQ' from '<unknown>'"> |
| RangeTest.test_count | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'ALWAYS_EQ' from '<unknown>'"> |
| RangeTest.test_repr | PASS | |
| RangeTest.test_exhausted_iterator_pickling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'rangeiter\' has policy BridgePolicy.LAZY_ITER but no to_host conversion arm"'> |
| RangeTest.test_large_exhausted_iterator_pickling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'rangeiter\' has policy BridgePolicy.LAZY_ITER but no to_host conversion arm"'> |
| RangeTest.test_iterator_unpickle_compat | PASS | |
| RangeTest.test_iterator_setstate | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**setstate**'"> |
| RangeTest.test_odd_bug | PASS | |
| RangeTest.test_types | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'ALWAYS_EQ' from '<unknown>'"> |
| RangeTest.test_strided_limits | PASS | |
| RangeTest.test_empty | PASS | |
| RangeTest.test_range_iterators_invocation | PASS | |
| RangeTest.test_slice | PASS | |
| RangeTest.test_contains | PASS | |
| RangeTest.test_reverse_iteration | PASS | |
| RangeTest.test_issue11845 | PASS | |
| RangeTest.test_comparison | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| RangeTest.test_user_index_method | uses-self.n |
| RangeTest.test_pickling | uses-self.subTest |
| RangeTest.test_iterator_pickling | uses-self.subTest |
| RangeTest.test_iterator_pickling_overflowing_index | uses-self.subTest |
| RangeTest.test_iterator_invalid_setstate | uses-self.subTest |
| RangeTest.test_range_iterators | self.assert_iterators_equal |
| RangeTest.test_attributes | self.assert_attrs |

## Expected vs got

### RangeTest.test_count (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'ALWAYS_EQ' from '<unknown>'">

### RangeTest.test_exhausted_iterator_pickling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'rangeiter\' has policy BridgePolicy.LAZY_ITER but no to_host conversion arm"'>

### RangeTest.test_index (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'ALWAYS_EQ' from '<unknown>'">

### RangeTest.test_iterator_setstate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**setstate**'">

### RangeTest.test_large_exhausted_iterator_pickling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'rangeiter\' has policy BridgePolicy.LAZY_ITER but no to_host conversion arm"'>

### RangeTest.test_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'ALWAYS_EQ' from '<unknown>'">
