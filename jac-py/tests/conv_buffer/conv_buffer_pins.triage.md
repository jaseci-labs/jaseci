# Triage report: `conv_buffer_pins.jac`

- source: reference/cpython/Lib/test/test_buffer.py
- guest leg: 0/8 marks
- pins: **2 passed** / 8 run (+87 quarantined of 95 extracted)

| pin | result | got |
|---|---|---|
| TestPythonBufferProtocol.test_basic | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "memoryview: a bytes-like object is required, not \'MyBuffer\'"'> |
| TestPythonBufferProtocol.test_bad_buffer_method | PASS | |
| TestPythonBufferProtocol.test_call_builtins | PASS | |
| TestPythonBufferProtocol.test_inheritance | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPythonBufferProtocol.test_inheritance_releasebuffer | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPythonBufferProtocol.test_inherit_but_return_something_else | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'memoryview.**enter**() takes no arguments (1 given)'"> |
| TestPythonBufferProtocol.test_override_only_release | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPythonBufferProtocol.test_release_buffer_with_exception_set | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'memoryview.**enter**() takes no arguments (1 given)'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestBufferProtocol.test_ndarray_getbuf | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_exceptions | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_linked_list | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_format_scalar | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_format_shape | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_format_strides | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_fortran | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_multidim | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_index_invalid | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_index_scalar | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_index_null_strides | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_index_getitem_single | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_index_setitem_single | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_index_getitem_multidim | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_sequence | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_slice_invalid | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_slice_zero_shape | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_slice_multidim | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_slice_redundant_suboffsets | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_slice_assign_single | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_slice_assign_multidim | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_random | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_random_invalid | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_random_slice_assign | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_re_export | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_zero_shape | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_zero_strides | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_offset | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_memoryview_from_buffer | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_get_pointer | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_tolist_null_strides | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_cmp_contig | decorator:unittest.skipUnless |
| TestBufferProtocol.test_ndarray_hash | decorator:unittest.skipUnless |
| TestBufferProtocol.test_py_buffer_to_contiguous | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_construction | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_cast_zero_shape | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_sizeof | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_struct_module | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_cast_zero_strides | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_cast_invalid | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_cast | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_cast_1D_ND | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_tolist | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_repr | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_sequence | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_index | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_assign | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_slice | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_array | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_special_cases | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_special_cases_deprecated_u_type_code | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_ndim_zero | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_ndim_one | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_zero_shape | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_zero_strides | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_random_formats | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_multidim_c | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_multidim_fortran | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_multidim_mixed | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_multidim_zero_shape | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_multidim_zero_strides | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_multidim_suboffsets | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_compare_not_equal | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_check_released | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_tobytes | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_get_contiguous | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_serializing | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_hash | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_release | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_redirect | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_from_static_exporter | decorator:unittest.skipUnless |
| TestBufferProtocol.test_memoryview_getbuffer_undefined | decorator:unittest.skipUnless |
| TestBufferProtocol.test_issue_7385 | decorator:unittest.skipUnless |
| TestBufferProtocol.test_bytearray_release_buffer_read_flag | decorator:unittest.skipUnless |
| TestBufferProtocol.test_pybuffer_size_from_format | decorator:unittest.skipUnless |
| TestBufferProtocol.test_flags_overflow | decorator:unittest.skipUnless |
| TestPythonBufferProtocol.test_c_buffer | decorator:unittest.skipIf |
| TestPythonBufferProtocol.test_c_buffer_invalid_flags | decorator:unittest.skipIf |
| TestPythonBufferProtocol.test_c_fill_buffer_invalid_flags | decorator:unittest.skipIf |
| TestPythonBufferProtocol.test_c_fill_buffer_readonly_and_writable | decorator:unittest.skipIf |
| TestPythonBufferProtocol.test_release_buffer | uses-self.held |
| TestPythonBufferProtocol.test_same_buffer_returned | uses-self.held |
| TestPythonBufferProtocol.test_buffer_flags | uses-self._data |
| TestPythonBufferProtocol.test_release_saves_reference | uses-self.assertEqual |
| TestPythonBufferProtocol.test_release_saves_reference_no_subclassing | uses-self.buffer |
| TestPythonBufferProtocol.test_multiple_inheritance_buffer_last | uses-self.buffer |
| TestPythonBufferProtocol.test_multiple_inheritance_buffer_last_raising | uses-self.buffer |

## Expected vs got

### TestPythonBufferProtocol.test_basic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "memoryview: a bytes-like object is required, not \'MyBuffer\'"'>

### TestPythonBufferProtocol.test_inherit_but_return_something_else (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'memoryview.**enter**() takes no arguments (1 given)'">

### TestPythonBufferProtocol.test_inheritance (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPythonBufferProtocol.test_inheritance_releasebuffer (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPythonBufferProtocol.test_override_only_release (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPythonBufferProtocol.test_release_buffer_with_exception_set (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'memoryview.**enter**() takes no arguments (1 given)'">
