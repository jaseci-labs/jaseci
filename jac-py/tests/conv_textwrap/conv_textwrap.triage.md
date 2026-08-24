# Triage report: `conv_textwrap_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_textwrap.py
- guest leg: 0/7 marks
- pins: **6 passed** / 7 run (+61 quarantined of 68 extracted)

| pin | result | got |
|---|---|---|
| WrapTestCase.test_bad_width | PASS | |
| DedentTestCase.test_type_error | PASS | |
| DedentTestCase.test_dedent_even | PASS | |
| DedentTestCase.test_dedent_uneven | PASS | |
| DedentTestCase.test_dedent_declining | PASS | |
| DedentTestCase.test_dedent_preserve_internal_tabs | PASS | |
| ShortenTestCase.test_width_too_small_for_placeholder | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'native_builtin\' has policy BridgePolicy.TRAMPOLINE but no to_host conversion arm"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| WrapTestCase.test_simple | self.check_wrap |
| WrapTestCase.test_empty_string | self.check_wrap |
| WrapTestCase.test_empty_string_with_initial_indent | self.check_wrap |
| WrapTestCase.test_whitespace | self.check |
| WrapTestCase.test_fix_sentence_endings | self.check |
| WrapTestCase.test_wrap_short | self.check_wrap |
| WrapTestCase.test_wrap_short_1line | self.check_wrap |
| WrapTestCase.test_hyphenated | self.check_wrap |
| WrapTestCase.test_hyphenated_numbers | self.check_wrap |
| WrapTestCase.test_em_dash | self.check_wrap |
| WrapTestCase.test_unix_options | self.check_wrap |
| WrapTestCase.test_funky_hyphens | self.check_split |
| WrapTestCase.test_punct_hyphens | self.check_split |
| WrapTestCase.test_funky_parens | self.check_split |
| WrapTestCase.test_drop_whitespace_false | self.check_wrap |
| WrapTestCase.test_drop_whitespace_false_whitespace_only | self.check_wrap |
| WrapTestCase.test_drop_whitespace_false_whitespace_only_with_indent | self.check_wrap |
| WrapTestCase.test_drop_whitespace_whitespace_only | self.check_wrap |
| WrapTestCase.test_drop_whitespace_leading_whitespace | self.check_wrap |
| WrapTestCase.test_drop_whitespace_whitespace_line | self.check_wrap |
| WrapTestCase.test_drop_whitespace_whitespace_only_with_indent | self.check_wrap |
| WrapTestCase.test_drop_whitespace_whitespace_indent | self.check_wrap |
| WrapTestCase.test_split | self.check |
| WrapTestCase.test_break_on_hyphens | self.check_wrap |
| WrapTestCase.test_no_split_at_umlaut | self.check_wrap |
| WrapTestCase.test_umlaut_followed_by_dash | self.check_wrap |
| WrapTestCase.test_non_breaking_space | self.check_wrap |
| WrapTestCase.test_narrow_non_breaking_space | self.check_wrap |
| MaxLinesTestCase.test_simple | self.check_wrap |
| MaxLinesTestCase.test_spaces | self.check_wrap |
| MaxLinesTestCase.test_placeholder | self.check_wrap |
| MaxLinesTestCase.test_placeholder_backtrack | self.check_wrap |
| LongWordTestCase.test_break_long | self.check_wrap |
| LongWordTestCase.test_nobreak_long | self.check |
| LongWordTestCase.test_max_lines_long | self.check_wrap |
| LongWordWithHyphensTestCase.test_break_long_words_on_hyphen | self.check_wrap |
| LongWordWithHyphensTestCase.test_break_long_words_not_on_hyphen | self.check_wrap |
| LongWordWithHyphensTestCase.test_break_on_hyphen_but_not_long_words | self.check_wrap |
| LongWordWithHyphensTestCase.test_do_not_break_long_words_or_on_hyphens | self.check_wrap |
| IndentTestCases.test_fill | self.check |
| IndentTestCases.test_initial_indent | self.check |
| IndentTestCases.test_subsequent_indent | self.check |
| DedentTestCase.test_dedent_whitespace | self.assertUnchanged |
| DedentTestCase.test_dedent_nomargin | self.assertUnchanged |
| DedentTestCase.test_dedent_preserve_margin_tabs | self.assertUnchanged |
| IndentTestCase.test_indent_nomargin_default | uses-self.CASES |
| IndentTestCase.test_indent_nomargin_explicit_default | uses-self.CASES |
| IndentTestCase.test_indent_nomargin_all_lines | uses-self.CASES |
| IndentTestCase.test_indent_no_lines | uses-self.CASES |
| IndentTestCase.test_roundtrip_spaces | uses-self.ROUNDTRIP_CASES |
| IndentTestCase.test_roundtrip_tabs | uses-self.ROUNDTRIP_CASES |
| IndentTestCase.test_roundtrip_mixed | uses-self.ROUNDTRIP_CASES |
| IndentTestCase.test_indent_default | uses-self.CASES |
| IndentTestCase.test_indent_explicit_default | uses-self.CASES |
| IndentTestCase.test_indent_all_lines | uses-self.CASES |
| IndentTestCase.test_indent_empty_lines | uses-self.CASES |
| ShortenTestCase.test_simple | self.check_shorten |
| ShortenTestCase.test_placeholder | self.check_shorten |
| ShortenTestCase.test_empty_string | self.check_shorten |
| ShortenTestCase.test_whitespace | self.check_shorten |
| ShortenTestCase.test_first_word_too_long_but_placeholder_fits | self.check_shorten |

## Expected vs got

### ShortenTestCase.test_width_too_small_for_placeholder (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'native_builtin\' has policy BridgePolicy.TRAMPOLINE but no to_host conversion arm"'>
