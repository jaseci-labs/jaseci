# Triage report: `conv_compile_pins.jac`

- source: reference/cpython/Lib/test/test_compile.py
- guest leg: 0/111 marks
- pins: **42 passed** / 111 run (+73 quarantined of 184 extracted)

| pin | result | got |
|---|---|---|
| TestSpecifics.test_no_ending_newline | PASS | |
| TestSpecifics.test_empty | PASS | |
| TestSpecifics.test_other_newlines | PASS | |
| TestSpecifics.test_debug_assignment | PASS | |
| TestSpecifics.test_argument_handling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "object can\'t be sent"'> |
| TestSpecifics.test_syntax_error | PASS | |
| TestSpecifics.test_none_keyword_arg | PASS | |
| TestSpecifics.test_duplicate_global_local | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "object can\'t be sent"'> |
| TestSpecifics.test_argument_order | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "object can\'t be sent"'> |
| TestSpecifics.test_float_literals | PASS | |
| TestSpecifics.test_indentation | PASS | |
| TestSpecifics.test_leading_newlines | PASS | |
| TestSpecifics.test_literals_with_leading_zeroes | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 777j, 777j)"'> |
| TestSpecifics.test_unary_minus | PASS | |
| TestSpecifics.test_sequence_unpacking_error | PASS | |
| TestSpecifics.test_none_assignment | PASS | |
| TestSpecifics.test_import | PASS | |
| TestSpecifics.test_for_distinct_code_objects | PASS | |
| TestSpecifics.test_lambda_doc | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsNone\', \'foo\')"'> |
| TestSpecifics.test_lambda_consts | PASS | |
| TestSpecifics.test_encoding | PASS | |
| TestSpecifics.test_annotation_limit | PASS | |
| TestSpecifics.test_mangling | PASS | |
| TestSpecifics.test_condition_expression_with_dead_blocks_compiles | PASS | |
| TestSpecifics.test_dead_code_with_except_handler_compiles | PASS | |
| TestSpecifics.test_try_except_in_while_with_chained_condition_compiles | PASS | |
| TestSpecifics.test_compile_invalid_namedexpr | PASS | |
| TestSpecifics.test_compile_redundant_jumps_and_nops_after_moving_cold_blocks | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| TestSpecifics.test_compile_redundant_jump_after_convert_pseudo_ops | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| TestSpecifics.test_compile_invalid_typealias | PASS | |
| TestSpecifics.test_dict_evaluation_order | PASS | |
| TestSpecifics.test_compile_filename | PASS | |
| TestSpecifics.test_compile_filename_refleak | PASS | |
| TestSpecifics.test_single_statement | PASS | |
| TestSpecifics.test_particularly_evil_undecodable | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestSpecifics.test_yet_more_evil_still_undecodable | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestSpecifics.test_null_terminated | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'exec() argument 1 must be a code object'"> |
| TestSpecifics.test_dont_merge_constants | PASS | |
| TestSpecifics.test_path_like_objects | PASS | |
| TestSpecifics.test_false_while_loop | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSpecifics.test_folding_type_param | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSpecifics.test_big_dict_literal | PASS | |
| TestSpecifics.test_redundant_jump_in_if_else_break | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSpecifics.test_no_wraparound_jump | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSpecifics.test_multi_line_lambda_as_argument | PASS | |
| TestSpecifics.test_apply_static_swaps | PASS | |
| TestSpecifics.test_apply_static_swaps_2 | PASS | |
| TestSpecifics.test_apply_static_swaps_3 | PASS | |
| TestSpecifics.test_variable_dependent | PASS | |
| TestSpecifics.test_remove_empty_basic_block_with_jump_target_label | PASS | |
| TestSpecifics.test_global_declaration_in_except_used_in_else | PASS | |
| TestSpecifics.test_globals_dict_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "exec() argument 2 must be a dict, not \'WeirdDict\'"'> |
| TestSpecifics.test_compile_warnings | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [3, 5, 3, 5])"'> |
| TestSpecifics.test_compile_warning_in_finally | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [5, 9])"'> |
| TestBooleanExpression.test_exception | PASS | |
| TestSourcePositions.test_simple_assignment | PASS | |
| TestSourcePositions.test_compiles_to_extended_op_arg | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_expression | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_boolean_expression | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_generator_expression | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_async_generator_expression | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_list_comprehension | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_async_list_comprehension | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_set_comprehension | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_async_set_comprehension | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_dict_comprehension | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_async_dict_comprehension | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_matchcase_sequence | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_matchcase_sequence_wildcard | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_matchcase_mapping | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_matchcase_mapping_wildcard | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_matchcase_class | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_matchcase_or | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_very_long_line_end_offset | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_complex_single_line_expression | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_multiline_assert_rewritten_as_method_call | PASS | |
| TestSourcePositions.test_attribute_augassign | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_attribute_del | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_attribute_load | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_attribute_store | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_method_call | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestSourcePositions.test_load_super_attr | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestExpressionStackSize.test_stack_3050 | PASS | |
| TestExpressionStackSize.test_stack_3050_2 | PASS | |
| TestStackSizeStability.test_if | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_if_else | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_try_except_bare | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_try_except_qualified | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_try_except_as | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_try_except_star_qualified | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_try_except_star_as | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_try_except_star_finally | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_try_finally | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_with | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_while_else | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_for | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_for_else | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_for_break_continue | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_for_break_continue_inside_try_finally_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_for_break_continue_inside_finally_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_for_break_continue_inside_except_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_for_break_continue_inside_with_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_return_inside_try_finally_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_return_inside_finally_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_return_inside_except_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_return_inside_with_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_async_with | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_async_for | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_async_for_else | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_for_break_continue_inside_async_with_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| TestStackSizeStability.test_return_inside_async_with_block | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestSpecifics.test_extended_arg | decorator:unittest.skipIf |
| TestSpecifics.test_same_filename_used | decorator:support.cpython_only |
| TestSpecifics.test_compiler_recursion_limit | decorator:support.cpython_only |
| TestSpecifics.test_merge_constants | decorator:support.cpython_only |
| TestSpecifics.test_merge_code_attrs | decorator:support.cpython_only |
| TestSpecifics.test_remove_unused_consts | decorator:support.cpython_only |
| TestSpecifics.test_remove_unused_consts_no_docstring | decorator:support.cpython_only |
| TestSpecifics.test_remove_unused_consts_extended_args | decorator:support.cpython_only |
| TestSpecifics.test_strip_unused_None | decorator:support.cpython_only |
| TestSpecifics.test_peephole_opt_unreachable_code_array_access_in_bounds | decorator:support.cpython_only |
| TestSpecifics.test_docstring | decorator:support.cpython_only |
| TestSpecifics.test_docstring_interactive_mode | decorator:support.cpython_only |
| TestSpecifics.test_docstring_omitted | decorator:support.cpython_only |
| TestSpecifics.test_stack_overflow | decorator:support.requires_resource |
| TestSpecifics.test_dead_blocks_do_not_generate_bytecode | decorator:support.cpython_only |
| TestSpecifics.test_uses_slice_instructions | decorator:support.cpython_only |
| TestSpecifics.test_pep_765_warnings | decorator:support.subTests |
| TestSpecifics.test_pep_765_no_warnings | decorator:support.subTests |
| TestSourcePositions.test_multiline_assert | decorator:unittest.skipIf |
| TestSourcePositions.test_column_offset_deduplication | decorator:support.cpython_only |
| TestInstructionSequence.test_basics | decorator:unittest.skipIf |
| TestInstructionSequence.test_nested | decorator:unittest.skipIf |
| TestInstructionSequence.test_static_attributes_are_sorted | decorator:unittest.skipIf |
| TestSpecifics.test_exec_with_general_mapping_for_locals | uses-self.results |
| TestSpecifics.test_int_literals_too_long | unresolved-name:err_ctx |
| TestSpecifics.test_subscripts | uses-self.data |
| TestSpecifics.test_condition_expression_with_redundant_comparisons_compiles | uses-self.subTest |
| TestSpecifics.test_compile_ast | unresolved-name:**file** |
| TestSpecifics.test_bad_single_statement | helper:assertInvalidSingle(uses-self.compile_single) |
| TestSpecifics.test_consts_in_conditionals | uses-self.subTest |
| TestSpecifics.test_imported_load_method | uses-self.subTest |
| TestSpecifics.test_lineno_after_implicit_return | uses-self.subTest |
| TestSpecifics.test_lineno_after_no_code | uses-self.subTest |
| TestSpecifics.test_lineno_attribute | uses-self.subTest |
| TestSpecifics.test_line_number_genexp | unresolved-name:y |
| TestSpecifics.test_line_number_implicit_return_after_async_for | unresolved-name:body |
| TestSpecifics.test_line_number_synthetic_jump_multiple_predecessors | unresolved-name:C1 |
| TestSpecifics.test_line_number_synthetic_jump_multiple_predecessors_nested | unresolved-name:C3 |
| TestSpecifics.test_line_number_synthetic_jump_multiple_predecessors_more_nested | unresolved-name:C3 |
| TestSpecifics.test_lineno_of_backward_jump_conditional_in_loop | unresolved-name:x |
| TestSpecifics.test_compare_positions | uses-self.subTest |
| TestSpecifics.test_if_expression_expression_empty_block | uses-self.subTest |
| TestSpecifics.test_duplicated_small_exit_block | unresolved-name:element |
| TestSpecifics.test_cold_block_moved_to_end | unresolved-name:name |
| TestSpecifics.test_remove_redundant_nop_edge_case | unresolved-name:a |
| TestSpecifics.test_regression_gh_120225 | unresolved-name:name_3 |
| TestBooleanExpression.test_short_circuit_and | uses-self.Yes |
| TestBooleanExpression.test_short_circuit_or | uses-self.No |
| TestBooleanExpression.test_compound | uses-self.No |
| TestSourcePositions.test_push_null_load_global_positions | uses-self.subTest |
| TestSourcePositions.test_weird_attribute_position_regressions | unresolved-name:bar |
| TestSourcePositions.test_lambda_return_position | uses-self.subTest |
| TestSourcePositions.test_return_in_with_positions | unresolved-name:R |
| TestStaticAttributes.test_basic | uses-self.a |
| TestStaticAttributes.test_nested_function | uses-self.x |
| TestStaticAttributes.test_nested_class | uses-self.x |
| TestStaticAttributes.test_subclass | uses-self.x |
| TestExpressionStackSize.test_and | uses-self.N |
| TestExpressionStackSize.test_or | uses-self.N |
| TestExpressionStackSize.test_and_or | uses-self.N |
| TestExpressionStackSize.test_chained_comparison | uses-self.N |
| TestExpressionStackSize.test_if_else | uses-self.N |
| TestExpressionStackSize.test_binop | uses-self.N |
| TestExpressionStackSize.test_list | uses-self.N |
| TestExpressionStackSize.test_tuple | uses-self.N |
| TestExpressionStackSize.test_set | uses-self.N |
| TestExpressionStackSize.test_dict | uses-self.N |
| TestExpressionStackSize.test_func_args | uses-self.N |
| TestExpressionStackSize.test_func_kwargs | uses-self.N |
| TestExpressionStackSize.test_meth_args | uses-self.N |
| TestExpressionStackSize.test_meth_kwargs | uses-self.N |
| TestExpressionStackSize.test_func_and | uses-self.N |
| TestSpecifics.test_lineno_procedure_call | host-raised:AssertionError:  |

