# Triage report: `conv_shelve_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_shelve.py
- guest leg: 0/5 marks
- pins: **5 passed** / 5 run (+9 quarantined of 14 extracted)

| pin | result | got |
|---|---|---|
| TestCase.test_close | PASS | |
| TestCase.test_keyencoding | PASS | |
| TestCase.test_writeback_also_writes_immediately | PASS | |
| TestCase.test_with | PASS | |
| TestCase.test_default_protocol | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCase.test_open_template | self.addCleanup |
| TestCase.test_ascii_file_shelf | self.test_open_template |
| TestCase.test_binary_file_shelf | self.test_open_template |
| TestCase.test_proto2_file_shelf | self.test_open_template |
| TestCase.test_pathlib_path_file_shelf | self.test_open_template |
| TestCase.test_bytes_path_file_shelf | self.test_open_template |
| TestCase.test_pathlib_bytes_path_file_shelf | self.test_open_template |
| TestCase.test_in_memory_shelf | unresolved-name:byteskeydict |
| TestCase.test_mutable_entry | unresolved-name:byteskeydict |
