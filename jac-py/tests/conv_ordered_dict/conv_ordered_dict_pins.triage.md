# Triage report: `conv_ordered_dict_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_ordered_dict.py
- guest leg: 0/88 marks
- pins: **0 passed** / 88 run (+31 quarantined of 119 extracted)

| pin | result | got |
|---|---|---|
| PurePythonOrderedDictSubclassTests.test_init | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_init | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_468 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CPythonOrderedDictSubclassTests.test_468 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| PurePythonOrderedDictSubclassTests.test_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_overridden_init | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_overridden_init | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_fromkeys | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_fromkeys | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_clear | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CPythonOrderedDictSubclassTests.test_clear | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| PurePythonOrderedDictSubclassTests.test_delitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_delitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_setitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_setitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_iterators | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CPythonOrderedDictSubclassTests.test_iterators | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| PurePythonOrderedDictSubclassTests.test_detect_deletion_during_iteration | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_detect_deletion_during_iteration | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_sorted_iterators | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_sorted_iterators | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_iterators_empty | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_iterators_empty | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_popitem | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CPythonOrderedDictSubclassTests.test_popitem | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| PurePythonOrderedDictSubclassTests.test_popitem_last | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_popitem_last | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_pop | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CPythonOrderedDictSubclassTests.test_pop | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| PurePythonOrderedDictSubclassTests.test_equality | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CPythonOrderedDictSubclassTests.test_equality | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| PurePythonOrderedDictSubclassTests.test_yaml_linkage | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_yaml_linkage | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_reduce_not_too_fat | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_reduce_not_too_fat | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_pickle_recursive | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_pickle_recursive | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_repr | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_repr | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_repr_recursive | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_repr_recursive | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_repr_recursive_values | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_repr_recursive_values | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_setdefault | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CPythonOrderedDictSubclassTests.test_setdefault | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| PurePythonOrderedDictSubclassTests.test_reinsert | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_reinsert | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_move_to_end | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_move_to_end | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_move_to_end_issue25406 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_move_to_end_issue25406 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_sizeof | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_sizeof | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_views | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_views | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_override_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_override_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_highly_nested | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_highly_nested | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_highly_nested_subclass | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_highly_nested_subclass | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_delitem_hash_collision | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_delitem_hash_collision | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_issue24347 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CPythonOrderedDictSubclassTests.test_issue24347 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| PurePythonOrderedDictSubclassTests.test_issue24348 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_issue24348 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_issue24667 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_issue24667 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_dict_setitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_dict_setitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_dict_delitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_dict_delitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_dict_clear | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_dict_clear | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_dict_pop | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_dict_pop | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_dict_popitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_dict_popitem | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_dict_setdefault | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_dict_setdefault | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_dict_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_dict_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_reference_loop | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_reference_loop | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |
| PurePythonOrderedDictSubclassTests.test_merge_operator | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| CPythonOrderedDictSubclassTests.test_merge_operator | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| OrderedDictTests.test_ordered_dict_items_result_gc | decorator:support.cpython_only |
| CPythonOrderedDictTests.test_sizeof_exact | decorator:unittest.skipUnless |
| CPythonOrderedDictTests.test_key_change_during_iteration | decorator:unittest.skipUnless |
| CPythonOrderedDictTests.test_iterators_pickling | decorator:unittest.skipUnless |
| CPythonOrderedDictTests.test_weakref_list_is_not_traversed | decorator:unittest.skipUnless |
| CPythonGeneralMappingTests.test_popitem | decorator:unittest.skipUnless |
| CPythonSubclassMappingTests.test_popitem | decorator:unittest.skipUnless |
| PurePythonOrderedDictSubclassTests.test_init_calls | self.OrderedDict |
| CPythonOrderedDictSubclassTests.test_init_calls | self.OrderedDict |
| PurePythonOrderedDictSubclassTests.test_abc | self.assertIsSubclass |
| CPythonOrderedDictSubclassTests.test_abc | self.assertIsSubclass |
| PurePythonOrderedDictSubclassTests.test_copying | self.assertNotHasAttr |
| CPythonOrderedDictSubclassTests.test_copying | self.assertNotHasAttr |
| PurePythonOrderedDictSubclassTests.test_issue119004_attribute_error | uses-self.OrderedDict |
| CPythonOrderedDictSubclassTests.test_issue119004_change_size_by_clear | uses-self.OrderedDict |
| CPythonOrderedDictSubclassTests.test_issue119004_change_size_by_delete_key | uses-self.OrderedDict |
| CPythonOrderedDictSubclassTests.test_issue119004_change_linked_list_by_clear | uses-self.OrderedDict |
| CPythonOrderedDictSubclassTests.test_issue119004_change_linked_list_by_delete_key | uses-self.OrderedDict |
| CPythonOrderedDictSubclassTests.test_issue119004_change_size_by_delete_key_in_dict_eq | uses-self.OrderedDict |
| PurePythonGeneralMappingTests.test_popitem | uses-self._empty_mapping |
| PurePythonSubclassMappingTests.test_popitem | uses-self._empty_mapping |
| PySimpleLRUCacheTests.test_add_after_full | uses-self.type2test |
| CSimpleLRUCacheTests.test_add_after_full | uses-self.type2test |
| PySimpleLRUCacheTests.test_popitem | uses-self.type2test |
| CSimpleLRUCacheTests.test_popitem | uses-self.type2test |
| PySimpleLRUCacheTests.test_pop | uses-self.type2test |
| CSimpleLRUCacheTests.test_pop | uses-self.type2test |
| PySimpleLRUCacheTests.test_change_order_on_get | uses-self.type2test |
| CSimpleLRUCacheTests.test_change_order_on_get | uses-self.type2test |
| PurePythonOrderedDictSubclassTests.test_free_after_iterating | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertRaises' |
| CPythonOrderedDictSubclassTests.test_free_after_iterating | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertRaises' |

