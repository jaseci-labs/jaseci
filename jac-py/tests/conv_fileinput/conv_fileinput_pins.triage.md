# Triage report: `conv_fileinput_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_fileinput.py
- guest leg: 0/14 marks
- pins: **5 passed** / 14 run (+43 quarantined of 57 extracted)

| pin | result | got |
|---|---|---|
| FileInputTests.test_invalid_opening_mode | PASS | |
| FileInputTests.test_stdin_binary_mode | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute '**init_subclass**'"> |
| FileInputTests.test_empty_files_list_specified_to_constructor | PASS | |
| Test_fileinput_input.test_state_is_not_None_and_state_file_is_None | PASS | |
| Test_fileinput_input.test_state_is_None | PASS | |
| Test_fileinput_close.test_state_is_None | PASS | |
| Test_fileinput_close.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_nextfile.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_filename.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_lineno.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_filelineno.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_fileno.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_isfirstline.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_isstdin.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| Test_hook_compressed.test_gz_ext_fake | decorator:unittest.skipUnless |
| Test_hook_compressed.test_gz_with_encoding_fake | decorator:unittest.skipUnless |
| Test_hook_compressed.test_bz2_ext_fake | decorator:unittest.skipUnless |
| BufferSizesTests.test_buffer_sizes | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_zero_byte_files | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_files_that_dont_end_with_newline | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_fileno | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_detached_stdin_binary_mode | self.assertNotHasAttr |
| FileInputTests.test_file_opening_hook | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_readline | self.addCleanup |
| FileInputTests.test_readline_binary_mode | self.addCleanup |
| FileInputTests.test_inplace_binary_write_mode | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_inplace_encoding_errors | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_file_hook_backward_compatibility | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_context_manager | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_close_on_exception | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_nextfile_oserror_deleting_backup | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_readline_os_fstat_raises_OSError | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_readline_os_chmod_raises_OSError | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_fileno_when_ValueError_raised | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_readline_buffering | unresolved-name:LineReader |
| FileInputTests.test_iteration_buffering | unresolved-name:LineReader |
| FileInputTests.test_pathlike_file | helper:writeTmp(self.addCleanup) |
| FileInputTests.test_pathlike_file_inplace | helper:writeTmp(self.addCleanup) |
| Test_fileinput_input.test_state_is_not_None_and_state_file_is_not_None | unresolved-name:cm |
| Test_fileinput_nextfile.test_state_is_None | unresolved-name:cm |
| Test_fileinput_filename.test_state_is_None | unresolved-name:cm |
| Test_fileinput_lineno.test_state_is_None | unresolved-name:cm |
| Test_fileinput_filelineno.test_state_is_None | unresolved-name:cm |
| Test_fileinput_fileno.test_state_is_None | unresolved-name:cm |
| Test_fileinput_isfirstline.test_state_is_None | unresolved-name:cm |
| Test_fileinput_isstdin.test_state_is_None | unresolved-name:cm |
| Test_hook_compressed.test_empty_string | helper:do_test_use_builtin_open_text(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_no_ext | helper:do_test_use_builtin_open_text(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_blah_ext | helper:do_test_use_builtin_open_binary(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_gz_ext_builtin | helper:do_test_use_builtin_open_binary(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_bz2_ext_builtin | helper:do_test_use_builtin_open_binary(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_binary_mode_encoding | helper:do_test_use_builtin_open_binary(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_text_mode_encoding | helper:do_test_use_builtin_open_text(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_encoded.test | unresolved-name:InvocationRecorder |
| Test_hook_encoded.test_errors | self.addCleanup |
| Test_hook_encoded.test_modes | self.addCleanup |
| MiscTest.test_all | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### FileInputTests.test_stdin_binary_mode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute '**init_subclass**'">

### Test_fileinput_close.test_state_is_not_None (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_filelineno.test_state_is_not_None (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_filename.test_state_is_not_None (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_fileno.test_state_is_not_None (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_isfirstline.test_state_is_not_None (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_isstdin.test_state_is_not_None (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_lineno.test_state_is_not_None (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_nextfile.test_state_is_not_None (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">