## Expected vs got

### TestSourcePositions.test_attribute_augassign (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_attribute_del (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_attribute_load (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_attribute_store (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_compiles_to_extended_op_arg (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_complex_single_line_expression (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_load_super_attr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_matchcase_class (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_matchcase_mapping (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_matchcase_mapping_wildcard (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_matchcase_or (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_matchcase_sequence (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_matchcase_sequence_wildcard (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_method_call (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_async_dict_comprehension (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_async_generator_expression (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_async_list_comprehension (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_async_set_comprehension (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_boolean_expression (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_dict_comprehension (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_expression (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_generator_expression (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_list_comprehension (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_multiline_set_comprehension (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSourcePositions.test_very_long_line_end_offset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSpecifics.test_argument_handling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "object can\'t be sent"'>

### TestSpecifics.test_argument_order (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "object can\'t be sent"'>

### TestSpecifics.test_compile_redundant_jump_after_convert_pseudo_ops (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### TestSpecifics.test_compile_redundant_jumps_and_nops_after_moving_cold_blocks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### TestSpecifics.test_compile_warning_in_finally (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [5, 9])"'>

### TestSpecifics.test_compile_warnings (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [3, 5, 3, 5])"'>

### TestSpecifics.test_duplicate_global_local (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "object can\'t be sent"'>

