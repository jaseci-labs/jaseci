# Triage report: `conv_iter_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_iter.py
- guest leg: 0/32 marks
- pins: **16 passed** / 32 run (+25 quarantined of 57 extracted)

| pin | result | got |
|---|---|---|
| TestCase.test_iter_basic | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ce59c70>"'> |
| TestCase.test_iter_idempotency | PASS | |
| TestCase.test_iter_for_loop | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not iterable'"> |
| TestCase.test_iter_independence | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not iterable'"> |
| TestCase.test_nested_comprehensions_iter | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not iterable'"> |
| TestCase.test_nested_comprehensions_for | PASS | |
| TestCase.test_new_style_iter_class | PASS | |
| TestCase.test_iter_function | PASS | |
| TestCase.test_iter_function_stop | PASS | |
| TestCase.test_iter_function_concealing_reentrant_exhaustion | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| TestCase.test_exception_function | PASS | |
| TestCase.test_iter_big_range | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not iterable'"> |
| TestCase.test_iter_empty | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ce59bc0>"'> |
| TestCase.test_iter_tuple | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ceaa4b0>"'> |
| TestCase.test_iter_range | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not iterable'"> |
| TestCase.test_iter_string | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ceab110>"'> |
| TestCase.test_iter_dict | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ceaa560>"'> |
| TestCase.test_iter_file | PASS | |
| TestCase.test_unicode_join_endcase | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'can only join an iterable'"> |
| TestCase.test_countOf | PASS | |
| TestCase.test_writelines | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Whatever\' object is not iterable"'> |
| TestCase.test_ref_counting_behavior | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 1, 0)"'> |
| TestCase.test_sinkstate_list | PASS | |
| TestCase.test_sinkstate_tuple | PASS | |
| TestCase.test_sinkstate_string | PASS | |
| TestCase.test_sinkstate_callable | PASS | |
| TestCase.test_sinkstate_dict | PASS | |
| TestCase.test_sinkstate_yield | PASS | |
| TestCase.test_sinkstate_range | PASS | |
| TestCase.test_sinkstate_enumerate | PASS | |
| TestCase.test_3720 | VM-CRASH |   jac dev mode - using compiler source at /var/tmp/lane8/jac  Error: 'PyUserObj' object has no attribute 'index' 14653 \|             } 14654 \|             iterator = top as PyIter; 14655 \|             if iterator.index < len(iterator.items) {       \|           ^^^^^^^^^^^^^^ 14656 \|                |
| TestCase.test_extending_list_with_iterator_does_not_segfault | VM-CRASH |   jac dev mode - using compiler source at /var/tmp/lane8/jac  Error: 'PyUserObj' object has no attribute 'index' 14653 \|             } 14654 \|             iterator = top as PyIter; 14655 \|             if iterator.index < len(iterator.items) {       \|           ^^^^^^^^^^^^^^ 14656 \|                |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCase.test_iter_class_for | unresolved-name:IteratingSequenceClass |
| TestCase.test_iter_class_iter | unresolved-name:IteratingSequenceClass |
| TestCase.test_seq_class_for | unresolved-name:SequenceClass |
| TestCase.test_seq_class_iter | unresolved-name:SequenceClass |
| TestCase.test_mutating_seq_class_iter_pickle | unresolved-name:SequenceClass |
| TestCase.test_mutating_seq_class_exhausted_iter | unresolved-name:SequenceClass |
| TestCase.test_reduce_mutating_builtins_iter | unresolved-name:EmptyIterClass |
| TestCase.test_iter_callable | unresolved-name:CallableIterClass |
| TestCase.test_exception_sequence | unresolved-name:SequenceClass |
| TestCase.test_stop_sequence | unresolved-name:SequenceClass |
| TestCase.test_builtin_list | unresolved-name:SequenceClass |
| TestCase.test_builtin_tuple | unresolved-name:SequenceClass |
| TestCase.test_builtin_filter | unresolved-name:SequenceClass |
| TestCase.test_builtin_max_min | unresolved-name:SequenceClass |
| TestCase.test_builtin_map | unresolved-name:SequenceClass |
| TestCase.test_builtin_zip | unresolved-name:IteratingSequenceClass |
| TestCase.test_in_and_not_in | unresolved-name:BadIterableClass |
| TestCase.test_indexOf | unresolved-name:BadIterableClass |
| TestCase.test_unpack_iter | unresolved-name:IteratingSequenceClass |
| TestCase.test_sinkstate_sequence | unresolved-name:SequenceClass |
| TestCase.test_iter_overflow | unresolved-name:UnlimitedSequenceClass |
| TestCase.test_iter_neg_setstate | unresolved-name:UnlimitedSequenceClass |
| TestCase.test_free_after_iterating | unresolved-name:SequenceClass |
| TestCase.test_error_iter | unresolved-name:BadIterableClass |
| TestCase.test_exception_locations | uses-self.subTest |

## Expected vs got

### TestCase.test_3720 (VM-CRASH)

- expected: host oracle = `ok`
- got:   jac dev mode - using compiler source at /var/tmp/lane8/jac
 Error: 'PyUserObj' object has no attribute 'index'
14653 |             }
14654 |             iterator = top as PyIter;
14655 |             if iterator.index < len(iterator.items) {
      |           ^^^^^^^^^^^^^^
14656 |

### TestCase.test_extending_list_with_iterator_does_not_segfault (VM-CRASH)

- expected: host oracle = `ok`
- got:   jac dev mode - using compiler source at /var/tmp/lane8/jac
 Error: 'PyUserObj' object has no attribute 'index'
14653 |             }
14654 |             iterator = top as PyIter;
14655 |             if iterator.index < len(iterator.items) {
      |           ^^^^^^^^^^^^^^
14656 |

### TestCase.test_iter_basic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ce59c70>"'>

### TestCase.test_iter_big_range (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not iterable'">

### TestCase.test_iter_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ceaa560>"'>

### TestCase.test_iter_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ce59bc0>"'>

### TestCase.test_iter_for_loop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not iterable'">

### TestCase.test_iter_function_concealing_reentrant_exhaustion (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### TestCase.test_iter_independence (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not iterable'">

### TestCase.test_iter_range (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not iterable'">

### TestCase.test_iter_string (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ceab110>"'>

### TestCase.test_iter_tuple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f3d9ceaa4b0>"'>

### TestCase.test_nested_comprehensions_iter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not iterable'">

### TestCase.test_ref_counting_behavior (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 1, 0)"'>

### TestCase.test_unicode_join_endcase (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'can only join an iterable'">

### TestCase.test_writelines (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Whatever\' object is not iterable"'>
