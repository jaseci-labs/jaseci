# Triage report: `conv_syntax_pins.jac`

- source: reference/cpython/Lib/test/test_syntax.py
- guest leg: 0/35 marks
- pins: **34 passed** / 35 run (+9 quarantined of 44 extracted)

| pin | result | got |
|---|---|---|
| SyntaxErrorTestCase.test_expression_with_assignment | PASS | |
| SyntaxErrorTestCase.test_curly_brace_after_primary_raises_immediately | PASS | |
| SyntaxErrorTestCase.test_assign_call | PASS | |
| SyntaxErrorTestCase.test_assign_del | PASS | |
| SyntaxErrorTestCase.test_global_param_err_first | PASS | |
| SyntaxErrorTestCase.test_nonlocal_param_err_first | PASS | |
| SyntaxErrorTestCase.test_yield_outside_function | PASS | |
| SyntaxErrorTestCase.test_return_outside_function | PASS | |
| SyntaxErrorTestCase.test_break_outside_loop | PASS | |
| SyntaxErrorTestCase.test_continue_outside_loop | PASS | |
| SyntaxErrorTestCase.test_unexpected_indent | PASS | |
| SyntaxErrorTestCase.test_no_indent | PASS | |
| SyntaxErrorTestCase.test_bad_outdent | PASS | |
| SyntaxErrorTestCase.test_kwargs_last | PASS | |
| SyntaxErrorTestCase.test_kwargs_last2 | PASS | |
| SyntaxErrorTestCase.test_kwargs_last3 | PASS | |
| SyntaxErrorTestCase.test_generator_in_function_call | PASS | |
| SyntaxErrorTestCase.test_except_then_except_star | PASS | |
| SyntaxErrorTestCase.test_except_star_then_except | PASS | |
| SyntaxErrorTestCase.test_empty_line_after_linecont | PASS | |
| SyntaxErrorTestCase.test_continuation_bad_indentation | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "object can\'t be sent"'> |
| SyntaxErrorTestCase.test_barry_as_flufl_with_syntax_errors | PASS | |
| SyntaxErrorTestCase.test_invalid_line_continuation_error_position | PASS | |
| SyntaxErrorTestCase.test_invalid_line_continuation_left_recursive | PASS | |
| SyntaxErrorTestCase.test_error_parenthesis | PASS | |
| SyntaxErrorTestCase.test_error_string_literal | PASS | |
| SyntaxErrorTestCase.test_invisible_characters | PASS | |
| SyntaxErrorTestCase.test_match_call_does_not_raise_syntax_error | PASS | |
| SyntaxErrorTestCase.test_case_call_does_not_raise_syntax_error | PASS | |
| SyntaxErrorTestCase.test_multiline_compiler_error_points_to_the_end | PASS | |
| SyntaxErrorTestCase.test_except_stmt_invalid_as_expr | PASS | |
| SyntaxErrorTestCase.test_match_stmt_invalid_as_expr | PASS | |
| SyntaxErrorTestCase.test_ifexp_else_stmt | PASS | |
| SyntaxErrorTestCase.test_ifexp_body_stmt_else_expression | PASS | |
| SyntaxErrorTestCase.test_ifexp_body_stmt_else_stmt | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| SyntaxErrorTestCase.test_disallowed_type_param_names | decorator:support.cpython_only |
| SyntaxErrorTestCase.test_nested_named_except_blocks | decorator:support.cpython_only |
| SyntaxErrorTestCase.test_with_statement_many_context_managers | decorator:support.cpython_only |
| SyntaxErrorTestCase.test_async_with_statement_many_context_managers | decorator:support.cpython_only |
| SyntaxErrorTestCase.test_syntax_error_on_deeply_nested_blocks | decorator:support.cpython_only |
| SyntaxErrorTestCase.test_error_on_parser_stack_overflow | decorator:support.cpython_only |
| SyntaxErrorTestCase.test_deep_invalid_rule | decorator:support.cpython_only |
| SyntaxWarningTest.test_return_in_finally | helper:check_warning(uses-self.assertWarnsRegex) |
| SyntaxWarningTest.test_break_and_continue_in_finally | helper:check_warning(uses-self.assertWarnsRegex) |

## Expected vs got

### SyntaxErrorTestCase.test_continuation_bad_indentation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "object can\'t be sent"'>
