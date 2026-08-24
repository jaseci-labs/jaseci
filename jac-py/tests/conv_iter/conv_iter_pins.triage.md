# Triage report: `conv_iter_pins.jac`

- source: reference/cpython/Lib/test/test_iter.py
- guest leg: 0/18 marks
- pins: **11 passed** / 18 run (+39 quarantined of 57 extracted)

| pin | result | got |
|---|---|---|
| TestCase.test_iter_idempotency | PASS | |
| TestCase.test_iter_independence | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not iterable'"> |
| TestCase.test_nested_comprehensions_iter | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not iterable'"> |
| TestCase.test_nested_comprehensions_for | PASS | |
| TestCase.test_new_style_iter_class | PASS | |
| TestCase.test_iter_function_concealing_reentrant_exhaustion | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| TestCase.test_exception_function | PASS | |
| TestCase.test_countOf | PASS | |
| TestCase.test_sinkstate_list | PASS | |
| TestCase.test_sinkstate_tuple | PASS | |
| TestCase.test_sinkstate_string | PASS | |
| TestCase.test_sinkstate_callable | PASS | |
| TestCase.test_sinkstate_dict | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'dictiter\' has policy BridgePolicy.LAZY_ITER but no to_host conversion arm"'> |
| TestCase.test_sinkstate_yield | PASS | |
| TestCase.test_sinkstate_range | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'rangeiter\' has policy BridgePolicy.LAZY_ITER but no to_host conversion arm"'> |
| TestCase.test_sinkstate_enumerate | PASS | |
| TestCase.test_3720 | VM-CRASH |   jac dev mode - using compiler source at /var/tmp/slatepetrel-wt/jac  Error: 'PyUserObj' object has no attribute 'index' 13703 \|             } 13704 \|             iterator = top as PyIter; 13705 \|             if iterator.index < len(iterator.items) {       \|           ^^^^^^^^^^^^^^ 13706 \|       |
| TestCase.test_extending_list_with_iterator_does_not_segfault | VM-CRASH |   jac dev mode - using compiler source at /var/tmp/slatepetrel-wt/jac  Error: 'PyUserObj' object has no attribute 'index' 13703 \|             } 13704 \|             iterator = top as PyIter; 13705 \|             if iterator.index < len(iterator.items) {       \|           ^^^^^^^^^^^^^^ 13706 \|       |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCase.test_iter_basic | self.check_iterator |
| TestCase.test_iter_for_loop | self.check_for_loop |
| TestCase.test_iter_class_for | self.check_for_loop |
| TestCase.test_iter_class_iter | self.check_iterator |
| TestCase.test_seq_class_for | self.check_for_loop |
| TestCase.test_seq_class_iter | self.check_iterator |
| TestCase.test_mutating_seq_class_iter_pickle | unresolved-name:SequenceClass |
| TestCase.test_mutating_seq_class_exhausted_iter | unresolved-name:SequenceClass |
| TestCase.test_reduce_mutating_builtins_iter | uses-self.name |
| TestCase.test_iter_callable | self.check_iterator |
| TestCase.test_iter_function | self.check_iterator |
| TestCase.test_iter_function_stop | self.check_iterator |
| TestCase.test_exception_sequence | unresolved-name:SequenceClass |
| TestCase.test_stop_sequence | self.check_for_loop |
| TestCase.test_iter_big_range | self.check_for_loop |
| TestCase.test_iter_empty | self.check_for_loop |
| TestCase.test_iter_tuple | self.check_for_loop |
| TestCase.test_iter_range | self.check_for_loop |
| TestCase.test_iter_string | self.check_for_loop |
| TestCase.test_iter_dict | self.check_for_loop |
| TestCase.test_iter_file | self.check_for_loop |
| TestCase.test_builtin_list | unresolved-name:SequenceClass |
| TestCase.test_builtin_tuple | unresolved-name:SequenceClass |
| TestCase.test_builtin_filter | uses-self.truth |
| TestCase.test_builtin_max_min | unresolved-name:SequenceClass |
| TestCase.test_builtin_map | unresolved-name:SequenceClass |
| TestCase.test_builtin_zip | uses-self.i |
| TestCase.test_unicode_join_endcase | uses-self.it |
| TestCase.test_in_and_not_in | unresolved-name:BadIterableClass |
| TestCase.test_indexOf | unresolved-name:BadIterableClass |
| TestCase.test_writelines | uses-self.start |
| TestCase.test_unpack_iter | unresolved-name:IteratingSequenceClass |
| TestCase.test_ref_counting_behavior | uses-self.**class** |
| TestCase.test_sinkstate_sequence | unresolved-name:SequenceClass |
| TestCase.test_iter_overflow | unresolved-name:UnlimitedSequenceClass |
| TestCase.test_iter_neg_setstate | unresolved-name:UnlimitedSequenceClass |
| TestCase.test_free_after_iterating | unresolved-name:SequenceClass |
| TestCase.test_error_iter | unresolved-name:BadIterableClass |
| TestCase.test_exception_locations | uses-self.subTest |

## Expected vs got

### TestCase.test_3720 (VM-CRASH)

- expected: host oracle = `ok`
- got:   jac dev mode - using compiler source at /var/tmp/slatepetrel-wt/jac
 Error: 'PyUserObj' object has no attribute 'index'
13703 |             }
13704 |             iterator = top as PyIter;
13705 |             if iterator.index < len(iterator.items) {
      |           ^^^^^^^^^^^^^^
13706 |

### TestCase.test_extending_list_with_iterator_does_not_segfault (VM-CRASH)

- expected: host oracle = `ok`
- got:   jac dev mode - using compiler source at /var/tmp/slatepetrel-wt/jac
 Error: 'PyUserObj' object has no attribute 'index'
13703 |             }
13704 |             iterator = top as PyIter;
13705 |             if iterator.index < len(iterator.items) {
      |           ^^^^^^^^^^^^^^
13706 |

### TestCase.test_iter_function_concealing_reentrant_exhaustion (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### TestCase.test_iter_independence (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not iterable'">

### TestCase.test_nested_comprehensions_iter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not iterable'">

### TestCase.test_sinkstate_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'dictiter\' has policy BridgePolicy.LAZY_ITER but no to_host conversion arm"'>

### TestCase.test_sinkstate_range (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'rangeiter\' has policy BridgePolicy.LAZY_ITER but no to_host conversion arm"'>
