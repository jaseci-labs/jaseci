# Triage report: `conv_descr_pins.jac`

- source: reference/cpython/Lib/test/test_descr.py
- guest leg: 0/59 marks
- pins: **23 passed** / 59 run (+103 quarantined of 162 extracted)

| pin | result | got |
|---|---|---|
| OperatorsTest.test_explicit_reverse_methods | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (4+3j), (4+3j))"'> |
| OperatorsTest.test_wrap_lenfunc_bad_cast | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**len**'"> |
| ClassPropertiesAndMethods.test_python_lists | PASS | |
| ClassPropertiesAndMethods.test_module_subclasses | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ClassPropertiesAndMethods.test_diamond_inheritance | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected MRO order disagreement (F)'"> |
| ClassPropertiesAndMethods.test_ex5_from_c3_switch | PASS | |
| ClassPropertiesAndMethods.test_monotonicity | PASS | |
| ClassPropertiesAndMethods.test_consistency_with_epg | PASS | |
| ClassPropertiesAndMethods.test_slots_descriptor | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'register'"> |
| ClassPropertiesAndMethods.test_errors | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'inheritance from both list and dict should be illegal'"> |
| ClassPropertiesAndMethods.test_staticmethod_annotations_without_dict_access | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**annotations**'"> |
| ClassPropertiesAndMethods.test_altmro | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'class\' has policy BridgePolicy.STANDIN but no to_host conversion arm"'> |
| ClassPropertiesAndMethods.test_load_attr_extended_arg | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'number_attrs\'"'> |
| ClassPropertiesAndMethods.test_keywords | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 0j, (666+42j))"'> |
| ClassPropertiesAndMethods.test_descrdoc | PASS | |
| ClassPropertiesAndMethods.test_doc_descriptor | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <**main**.DocDescr object at 0x7f8f9171e0b0>, \'object=None; type=NewClass\')"'> |
| ClassPropertiesAndMethods.test_set_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'b'"> |
| ClassPropertiesAndMethods.test_buffer_inheritance | PASS | |
| ClassPropertiesAndMethods.test_repr_with_module_str_subclass | PASS | |
| ClassPropertiesAndMethods.test_keyword_arguments | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**call**'"> |
| ClassPropertiesAndMethods.test_hash_inheritance | PASS | |
| ClassPropertiesAndMethods.test_str_operations | PASS | |
| ClassPropertiesAndMethods.test_deepcopy_recursive | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| ClassPropertiesAndMethods.test_imul_bug | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for *: \'C\' and \'float\'"'> |
| ClassPropertiesAndMethods.test_slices | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [3, 1, 2], [3, 2, 1])"'> |
| ClassPropertiesAndMethods.test_rmul | PASS | |
| ClassPropertiesAndMethods.test_ipow | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for **: \'C\' and \'int\'"'> |
| ClassPropertiesAndMethods.test_ipow_returns_not_implemented | PASS | |
| ClassPropertiesAndMethods.test_no_ipow | PASS | |
| ClassPropertiesAndMethods.test_mutable_bases | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'meth'"> |
| ClassPropertiesAndMethods.test_builtin_bases | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'> |
| ClassPropertiesAndMethods.test_unsubclassable_types | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| ClassPropertiesAndMethods.test_mutable_bases_catch_mro_conflict | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "didn\'t catch MRO conflict"'> |
| ClassPropertiesAndMethods.test_mutable_names | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (\'**main**\', \'C\'), (\'**main**\', \'D\'))"'> |
| ClassPropertiesAndMethods.test_evil_type_name | PASS | |
| ClassPropertiesAndMethods.test_subclass_right_op | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'C.**rfloordiv**\', \'C.**floordiv**\')"'> |
| ClassPropertiesAndMethods.test_carloverre | PASS | |
| ClassPropertiesAndMethods.test_carloverre_multi_inherit_valid | PASS | |
| ClassPropertiesAndMethods.test_carloverre_multi_inherit_invalid | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'setattr through indirect base types should be rejected'"> |
| ClassPropertiesAndMethods.test_file_fault | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| ClassPropertiesAndMethods.test_init | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'did not test **init**() for None return'"> |
| ClassPropertiesAndMethods.test_type___getattribute__ | PASS | |
| ClassPropertiesAndMethods.test_abstractmethods | PASS | |
| ClassPropertiesAndMethods.test_proxy_call | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', <**main**.FakeStr object at 0x7f8f928d8590>, <class \'str\'>)"'> |
| ClassPropertiesAndMethods.test_specialized_method_calls_check_types | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'append'"> |
| ClassPropertiesAndMethods.test_mixing_slot_wrappers | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "descriptor \'**setitem**\' requires a \'dict\' object but received a \'str\'"'> |
| ClassPropertiesAndMethods.test_wrong_class_slot_wrapper | PASS | |
| ClassPropertiesAndMethods.test_qualname | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| ClassPropertiesAndMethods.test_qualname_dict | PASS | |
| ClassPropertiesAndMethods.test_object_new_and_init_with_parameters | PASS | |
| ClassPropertiesAndMethods.test_subclassing_does_not_duplicate_dict_descriptors | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIn\', \'**dict**\', {\'**name**\': \'**main**\', \'**module**\': \'**main**\', \'**qualname**\': \'_t.<locals>.Base\', \'**firstlineno**\': 7, \'**static_attributes**\': ()})"'> |
| ClassPropertiesAndMethods.test_remove_subclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**subclasses**'"> |
| ClassPropertiesAndMethods.test_instance_method_get_behavior | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**get**'"> |
| ClassPropertiesAndMethods.test_staticmethod_new | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'<**main**.MyStaticMethod object at 0x7f8f918e3f50>\', \'<staticmethod(None)>\')"'> |
| ClassPropertiesAndMethods.test_classmethod_new | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'<**main**.MyClassMethod object at 0x7f8f918e3ee0>\', \'<classmethod(None)>\')"'> |
| DictProxyTests.test_dict_type_with_metaclass | PASS | |
| AAAPTypesLongInitTest.test_pytype_long_ready | PASS | |
| PicklingTests.test_issue24097 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError ''"> |
| PicklingTests.test_object_reduce | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| OperatorsTest.test_spam_lists | decorator:support.impl_detail |
| OperatorsTest.test_spam_dicts | decorator:support.impl_detail |
| ClassPropertiesAndMethods.test_slots | decorator:support.thread_unsafe |
| ClassPropertiesAndMethods.test_refleaks_in_classmethod___init__ | decorator:support.refcount_test |
| ClassPropertiesAndMethods.test_classmethods_in_c | decorator:support.impl_detail |
| ClassPropertiesAndMethods.test_method_get_meth_method_invalid_type | decorator:support.cpython_only |
| ClassPropertiesAndMethods.test_refleaks_in_staticmethod___init__ | decorator:support.refcount_test |
| ClassPropertiesAndMethods.test_staticmethods_in_c | decorator:support.impl_detail |
| ClassPropertiesAndMethods.test_bad_new | decorator:unittest.expectedFailure |
| ClassPropertiesAndMethods.test_restored_object_new | decorator:unittest.expectedFailure |
| ClassPropertiesAndMethods.test_methods_in_c | decorator:support.impl_detail |
| ClassPropertiesAndMethods.test_properties_doc_attrib | decorator:unittest.skipIf |
| ClassPropertiesAndMethods.test_testcapi_no_segfault | decorator:support.cpython_only |
| ClassPropertiesAndMethods.test_recursive_call | decorator:support.skip_wasi_stack_overflow |
| ClassPropertiesAndMethods.test_slots_trash | decorator:support.skip_emscripten_stack_overflow |
| ClassPropertiesAndMethods.test_meth_class_get | decorator:support.impl_detail |
| ClassPropertiesAndMethods.test_wrapper_segfault | decorator:support.skip_wasi_stack_overflow |
| ClassPropertiesAndMethods.test_repr_as_str | decorator:support.skip_emscripten_stack_overflow |
| ClassPropertiesAndMethods.test_bpo25750 | decorator:unittest.skipIf |
| DictProxyTests.test_iter_keys | decorator:unittest.skipIf |
| DictProxyTests.test_iter_values | decorator:unittest.skipIf |
| DictProxyTests.test_iter_items | decorator:unittest.skipIf |
| PicklingTests.test_pickle_slots | decorator:support.thread_unsafe |
| PicklingTests.test_reduce_copying | decorator:support.thread_unsafe |
| SharedKeyTests.test_subclasses | decorator:support.cpython_only |
| OperatorsTest.test_lists | self.binop_test |
| OperatorsTest.test_dicts | self.binop_test |
| OperatorsTest.test_ints | self.number_operators |
| OperatorsTest.test_floats | self.number_operators |
| OperatorsTest.test_complexes | self.number_operators |
| ClassPropertiesAndMethods.test_python_dicts | self.assertIsSubclass |
| ClassPropertiesAndMethods.test_metaclass | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_multiple_inheritance | uses-self.__state |
| ClassPropertiesAndMethods.test_object_class | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_object_class_assignment_between_heaptypes_and_nonheaptypes | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_slots_special | self.assertHasAttr |
| ClassPropertiesAndMethods.test_slots_special2 | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_dynamics | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_classmethods | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_classmethod_staticmethod_annotations | uses-self.subTest |
| ClassPropertiesAndMethods.test_staticmethods | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_classic | self.assertStartsWith |
| ClassPropertiesAndMethods.test_compattr | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_newslots | uses-self.foo |
| ClassPropertiesAndMethods.test_object_new | uses-self.foo |
| ClassPropertiesAndMethods.test_overloading | uses-self.setitem |
| ClassPropertiesAndMethods.test_methods | self.assertStartsWith |
| ClassPropertiesAndMethods.test_special_method_lookup | uses-self.impl |
| ClassPropertiesAndMethods.test_specials | uses-self.x |
| ClassPropertiesAndMethods.test_properties | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_properties_plus | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_dict_constructors | uses-self.dict |
| ClassPropertiesAndMethods.test_dir | uses-self.test_dir |
| ClassPropertiesAndMethods.test_supers | uses-self.__super |
| ClassPropertiesAndMethods.test_basic_inheritance | uses-self.prec |
| ClassPropertiesAndMethods.test_str_subclass_as_dict_key | uses-self.canonical |
| ClassPropertiesAndMethods.test_classic_comparisons | uses-self.value |
| ClassPropertiesAndMethods.test_rich_comparisons | uses-self.value |
| ClassPropertiesAndMethods.test_set_class | uses-self.**class** |
| ClassPropertiesAndMethods.test_binary_operator_override | uses-self.lower |
| ClassPropertiesAndMethods.test_str_of_str_subclass | uses-self.encode |
| ClassPropertiesAndMethods.test_uninitialized_modules | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_funny_new | uses-self.foo |
| ClassPropertiesAndMethods.test_copy_setstate | uses-self.foo |
| ClassPropertiesAndMethods.test_slots_multiple_inheritance | self.assertHasAttr |
| ClassPropertiesAndMethods.test_ipow_exception_text | unresolved-name:cm |
| ClassPropertiesAndMethods.test_pow_wrapper_error_messages | assertRaisesRegex call form |
| ClassPropertiesAndMethods.test_mutable_bases_with_failing_mro | uses-self.flag |
| ClassPropertiesAndMethods.test_isinst_isclass | uses-self.__obj |
| ClassPropertiesAndMethods.test_proxy_super | uses-self.__obj |
| ClassPropertiesAndMethods.test_weakref_segfault | uses-self.ref |
| ClassPropertiesAndMethods.test_vicious_descriptor_nonsense | self.assertNotHasAttr |
| ClassPropertiesAndMethods.test_method_wrapper | self.assertNotOrderable |
| ClassPropertiesAndMethods.test_builtin_function_or_method | self.assertNotOrderable |
| ClassPropertiesAndMethods.test_special_unbound_method_types | self.assertNotOrderable |
| ClassPropertiesAndMethods.test_not_implemented | uses-self.subTest |
| ClassPropertiesAndMethods.test_assign_slice | uses-self.value |
| ClassPropertiesAndMethods.test_set_and_no_get | uses-self.name |
| ClassPropertiesAndMethods.test_getattr_hooks | uses-self.counter |
| ClassPropertiesAndMethods.test_gh55664 | uses-self.assertWarnsRegex |
| ClassPropertiesAndMethods.test_slot_shadows_class_variable | unresolved-name:cm |
| ClassPropertiesAndMethods.test_set_doc | unresolved-name:cm |
| ClassPropertiesAndMethods.test_cycle_through_dict | uses-self.**dict** |
| ClassPropertiesAndMethods.test_bound_method_repr | self.assertRegex |
| ClassPropertiesAndMethods.test_attr_raise_through_property | uses-self.**getattr** |
| DictProxyTests.test_repr | self.assertStartsWith |
| MiscTests.test_type_lookup_mro_reference | self.assertRegex |
| PicklingTests.test_reduce | self._check_reduce |
| PicklingTests.test_special_method_lookup | self._check_reduce |
| MroTest.test_incomplete_set_bases_on_self | uses-self.step_until |
| MroTest.test_reent_set_bases_on_base | uses-self.step_until |
| MroTest.test_reent_set_bases_on_direct_base | uses-self.step_until |
| MroTest.test_reent_set_bases_tp_base_cycle | uses-self.ready |
| MroTest.test_tp_subclasses_cycle_in_update_slots | uses-self.ready |
| MroTest.test_tp_subclasses_cycle_error_return_path | uses-self.ready |
| MroTest.test_incomplete_extend | uses-self.assertRaises |
| MroTest.test_incomplete_super | uses-self.assertRaises |
| MroTest.test_disappearing_custom_mro | unresolved-name:DebugHelperMeta |
| ClassPropertiesAndMethods.test_mro_disagreement | harness-error:ModuleNotFoundError: No module named 'test' |
| ClassPropertiesAndMethods.test_weakrefs | harness-error:ModuleNotFoundError: No module named 'test' |
| ClassPropertiesAndMethods.test_subclass_propagation | harness-error:ModuleNotFoundError: No module named 'test' |
| ClassPropertiesAndMethods.test_delete_hook | harness-error:ModuleNotFoundError: No module named 'test' |
| ClassPropertiesAndMethods.test_subtype_resurrection | harness-error:ModuleNotFoundError: No module named 'test' |

## Expected vs got

### ClassPropertiesAndMethods.test_altmro (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'class\' has policy BridgePolicy.STANDIN but no to_host conversion arm"'>

### ClassPropertiesAndMethods.test_builtin_bases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'>

### ClassPropertiesAndMethods.test_carloverre_multi_inherit_invalid (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'setattr through indirect base types should be rejected'">

### ClassPropertiesAndMethods.test_classmethod_new (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'<**main**.MyClassMethod object at 0x7f8f918e3ee0>\', \'<classmethod(None)>\')"'>

### ClassPropertiesAndMethods.test_deepcopy_recursive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### ClassPropertiesAndMethods.test_diamond_inheritance (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected MRO order disagreement (F)'">

### ClassPropertiesAndMethods.test_doc_descriptor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <**main**.DocDescr object at 0x7f8f9171e0b0>, \'object=None; type=NewClass\')"'>

### ClassPropertiesAndMethods.test_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'inheritance from both list and dict should be illegal'">

### ClassPropertiesAndMethods.test_file_fault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### ClassPropertiesAndMethods.test_imul_bug (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for *: \'C\' and \'float\'"'>

### ClassPropertiesAndMethods.test_init (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'did not test **init**() for None return'">

### ClassPropertiesAndMethods.test_instance_method_get_behavior (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**get**'">

### ClassPropertiesAndMethods.test_ipow (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for **: \'C\' and \'int\'"'>

### ClassPropertiesAndMethods.test_keyword_arguments (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**call**'">

### ClassPropertiesAndMethods.test_keywords (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 0j, (666+42j))"'>

### ClassPropertiesAndMethods.test_load_attr_extended_arg (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'number_attrs\'"'>

### ClassPropertiesAndMethods.test_mixing_slot_wrappers (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "descriptor \'**setitem**\' requires a \'dict\' object but received a \'str\'"'>

### ClassPropertiesAndMethods.test_module_subclasses (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ClassPropertiesAndMethods.test_mutable_bases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'meth'">

### ClassPropertiesAndMethods.test_mutable_bases_catch_mro_conflict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "didn\'t catch MRO conflict"'>

### ClassPropertiesAndMethods.test_mutable_names (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (\'**main**\', \'C\'), (\'**main**\', \'D\'))"'>

### ClassPropertiesAndMethods.test_proxy_call (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', <**main**.FakeStr object at 0x7f8f928d8590>, <class \'str\'>)"'>

### ClassPropertiesAndMethods.test_qualname (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### ClassPropertiesAndMethods.test_remove_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**subclasses**'">

### ClassPropertiesAndMethods.test_set_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'b'">

### ClassPropertiesAndMethods.test_slices (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [3, 1, 2], [3, 2, 1])"'>

### ClassPropertiesAndMethods.test_slots_descriptor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'register'">

### ClassPropertiesAndMethods.test_specialized_method_calls_check_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'append'">

### ClassPropertiesAndMethods.test_staticmethod_annotations_without_dict_access (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**annotations**'">

### ClassPropertiesAndMethods.test_staticmethod_new (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'<**main**.MyStaticMethod object at 0x7f8f918e3f50>\', \'<staticmethod(None)>\')"'>

### ClassPropertiesAndMethods.test_subclass_right_op (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'C.**rfloordiv**\', \'C.**floordiv**\')"'>

### ClassPropertiesAndMethods.test_subclassing_does_not_duplicate_dict_descriptors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIn\', \'**dict**\', {\'**name**\': \'**main**\', \'**module**\': \'**main**\', \'**qualname**\': \'_t.<locals>.Base\', \'**firstlineno**\': 7, \'**static_attributes**\': ()})"'>

### ClassPropertiesAndMethods.test_unsubclassable_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### OperatorsTest.test_explicit_reverse_methods (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (4+3j), (4+3j))"'>

### OperatorsTest.test_wrap_lenfunc_bad_cast (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**len**'">

### PicklingTests.test_issue24097 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError ''">
