# Triage report: `conv_difflib_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_difflib.py
- guest leg: TIMEOUT at 60s cap
- pins: **0 passed** / 30 run (+8 quarantined of 38 extracted)

| pin | result | got |
|---|---|---|
| TestWithAscii.test_one_insert | TIMEOUT | jac run hit 60s cap |
| TestWithAscii.test_one_delete | TIMEOUT | jac run hit 60s cap |
| TestWithAscii.test_opcode_caching | TIMEOUT | jac run hit 60s cap |
| TestWithAscii.test_bjunk | TIMEOUT | jac run hit 60s cap |
| TestAutojunk.test_one_insert_homogenous_sequence | TIMEOUT | jac run hit 60s cap |
| TestSFbugs.test_ratio_for_null_seqn | TIMEOUT | jac run hit 60s cap |
| TestSFbugs.test_comparing_empty_lists | TIMEOUT | jac run hit 60s cap |
| TestSFbugs.test_matching_blocks_cache | TIMEOUT | jac run hit 60s cap |
| TestSFbugs.test_added_tab_hint | TIMEOUT | jac run hit 60s cap |
| TestSFbugs.test_hint_indented_properly_with_tabs | TIMEOUT | jac run hit 60s cap |
| TestSFbugs.test_mdiff_catch_stop_iteration | TIMEOUT | jac run hit 60s cap |
| TestSFpatches.test_html_diff | TIMEOUT | jac run hit 60s cap |
| TestSFpatches.test_recursion_limit | TIMEOUT | jac run hit 60s cap |
| TestSFpatches.test_make_file_default_charset | TIMEOUT | jac run hit 60s cap |
| TestSFpatches.test_make_file_iso88591_charset | TIMEOUT | jac run hit 60s cap |
| TestSFpatches.test_make_file_usascii_charset_with_nonascii_input | TIMEOUT | jac run hit 60s cap |
| TestDiffer.test_close_matches_aligned | TIMEOUT | jac run hit 60s cap |
| TestDiffer.test_one_insert | TIMEOUT | jac run hit 60s cap |
| TestDiffer.test_one_delete | TIMEOUT | jac run hit 60s cap |
| TestOutputFormat.test_tab_delimiter | TIMEOUT | jac run hit 60s cap |
| TestOutputFormat.test_no_trailing_tab_on_empty_filedate | TIMEOUT | jac run hit 60s cap |
| TestOutputFormat.test_range_format_unified | TIMEOUT | jac run hit 60s cap |
| TestOutputFormat.test_range_format_context | TIMEOUT | jac run hit 60s cap |
| TestJunkAPIs.test_is_line_junk_true | TIMEOUT | jac run hit 60s cap |
| TestJunkAPIs.test_is_line_junk_false | TIMEOUT | jac run hit 60s cap |
| TestJunkAPIs.test_is_line_junk_REDOS | TIMEOUT | jac run hit 60s cap |
| TestJunkAPIs.test_is_character_junk_true | TIMEOUT | jac run hit 60s cap |
| TestJunkAPIs.test_is_character_junk_false | TIMEOUT | jac run hit 60s cap |
| TestCloseMatches.test_invalid_inputs | TIMEOUT | jac run hit 60s cap |
| TestRestore.test_invalid_input | TIMEOUT | jac run hit 60s cap |

## Quarantined at conversion

| test | reason |
|---|---|
| TestBytes.test_byte_content | uses-self.check |
| TestBytes.test_byte_filenames | uses-self.check |
| TestInputTypes.test_input_type_checks | self._assert_type_error |
| TestInputTypes.test_mixed_types_content | self._assert_type_error |
| TestInputTypes.test_mixed_types_filenames | self._assert_type_error |
| TestInputTypes.test_mixed_types_dates | self._assert_type_error |
| TestFindLongest.test_default_args | uses-self.longer_match_exists |
| TestFindLongest.test_longest_match_with_popular_chars | uses-self.longer_match_exists |

## Expected vs got

### TestAutojunk.test_one_insert_homogenous_sequence (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestCloseMatches.test_invalid_inputs (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestDiffer.test_close_matches_aligned (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestDiffer.test_one_delete (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestDiffer.test_one_insert (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestJunkAPIs.test_is_character_junk_false (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestJunkAPIs.test_is_character_junk_true (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestJunkAPIs.test_is_line_junk_REDOS (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestJunkAPIs.test_is_line_junk_false (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestJunkAPIs.test_is_line_junk_true (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestOutputFormat.test_no_trailing_tab_on_empty_filedate (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestOutputFormat.test_range_format_context (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestOutputFormat.test_range_format_unified (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestOutputFormat.test_tab_delimiter (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestRestore.test_invalid_input (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFbugs.test_added_tab_hint (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFbugs.test_comparing_empty_lists (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFbugs.test_hint_indented_properly_with_tabs (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFbugs.test_matching_blocks_cache (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFbugs.test_mdiff_catch_stop_iteration (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFbugs.test_ratio_for_null_seqn (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFpatches.test_html_diff (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFpatches.test_make_file_default_charset (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFpatches.test_make_file_iso88591_charset (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFpatches.test_make_file_usascii_charset_with_nonascii_input (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestSFpatches.test_recursion_limit (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestWithAscii.test_bjunk (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestWithAscii.test_one_delete (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestWithAscii.test_one_insert (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

### TestWithAscii.test_opcode_caching (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap
