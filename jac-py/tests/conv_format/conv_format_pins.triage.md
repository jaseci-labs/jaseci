# Triage report: `conv_format_pins.jac`

- source: /var/tmp/sp2-wt/reference/cpython/Lib/test/test_format.py
- guest leg: 0/14 marks
- pins: **9 passed** / 14 run (+8 quarantined of 22 extracted)

| pin | result | got |
|---|---|---|
| FormatTest.test_common_format | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'verbose' from '<unknown>'"> |
| FormatTest.test_str_format | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'verbose' from '<unknown>'"> |
| FormatTest.test_bytes_and_bytearray_format | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'verbose' from '<unknown>'"> |
| FormatTest.test_nul | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'verbose' from '<unknown>'"> |
| FormatTest.test_non_ascii | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'verbose' from '<unknown>'"> |
| FormatTest.test_precision | PASS | |
| FormatTest.test_g_format_has_no_trailing_zeros | PASS | |
| FormatTest.test_with_two_commas_in_format_specifier | PASS | |
| FormatTest.test_with_two_underscore_in_format_specifier | PASS | |
| FormatTest.test_with_a_commas_and_an_underscore_in_format_specifier | PASS | |
| FormatTest.test_with_an_underscore_and_a_comma_in_format_specifier | PASS | |
| FormatTest.test_unicode_in_error_message | PASS | |
| FormatTest.test_negative_zero | PASS | |
| FormatTest.test_specifier_z_error | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| FormatTest.test_optimisations | decorator:support.cpython_only |
| FormatTest.test_precision_c_limits | decorator:support.cpython_only |
| FormatTest.test_locale | self.skipTest |
| FormatTest.test_better_error_message_format | uses-self.subTest |
| testformat | host-raised:NameError: name 'output' is not defined |
| testcommon | host-raised:NameError: name 'formatstr' is not defined |
| test_exc | host-raised:NameError: name 'exception' is not defined |
| test_exc_common | host-raised:NameError: name 'formatstr' is not defined |

## Expected vs got

### FormatTest.test_bytes_and_bytearray_format (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'verbose' from '<unknown>'">

### FormatTest.test_common_format (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'verbose' from '<unknown>'">

### FormatTest.test_non_ascii (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'verbose' from '<unknown>'">

### FormatTest.test_nul (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'verbose' from '<unknown>'">

### FormatTest.test_str_format (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'verbose' from '<unknown>'">
