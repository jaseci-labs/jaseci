# Triage report: `conv_call_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_call.py
- guest leg: 0/46 marks
- pins: **38 passed** / 46 run (+50 quarantined of 96 extracted)

| pin | result | got |
|---|---|---|
| FunctionCalls.test_kwargs_order | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'argument after ** must be a mapping, not host'"> |
| FunctionCalls.test_frames_are_popped_after_failed_calls | PASS | |
| CFunctionCallsErrorMessages.test_varargs0 | PASS | |
| CFunctionCallsErrorMessages.test_varargs2 | PASS | |
| CFunctionCallsErrorMessages.test_varargs3 | PASS | |
| CFunctionCallsErrorMessages.test_varargs1min | PASS | |
| CFunctionCallsErrorMessages.test_varargs2min | PASS | |
| CFunctionCallsErrorMessages.test_varargs1max | PASS | |
| CFunctionCallsErrorMessages.test_varargs2max | PASS | |
| CFunctionCallsErrorMessages.test_varargs1_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs2_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs3_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs4_kw | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC ValueError 'not in list'"> |
| CFunctionCallsErrorMessages.test_varargs5_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs6_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs7_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs8_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs9_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs10_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs11_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs12_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs13_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs14_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs15_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs16_kw | PASS | |
| CFunctionCallsErrorMessages.test_varargs17_kw | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'int\' object has no attribute \'join\'"'> |
| CFunctionCallsErrorMessages.test_varargs18_kw | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| CFunctionCallsErrorMessages.test_varargs19_kw | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| CFunctionCallsErrorMessages.test_oldargs0_1 | PASS | |
| CFunctionCallsErrorMessages.test_oldargs0_2 | PASS | |
| CFunctionCallsErrorMessages.test_oldargs0_1_kw | PASS | |
| CFunctionCallsErrorMessages.test_oldargs0_2_kw | PASS | |
| CFunctionCallsErrorMessages.test_oldargs1_0 | PASS | |
| CFunctionCallsErrorMessages.test_oldargs1_2 | PASS | |
| CFunctionCallsErrorMessages.test_oldargs1_0_kw | PASS | |
| CFunctionCallsErrorMessages.test_oldargs1_1_kw | PASS | |
| CFunctionCallsErrorMessages.test_oldargs1_2_kw | PASS | |
| CFunctionCallsErrorMessages.test_object_not_callable | PASS | |
| CFunctionCallsErrorMessages.test_module_not_callable_no_suggestion_0 | PASS | |
| CFunctionCallsErrorMessages.test_module_not_callable_no_suggestion_1 | PASS | |
| CFunctionCallsErrorMessages.test_module_not_callable_no_suggestion_2 | PASS | |
| CFunctionCallsErrorMessages.test_module_not_callable_no_suggestion_3 | PASS | |
| CFunctionCallsErrorMessages.test_module_not_callable_suggestion | PASS | |
| FastCallTests.test_fastcall_clearing_dict | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'IntWithDict\' object cannot be interpreted as an integer"'> |
| TestRecursion.test_recursion_with_kwargs | VM-CRASH | y/jacpython/ceval.jac:16052   at exec_code_frame() /var/tmp/lane8/jac-py/jacpython/ceval.jac:14273   at tp_call() /var/tmp/lane8/jac-py/jacpython/ceval.jac:4067   at py_invoke() /var/tmp/lane8/jac-py/jacpython/ceval.jac:8801   at run_frame() /var/tmp/lane8/jac-py/jacpython/ceval.jac:16052   at exec_ |
| TestFunctionWithManyArgs.test_function_with_many_args | VM-CRASH | y/jacpython/ceval.jac:16052   at exec_code_frame() /var/tmp/lane8/jac-py/jacpython/ceval.jac:14273   at tp_call() /var/tmp/lane8/jac-py/jacpython/ceval.jac:4067   at py_invoke() /var/tmp/lane8/jac-py/jacpython/ceval.jac:8801   at run_frame() /var/tmp/lane8/jac-py/jacpython/ceval.jac:16052   at exec_ |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCallingConventions.test_varargs | decorator:unittest.skipIf |
| TestCallingConventions.test_varargs_ext | decorator:unittest.skipIf |
| TestCallingConventions.test_varargs_error_kw | decorator:unittest.skipIf |
| TestCallingConventions.test_varargs_keywords | decorator:unittest.skipIf |
| TestCallingConventions.test_varargs_keywords_ext | decorator:unittest.skipIf |
| TestCallingConventions.test_o | decorator:unittest.skipIf |
| TestCallingConventions.test_o_ext | decorator:unittest.skipIf |
| TestCallingConventions.test_o_error_no_arg | decorator:unittest.skipIf |
| TestCallingConventions.test_o_error_two_args | decorator:unittest.skipIf |
| TestCallingConventions.test_o_error_ext | decorator:unittest.skipIf |
| TestCallingConventions.test_o_error_kw | decorator:unittest.skipIf |
| TestCallingConventions.test_o_error_arg_kw | decorator:unittest.skipIf |
| TestCallingConventions.test_noargs | decorator:unittest.skipIf |
| TestCallingConventions.test_noargs_ext | decorator:unittest.skipIf |
| TestCallingConventions.test_noargs_error_arg | decorator:unittest.skipIf |
| TestCallingConventions.test_noargs_error_arg2 | decorator:unittest.skipIf |
| TestCallingConventions.test_noargs_error_ext | decorator:unittest.skipIf |
| TestCallingConventions.test_noargs_error_kw | decorator:unittest.skipIf |
| TestCallingConventions.test_fastcall | decorator:unittest.skipIf |
| TestCallingConventions.test_fastcall_ext | decorator:unittest.skipIf |
| TestCallingConventions.test_fastcall_error_kw | decorator:unittest.skipIf |
| TestCallingConventions.test_fastcall_keywords | decorator:unittest.skipIf |
| TestCallingConventions.test_fastcall_keywords_ext | decorator:unittest.skipIf |
| FastCallTests.test_vectorcall_dict | decorator:unittest.skipIf |
| FastCallTests.test_vectorcall | decorator:unittest.skipIf |
| TestPEP590.test_method_descriptor_flag | decorator:unittest.skipIf |
| TestPEP590.test_vectorcall_flag | decorator:unittest.skipIf |
| TestPEP590.test_vectorcall_override | decorator:unittest.skipIf |
| TestPEP590.test_vectorcall_override_on_mutable_class | decorator:unittest.skipIf |
| TestPEP590.test_vectorcall_override_with_subclass | decorator:unittest.skipIf |
| TestPEP590.test_vectorcall | decorator:unittest.skipIf |
| TestPEP590.test_setvectorcall | decorator:unittest.skipIf |
| TestPEP590.test_setvectorcall_load_attr_specialization_skip | decorator:unittest.skipIf |
| TestPEP590.test_setvectorcall_load_attr_specialization_deopt | decorator:unittest.skipIf |
| TestPEP590.test_vectorcall_limited_incoming | decorator:unittest.skipIf |
| TestPEP590.test_vectorcall_limited_outgoing | decorator:unittest.skipIf |
| TestPEP590.test_vectorcall_limited_outgoing_method | decorator:unittest.skipIf |
| TestRecursion.test_super_deep | decorator:unittest.skipIf |
| TestCAPI.test_cfunction_call | decorator:unittest.skipIf |
| TestErrorMessagesUseQualifiedName.test_missing_arguments | helper:check_raises_type_error(decorated-helper) |
| TestErrorMessagesUseQualifiedName.test_too_many_positional | helper:check_raises_type_error(decorated-helper) |
| TestErrorMessagesUseQualifiedName.test_positional_only_passed_as_keyword | helper:check_raises_type_error(decorated-helper) |
| TestErrorMessagesUseQualifiedName.test_unexpected_keyword | helper:check_raises_type_error(decorated-helper) |
| TestErrorMessagesUseQualifiedName.test_multiple_values | helper:check_raises_type_error(decorated-helper) |
| TestErrorMessagesSuggestions.test_unexpected_keyword_suggestion_valid_positions | helper:check_suggestion_includes(decorated-helper) |
| TestErrorMessagesSuggestions.test_unexpected_keyword_suggestion_kinds | helper:check_suggestion_includes(decorated-helper) |
| TestErrorMessagesSuggestions.test_unexpected_keyword_suggestion_via_getargs | helper:check_suggestion_includes(decorated-helper) |
| TestRecursion.test_margin_is_sufficient | unresolved-name:_testcapi |
| testfunction | host-raised:NameError: name 'self' is not defined |
| testfunction_kw | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### CFunctionCallsErrorMessages.test_varargs17_kw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'int\' object has no attribute \'join\'"'>

