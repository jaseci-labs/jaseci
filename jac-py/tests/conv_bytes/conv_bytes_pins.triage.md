# Triage report: `conv_bytes_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_bytes.py
- guest leg: 0/44 marks
- pins: **18 passed** / 44 run (+99 quarantined of 143 extracted)

| pin | result | got |
|---|---|---|
| BaseBytesTest.test_from_mutating_list | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'X\' object cannot be interpreted as an integer"'> |
| BytesTest.test_getitem_error | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| BytesTest.test_bytes_blocking | PASS | |
| BytesTest.test_repeat_id_preserving | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 139664801626352, 139664801625488)"'> |
| ByteArrayTest.test_getitem_error | PASS | |
| ByteArrayTest.test_setitem_error | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| ByteArrayTest.test_nohash | PASS | |
| ByteArrayTest.test_bytearray_api | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ByteArrayTest.test_mod_concurrent_mutation | PASS | |
| ByteArrayTest.test_reverse | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertFalse\', bytearray(b\'\'))"'> |
| ByteArrayTest.test_clear | PASS | |
| ByteArrayTest.test_copy | PASS | |
| ByteArrayTest.test_regexps | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [b\'Hello\', b\'world\'], [bytearray(b\'Hello\'), bytearray(b\'world\')])"'> |
| ByteArrayTest.test_setslice | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| ByteArrayTest.test_setslice_extend | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item deletion'"> |
| ByteArrayTest.test_fifo_overrun | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item deletion'"> |
| ByteArrayTest.test_del_expand | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item deletion'"> |
| ByteArrayTest.test_extended_set_del_slice | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| ByteArrayTest.test_setslice_trap | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| ByteArrayTest.test_iconcat | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', bytearray(b\'abcdef\'), bytearray(b\'abc\'))"'> |
| ByteArrayTest.test_irepeat | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', bytearray(b\'abcabcabc\'), bytearray(b\'abc\'))"'> |
| ByteArrayTest.test_irepeat_1char | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', bytearray(b\'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\'), bytearray(b\'x\'))"'> |
| ByteArrayTest.test_alloc | PASS | |
| ByteArrayTest.test_init_alloc | PASS | |
| ByteArrayTest.test_pop | PASS | |
| ByteArrayTest.test_nosort | PASS | |
| ByteArrayTest.test_copied | PASS | |
| ByteArrayTest.test_partition_bytearray_doesnt_share_nullstring | PASS | |
| ByteArrayTest.test_resize_forbidden | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| ByteArrayTest.test_iterator_pickling2 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f063efe7c10>"'> |
| ByteArrayTest.test_iterator_length_hint | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [])"'> |
| ByteArrayTest.test_repeat_after_setslice | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| ByteArrayTest.test_search_methods_reentrancy_raises_buffererror | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "argument should be integer or bytes-like object, not \'Evil\'"'> |
| ByteArrayTest.test_extend_empty_buffer_overflow | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "can\'t extend bytearray with EvilIter"'> |
| ByteArrayTest.test_hex_use_after_free | PASS | |
| AssortedBytesTest.test_format | PASS | |
| AssortedBytesTest.test_compare_bytes_to_bytearray | PASS | |
| AssortedBytesTest.test_from_bytearray | PASS | |
| AssortedBytesTest.test_literal | PASS | |
| AssortedBytesTest.test_split_bytearray | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [b\'a\', b\'b\'], [b\'a\', b\'b\'])"'> |
| AssortedBytesTest.test_rsplit_bytearray | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [b\'a\', b\'b\'], [b\'a\', b\'b\'])"'> |
| AssortedBytesTest.test_return_self | PASS | |
| BytearrayPEP3137Test.test_returns_new_copy | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'val\' is not defined"'> |
| ByteArraySubclassTest.test_init_override | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <**main**.subclass object at 0x7f063ee0b6d0>, b\'abcd\')"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| AssortedBytesTest.test_doc | decorator:.requires_docstrings |
| AssortedBytesTest.test_compare | decorator:unittest.skipUnless |
| FreeThreadingTest.test_free_threading_bytearray | decorator:unittest.skipUnless |
| FreeThreadingTest.test_free_threading_bytearrayiter | decorator:unittest.skipUnless |
| FreeThreadingTest.test_free_threading_bytearray_resize | decorator:unittest.skipUnless |
| BaseBytesTest.test_basics | uses-self.type2test |
| BaseBytesTest.test_copy | uses-self.type2test |
| BaseBytesTest.test_empty_sequence | uses-self.type2test |
| BaseBytesTest.test_from_iterable | uses-self.type2test |
| BaseBytesTest.test_from_tuple | uses-self.type2test |
| BaseBytesTest.test_from_list | uses-self.type2test |
| BaseBytesTest.test_from_index | uses-self.type2test |
| BaseBytesTest.test_from_buffer | uses-self.type2test |
| BaseBytesTest.test_from_ssize | uses-self.type2test |
| BaseBytesTest.test_constructor_type_errors | uses-self.type2test |
| BaseBytesTest.test_constructor_value_errors | uses-self.type2test |
| BaseBytesTest.test_constructor_overflow | uses-self.type2test |
| BaseBytesTest.test_constructor_exceptions | uses-self.type2test |
| BaseBytesTest.test_compare | uses-self.type2test |
| BaseBytesTest.test_compare_to_str | uses-self.type2test |
| BaseBytesTest.test_reversed | uses-self.type2test |
| BaseBytesTest.test_getslice | uses-self.type2test |
| BaseBytesTest.test_extended_getslice | uses-self.type2test |
| BaseBytesTest.test_encoding | uses-self.type2test |
| BaseBytesTest.test_decode | uses-self.type2test |
| BaseBytesTest.test_from_int | uses-self.type2test |
| BaseBytesTest.test_concat | uses-self.type2test |
| BaseBytesTest.test_repeat | uses-self.type2test |
| BaseBytesTest.test_repeat_1char | uses-self.type2test |
| BaseBytesTest.test_contains | uses-self.type2test |
| BaseBytesTest.test_fromhex | uses-self.type2test |
| BaseBytesTest.test_hex | uses-self.type2test |
| BaseBytesTest.test_hex_separator_basics | uses-self.type2test |
| BaseBytesTest.test_hex_separator_five_bytes | uses-self.type2test |
| BaseBytesTest.test_hex_separator_six_bytes | uses-self.type2test |
| BaseBytesTest.test_join | uses-self.type2test |
| BaseBytesTest.test_count | uses-self.type2test |
| BaseBytesTest.test_startswith | uses-self.type2test |
| BaseBytesTest.test_endswith | uses-self.type2test |
| BaseBytesTest.test_find | assertRaisesRegex call form |
| BaseBytesTest.test_rfind | uses-self.type2test |
| BaseBytesTest.test_index | uses-self.type2test |
| BaseBytesTest.test_rindex | uses-self.type2test |
| BaseBytesTest.test_mod | uses-self.type2test |
| BaseBytesTest.test_memory_leak_gh_140939 | uses-self.type2test |
| BaseBytesTest.test_imod | uses-self.type2test |
| BaseBytesTest.test_rmod | uses-self.type2test |
| BaseBytesTest.test_replace | uses-self.type2test |
| BaseBytesTest.test_replace_int_error | uses-self.type2test |
| BaseBytesTest.test_split_string_error | uses-self.type2test |
| BaseBytesTest.test_split_int_error | uses-self.type2test |
| BaseBytesTest.test_split_unicodewhitespace | uses-self.type2test |
| BaseBytesTest.test_rsplit_unicodewhitespace | uses-self.type2test |
| BaseBytesTest.test_partition | uses-self.type2test |
| BaseBytesTest.test_rpartition | uses-self.type2test |
| BaseBytesTest.test_partition_string_error | uses-self.type2test |
| BaseBytesTest.test_partition_int_error | uses-self.type2test |
| BaseBytesTest.test_pickling | uses-self.type2test |
| BaseBytesTest.test_iterator_pickling | uses-self.type2test |
| BaseBytesTest.test_strip_bytearray | uses-self.type2test |
| BaseBytesTest.test_strip_string_error | uses-self.type2test |
| BaseBytesTest.test_strip_int_error | uses-self.type2test |
| BaseBytesTest.test_center | uses-self.type2test |
| BaseBytesTest.test_ljust | uses-self.type2test |
| BaseBytesTest.test_rjust | uses-self.type2test |
| BaseBytesTest.test_xjust_int_error | uses-self.type2test |
| BaseBytesTest.test_ord | uses-self.type2test |
| BaseBytesTest.test_none_arguments | uses-self.type2test |
| BaseBytesTest.test_integer_arguments_out_of_byte_range | uses-self.type2test |
| BaseBytesTest.test_find_etc_raise_correct_error_messages | assertRaisesRegex call form |
| BaseBytesTest.test_translate | uses-self.type2test |
| BaseBytesTest.test_sq_item | uses-self.type2test |
| BytesTest.test_buffer_is_readonly | unresolved-name:**file** |
| BytesTest.test_custom | unresolved-name:BytesSubclass |
| BytesTest.test_from_format | uses-self.assertEqual |
| ByteArrayTest.test_resize | unresolved-name:ByteArraySubclass |
| ByteArrayTest.test_setitem | unresolved-name:Indexable |
| ByteArrayTest.test_extend | assertRaisesRegex call form |
| ByteArrayTest.test_remove | unresolved-name:Indexable |
| ByteArrayTest.test_append | unresolved-name:Indexable |
| ByteArrayTest.test_insert | unresolved-name:Indexable |
| AssortedBytesTest.test_bytes_repr | unresolved-name:BytesSubclass |
| AssortedBytesTest.test_bytearray_repr | unresolved-name:ByteArraySubclass |
| AssortedBytesTest.test_bytes_str | self.test_bytes_repr |
| AssortedBytesTest.test_bytearray_str | self.test_bytearray_repr |
| FixedStringTest.test_mixed_cmp | self._assert_cmp |
| SubclassTest.test_basic | self.assertIsSubclass |
| SubclassTest.test_join | uses-self.basetype |
| SubclassTest.test_pickle | self.assertNotHasAttr |
| SubclassTest.test_copy | self.assertNotHasAttr |
| BaseBytesTest.test_check_encoding_errors | host-raised:AttributeError: '_SelfNS' object has no attribute 'type2test' |
| BaseBytesTest.test_maketrans | host-raised:AttributeError: '_SelfNS' object has no attribute 'type2test' |
| BaseBytesTest.test_free_after_iterating | host-raised:AttributeError: '_SelfNS' object has no attribute 'type2test' |
| BytesTest.test__bytes__ | host-raised:AttributeError: '_SelfNS' object has no attribute 'type2test' |
| ByteArrayTest.test_delitem | host-raised:AttributeError: '_SelfNS' object has no attribute '_testlimitedcapi' |
| ByteArrayTest.test_obsolete_write_lock | host-raised:SkipTest: No module named '_testcapi' |
| ByteArrayTest.test_mutating_index | host-raised:AttributeError: '_SelfNS' object has no attribute '_testlimitedcapi' |
| ByteArrayTest.test_mutating_index_inbounds | host-raised:AttributeError: '_SelfNS' object has no attribute '_testlimitedcapi' |
| SubclassTest.test_fromhex | host-raised:AttributeError: '_SelfNS' object has no attribute 'type2test' |

## Expected vs got

### AssortedBytesTest.test_rsplit_bytearray (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [b\'a\', b\'b\'], [b\'a\', b\'b\'])"'>

### AssortedBytesTest.test_split_bytearray (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [b\'a\', b\'b\'], [b\'a\', b\'b\'])"'>

### BaseBytesTest.test_from_mutating_list (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'X\' object cannot be interpreted as an integer"'>

### ByteArraySubclassTest.test_init_override (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <**main**.subclass object at 0x7f063ee0b6d0>, b\'abcd\')"'>

### ByteArrayTest.test_bytearray_api (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ByteArrayTest.test_del_expand (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item deletion'">

### ByteArrayTest.test_extend_empty_buffer_overflow (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "can\'t extend bytearray with EvilIter"'>

### ByteArrayTest.test_extended_set_del_slice (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### ByteArrayTest.test_fifo_overrun (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item deletion'">

### ByteArrayTest.test_iconcat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', bytearray(b\'abcdef\'), bytearray(b\'abc\'))"'>

### ByteArrayTest.test_irepeat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', bytearray(b\'abcabcabc\'), bytearray(b\'abc\'))"'>

### ByteArrayTest.test_irepeat_1char (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', bytearray(b\'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\'), bytearray(b\'x\'))"'>

### ByteArrayTest.test_iterator_length_hint (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [])"'>

### ByteArrayTest.test_iterator_pickling2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle local object <function_jac_make_host_iterator.<locals>._next at 0x7f063efe7c10>"'>

### ByteArrayTest.test_regexps (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [b\'Hello\', b\'world\'], [bytearray(b\'Hello\'), bytearray(b\'world\')])"'>

### ByteArrayTest.test_repeat_after_setslice (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### ByteArrayTest.test_resize_forbidden (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### ByteArrayTest.test_reverse (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertFalse\', bytearray(b\'\'))"'>

### ByteArrayTest.test_search_methods_reentrancy_raises_buffererror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "argument should be integer or bytes-like object, not \'Evil\'"'>

### ByteArrayTest.test_setitem_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### ByteArrayTest.test_setslice (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### ByteArrayTest.test_setslice_extend (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item deletion'">

### ByteArrayTest.test_setslice_trap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### BytearrayPEP3137Test.test_returns_new_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'val\' is not defined"'>

### BytesTest.test_getitem_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### BytesTest.test_repeat_id_preserving (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 139664801626352, 139664801625488)"'>
