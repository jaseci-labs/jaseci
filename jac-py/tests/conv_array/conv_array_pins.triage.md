# Triage report: `conv_array_pins.jac`

- source: reference/cpython/Lib/test/test_array.py
- guest leg: 0/5 marks
- pins: **2 passed** / 5 run (+93 quarantined of 98 extracted)

| pin | result | got |
|---|---|---|
| MiscTest.test_array_is_sequence | PASS | |
| MiscTest.test_bad_constructor | PASS | |
| MiscTest.test_empty | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| LargeArrayTest.test_gh_128961 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**setstate**'"> |
| LargeArrayTest.test_setitem_use_after_shrink_with_int_data | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Index\' object cannot be interpreted as an integer"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| MiscTest.test_disallow_instantiation | decorator:support.cpython_only |
| MiscTest.test_immutable | decorator:support.cpython_only |
| BaseTest.test_bug_782369 | decorator:unittest.skipUnless |
| BaseTest.test_sizeof_with_buffer | decorator:support.cpython_only |
| BaseTest.test_sizeof_without_buffer | decorator:support.cpython_only |
| BaseTest.test_obsolete_write_lock | decorator:support.cpython_only |
| LargeArrayTest.test_example_data | decorator:support.bigmemtest |
| LargeArrayTest.test_access | decorator:support.bigmemtest |
| LargeArrayTest.test_slice | decorator:support.bigmemtest |
| LargeArrayTest.test_count | decorator:support.bigmemtest |
| LargeArrayTest.test_append | decorator:support.bigmemtest |
| LargeArrayTest.test_extend | decorator:support.bigmemtest |
| LargeArrayTest.test_frombytes | decorator:support.bigmemtest |
| LargeArrayTest.test_fromlist | decorator:support.bigmemtest |
| LargeArrayTest.test_index | decorator:support.bigmemtest |
| LargeArrayTest.test_insert | decorator:support.bigmemtest |
| LargeArrayTest.test_pop | decorator:support.bigmemtest |
| LargeArrayTest.test_remove | decorator:support.bigmemtest |
| LargeArrayTest.test_reverse | decorator:support.bigmemtest |
| LargeArrayTest.test_tolist | decorator:support.bigmemtest |
| ArrayReconstructorTest.test_error | helper:setUp(self.enterContext) |
| ArrayReconstructorTest.test_numbers | helper:setUp(self.enterContext) |
| ArrayReconstructorTest.test_unicode | helper:setUp(self.enterContext) |
| BaseTest.test_constructor | helper:setUp(self.enterContext) |
| BaseTest.test_len | helper:setUp(self.enterContext) |
| BaseTest.test_buffer_info | helper:setUp(self.enterContext) |
| BaseTest.test_byteswap | helper:setUp(self.enterContext) |
| BaseTest.test_copy | helper:setUp(self.enterContext) |
| BaseTest.test_deepcopy | helper:setUp(self.enterContext) |
| BaseTest.test_reduce_ex | helper:setUp(self.enterContext) |
| BaseTest.test_pickle | helper:setUp(self.enterContext) |
| BaseTest.test_pickle_for_empty_array | helper:setUp(self.enterContext) |
| BaseTest.test_iterator_pickle | helper:setUp(self.enterContext) |
| BaseTest.test_exhausted_iterator | helper:setUp(self.enterContext) |
| BaseTest.test_reverse_iterator | helper:setUp(self.enterContext) |
| BaseTest.test_reverse_iterator_picking | helper:setUp(self.enterContext) |
| BaseTest.test_exhausted_reverse_iterator | helper:setUp(self.enterContext) |
| BaseTest.test_insert | helper:setUp(self.enterContext) |
| BaseTest.test_tofromfile | helper:setUp(self.enterContext) |
| BaseTest.test_fromfile_ioerror | helper:setUp(self.enterContext) |
| BaseTest.test_filewrite | helper:setUp(self.enterContext) |
| BaseTest.test_tofromlist | helper:setUp(self.enterContext) |
| BaseTest.test_tofrombytes | helper:setUp(self.enterContext) |
| BaseTest.test_fromarray | helper:setUp(self.enterContext) |
| BaseTest.test_repr | helper:setUp(self.enterContext) |
| BaseTest.test_str | helper:setUp(self.enterContext) |
| BaseTest.test_cmp | helper:setUp(self.enterContext) |
| BaseTest.test_add | helper:setUp(self.enterContext) |
| BaseTest.test_iadd | helper:setUp(self.enterContext) |
| BaseTest.test_mul | helper:setUp(self.enterContext) |
| BaseTest.test_imul | helper:setUp(self.enterContext) |
| BaseTest.test_getitem | helper:setUp(self.enterContext) |
| BaseTest.test_setitem | helper:setUp(self.enterContext) |
| BaseTest.test_delitem | helper:setUp(self.enterContext) |
| BaseTest.test_getslice | helper:setUp(self.enterContext) |
| BaseTest.test_extended_getslice | helper:setUp(self.enterContext) |
| BaseTest.test_setslice | helper:setUp(self.enterContext) |
| BaseTest.test_extended_set_del_slice | helper:setUp(self.enterContext) |
| BaseTest.test_index | helper:setUp(self.enterContext) |
| BaseTest.test_count | helper:setUp(self.enterContext) |
| BaseTest.test_remove | helper:setUp(self.enterContext) |
| BaseTest.test_pop | helper:setUp(self.enterContext) |
| BaseTest.test_clear | helper:setUp(self.enterContext) |
| BaseTest.test_reverse | helper:setUp(self.enterContext) |
| BaseTest.test_extend | helper:setUp(self.enterContext) |
| BaseTest.test_constructor_with_iterable_argument | helper:setUp(self.enterContext) |
| BaseTest.test_coveritertraverse | helper:setUp(self.enterContext) |
| BaseTest.test_buffer | helper:setUp(self.enterContext) |
| BaseTest.test_weakref | helper:setUp(self.enterContext) |
| BaseTest.test_subclass_with_kwargs | helper:setUp(self.enterContext) |
| BaseTest.test_create_from_bytes | helper:setUp(self.enterContext) |
| BaseTest.test_initialize_with_unicode | helper:setUp(self.enterContext) |
| BaseTest.test_free_after_iterating | helper:setUp(self.enterContext) |
| StringTest.test_setitem | helper:setUp(self.enterContext) |
| UnicodeTest.test_unicode | helper:setUp(self.enterContext) |
| UnicodeTest.test_issue17223 | helper:setUp(self.enterContext) |
| UnicodeTest.test_typecode_u_deprecation | helper:setUp(self.enterContext) |
| UnicodeTest.test_empty_string_mem_leak_gh140474 | helper:setUp(self.enterContext) |
| NumberTest.test_extslice | helper:setUp(self.enterContext) |
| NumberTest.test_delslice | helper:setUp(self.enterContext) |
| NumberTest.test_assignment | helper:setUp(self.enterContext) |
| NumberTest.test_iterationcontains | helper:setUp(self.enterContext) |
| NumberTest.test_subclassing | helper:setUp(self.enterContext) |
| NumberTest.test_frombytearray | helper:setUp(self.enterContext) |
| IntegerNumberTest.test_type_error | helper:setUp(self.enterContext) |
| SignedNumberTest.test_overflow | helper:setUp(self.enterContext) |
| UnsignedNumberTest.test_overflow | helper:setUp(self.enterContext) |
| UnsignedNumberTest.test_bytes_extend | helper:setUp(self.enterContext) |
| FPTest.test_nan | helper:setUp(self.enterContext) |
| FPTest.test_byteswap | helper:setUp(self.enterContext) |
| DoubleTest.test_alloc_overflow | helper:setUp(self.enterContext) |
| LargeArrayTest.test_setitem_use_after_clear_with_int_data | unresolved-name:dtype |
| LargeArrayTest.test_setitem_use_after_clear_with_float_data | unresolved-name:dtype |

## Expected vs got

### LargeArrayTest.test_gh_128961 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**setstate**'">

### LargeArrayTest.test_setitem_use_after_shrink_with_int_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Index\' object cannot be interpreted as an integer"'>

### MiscTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">
