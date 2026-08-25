# Triage report: `conv_getpass_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_getpass.py
- guest leg: 0/6 marks
- pins: **4 passed** / 6 run (+18 quarantined of 24 extracted)

| pin | result | got |
|---|---|---|
| GetpassRawinputTest.test_flushes_stream_after_prompt | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute '**init_subclass**'"> |
| GetpassRawinputTest.test_uses_stderr_as_default | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'result' from 'unittest' (/home/jac/.cache/jac/rt/553c250071fd962f-c152554fd6e7fdad/python/lib/python3.14/unittest/**init**.py)"> |
| GetpassRawinputTest.test_raises_on_empty_input | PASS | |
| GetpassRawinputTest.test_trims_trailing_newline | PASS | |
| GetpassEchoCharTest.test_accept_none | PASS | |
| GetpassEchoCharTest.test_reject_empty_string | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| UnixGetpassTest.test_uses_tty_directly | decorator:unittest.skipUnless |
| UnixGetpassTest.test_resets_termios | decorator:unittest.skipUnless |
| UnixGetpassTest.test_falls_back_to_fallback_if_termios_raises | decorator:unittest.skipUnless |
| UnixGetpassTest.test_flushes_stream_after_input | decorator:unittest.skipUnless |
| UnixGetpassTest.test_falls_back_to_stdin | decorator:unittest.skipUnless |
| UnixGetpassTest.test_echo_char_replaces_input_with_asterisks | decorator:unittest.skipUnless |
| UnixGetpassTest.test_raw_input_with_echo_char | decorator:unittest.skipUnless |
| UnixGetpassTest.test_control_chars_with_echo_char | decorator:unittest.skipUnless |
| GetpassEchoCharTest.test_accept_single_printable_ascii | decorator:support.subTests |
| GetpassEchoCharTest.test_reject_multi_character_strings | decorator:support.subTests |
| GetpassEchoCharTest.test_reject_non_ascii | decorator:support.subTests |
| GetpassEchoCharTest.test_reject_non_printable_characters | decorator:support.subTests |
| GetpassEchoCharTest.test_reject_non_string | decorator:support.subTests |
| GetpassGetuserTest.test_username_takes_username_from_env | unresolved-name:environ |
| GetpassGetuserTest.test_username_priorities_of_env_values | unresolved-name:environ |
| GetpassGetuserTest.test_username_falls_back_to_pwd | unresolved-name:environ |
| GetpassRawinputTest.test_uses_stdin_as_default_input | unresolved-name:mock_input |
| GetpassRawinputTest.test_uses_stdin_as_different_locale | unresolved-name:mock_input |

## Expected vs got

### GetpassRawinputTest.test_flushes_stream_after_prompt (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute '**init_subclass**'">

### GetpassRawinputTest.test_uses_stderr_as_default (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'result' from 'unittest' (/home/jac/.cache/jac/rt/553c250071fd962f-c152554fd6e7fdad/python/lib/python3.14/unittest/**init**.py)">