### CFunctionCallsErrorMessages.test_varargs18_kw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### CFunctionCallsErrorMessages.test_varargs19_kw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### CFunctionCallsErrorMessages.test_varargs4_kw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC ValueError 'not in list'">

### FastCallTests.test_fastcall_clearing_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'IntWithDict\' object cannot be interpreted as an integer"'>

### FunctionCalls.test_kwargs_order (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'argument after ** must be a mapping, not host'">

### TestFunctionWithManyArgs.test_function_with_many_args (VM-CRASH)

- expected: host oracle = `ok`
- got: y/jacpython/ceval.jac:16052
  at exec_code_frame() /var/tmp/lane8/jac-py/jacpython/ceval.jac:14273
  at tp_call() /var/tmp/lane8/jac-py/jacpython/ceval.jac:4067
  at py_invoke() /var/tmp/lane8/jac-py/jacpython/ceval.jac:8801
  at run_frame() /var/tmp/lane8/jac-py/jacpython/ceval.jac:16052
  at exec_

### TestRecursion.test_recursion_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: y/jacpython/ceval.jac:16052
  at exec_code_frame() /var/tmp/lane8/jac-py/jacpython/ceval.jac:14273
  at tp_call() /var/tmp/lane8/jac-py/jacpython/ceval.jac:4067
  at py_invoke() /var/tmp/lane8/jac-py/jacpython/ceval.jac:8801
  at run_frame() /var/tmp/lane8/jac-py/jacpython/ceval.jac:16052
  at exec_
