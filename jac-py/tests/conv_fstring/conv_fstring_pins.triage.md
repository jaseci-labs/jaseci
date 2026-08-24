# Triage report: `conv_fstring_pins.jac`

- source: reference/cpython/Lib/test/test_fstring.py
- guest leg: 0/58 marks
- pins: **49 passed** / 58 run (+32 quarantined of 90 extracted)

| pin | result | got |
|---|---|---|
| TestCase.test__format__lookup | PASS | |
| TestCase.test_ast_line_numbers | PASS | |
| TestCase.test_ast_line_numbers_multiple_formattedvalues | PASS | |
| TestCase.test_ast_line_numbers_nested | PASS | |
| TestCase.test_ast_line_numbers_duplicate_expression | PASS | |
| TestCase.test_ast_numbers_fstring_with_formatting | PASS | |
| TestCase.test_ast_line_numbers_multiline_fstring | PASS | |
| TestCase.test_ast_line_numbers_with_parentheses | PASS | |
| TestCase.test_ast_fstring_empty_format_spec | PASS | |
| TestCase.test_ast_fstring_format_spec | PASS | |
| TestCase.test_docstring | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsNone\', \'Not a docstring\')"'> |
| TestCase.test_literal_eval | PASS | |
| TestCase.test_ast_compile_time_concat | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'> |
| TestCase.test_literal | PASS | |
| TestCase.test_many_expressions | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'> |
| TestCase.test_no_escapes_for_braces | PASS | |
| TestCase.test_newlines_in_expressions | PASS | |
| TestCase.test_valid_prefixes | PASS | |
| TestCase.test_roundtrip_raw_quotes | PASS | |
| TestCase.test_fstring_backslash_prefix_raw | PASS | |
| TestCase.test_fstring_format_spec_greedy_matching | PASS | |
| TestCase.test_yield | PASS | |
| TestCase.test_yield_send | PASS | |
| TestCase.test_expressions_with_triple_quoted_strings | PASS | |
| TestCase.test_multiple_vars | PASS | |
| TestCase.test_closure | PASS | |
| TestCase.test_arguments | PASS | |
| TestCase.test_locals | PASS | |
| TestCase.test_missing_format_spec | PASS | |
| TestCase.test_global | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestCase.test_shadowed_global | PASS | |
| TestCase.test_call | PASS | |
| TestCase.test_nested_fstrings | PASS | |
| TestCase.test_leading_trailing_spaces | PASS | |
| TestCase.test_not_equal | PASS | |
| TestCase.test_equal_equal | PASS | |
| TestCase.test_if_conditional | PASS | |
| TestCase.test_empty_format_specifier | PASS | |
| TestCase.test_str_format_differences | PASS | |
| TestCase.test_filename_in_syntaxerror | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.os_helper'"> |
| TestCase.test_loop | PASS | |
| TestCase.test_dict | PASS | |
| TestCase.test_backslash_char | PASS | |
| TestCase.test_debug_conversion | PASS | |
| TestCase.test_debug_expressions_are_raw_strings | PASS | |
| TestCase.test_walrus | PASS | |
| TestCase.test_invalid_syntax_error_message | PASS | |
| TestCase.test_with_two_commas_in_format_specifier | PASS | |
| TestCase.test_with_two_underscore_in_format_specifier | PASS | |
| TestCase.test_with_a_commas_and_an_underscore_in_format_specifier | PASS | |
| TestCase.test_with_an_underscore_and_a_comma_in_format_specifier | PASS | |
| TestCase.test_syntax_error_for_starred_expressions | PASS | |
| TestCase.test_debug_in_file | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.os_helper'"> |
| TestCase.test_syntax_warning_infinite_recursion_in_file | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.os_helper'"> |
| TestCase.test_fstring_without_formatting_bytecode | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestCase.test_gh129093 | PASS | |
| TestCase.test_raw_fstring_format_spec | PASS | |
| TestCase.test_gh139516 | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.os_helper'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCase.test_mismatched_parens | decorator:unittest.skipIf |
| TestCase.test_fstring_nested_too_deeply | decorator:unittest.skipIf |
| TestCase.test_ast | uses-self.called |
| TestCase.test_compile_time_concat_errors | self.assertAllRaise |
| TestCase.test_unterminated_string | self.assertAllRaise |
| TestCase.test_syntax_error_in_nested_fstring | self.assertAllRaise |
| TestCase.test_double_braces | self.assertAllRaise |
| TestCase.test_compile_time_concat | self.assertAllRaise |
| TestCase.test_comments | self.assertAllRaise |
| TestCase.test_format_specifier_expressions | self.assertAllRaise |
| TestCase.test_custom_format_specifier | uses-self.assertWarns |
| TestCase.test_side_effect_order | uses-self.i |
| TestCase.test_missing_expression | self.assertAllRaise |
| TestCase.test_parens_in_expressions | self.assertAllRaise |
| TestCase.test_newlines_before_syntax_error | self.assertAllRaise |
| TestCase.test_backslashes_in_string_part | uses-self.assertWarns |
| TestCase.test_misformed_unicode_character_name | self.assertAllRaise |
| TestCase.test_backslashes_in_expression_part | self.assertAllRaise |
| TestCase.test_invalid_backslashes_inside_fstring_context | self.assertAllRaise |
| TestCase.test_lambda | self.assertAllRaise |
| TestCase.test_fstring_backslash_before_double_bracket | uses-self.subTest |
| TestCase.test_fstring_backslash_before_double_bracket_warns_once | uses-self.assertWarns |
| TestCase.test_missing_variable | unresolved-name:value |
| TestCase.test_invalid_string_prefixes | self.assertAllRaise |
| TestCase.test_conversions | self.assertAllRaise |
| TestCase.test_assignment | self.assertAllRaise |
| TestCase.test_del | self.assertAllRaise |
| TestCase.test_mismatched_braces | self.assertAllRaise |
| TestCase.test_errors | self.assertAllRaise |
| TestCase.test_not_closing_quotes | self.assertAllRaise |
| TestCase.test_syntax_error_after_debug | self.assertAllRaise |
| TestCase.test_newlines_in_format_specifiers | self.assertAllRaise |

## Expected vs got

### TestCase.test_ast_compile_time_concat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'>

### TestCase.test_debug_in_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.os_helper'">

### TestCase.test_docstring (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsNone\', \'Not a docstring\')"'>

### TestCase.test_filename_in_syntaxerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.os_helper'">

### TestCase.test_fstring_without_formatting_bytecode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestCase.test_gh139516 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.os_helper'">

### TestCase.test_global (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestCase.test_many_expressions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'>

### TestCase.test_syntax_warning_infinite_recursion_in_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.os_helper'">
