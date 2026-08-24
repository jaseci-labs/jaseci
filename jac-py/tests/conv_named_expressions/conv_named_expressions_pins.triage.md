# Triage report: `conv_named_expressions_pins.jac`

- source: reference/cpython/Lib/test/test_named_expressions.py
- guest leg: 0/60 marks
- pins: **59 passed** / 60 run (+14 quarantined of 74 extracted)

| pin | result | got |
|---|---|---|
| NamedExpressionInvalidTest.test_named_expression_invalid_01 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_02 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_03 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_04 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_06 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_07 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_08 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_09 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_10 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_11 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_12 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_13 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_14 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_15 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_16 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_17 | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_in_class_body | PASS | |
| NamedExpressionInvalidTest.test_named_expression_invalid_mangled_class_variables | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_01 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_02 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_03 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_04 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_05 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_06 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_07 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_08 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_09 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_10 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_11 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_12 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_13 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_14 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_15 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_16 | PASS | |
| NamedExpressionAssignmentTest.test_named_expression_assignment_17 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_01 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_02 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_03 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_04 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_05 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_06 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_07 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_08 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_09 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_10 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_11 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_17 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_18 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_19 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_20 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_21 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_22 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_23 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_24 | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_25 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'a\'"'> |
| NamedExpressionScopeTest.test_named_expression_global_scope | PASS | |
| NamedExpressionScopeTest.test_named_expression_global_scope_no_global_keyword | PASS | |
| NamedExpressionScopeTest.test_named_expression_nonlocal_scope | PASS | |
| NamedExpressionScopeTest.test_named_expression_nonlocal_scope_no_nonlocal_keyword | PASS | |
| NamedExpressionScopeTest.test_named_expression_scope_in_genexp | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| NamedExpressionInvalidTest.test_named_expression_valid_rebinding_iteration_variable | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_rebinding_iteration_variable | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_rebinding_list_comprehension_iteration_variable | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_rebinding_list_comprehension_inner_loop | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_list_comprehension_iterable_expression | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_rebinding_set_comprehension_iteration_variable | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_rebinding_set_comprehension_inner_loop | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_set_comprehension_iterable_expression | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_rebinding_dict_comprehension_iteration_variable | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_rebinding_dict_comprehension_inner_loop | uses-self.subTest |
| NamedExpressionInvalidTest.test_named_expression_invalid_dict_comprehension_iterable_expression | uses-self.subTest |
| NamedExpressionAssignmentTest.test_named_expression_assignment_18 | uses-self.two_dimensional_list |
| NamedExpressionScopeTest.test_named_expression_variable_reuse_in_comprehensions | uses-self.subTest |
| NamedExpressionScopeTest.test_named_expression_scope_mangled_names | uses-self.assertEqual |

## Expected vs got

### NamedExpressionScopeTest.test_named_expression_scope_25 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'a\'"'>
