# Triage report: `conv_dict_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_dict.py
- guest leg: 0/75 marks
- pins: **49 passed** / 75 run (+17 quarantined of 92 extracted)

| pin | result | got |
|---|---|---|
| DictTest.test_invalid_keyword_arguments | PASS | |
| DictTest.test_constructor | PASS | |
| DictTest.test_literal_constructor | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DictTest.test_merge_operator | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for \|: \'dict\' and \'list\'"'> |
| DictTest.test_bool | PASS | |
| DictTest.test_keys | PASS | |
| DictTest.test_values | PASS | |
| DictTest.test_items | PASS | |
| DictTest.test_views_mapping | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'mapping'"> |
| DictTest.test_contains | PASS | |
| DictTest.test_len | PASS | |
| DictTest.test_getitem | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "cannot use \'BadHash\' as a dict key (unhashable type: \'BadHash\')"'> |
| DictTest.test_clear | PASS | |
| DictTest.test_update | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {}, {1: 1, 2: 2, 3: 3})"'> |
| DictTest.test_update_shared_keys | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {\'a\': \'a\', \'a\': \'a\', \'b\': \'b\'}, {\'a\': \'a\', \'b\': \'b\'})"'> |
| DictTest.test_fromkeys | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', {\'a\': None}, <class \'**main**.dictlike\'>)"'> |
| DictTest.test_copy | PASS | |
| DictTest.test_copy_fuzz | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DictTest.test_copy_maintains_tracking | PASS | |
| DictTest.test_copy_noncompact | PASS | |
| DictTest.test_get | PASS | |
| DictTest.test_setdefault | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "cannot use \'BadHash\' as a dict key (unhashable type: \'BadHash\')"'> |
| DictTest.test_setdefault_atomic | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'> |
| DictTest.test_setitem_atomic_at_resize | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'> |
| DictTest.test_popitem | PASS | |
| DictTest.test_pop | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC KeyError '<unhashable>'"> |
| DictTest.test_mutating_iteration | PASS | |
| DictTest.test_mutating_iteration_delete | PASS | |
| DictTest.test_mutating_iteration_delete_over_values | PASS | |
| DictTest.test_mutating_iteration_delete_over_items | PASS | |
| DictTest.test_mutating_lookup | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {}, {<**main**.NastyKey object at 0x7fd5cb7478d0>: 2})"'> |
| DictTest.test_repr | PASS | |
| DictTest.test_eq | PASS | |
| DictTest.test_keys_contained | PASS | |
| DictTest.test_errors_in_view_containment_check | PASS | |
| DictTest.test_dictview_set_operations_on_keys | PASS | |
| DictTest.test_dictview_set_operations_on_items | PASS | |
| DictTest.test_items_symmetric_difference | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DictTest.test_dictview_mixed_set_operations | PASS | |
| DictTest.test_bad_key | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'d\' is not defined"'> |
| DictTest.test_resize1 | PASS | |
| DictTest.test_resize2 | PASS | |
| DictTest.test_empty_presized_dict_in_freelist | PASS | |
| DictTest.test_container_iterator | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIs\', <**main**.C object at 0x7fd5cb7a4150>, None)"'> |
| DictTest.test_iterator_pickling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7fd5cb84b110>"'> |
| DictTest.test_itemiterator_pickling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7fd5ccccbab0>"'> |
| DictTest.test_valuesiterator_pickling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7fd5ccccb110>"'> |
| DictTest.test_reverseiterator_pickling | PASS | |
| DictTest.test_reverseitemiterator_pickling | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'abc'"> |
| DictTest.test_reversevaluesiterator_pickling | PASS | |
| DictTest.test_instance_dict_getattr_str_subclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError ''"> |
| DictTest.test_object_set_item_single_instance_non_str_key | PASS | |
| DictTest.test_reentrant_insertion | PASS | |
| DictTest.test_merge_and_mutate | PASS | |
| DictTest.test_equal_operator_modifying_operand | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'> |
| DictTest.test_fromkeys_operator_modifying_dict_operand | PASS | |
| DictTest.test_fromkeys_operator_modifying_set_operand | PASS | |
| DictTest.test_dictitems_contains_use_after_free | PASS | |
| DictTest.test_dict_contain_use_after_free | PASS | |
| DictTest.test_init_use_after_free | PASS | |
| DictTest.test_oob_indexing_dictiter_iternextitem | PASS | |
| DictTest.test_reversed | PASS | |
| DictTest.test_reverse_iterator_for_empty_dict | PASS | |
| DictTest.test_reverse_iterator_for_shared_shared_dicts | PASS | |
| DictTest.test_dict_copy_order | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [(\'c\', 3), (\'b\', 2), (\'a\', 1)], [(\'a\', 1), (\'b\', 2), (\'c\', 3)])"'> |
| DictTest.test_store_evilattr | PASS | |
| DictTest.test_str_nonstr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'check_impl_detail'"> |
| DictTest.test_overwrite_managed_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'attr'"> |
| DictTest.test_clear_at_lookup | PASS | |
| DictTest.test_split_table_update_with_str_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 1, 2)"'> |
| DictTest.test_split_table_insert_with_str_subclass | PASS | |
| DictTest.test_clear_reentrant_embedded | PASS | |
| DictTest.test_clear_reentrant_cycle | PASS | |
| DictTest.test_clear_reentrant_force_combined | PASS | |
| DictTest.test_clear_reentrant_delete | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| DictTest.test_repr_deep | decorator:support.skip_wasi_stack_overflow |
| DictTest.test_splittable_setdefault | decorator:support.cpython_only |
| DictTest.test_splittable_del | decorator:support.cpython_only |
| DictTest.test_splittable_pop | decorator:support.cpython_only |
| DictTest.test_splittable_pop_pending | decorator:support.cpython_only |
| DictTest.test_splittable_popitem | decorator:support.cpython_only |
| DictTest.test_splittable_update | decorator:support.cpython_only |
| DictTest.test_splittable_to_generic_combinedtable | decorator:support.cpython_only |
| DictTest.test_dict_items_result_gc | decorator:support.cpython_only |
| DictTest.test_dict_items_result_gc_reversed | decorator:support.cpython_only |
| CAPITest.test_getitem_knownhash | decorator:support.cpython_only |
| DictTest.test_update_type_error | unresolved-name:cm |
| DictTest.test_missing | self.assertNotHasAttr |
| DictTest.test_tuple_keyerror | unresolved-name:c |
| DictTest.test_unhashable_key | uses-self.assertRaisesRegex |
| DictTest.test_hash_collision_remove_add | unresolved-name:CustomHash |
| DictTest.test_free_after_iterating | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### DictTest.test_bad_key (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'d\' is not defined"'>

### DictTest.test_container_iterator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIs\', <**main**.C object at 0x7fd5cb7a4150>, None)"'>

### DictTest.test_copy_fuzz (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DictTest.test_dict_copy_order (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [(\'c\', 3), (\'b\', 2), (\'a\', 1)], [(\'a\', 1), (\'b\', 2), (\'c\', 3)])"'>

### DictTest.test_equal_operator_modifying_operand (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'>

### DictTest.test_fromkeys (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', {\'a\': None}, <class \'**main**.dictlike\'>)"'>

### DictTest.test_getitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "cannot use \'BadHash\' as a dict key (unhashable type: \'BadHash\')"'>

### DictTest.test_instance_dict_getattr_str_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError ''">

### DictTest.test_itemiterator_pickling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7fd5ccccbab0>"'>

### DictTest.test_items_symmetric_difference (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DictTest.test_iterator_pickling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7fd5cb84b110>"'>

### DictTest.test_literal_constructor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DictTest.test_merge_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for |: \'dict\' and \'list\'"'>

### DictTest.test_mutating_lookup (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {}, {<**main**.NastyKey object at 0x7fd5cb7478d0>: 2})"'>

### DictTest.test_overwrite_managed_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'attr'">

### DictTest.test_pop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC KeyError '<unhashable>'">

### DictTest.test_reverseitemiterator_pickling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'abc'">

### DictTest.test_setdefault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "cannot use \'BadHash\' as a dict key (unhashable type: \'BadHash\')"'>

### DictTest.test_setdefault_atomic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'>

### DictTest.test_setitem_atomic_at_resize (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'>

### DictTest.test_split_table_update_with_str_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 1, 2)"'>

### DictTest.test_str_nonstr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'check_impl_detail'">

### DictTest.test_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {}, {1: 1, 2: 2, 3: 3})"'>

### DictTest.test_update_shared_keys (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {\'a\': \'a\', \'a\': \'a\', \'b\': \'b\'}, {\'a\': \'a\', \'b\': \'b\'})"'>

### DictTest.test_valuesiterator_pickling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7fd5ccccb110>"'>

### DictTest.test_views_mapping (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'mapping'">
