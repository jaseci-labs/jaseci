# Triage report: `conv_linecache_pins.jac`

- source: reference/cpython/Lib/test/test_linecache.py
- guest leg: 0/11 marks
- pins: **3 passed** / 11 run (+13 quarantined of 24 extracted)

| pin | result | got |
|---|---|---|
| LineCacheTests.test_getline | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">` |
| LineCacheTests.test_clearcache | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">` |
| LineCacheTests.test_lazycache_no_globals | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">` |
| LineCacheTests.test_lazycache_smoke | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', True, False)"'> |
| LineCacheTests.test_lazycache_provide_after_failed_lookup | PASS | |
| LineCacheTests.test_lazycache_check | PASS | |
| LineCacheTests.test_lazycache_bad_filename | PASS | |
| LineCacheTests.test_lazycache_already_cached | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'/usr/lib/python3.14/linecache.py.missing\'"'> |
| LineCacheTests.test_memoryerror | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">` |
| LineCacheTests.test_frozen | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">` |
| LineCacheTests.test_linecache_python_string | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| MultiThreadingTest.test_read_write_safety | decorator:threading_helper.requires_working_threading |
| GetLineTestsGoodData.test_getline | helper:setUp(uses-self.file_byte_string) |
| GetLineTestsGoodData.test_getlines | helper:setUp(uses-self.file_byte_string) |
| GetLineTestsBadData.test_getline | helper:setUp(self.addCleanup) |
| GetLineTestsBadData.test_getlines | helper:setUp(self.addCleanup) |
| EmptyFile.test_getlines | helper:setUp(uses-self.file_byte_string) |
| LineCacheTests.test_no_ending_newline | self.addCleanup |
| LineCacheTests.test_checkcache | self.addCleanup |
| LineCacheTests.test_loader | unresolved-name:FakeLoader |
| LineCacheTests.test_invalid_names | uses-self.subTest |
| LineCacheInvalidationTests.test_checkcache_for_deleted_file | helper:setUp(self.addCleanup) |
| LineCacheInvalidationTests.test_checkcache_for_modified_file | helper:setUp(self.addCleanup) |
| LineCacheInvalidationTests.test_checkcache_with_no_parameter | helper:setUp(self.addCleanup) |

## Expected vs got

### LineCacheTests.test_clearcache (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">`

### LineCacheTests.test_frozen (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">`

### LineCacheTests.test_getline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">`

### LineCacheTests.test_lazycache_already_cached (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'/usr/lib/python3.14/linecache.py.missing\'"'>

### LineCacheTests.test_lazycache_no_globals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">`

### LineCacheTests.test_lazycache_smoke (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', True, False)"'>

### LineCacheTests.test_linecache_python_string (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'">

### LineCacheTests.test_memoryerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'TextIOWrapper.__enter__() takes no arguments (1 given)'">`
