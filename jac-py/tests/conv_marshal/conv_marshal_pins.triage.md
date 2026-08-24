# Triage report: `conv_marshal_pins.jac`

- source: reference/cpython/Lib/test/test_marshal.py
- guest leg: 0/36 marks
- pins: **16 passed** / 36 run (+39 quarantined of 75 extracted)

| pin | result | got |
|---|---|---|
| IntTestCase.test_ints | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| IntTestCase.test_int64 | PASS | |
| IntTestCase.test_bool | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| FloatTestCase.test_floats | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| StringTestCase.test_unicode | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| StringTestCase.test_string | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| StringTestCase.test_bytes | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| ExceptionTestCase.test_exceptions | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'exception_type\' has policy BridgePolicy.FAIL but no to_host conversion arm"'> |
| CodeTestCase.test_different_filenames | PASS | |
| BufferTestCase.test_bytearray | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| BufferTestCase.test_memoryview | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| BufferTestCase.test_array | PASS | |
| BugsTestCase.test_bug_5888452 | PASS | |
| BugsTestCase.test_patch_873224 | PASS | |
| BugsTestCase.test_version_argument | PASS | |
| BugsTestCase.test_fuzz | PASS | |
| BugsTestCase.test_loads_recursion | PASS | |
| BugsTestCase.test_recursion_limit | PASS | |
| BugsTestCase.test_reference_loop_list | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'"> |
| BugsTestCase.test_reference_loop_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'"> |
| BugsTestCase.test_reference_loop_tuple | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'"> |
| BugsTestCase.test_reference_loop_slice | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'"> |
| BugsTestCase.test_loads_reference_loop_list | PASS | |
| BugsTestCase.test_loads_reference_loop_dict | PASS | |
| BugsTestCase.test_exact_type_match | PASS | |
| BugsTestCase.test_large_marshal | PASS | |
| BugsTestCase.test_invalid_longs | PASS | |
| BugsTestCase.test_multiple_dumps_and_loads | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| BugsTestCase.test_loads_reject_unicode_strings | PASS | |
| BugsTestCase.test_bad_reader | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC EOFError 'EOF read where object expected'"> |
| BugsTestCase.test_eof | PASS | |
| InstancingTestCase.testInt | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| InstancingTestCase.testFloat | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| InstancingTestCase.testStr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| InstancingTestCase.testBytes | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| InstancingTestCase.testRecursion | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| CodeTestCase.test_same_filename_used | decorator:support.cpython_only |
| LargeValuesTestCase.test_bytes | decorator:unittest.skipIf |
| LargeValuesTestCase.test_str | decorator:unittest.skipIf |
| LargeValuesTestCase.test_tuple | decorator:unittest.skipIf |
| LargeValuesTestCase.test_list | decorator:unittest.skipIf |
| LargeValuesTestCase.test_set | decorator:unittest.skipIf |
| LargeValuesTestCase.test_frozenset | decorator:unittest.skipIf |
| LargeValuesTestCase.test_bytearray | decorator:unittest.skipIf |
| CAPI_TestCase.test_write_long_to_file | decorator:unittest.skipUnless |
| CAPI_TestCase.test_write_object_to_file | decorator:unittest.skipUnless |
| CAPI_TestCase.test_read_short_from_file | decorator:unittest.skipUnless |
| CAPI_TestCase.test_read_long_from_file | decorator:unittest.skipUnless |
| CAPI_TestCase.test_read_last_object_from_file | decorator:unittest.skipUnless |
| CAPI_TestCase.test_read_object_from_file | decorator:unittest.skipUnless |
| CodeTestCase.test_code | unresolved-name:ExceptionTestCase |
| CodeTestCase.test_many_codeobjects | unresolved-name:ExceptionTestCase |
| CodeTestCase.test_no_allow_code | unresolved-name:ExceptionTestCase |
| CodeTestCase.test_minimal_linetable_with_no_debug_ranges | unresolved-name:ExceptionTestCase |
| ContainerTestCase.test_dict | uses-self.d |
| ContainerTestCase.test_list | uses-self.d |
| ContainerTestCase.test_tuple | uses-self.d |
| ContainerTestCase.test_sets | uses-self.d |
| BugsTestCase.test_reference_loop_code | self.addCleanup |
| BugsTestCase.test_loads_abnormal_reference_loops | uses-self.subTest |
| BugsTestCase.test_deterministic_sets | uses-self.subTest |
| BugsTestCase.test_unmarshallable | uses-self.subTest |
| InstancingTestCase.testList | uses-self.keys |
| InstancingTestCase.testTuple | uses-self.keys |
| InstancingTestCase.testSet | uses-self.keys |
| InstancingTestCase.testFrozenSet | uses-self.keys |
| InstancingTestCase.testDict | uses-self.keys |
| InstancingTestCase.testModule | unresolved-name:**file** |
| CompatibilityTestCase.test0To3 | helper:_test(unresolved-name:**file**) |
| CompatibilityTestCase.test1To3 | helper:_test(unresolved-name:**file**) |
| CompatibilityTestCase.test2To3 | helper:_test(unresolved-name:**file**) |
| CompatibilityTestCase.test3To3 | helper:_test(unresolved-name:**file**) |
| InterningTestCase.testIntern | uses-self.strobj |
| InterningTestCase.testNoIntern | uses-self.strobj |
| SliceTestCase.test_slice | uses-self.helper |

## Expected vs got

### BufferTestCase.test_bytearray (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### BufferTestCase.test_memoryview (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### BugsTestCase.test_bad_reader (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC EOFError 'EOF read where object expected'">

### BugsTestCase.test_multiple_dumps_and_loads (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### BugsTestCase.test_reference_loop_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'">

### BugsTestCase.test_reference_loop_list (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'">

### BugsTestCase.test_reference_loop_slice (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'">

### BugsTestCase.test_reference_loop_tuple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'">

### ExceptionTestCase.test_exceptions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'exception_type\' has policy BridgePolicy.FAIL but no to_host conversion arm"'>

### FloatTestCase.test_floats (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### InstancingTestCase.testBytes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### InstancingTestCase.testFloat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### InstancingTestCase.testInt (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### InstancingTestCase.testRecursion (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'">

### InstancingTestCase.testStr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### IntTestCase.test_bool (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### IntTestCase.test_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### StringTestCase.test_bytes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### StringTestCase.test_string (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">

### StringTestCase.test_unicode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'">
