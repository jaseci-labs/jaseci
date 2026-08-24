# Triage report: `conv_marshal_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_marshal.py
- guest leg: 0/39 marks
- pins: **17 passed** / 39 run (+36 quarantined of 75 extracted)

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
| BugsTestCase.test_loads_abnormal_reference_loops | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIs\', ([(...)],), ([([(...)],)],))"'> |
| BugsTestCase.test_exact_type_match | PASS | |
| BugsTestCase.test_large_marshal | PASS | |
| BugsTestCase.test_invalid_longs | PASS | |
| BugsTestCase.test_multiple_dumps_and_loads | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'BufferedWriter.**enter**() takes no arguments (1 given)'"> |
| BugsTestCase.test_loads_reject_unicode_strings | PASS | |
| BugsTestCase.test_bad_reader | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC EOFError 'EOF read where object expected'"> |
| BugsTestCase.test_eof | PASS | |
| BugsTestCase.test_deterministic_sets | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'"> |
| BugsTestCase.test_unmarshallable | PASS | |
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
| BugsTestCase.test_reference_loop_code | self.addCleanup |
| InstancingTestCase.testModule | unresolved-name:**file** |
| CompatibilityTestCase.test0To3 | helper:_test(unresolved-name:**file**) |
| CompatibilityTestCase.test1To3 | helper:_test(unresolved-name:**file**) |
| CompatibilityTestCase.test2To3 | helper:_test(unresolved-name:**file**) |
| CompatibilityTestCase.test3To3 | helper:_test(unresolved-name:**file**) |
| ContainerTestCase.test_dict | host-raised:AttributeError: '_SelfNS' object has no attribute 'd' |
| ContainerTestCase.test_list | host-raised:AttributeError: '_SelfNS' object has no attribute 'd' |
| ContainerTestCase.test_tuple | host-raised:AttributeError: '_SelfNS' object has no attribute 'd' |
| ContainerTestCase.test_sets | host-raised:AttributeError: '_SelfNS' object has no attribute 'd' |
| InstancingTestCase.testList | host-raised:AttributeError: '_SelfNS' object has no attribute 'keys' |
| InstancingTestCase.testTuple | host-raised:AttributeError: '_SelfNS' object has no attribute 'keys' |
| InstancingTestCase.testSet | host-raised:AttributeError: '_SelfNS' object has no attribute 'keys' |
| InstancingTestCase.testFrozenSet | host-raised:AttributeError: '_SelfNS' object has no attribute 'keys' |
| InstancingTestCase.testDict | host-raised:AttributeError: '_SelfNS' object has no attribute 'keys' |
| InterningTestCase.testIntern | host-raised:AttributeError: '_SelfNS' object has no attribute 'strobj' |
| InterningTestCase.testNoIntern | host-raised:AttributeError: '_SelfNS' object has no attribute 'strobj' |
| SliceTestCase.test_slice | host-raised:AttributeError: '_SelfNS' object has no attribute 'helper' |

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

### BugsTestCase.test_deterministic_sets (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'">

### BugsTestCase.test_loads_abnormal_reference_loops (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIs\', ([(...)],), ([([(...)],)],))"'>

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
