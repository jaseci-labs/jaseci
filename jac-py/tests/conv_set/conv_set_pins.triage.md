# Triage report: `conv_set_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_set.py
- guest leg: 0/68 marks
- pins: **66 passed** / 68 run (+138 quarantined of 206 extracted)

| pin | result | got |
|---|---|---|
| TestBasicOps.test_issue_37219 | PASS | |
| TestBasicOpsSingleton.test_in | PASS | |
| TestBasicOpsSingleton.test_not_in | PASS | |
| TestBasicOpsTuple.test_in | PASS | |
| TestBasicOpsTuple.test_not_in | PASS | |
| TestExceptionPropagation.test_instanceWithException | PASS | |
| TestExceptionPropagation.test_instancesWithoutException | PASS | |
| TestExceptionPropagation.test_changingSizeWhileIterating | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'no exception when changing size during iteration'"> |
| TestSetOfSets.test_constructor | PASS | |
| TestBinaryOps.test_eq | PASS | |
| TestBinaryOps.test_union_subset | PASS | |
| TestBinaryOps.test_union_superset | PASS | |
| TestBinaryOps.test_union_overlap | PASS | |
| TestBinaryOps.test_union_non_overlap | PASS | |
| TestBinaryOps.test_intersection_subset | PASS | |
| TestBinaryOps.test_intersection_superset | PASS | |
| TestBinaryOps.test_intersection_overlap | PASS | |
| TestBinaryOps.test_intersection_non_overlap | PASS | |
| TestBinaryOps.test_isdisjoint_subset | PASS | |
| TestBinaryOps.test_isdisjoint_superset | PASS | |
| TestBinaryOps.test_isdisjoint_overlap | PASS | |
| TestBinaryOps.test_isdisjoint_non_overlap | PASS | |
| TestBinaryOps.test_sym_difference_subset | PASS | |
| TestBinaryOps.test_sym_difference_superset | PASS | |
| TestBinaryOps.test_sym_difference_overlap | PASS | |
| TestBinaryOps.test_sym_difference_non_overlap | PASS | |
| TestUpdateOps.test_union_subset | PASS | |
| TestUpdateOps.test_union_superset | PASS | |
| TestUpdateOps.test_union_overlap | PASS | |
| TestUpdateOps.test_union_non_overlap | PASS | |
| TestUpdateOps.test_union_method_call | PASS | |
| TestUpdateOps.test_intersection_subset | PASS | |
| TestUpdateOps.test_intersection_superset | PASS | |
| TestUpdateOps.test_intersection_overlap | PASS | |
| TestUpdateOps.test_intersection_non_overlap | PASS | |
| TestUpdateOps.test_intersection_method_call | PASS | |
| TestUpdateOps.test_sym_difference_subset | PASS | |
| TestUpdateOps.test_sym_difference_superset | PASS | |
| TestUpdateOps.test_sym_difference_overlap | PASS | |
| TestUpdateOps.test_sym_difference_non_overlap | PASS | |
| TestUpdateOps.test_sym_difference_method_call | PASS | |
| TestUpdateOps.test_difference_subset | PASS | |
| TestUpdateOps.test_difference_superset | PASS | |
| TestUpdateOps.test_difference_overlap | PASS | |
| TestUpdateOps.test_difference_non_overlap | PASS | |
| TestUpdateOps.test_difference_method_call | PASS | |
| TestMutate.test_add_present | PASS | |
| TestMutate.test_add_absent | PASS | |
| TestMutate.test_add_until_full | PASS | |
| TestMutate.test_remove_present | PASS | |
| TestMutate.test_remove_absent | PASS | |
| TestMutate.test_remove_until_empty | PASS | |
| TestMutate.test_discard_present | PASS | |
| TestMutate.test_discard_absent | PASS | |
| TestMutate.test_clear | PASS | |
| TestMutate.test_pop | PASS | |
| TestMutate.test_update_empty_tuple | PASS | |
| TestMutate.test_update_unit_tuple_overlap | PASS | |
| TestMutate.test_update_unit_tuple_non_overlap | PASS | |
| TestIdentities.test_binopsVsSubsets | PASS | |
| TestIdentities.test_commutativity | PASS | |
| TestIdentities.test_summations | PASS | |
| TestIdentities.test_exclusion | PASS | |
| TestWeirdBugs.test_iter_and_mutate | PASS | |
| TestWeirdBugs.test_merge_and_mutate | PASS | |
| TestWeirdBugs.test_hash_collision_concurrent_add | PASS | |
| TestGraphs.test_cube | PASS | |
| TestGraphs.test_cuboctahedron | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestJointOps.test_new_or_init | helper:setUp(uses-self.thetype) |
| TestJointOps.test_uniquification | helper:setUp(uses-self.thetype) |
| TestJointOps.test_len | helper:setUp(uses-self.thetype) |
| TestJointOps.test_contains | helper:setUp(uses-self.thetype) |
| TestJointOps.test_union | helper:setUp(uses-self.thetype) |
| TestJointOps.test_or | helper:setUp(uses-self.thetype) |
| TestJointOps.test_intersection | helper:setUp(uses-self.thetype) |
| TestJointOps.test_isdisjoint | helper:setUp(uses-self.thetype) |
| TestJointOps.test_and | helper:setUp(uses-self.thetype) |
| TestJointOps.test_difference | helper:setUp(uses-self.thetype) |
| TestJointOps.test_sub | helper:setUp(uses-self.thetype) |
| TestJointOps.test_symmetric_difference | helper:setUp(uses-self.thetype) |
| TestJointOps.test_xor | helper:setUp(uses-self.thetype) |
| TestJointOps.test_equality | helper:setUp(uses-self.thetype) |
| TestJointOps.test_setOfFrozensets | helper:setUp(uses-self.thetype) |
| TestJointOps.test_sub_and_super | helper:setUp(uses-self.thetype) |
| TestJointOps.test_pickling | helper:setUp(uses-self.thetype) |
| TestJointOps.test_iterator_pickling | helper:setUp(uses-self.thetype) |
| TestJointOps.test_deepcopy | helper:setUp(uses-self.thetype) |
| TestJointOps.test_gc | helper:setUp(uses-self.thetype) |
| TestJointOps.test_subclass_with_custom_hash | helper:setUp(uses-self.thetype) |
| TestJointOps.test_badcmp | helper:setUp(uses-self.thetype) |
| TestJointOps.test_cyclical_repr | helper:setUp(uses-self.thetype) |
| TestJointOps.test_do_not_rehash_dict_keys | helper:setUp(uses-self.thetype) |
| TestJointOps.test_container_iterator | helper:setUp(uses-self.thetype) |
| TestJointOps.test_free_after_iterating | helper:setUp(uses-self.thetype) |
| TestSet.test_init | helper:setUp(uses-self.thetype) |
| TestSet.test_constructor_identity | helper:setUp(uses-self.thetype) |
| TestSet.test_set_literal | helper:setUp(uses-self.thetype) |
| TestSet.test_set_literal_insertion_order | helper:setUp(uses-self.thetype) |
| TestSet.test_set_literal_evaluation_order | helper:setUp(uses-self.thetype) |
| TestSet.test_hash | helper:setUp(uses-self.thetype) |
| TestSet.test_clear | helper:setUp(uses-self.thetype) |
| TestSet.test_copy | helper:setUp(uses-self.thetype) |
| TestSet.test_add | helper:setUp(uses-self.thetype) |
| TestSet.test_remove | helper:setUp(uses-self.thetype) |
| TestSet.test_remove_keyerror_unpacking | helper:setUp(uses-self.thetype) |
| TestSet.test_remove_keyerror_set | helper:setUp(uses-self.thetype) |
| TestSet.test_discard | helper:setUp(uses-self.thetype) |
| TestSet.test_pop | helper:setUp(uses-self.thetype) |
| TestSet.test_update | helper:setUp(uses-self.thetype) |
| TestSet.test_ior | helper:setUp(uses-self.thetype) |
| TestSet.test_intersection_update | helper:setUp(uses-self.thetype) |
| TestSet.test_iand | helper:setUp(uses-self.thetype) |
| TestSet.test_difference_update | helper:setUp(uses-self.thetype) |
| TestSet.test_isub | helper:setUp(uses-self.thetype) |
| TestSet.test_symmetric_difference_update | helper:setUp(uses-self.thetype) |
| TestSet.test_ixor | helper:setUp(uses-self.thetype) |
| TestSet.test_inplace_on_self | helper:setUp(uses-self.thetype) |
| TestSet.test_weakref | helper:setUp(uses-self.thetype) |
| TestSet.test_rich_compare | helper:setUp(uses-self.thetype) |
| TestSet.test_set_membership | helper:setUp(uses-self.thetype) |
| TestSet.test_unhashable_element | helper:setUp(uses-self.thetype) |
| TestSet.test_hash_collision_remove_add | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_keywords_in_subclass | helper:setUp(uses-self.thetype) |
| TestFrozenSet.test_init | helper:setUp(uses-self.thetype) |
| TestFrozenSet.test_constructor_identity | helper:setUp(uses-self.thetype) |
| TestFrozenSet.test_hash | helper:setUp(uses-self.thetype) |
| TestFrozenSet.test_copy | helper:setUp(uses-self.thetype) |
| TestFrozenSet.test_frozen_as_dictkey | helper:setUp(uses-self.thetype) |
| TestFrozenSet.test_hash_caching | helper:setUp(uses-self.thetype) |
| TestFrozenSet.test_hash_effectiveness | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_keywords_in_subclass | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_constructor_identity | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_copy | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_nested_empty_constructor | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_singleton_empty_frozenset | helper:setUp(uses-self.thetype) |
| TestBasicOpsString.test_repr | helper:check_repr_against_values(self.assertStartsWith) |
| TestBasicOpsBytes.test_repr | helper:check_repr_against_values(self.assertStartsWith) |
| TestBasicOpsMixedStringBytes.test_repr | helper:setUp(self.enterContext) |
| TestSubsets.test_issubset | unresolved-name:TestSubsets |
| TestVariousIteratorArgs.test_constructor | unresolved-name:E |
| TestVariousIteratorArgs.test_inline_methods | unresolved-name:E |
| TestVariousIteratorArgs.test_inplace_methods | unresolved-name:E |
| TestWeirdBugs.test_8420_set_merge | unresolved-name:bad_dict_clear |
| TestBinaryOpsMutating.test_eq_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_ne_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_lt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_le_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_gt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_ge_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_and_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_or_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_sub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_xor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_iadd_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_ior_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_isub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_ixor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating.test_iteration_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_issubset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_issuperset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_intersection_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_union_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_symmetric_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_isdisjoint_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_intersection_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_symmetric_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating.test_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBasicOps.test_repr | host-raised:AttributeError: '_SelfNS' object has no attribute 'repr' |
| TestBasicOps.test_length | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_self_equality | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_equivalent_equality | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_copy | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_self_union | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_empty_union | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_union_empty | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_self_intersection | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_empty_intersection | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_intersection_empty | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_self_isdisjoint | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_empty_isdisjoint | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_isdisjoint_empty | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_self_symmetric_difference | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_empty_symmetric_difference | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_self_difference | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_empty_difference | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_empty_difference_rev | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_iteration | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestBasicOps.test_pickling | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_eq_ne | host-raised:AttributeError: '_SelfNS' object has no attribute 'other' |
| TestOnlySetsInBinaryOps.test_ge_gt_le_lt | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_update_operator | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_update | host-raised:AttributeError: '_SelfNS' object has no attribute 'otherIsIterable' |
| TestOnlySetsInBinaryOps.test_union | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_intersection_update_operator | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_intersection_update | host-raised:AttributeError: '_SelfNS' object has no attribute 'otherIsIterable' |
| TestOnlySetsInBinaryOps.test_intersection | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_sym_difference_update_operator | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_sym_difference_update | host-raised:AttributeError: '_SelfNS' object has no attribute 'otherIsIterable' |
| TestOnlySetsInBinaryOps.test_sym_difference | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_difference_update_operator | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestOnlySetsInBinaryOps.test_difference_update | host-raised:AttributeError: '_SelfNS' object has no attribute 'otherIsIterable' |
| TestOnlySetsInBinaryOps.test_difference | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestCopying.test_copy | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |
| TestCopying.test_deep_copy | host-raised:AttributeError: '_SelfNS' object has no attribute 'set' |

## Expected vs got

### TestExceptionPropagation.test_changingSizeWhileIterating (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'no exception when changing size during iteration'">

### TestGraphs.test_cuboctahedron (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">
