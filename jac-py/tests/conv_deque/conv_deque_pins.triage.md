# Triage report: `conv_deque_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_deque.py
- guest leg: 0/60 marks
- pins: **37 passed** / 60 run (+3 quarantined of 63 extracted)

| pin | result | got |
|---|---|---|
| TestBasic.test_basics | PASS | |
| TestBasic.test_maxlen | PASS | |
| TestBasic.test_maxlen_zero | PASS | |
| TestBasic.test_maxlen_attribute | PASS | |
| TestBasic.test_count | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'"> |
| TestBasic.test_comparisons | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', True, False)"'> |
| TestBasic.test_contains | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| TestBasic.test_contains_count_index_stop_crashes | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| TestBasic.test_extend | PASS | |
| TestBasic.test_add | PASS | |
| TestBasic.test_iadd | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError \'can only concatenate deque (not "str") to deque\''> |
| TestBasic.test_extendleft | PASS | |
| TestBasic.test_getitem | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestBasic.test_index | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| TestBasic.test_index_bug_24913 | PASS | |
| TestBasic.test_insert | PASS | |
| TestBasic.test_insert_bug_26194 | PASS | |
| TestBasic.test_imul | PASS | |
| TestBasic.test_mul | PASS | |
| TestBasic.test_setitem | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| TestBasic.test_delitem | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestBasic.test_reverse | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestBasic.test_rotate | PASS | |
| TestBasic.test_len | PASS | |
| TestBasic.test_underflow | PASS | |
| TestBasic.test_clear | PASS | |
| TestBasic.test_remove | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'> |
| TestBasic.test_repr | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'deque\' is not defined"'> |
| TestBasic.test_init | PASS | |
| TestBasic.test_hash | PASS | |
| TestBasic.test_long_steadystate_queue_popleft | PASS | |
| TestBasic.test_long_steadystate_queue_popright | PASS | |
| TestBasic.test_big_queue_popleft | PASS | |
| TestBasic.test_big_queue_popright | PASS | |
| TestBasic.test_big_stack_right | PASS | |
| TestBasic.test_big_stack_left | PASS | |
| TestBasic.test_roundtrip_iter_init | PASS | |
| TestBasic.test_pickle | PASS | |
| TestBasic.test_pickle_recursive | PASS | |
| TestBasic.test_iterator_pickle | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'"> |
| TestBasic.test_deepcopy | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertNotEqual\', [[10]], [[10]])"'> |
| TestBasic.test_copy | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestBasic.test_copy_method | PASS | |
| TestBasic.test_reversed | PASS | |
| TestBasic.test_reversed_new | PASS | |
| TestBasic.test_gc_doesnt_blowup | PASS | |
| TestBasic.test_container_iterator | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'> |
| TestVariousIteratorArgs.test_constructor | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'"> |
| TestVariousIteratorArgs.test_iter_with_altered_data | PASS | |
| TestVariousIteratorArgs.test_runtime_error_on_empty_deque | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC StopIteration ''"> |
| TestSubclass.test_basics | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'append'"> |
| TestSubclass.test_copy_pickle | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__copy__'">` |
| TestSubclass.test_pickle_recursive | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'append'"> |
| TestSubclass.test_weakref | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'"> |
| TestSubclass.test_strange_subclass | PASS | |
| TestSubclassWithKwargs.test_subclass_with_kwargs | PASS | |
| TestSequence.test_getitem | PASS | |
| TestSequence.test_getslice | PASS | |
| TestSequence.test_subscript | PASS | |
| deque.doctests:libreftest | GUEST-WRONG-OUTPUT | RUN<'IndexError: pop from an empty deque'> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestBasic.test_sizeof | decorator:support.cpython_only |
| TestSubclass.test_bug_31608 | decorator:support.cpython_only |
| TestSequence.test_free_after_iterating | self.skipTest |

## Expected vs got

### TestBasic.test_comparisons (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', True, False)"'>

### TestBasic.test_container_iterator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'>

### TestBasic.test_contains (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### TestBasic.test_contains_count_index_stop_crashes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### TestBasic.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestBasic.test_count (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'">

### TestBasic.test_deepcopy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertNotEqual\', [[10]], [[10]])"'>

### TestBasic.test_delitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestBasic.test_getitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestBasic.test_iadd (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError \'can only concatenate deque (not "str") to deque\''>

### TestBasic.test_index (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### TestBasic.test_iterator_pickle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'">

### TestBasic.test_remove (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'>

### TestBasic.test_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'deque\' is not defined"'>

### TestBasic.test_reverse (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestBasic.test_setitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### TestSubclass.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'append'">

### TestSubclass.test_copy_pickle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__copy__'">`

### TestSubclass.test_pickle_recursive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'append'">

### TestSubclass.test_weakref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'">

### TestVariousIteratorArgs.test_constructor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'seq_tests' from '<unknown>'">

### TestVariousIteratorArgs.test_runtime_error_on_empty_deque (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC StopIteration ''">

### deque.doctests:libreftest (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'IndexError: pop from an empty deque'>