### TestSpecifics.test_false_while_loop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSpecifics.test_folding_type_param (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSpecifics.test_globals_dict_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "exec() argument 2 must be a dict, not \'WeirdDict\'"'>

### TestSpecifics.test_lambda_doc (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsNone\', \'foo\')"'>

### TestSpecifics.test_literals_with_leading_zeroes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 777j, 777j)"'>

### TestSpecifics.test_no_wraparound_jump (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSpecifics.test_null_terminated (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'exec() argument 1 must be a code object'">

### TestSpecifics.test_particularly_evil_undecodable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestSpecifics.test_redundant_jump_in_if_else_break (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestSpecifics.test_yet_more_evil_still_undecodable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestStackSizeStability.test_async_for (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_async_for_else (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_async_with (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_for (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_for_break_continue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_for_break_continue_inside_async_with_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_for_break_continue_inside_except_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_for_break_continue_inside_finally_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_for_break_continue_inside_try_finally_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_for_break_continue_inside_with_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_for_else (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_if (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_if_else (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_return_inside_async_with_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_return_inside_except_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_return_inside_finally_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_return_inside_try_finally_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_return_inside_with_block (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_try_except_as (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_try_except_bare (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_try_except_qualified (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_try_except_star_as (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_try_except_star_finally (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_try_except_star_qualified (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_try_finally (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_while_else (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### TestStackSizeStability.test_with (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>
