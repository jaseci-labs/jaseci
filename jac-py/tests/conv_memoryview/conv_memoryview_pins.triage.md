# Triage report: `conv_memoryview_pins.jac`

- source: reference/cpython/Lib/test/test_memoryview.py
- guest leg: 0/8 marks
- pins: **7 passed** / 8 run (+35 quarantined of 43 extracted)

| pin | result | got |
|---|---|---|
| AbstractMemoryTests.test_issue22668 | PASS | |
| AbstractMemoryTests.test_hex_use_after_free | PASS | |
| ArrayMemoryviewTest.test_array_assign | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| ArrayMemoryviewTest.test_boolean_format | PASS | |
| OtherTest.test_half_float | PASS | |
| OtherTest.test_memoryview_hex | PASS | |
| OtherTest.test_copy | PASS | |
| OtherTest.test_pickle | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| BaseArrayMemoryTests.test_getbuffer | decorator:unittest.skip |
| BaseArrayMemoryTests.test_tolist | decorator:unittest.skip |
| RacingTest.test_racing_getbuf_and_releasebuf | decorator:support.requires_resource |
| AbstractMemoryTests.test_getitem | helper:check_getitem_with_type(uses-self._source) |
| AbstractMemoryTests.test_index | uses-self._types |
| AbstractMemoryTests.test_iter | uses-self._types |
| AbstractMemoryTests.test_count | uses-self._types |
| AbstractMemoryTests.test_setitem_readonly | self.skipTest |
| AbstractMemoryTests.test_setitem_writable | self.skipTest |
| AbstractMemoryTests.test_delitem | uses-self._types |
| AbstractMemoryTests.test_tobytes | uses-self._types |
| AbstractMemoryTests.test_tolist | uses-self._types |
| AbstractMemoryTests.test_compare | uses-self._types |
| AbstractMemoryTests.test_attributes_readonly | helper:check_attributes_with_type(uses-self._view) |
| AbstractMemoryTests.test_attributes_writable | helper:check_attributes_with_type(uses-self._view) |
| AbstractMemoryTests.test_getbuffer | self._check_contents |
| AbstractMemoryTests.test_gc | uses-self._types |
| AbstractMemoryTests.test_contextmanager | helper:_check_released(uses-self.assertRaisesRegex) |
| AbstractMemoryTests.test_release | helper:_check_released(uses-self.assertRaisesRegex) |
| AbstractMemoryTests.test_writable_readonly | self.skipTest |
| AbstractMemoryTests.test_getbuf_fail | uses-self._view |
| AbstractMemoryTests.test_hash | self.skipTest |
| AbstractMemoryTests.test_hash_writable | self.skipTest |
| AbstractMemoryTests.test_hash_use_after_free | uses-self.clear |
| AbstractMemoryTests.test_weakref | uses-self._types |
| AbstractMemoryTests.test_reversed | uses-self._types |
| AbstractMemoryTests.test_toreadonly | uses-self._types |
| BaseMemoryviewTests.test_count | uses-self._types |
| BaseMemorySliceTests.test_refs | uses-self._types |
| BytesMemoryviewTest.test_constructor | uses-self._types |
| OtherTest.test_ctypes_cast | uses-self.subTest |
| OtherTest.test_memoryview_hex_separator | uses-self.subTest |
| OtherTest.test_use_released_memory | uses-self.subTest |
| OtherTest.test_buffer_reference_loop | unresolved-name:MyObject |
| OtherTest.test_picklebuffer_reference_loop | unresolved-name:MyObject |

## Expected vs got

### ArrayMemoryviewTest.test_array_assign (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">