## Expected vs got

### CPythonOrderedDictSubclassTests.test_468 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CPythonOrderedDictSubclassTests.test_clear (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CPythonOrderedDictSubclassTests.test_delitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_delitem_hash_collision (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_detect_deletion_during_iteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_dict_clear (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_dict_delitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_dict_pop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_dict_popitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_dict_setdefault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_dict_setitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_dict_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_equality (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CPythonOrderedDictSubclassTests.test_fromkeys (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_highly_nested (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_highly_nested_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_init (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_issue24347 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CPythonOrderedDictSubclassTests.test_issue24348 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_issue24667 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_iterators (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CPythonOrderedDictSubclassTests.test_iterators_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_merge_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_move_to_end (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_move_to_end_issue25406 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_overridden_init (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_override_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_pickle_recursive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_pop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CPythonOrderedDictSubclassTests.test_popitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CPythonOrderedDictSubclassTests.test_popitem_last (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_reduce_not_too_fat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_reference_loop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_reinsert (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_repr_recursive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_repr_recursive_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_setdefault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CPythonOrderedDictSubclassTests.test_setitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_sizeof (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_sorted_iterators (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_views (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### CPythonOrderedDictSubclassTests.test_yaml_linkage (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_468 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### PurePythonOrderedDictSubclassTests.test_clear (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### PurePythonOrderedDictSubclassTests.test_delitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_delitem_hash_collision (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_detect_deletion_during_iteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_dict_clear (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_dict_delitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_dict_pop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_dict_popitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_dict_setdefault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_dict_setitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_dict_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_equality (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### PurePythonOrderedDictSubclassTests.test_fromkeys (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_highly_nested (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_highly_nested_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'mapping_tests' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_init (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_issue24347 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### PurePythonOrderedDictSubclassTests.test_issue24348 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_issue24667 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_iterators (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### PurePythonOrderedDictSubclassTests.test_iterators_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_merge_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_move_to_end (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_move_to_end_issue25406 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_overridden_init (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_override_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_pickle_recursive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_pop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### PurePythonOrderedDictSubclassTests.test_popitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### PurePythonOrderedDictSubclassTests.test_popitem_last (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_reduce_not_too_fat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_reference_loop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_reinsert (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_repr_recursive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_repr_recursive_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_setdefault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### PurePythonOrderedDictSubclassTests.test_setitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_sizeof (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_sorted_iterators (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_views (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### PurePythonOrderedDictSubclassTests.test_yaml_linkage (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">
