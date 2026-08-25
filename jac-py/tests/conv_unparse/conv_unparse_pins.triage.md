# Triage report: `conv_unparse_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_unparse.py
- guest leg: 0/30 marks
- pins: **0 passed** / 30 run (+49 quarantined of 79 extracted)

| pin | result | got |
|---|---|---|
| UnparseTestCase.test_tstring_with_nonsensical_str_field | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_tstring_with_none_str_field | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_invalid_raise | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_invalid_fstring_value | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_fstring_backslash | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_invalid_yield_from | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_import_from_level_none | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_constant_tuples | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_unparse_interactive_semicolons | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_unparse_interactive_integrity_1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_unparse_interactive_integrity_2 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| UnparseTestCase.test_unparse_interactive_integrity_3 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_simple_expressions_parens | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_class_bases_and_keywords | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_fstrings | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_docstrings | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_unary_op_factor | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_slices | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_lambda_parameters | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_star_expr_assign_target | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| CosmeticTestCase.test_star_expr_assign_target_multiple | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_class | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_class_with_type_params | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_function | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_function_with_type_params | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_function_with_type_params_and_bound | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_function_with_type_params_and_default | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_async_function | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_async_function_with_type_params | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |
| ManualASTCreationTestCase.test_async_function_with_type_params_and_default | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| UnparseTestCase.test_fstrings | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_fstrings_special_chars | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_fstrings_complicated | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_fstrings_pep701 | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_tstrings | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_strings | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_del_statement | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_shifts | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_for_else | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_while_else | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_unary_parens | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_integer_parens | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_huge_float | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_nan | self.assertASTEqual |
| UnparseTestCase.test_min_int | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_imaginary_literals | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_lambda_parentheses | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_chained_comparisons | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_function_arguments | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_relative_import | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_nonlocal | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_raise_from | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_bytes | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_annotations | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_set_literal | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_empty_set | self.assertASTEqual |
| UnparseTestCase.test_set_comprehension | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_dict_comprehension | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_class_decorators | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_class_definition | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_elifs | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_try_except_finally | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_try_except_star_finally | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_starred_assignment | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_with_simple | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_with_as | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_with_two_items | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_dict_unpacking_in_dict | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_slices | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_docstrings | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_function_type | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_type_comments | helper:check_ast_roundtrip(self.assertASTEqual) |
| UnparseTestCase.test_type_ignore | helper:check_ast_roundtrip(self.assertASTEqual) |
| CosmeticTestCase.test_docstrings_negative_cases | helper:check_ast_roundtrip(self.assertASTEqual) |
| CosmeticTestCase.test_multiquote_joined_string | helper:check_ast_roundtrip(self.assertASTEqual) |
| CosmeticTestCase.test_backslash_in_format_spec | helper:check_ast_roundtrip(self.assertASTEqual) |
| CosmeticTestCase.test_quote_in_format_spec | helper:check_ast_roundtrip(self.assertASTEqual) |
| CosmeticTestCase.test_type_params | helper:check_ast_roundtrip(self.assertASTEqual) |
| DirectoryTestCase.test_files | helper:files_to_test(decorated-helper) |

## Expected vs got

### CosmeticTestCase.test_class_bases_and_keywords (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### CosmeticTestCase.test_docstrings (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### CosmeticTestCase.test_fstrings (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### CosmeticTestCase.test_lambda_parameters (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### CosmeticTestCase.test_simple_expressions_parens (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### CosmeticTestCase.test_slices (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### CosmeticTestCase.test_star_expr_assign_target (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### CosmeticTestCase.test_star_expr_assign_target_multiple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### CosmeticTestCase.test_unary_op_factor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_async_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_async_function_with_type_params (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_async_function_with_type_params_and_default (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_class (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_class_with_type_params (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_function_with_type_params (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_function_with_type_params_and_bound (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### ManualASTCreationTestCase.test_function_with_type_params_and_default (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_constant_tuples (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_fstring_backslash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_import_from_level_none (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_invalid_fstring_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_invalid_raise (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_invalid_yield_from (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_tstring_with_none_str_field (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_tstring_with_nonsensical_str_field (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_unparse_interactive_integrity_1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_unparse_interactive_integrity_2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_unparse_interactive_integrity_3 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### UnparseTestCase.test_unparse_interactive_semicolons (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>
