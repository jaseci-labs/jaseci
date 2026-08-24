# Triage report: `conv_class_pins.jac`

- source: reference/cpython/Lib/test/test_class.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+35 quarantined of 37 extracted)

| pin | result | got |
|---|---|---|
| TestInlineValues.test_store_attr_deleted_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**dict**'"> |
| TestInlineValues.test_rematerialize_object_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**dict**'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| ClassTests.testInit | decorator:support.thread_unsafe |
| ClassTests.testBinaryOps | decorator:support.thread_unsafe |
| ClassTests.testListAndDictOps | decorator:support.thread_unsafe |
| ClassTests.testUnaryOps | decorator:support.thread_unsafe |
| ClassTests.testMisc | decorator:support.thread_unsafe |
| ClassTests.testGetSetAndDel | decorator:support.thread_unsafe |
| ClassTests.testHasAttrString | decorator:support.thread_unsafe |
| ClassTests.testDel | decorator:support.thread_unsafe |
| ClassTests.testBadTypeReturned | decorator:support.thread_unsafe |
| ClassTests.testHashStuff | decorator:support.thread_unsafe |
| ClassTests.testPredefinedAttrs | decorator:support.thread_unsafe |
| ClassTests.testSFBug532646 | decorator:support.thread_unsafe |
| ClassTests.testForExceptionsRaisedInInstanceGetattr2 | decorator:support.thread_unsafe |
| ClassTests.testHashComparisonOfMethods | decorator:support.thread_unsafe |
| ClassTests.testSetattrWrapperNameIntern | decorator:support.thread_unsafe |
| ClassTests.testSetattrNonStringName | decorator:support.thread_unsafe |
| ClassTests.testTypeAttributeAccessErrorMessages | decorator:support.thread_unsafe |
| ClassTests.testObjectAttributeAccessErrorMessages | decorator:support.thread_unsafe |
| ClassTests.testConstructorErrorMessages | decorator:support.thread_unsafe |
| ClassTests.testClassWithExtCall | decorator:support.thread_unsafe |
| ClassTests.testClassCallRecursionLimit | decorator:support.thread_unsafe |
| ClassTests.testMetaclassCallOptimization | decorator:support.thread_unsafe |
| ClassTests.test_specialization_class_call_doesnt_crash | decorator:support.thread_unsafe |
| TestInlineValues.test_no_flags_for_slots_class | unresolved-name:NoManagedDict |
| TestInlineValues.test_both_flags_for_regular_class | uses-self.subTest |
| TestInlineValues.test_managed_dict_only_for_varsized_subclass | unresolved-name:VarSizedSubclass |
| TestInlineValues.test_has_inline_values | unresolved-name:Plain |
| TestInlineValues.test_instances | unresolved-name:Plain |
| TestInlineValues.test_inspect_dict | unresolved-name:Plain |
| TestInlineValues.test_update_dict | unresolved-name:Plain |
| TestInlineValues.test_many_attributes | self.set_100 |
| TestInlineValues.test_many_attributes_with_dict | self.set_100 |
| TestInlineValues.test_bug_117750 | uses-self.**dict** |
| TestInlineValues.test_store_attr_type_cache | uses-self.assertEqual |
| TestInlineValues.test_detach_materialized_dict_no_memory | harness-error:ModuleNotFoundError: No module named 'test' |

## Expected vs got

### TestInlineValues.test_rematerialize_object_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**dict**'">

### TestInlineValues.test_store_attr_deleted_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**dict**'">
