# Triage report: `conv_types_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_types.py
- guest leg: 0/98 marks
- pins: **49 passed** / 98 run (+31 quarantined of 129 extracted)

| pin | result | got |
|---|---|---|
| TypesTests.test_names | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| TypesTests.test_truth_values | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| TypesTests.test_boolean_ops | PASS | |
| TypesTests.test_comparisons | PASS | |
| TypesTests.test_float_constructor | PASS | |
| TypesTests.test_zero_division | PASS | |
| TypesTests.test_numeric_types | PASS | |
| TypesTests.test_float_to_string | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| TypesTests.test_normal_integers | PASS | |
| TypesTests.test_floats | PASS | |
| TypesTests.test_strings | PASS | |
| TypesTests.test_type_function | PASS | |
| TypesTests.test_int__format__ | PASS | |
| TypesTests.test_float__format__locale | PASS | |
| TypesTests.test_int__format__locale | PASS | |
| TypesTests.test_float__format__ | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| TypesTests.test_format_spec_errors | PASS | |
| TypesTests.test_internal_sizes | PASS | |
| TypesTests.test_slot_wrapper_types | PASS | |
| TypesTests.test_method_wrapper_types | PASS | |
| TypesTests.test_method_descriptor_types | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', <built-in method join of str object>, <class \'builtin_function_or_method\'>)"'> |
| TypesTests.test_method_descriptor_crash | PASS | |
| TypesTests.test_ellipsis_type | PASS | |
| TypesTests.test_notimplemented_type | PASS | |
| TypesTests.test_none_type | PASS | |
| TypesTests.test_traceback_and_frame_types | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| TypesTests.test_capsule_type | PASS | |
| TypesTests.test_call_unbound_crash | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'"> |
| UnionTests.test_hash | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_union_of_unhashable | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for \|: \'UnhashableMeta\' and \'UnhashableMeta\'"'> |
| UnionTests.test_unhashable_becomes_hashable | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for \|: \'UnhashableMeta\' and \'UnhashableMeta\'"'> |
| UnionTests.test_bad_instancecheck | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for \|: \'host\' and \'BadMeta\'"'> |
| UnionTests.test_or_type_operator_with_TypeVar | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_union_args | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_union_parameter_chaining | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_union_parameter_substitution | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_union_pickle | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_union_copy | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_union_parameter_substitution_errors | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_Protocol | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_Alias | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_NamedTuple | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'UserDict' from '<unknown>'"> |
| UnionTests.test_or_type_operator_with_TypedDict | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_NewType | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_IO | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_SpecialForm | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_Literal | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_repr | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_genericalias | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| UnionTests.test_or_type_operator_with_bad_module | PASS | |
| ClassCreationTests.test_new_class_basics | PASS | |
| ClassCreationTests.test_new_class_metaclass_keywords | PASS | |
| ClassCreationTests.test_new_class_defaults | PASS | |
| ClassCreationTests.test_new_class_with_mro_entry | PASS | |
| ClassCreationTests.test_new_class_with_mro_entry_genericalias | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| ClassCreationTests.test_new_class_with_mro_entry_none | PASS | |
| ClassCreationTests.test_new_class_with_mro_entry_error | PASS | |
| ClassCreationTests.test_new_class_with_mro_entry_multiple | PASS | |
| ClassCreationTests.test_new_class_with_mro_entry_multiple_2 | PASS | |
| ClassCreationTests.test_get_original_bases | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| ClassCreationTests.test_prepare_class | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'metaclass conflict: the metaclass of a derived class must be a (non-strict) subclass of the metaclasses of all its bases'"> |
| ClassCreationTests.test_bad___prepare__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| ClassCreationTests.test_resolve_bases | PASS | |
| ClassCreationTests.test_resolve_bases_with_mro_entry | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| ClassCreationTests.test_metaclass_derivation | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'too many positional arguments'"> |
| ClassCreationTests.test_metaclass_override_callable | PASS | |
| ClassCreationTests.test_metaclass_new_error | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| ClassCreationTests.test_subclass_inherited_slot_update | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "descriptor \'**getitem**\' for \'dict\' objects doesn\'t apply to a \'NoneType\' object"'> |
| ClassCreationTests.test_tuple_subclass_as_bases | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <class \'tuple\'>, <class \'**main**.TupleSubclass\'>)"'> |
| SimpleNamespaceTests.test_constructor | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'UserDict' from '<unknown>'"> |
| SimpleNamespaceTests.test_unbound | PASS | |
| SimpleNamespaceTests.test_underlying_dict | PASS | |
| SimpleNamespaceTests.test_attrget | PASS | |
| SimpleNamespaceTests.test_attrset | PASS | |
| SimpleNamespaceTests.test_attrdel | PASS | |
| SimpleNamespaceTests.test_repr | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'namespace(w=3, y=2, x=1)\', \'namespace(x=1, y=2, w=3)\')"'> |
| SimpleNamespaceTests.test_equal | PASS | |
| SimpleNamespaceTests.test_nested | PASS | |
| SimpleNamespaceTests.test_recursive | PASS | |
| SimpleNamespaceTests.test_recursive_repr | PASS | |
| SimpleNamespaceTests.test_as_dict | PASS | |
| SimpleNamespaceTests.test_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {}, {\'ham\': 8, \'eggs\': 9})"'> |
| SimpleNamespaceTests.test_pickle | PASS | |
| SimpleNamespaceTests.test_replace | PASS | |
| SimpleNamespaceTests.test_replace_subclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'replace() does not support Spam objects'"> |
| SimpleNamespaceTests.test_fake_namespace_compare | PASS | |
| CoroutineTests.test_wrong_args | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| CoroutineTests.test_non_gen_values | PASS | |
| CoroutineTests.test_async_def | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'cr_code'"> |
| CoroutineTests.test_duck_coro | PASS | |
| CoroutineTests.test_duck_corogen | PASS | |
| CoroutineTests.test_duck_gen | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| CoroutineTests.test_gen | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', <callable_iterator object at 0x7f69008ccd90>, <class \'**main**._GeneratorWrapper\'>)"'> |
| CoroutineTests.test_returning_itercoro | PASS | |
| CoroutineTests.test_genfunc | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| CoroutineTests.test_wrapper_object | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIn\', \'GeneratorWrapper\', \'<callable_iterator object at 0x7f69009868f0>\')"'> |
| FunctionTests.test_function_type_defaults | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'code\' has policy BridgePolicy.FAIL but no to_host conversion arm"'> |
| FunctionTests.test_function_type_wrong_defaults | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TypesTests.test_dunder_get_signature | decorator:unittest.skipIf |
| UnionTests.test_or_types_operator | unresolved-name:Example |
| UnionTests.test_instancecheck_and_subclasscheck | self.assertNotIsInstance |
| UnionTests.test_instancecheck_and_subclasscheck_order | self.assertIsSubclass |
| UnionTests.test_bad_subclasscheck | self.assertIsSubclass |
| UnionTests.test_or_type_operator_with_forward | unresolved-name:Forward |
| UnionTests.test_or_type_operator_reference_cycle | self.skipTest |
| MappingProxyTests.test_constructor | uses-self.mappingproxy |
| MappingProxyTests.test_methods | uses-self.mappingproxy |
| MappingProxyTests.test_get | uses-self.mappingproxy |
| MappingProxyTests.test_missing | uses-self.mappingproxy |
| MappingProxyTests.test_customdict | uses-self.mappingproxy |
| MappingProxyTests.test_chainmap | uses-self.mappingproxy |
| MappingProxyTests.test_contains | uses-self.mappingproxy |
| MappingProxyTests.test_views | uses-self.mappingproxy |
| MappingProxyTests.test_len | uses-self.mappingproxy |
| MappingProxyTests.test_iterators | uses-self.mappingproxy |
| MappingProxyTests.test_reversed | uses-self.mappingproxy |
| MappingProxyTests.test_copy | uses-self.mappingproxy |
| MappingProxyTests.test_union | uses-self.mappingproxy |
| MappingProxyTests.test_hash | uses-self.mappingproxy |
| ClassCreationTests.test_new_class_subclass | self.assertIsSubclass |
| ClassCreationTests.test_new_class_meta_with_base | self.assertIsSubclass |
| ClassCreationTests.test_one_argument_type | unresolved-name:cm |
| SimpleNamespaceTests.test_replace_invalid_subtype | assertRaisesRegex call form |
| CoroutineTests.test_duck_functional_gen | uses-self.send |
| SubinterpreterTests.test_static_types_inherited_slots | uses-self.create_channel |
| UnionTests.test_instantiation | host-raised:NameError: name 'self' is not defined |
| ClassCreationTests.test_new_class_meta | host-raised:AttributeError: '_SelfNS' object has no attribute 'Meta' |
| ClassCreationTests.test_new_class_exec_body | host-raised:AttributeError: '_SelfNS' object has no attribute 'Meta' |
| ClassCreationTests.test_metaclass_override_function | host-raised:AttributeError: '_SelfNS' object has no attribute 'Meta' |

## Expected vs got

### ClassCreationTests.test_bad___prepare__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### ClassCreationTests.test_get_original_bases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### ClassCreationTests.test_metaclass_derivation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'too many positional arguments'">

### ClassCreationTests.test_metaclass_new_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### ClassCreationTests.test_new_class_with_mro_entry_genericalias (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### ClassCreationTests.test_prepare_class (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'metaclass conflict: the metaclass of a derived class must be a (non-strict) subclass of the metaclasses of all its bases'">

### ClassCreationTests.test_resolve_bases_with_mro_entry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### ClassCreationTests.test_subclass_inherited_slot_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "descriptor \'**getitem**\' for \'dict\' objects doesn\'t apply to a \'NoneType\' object"'>

### ClassCreationTests.test_tuple_subclass_as_bases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <class \'tuple\'>, <class \'**main**.TupleSubclass\'>)"'>

### CoroutineTests.test_async_def (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'cr_code'">

### CoroutineTests.test_duck_gen (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### CoroutineTests.test_gen (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', <callable_iterator object at 0x7f69008ccd90>, <class \'**main**._GeneratorWrapper\'>)"'>

### CoroutineTests.test_genfunc (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### CoroutineTests.test_wrapper_object (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIn\', \'GeneratorWrapper\', \'<callable_iterator object at 0x7f69009868f0>\')"'>

### CoroutineTests.test_wrong_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### FunctionTests.test_function_type_defaults (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'code\' has policy BridgePolicy.FAIL but no to_host conversion arm"'>

### FunctionTests.test_function_type_wrong_defaults (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### SimpleNamespaceTests.test_constructor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'UserDict' from '<unknown>'">

### SimpleNamespaceTests.test_replace_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'replace() does not support Spam objects'">

### SimpleNamespaceTests.test_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'namespace(w=3, y=2, x=1)\', \'namespace(x=1, y=2, w=3)\')"'>

### SimpleNamespaceTests.test_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {}, {\'ham\': 8, \'eggs\': 9})"'>

### TypesTests.test_call_unbound_crash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'">

### TypesTests.test_float__format__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### TypesTests.test_float_to_string (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### TypesTests.test_method_descriptor_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', <built-in method join of str object>, <class \'builtin_function_or_method\'>)"'>

### TypesTests.test_names (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### TypesTests.test_traceback_and_frame_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### TypesTests.test_truth_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_bad_instancecheck (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for |: \'host\' and \'BadMeta\'"'>

### UnionTests.test_hash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_Alias (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_IO (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_Literal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_NamedTuple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'UserDict' from '<unknown>'">

### UnionTests.test_or_type_operator_with_NewType (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_Protocol (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_SpecialForm (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_TypeVar (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_TypedDict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_operator_with_genericalias (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_or_type_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_unhashable_becomes_hashable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for |: \'UnhashableMeta\' and \'UnhashableMeta\'"'>

### UnionTests.test_union_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_union_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_union_of_unhashable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for |: \'UnhashableMeta\' and \'UnhashableMeta\'"'>

### UnionTests.test_union_parameter_chaining (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_union_parameter_substitution (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_union_parameter_substitution_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### UnionTests.test_union_pickle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>
