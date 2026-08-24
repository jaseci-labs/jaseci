# Triage report: `conv_struct_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_struct.py
- guest leg: 0/33 marks
- pins: **28 passed** / 33 run (+10 quarantined of 43 extracted)

| pin | result | got |
|---|---|---|
| StructTest.test_isbigendian | PASS | |
| StructTest.test_consistence | PASS | |
| StructTest.test_transitiveness | PASS | |
| StructTest.test_new_features | PASS | |
| StructTest.test_calcsize | PASS | |
| StructTest.test_p_code | PASS | |
| StructTest.test_705836 | PASS | |
| StructTest.test_1530559 | PASS | |
| StructTest.test_unpack_from | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'abcd\',), (b\'abcd\',))"'> |
| StructTest.test_pack_into | PASS | |
| StructTest.test_pack_into_fn | PASS | |
| StructTest.test_unpack_with_buffer | PASS | |
| StructTest.test_bool | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "Expected OSError: struct.pack(\'<?\', ExplodingBool())"'> |
| StructTest.test_count_overflow | PASS | |
| StructTest.test_trailing_counter | PASS | |
| StructTest.test_Struct_reinitialization | PASS | |
| StructTest.test_boundary_error_message | PASS | |
| StructTest.test_boundary_error_message_with_negative_offset | PASS | |
| StructTest.test_boundary_error_message_with_large_offset | PASS | |
| StructTest.test_issue29802 | PASS | |
| StructTest.test_format_attr | PASS | |
| StructTest.test_struct_cleans_up_at_runtime_shutdown | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'"> |
| StructTest.test__struct_reference_cycle_cleaned_up | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| StructTest.test_issue35714 | PASS | |
| StructTest.test_struct_subclass_instantiation | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object.**init**() takes exactly one argument (the instance to initialize)'"> |
| StructTest.test_repr | PASS | |
| StructTest.test_operations_on_half_initialized_Struct | PASS | |
| UnpackIteratorTest.test_construct | PASS | |
| UnpackIteratorTest.test_uninstantiable | PASS | |
| UnpackIteratorTest.test_iterate | PASS | |
| UnpackIteratorTest.test_arbitrary_buffer | PASS | |
| UnpackIteratorTest.test_length_hint | PASS | |
| UnpackIteratorTest.test_module_func | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| StructTest.test__sizeof__ | decorator:support.cpython_only |
| StructTest.test__struct_types_immutable | decorator:support.cpython_only |
| StructTest.test_issue98248 | decorator:support.cpython_only |
| StructTest.test_issue98248_error_propagation | decorator:support.cpython_only |
| StructTest.test_endian_table_init_subinterpreters | decorator:unittest.skipIf |
| StructTest.test_integers | uses-self.assertEqual |
| StructTest.test_nN_code | unresolved-name:cm |
| StructTest.test_c_complex_round_trip | self.assertComplexesAreIdentical |
| StructTest.test_float_round_trip | uses-self.subTest |
| UnpackIteratorTest.test_half_float | host-raised:SkipTest: No module named '_testcapi' |

## Expected vs got

### StructTest.test__struct_reference_cycle_cleaned_up (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### StructTest.test_bool (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "Expected OSError: struct.pack(\'<?\', ExplodingBool())"'>

### StructTest.test_struct_cleans_up_at_runtime_shutdown (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'">

### StructTest.test_struct_subclass_instantiation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object.**init**() takes exactly one argument (the instance to initialize)'">

### StructTest.test_unpack_from (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'abcd\',), (b\'abcd\',))"'>
