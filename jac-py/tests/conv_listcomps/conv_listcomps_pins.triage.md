# Triage report: `conv_listcomps_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_listcomps.py
- guest leg: 0/62 marks
- pins: **8 passed** / 62 run (+6 quarantined of 68 extracted)

| pin | result | got |
|---|---|---|
| ListComprehensionTest.test_lambdas_with_iteration_var_as_default | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_lambdas_with_free_var | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_class_scope_free_var_with_class_cell | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC RuntimeError 'super(): no arguments'"> |
| ListComprehensionTest.test_references_super | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'res\'"'> |
| ListComprehensionTest.test_references___class__ | PASS | |
| ListComprehensionTest.test_references___class___nested | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| ListComprehensionTest.test_references___class___nested_used | PASS | |
| ListComprehensionTest.test_references___class___defined | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'res\'"'> |
| ListComprehensionTest.test_references___class___defined_nested | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'res\'"'> |
| ListComprehensionTest.test_references___classdict__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| ListComprehensionTest.test_references___conditional_annotations__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| ListComprehensionTest.test_references___conditional_annotations___nested | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| ListComprehensionTest.test_references___class___enclosing | PASS | |
| ListComprehensionTest.test_super_and_class_cell_in_sibling_comps | PASS | |
| ListComprehensionTest.test_inner_cell_shadows_outer | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_inner_cell_shadows_outer_no_store | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_closure_can_jump_over_comp_scope | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'z\'"'> |
| ListComprehensionTest.test_cell_inner_free_outer | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_free_inner_cell_outer | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_inner_cell_shadows_outer_redefined | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_shadows_outer_cell | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_explicit_global | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not callable'"> |
| ListComprehensionTest.test_explicit_global_2 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not callable'"> |
| ListComprehensionTest.test_explicit_global_3 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not callable'"> |
| ListComprehensionTest.test_assignment_expression | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_free_var_in_comp_child | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_shadow_with_free_and_local | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_shadow_comp_iterable_name | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_nested_free | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_introspecting_frame_locals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'i\'"'> |
| ListComprehensionTest.test_nested | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_nested_2 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_nested_3 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_nested_4 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'out\'"'> |
| ListComprehensionTest.test_nameerror | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| ListComprehensionTest.test_dunder_name | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_unbound_local_after_comprehension | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| ListComprehensionTest.test_unbound_local_inside_comprehension | PASS | |
| ListComprehensionTest.test_global_outside_cellvar_inside_plus_freevar | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_cell_in_nested_comprehension | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_name_error_in_class_scope | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| ListComprehensionTest.test_global_in_class_scope | PASS | |
| ListComprehensionTest.test_in_class_scope_inside_function_1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'vals\'"'> |
| ListComprehensionTest.test_in_class_scope_inside_function_2 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'vals\'"'> |
| ListComprehensionTest.test_in_class_scope_with_global | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'vals\'"'> |
| ListComprehensionTest.test_in_class_scope_with_nonlocal | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'vals\'"'> |
| ListComprehensionTest.test_nested_has_free_var | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not callable'"> |
| ListComprehensionTest.test_nested_free_var_not_bound_in_outer_comp | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not callable'"> |
| ListComprehensionTest.test_nested_free_var_in_iter | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not callable'"> |
| ListComprehensionTest.test_nested_free_var_in_expr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not callable'"> |
| ListComprehensionTest.test_nested_listcomp_in_lambda | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'z\'"'> |
| ListComprehensionTest.test_lambda_in_iter | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'c\'"'> |
| ListComprehensionTest.test_assign_to_comp_iter_var_in_outer_function | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'a\'"'> |
| ListComprehensionTest.test_no_leakage_to_locals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [\'fn\', \'args\', \'kwargs\'], [])"'> |
| ListComprehensionTest.test_iter_var_available_in_locals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'x\'"'> |
| ListComprehensionTest.test_comp_in_try_except | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'value\'"'> |
| ListComprehensionTest.test_comp_in_try_finally | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'value\'"'> |
| ListComprehensionTest.test_exception_in_post_comp_call | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'value\'"'> |
| ListComprehensionTest.test_frame_locals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'val\'"'> |
| ListComprehensionTest.test_multiple_comprehension_name_reuse | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC KeyError "\'y\'"'> |
| ListComprehensionTest.test_only_calls_dunder_iter_once | PASS | |
| listcomps.doctests:doctests | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| ListComprehensionTest.test_references___classdict___nested | unresolved-name:**classdict** |
| listcomps.doctests:doctests.ex11 | doctest-options:[32] |
| listcomps.doctests:doctests.ex12 | doctest-options:[32] |
| ListComprehensionTest.test_code_replace | host-raised:AttributeError: '_SelfNS' object has no attribute '_replacing_exec' |
| ListComprehensionTest.test_code_replace_extended_arg | host-raised:AttributeError: '_SelfNS' object has no attribute '_replacing_exec' |
| ListComprehensionTest.test_exception_locations | host-raised:AssertionError: ('assertEqual', ' in BrokenIter(init_raises=T', 'BrokenIter(init_raises=True)') |

## Expected vs got

### ListComprehensionTest.test_assign_to_comp_iter_var_in_outer_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'a\'"'>

### ListComprehensionTest.test_assignment_expression (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_cell_in_nested_comprehension (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_cell_inner_free_outer (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_class_scope_free_var_with_class_cell (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC RuntimeError 'super(): no arguments'">

### ListComprehensionTest.test_closure_can_jump_over_comp_scope (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'z\'"'>

### ListComprehensionTest.test_comp_in_try_except (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'value\'"'>

### ListComprehensionTest.test_comp_in_try_finally (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'value\'"'>

### ListComprehensionTest.test_dunder_name (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_exception_in_post_comp_call (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'value\'"'>

### ListComprehensionTest.test_explicit_global (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not callable'">

### ListComprehensionTest.test_explicit_global_2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not callable'">

### ListComprehensionTest.test_explicit_global_3 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not callable'">

### ListComprehensionTest.test_frame_locals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'val\'"'>

### ListComprehensionTest.test_free_inner_cell_outer (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_free_var_in_comp_child (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_global_outside_cellvar_inside_plus_freevar (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_in_class_scope_inside_function_1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'vals\'"'>

### ListComprehensionTest.test_in_class_scope_inside_function_2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'vals\'"'>

### ListComprehensionTest.test_in_class_scope_with_global (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'vals\'"'>

### ListComprehensionTest.test_in_class_scope_with_nonlocal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'vals\'"'>

### ListComprehensionTest.test_inner_cell_shadows_outer (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_inner_cell_shadows_outer_no_store (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_inner_cell_shadows_outer_redefined (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_introspecting_frame_locals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'i\'"'>

### ListComprehensionTest.test_iter_var_available_in_locals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_lambda_in_iter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'c\'"'>

### ListComprehensionTest.test_lambdas_with_free_var (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_lambdas_with_iteration_var_as_default (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_multiple_comprehension_name_reuse (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_name_error_in_class_scope (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### ListComprehensionTest.test_nameerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### ListComprehensionTest.test_nested (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_nested_2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_nested_3 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'y\'"'>

### ListComprehensionTest.test_nested_4 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'out\'"'>

### ListComprehensionTest.test_nested_free (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_nested_free_var_in_expr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not callable'">

### ListComprehensionTest.test_nested_free_var_in_iter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not callable'">

### ListComprehensionTest.test_nested_free_var_not_bound_in_outer_comp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not callable'">

### ListComprehensionTest.test_nested_has_free_var (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not callable'">

### ListComprehensionTest.test_nested_listcomp_in_lambda (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'z\'"'>

### ListComprehensionTest.test_no_leakage_to_locals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [\'fn\', \'args\', \'kwargs\'], [])"'>

### ListComprehensionTest.test_references___class___defined (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'res\'"'>

### ListComprehensionTest.test_references___class___defined_nested (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'res\'"'>

### ListComprehensionTest.test_references___class___nested (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### ListComprehensionTest.test_references___classdict__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### ListComprehensionTest.test_references___conditional_annotations__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### ListComprehensionTest.test_references___conditional_annotations___nested (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### ListComprehensionTest.test_references_super (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'res\'"'>

### ListComprehensionTest.test_shadow_comp_iterable_name (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_shadow_with_free_and_local (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_shadows_outer_cell (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC KeyError "\'x\'"'>

### ListComprehensionTest.test_unbound_local_after_comprehension (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">
