# Triage report: `conv_builtin_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_builtin.py
- guest leg: 0/93 marks
- pins: **44 passed** / 93 run (+40 quarantined of 133 extracted)

| pin | result | got |
|---|---|---|
| BuiltinTest.test_abs | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bad operand type for abs(): \'AbsClass\'"'> |
| BuiltinTest.test_all | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'TestFailingIter\' object is not iterable"'> |
| BuiltinTest.test_any | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'TestFailingIter\' object is not iterable"'> |
| BuiltinTest.test_all_any_tuple_optimization | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 4, 1)"'> |
| BuiltinTest.test_builtin_call_async_genexpr_no_crash | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'async_yield' from '<unknown>'"> |
| BuiltinTest.test_ascii | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'"> |
| BuiltinTest.test_neg | PASS | |
| BuiltinTest.test_chr | PASS | |
| BuiltinTest.test_cmp | PASS | |
| BuiltinTest.test_compile | PASS | |
| BuiltinTest.test_compile_top_level_await_no_coro | GUEST-WRONG-OUTPUT | RUN<'TypeError: expected code object'> |
| BuiltinTest.test_compile_top_level_await | GUEST-WRONG-OUTPUT | RUN<'TypeError: expected code object'> |
| BuiltinTest.test_compile_top_level_await_invalid_cases | PASS | |
| BuiltinTest.test_compile_async_generator | PASS | |
| BuiltinTest.test_compile_ast | PASS | |
| BuiltinTest.test_delattr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError ''"> |
| BuiltinTest.test_dir | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertNotIn\', \'**repr**\', [\'**class**\', \'**delattr**\', \'**dict**\', \'**dir**\', \'**doc**\', \'**eq**\', \'**firstlineno**\', \'**format**\', \'**ge**\', \'**getattribute**\', \'**getstate**\', \'**gt**\', \'**hash**\', \'**init**\', \'**init_subclass**\', \'**le**\', \'**lt**\', \'**module**\', \'**ne**\', \'**new**\', \'**reduce**\', \'**reduce_ex**\', \'**repr**\', \'**setattr**\', \'**sizeof**\', \'**slots**\', \'**static_attributes**\', \'**str**\', \'**subclasshook**\', \'**weakref**\', \'bar\'])"'> |
| BuiltinTest.test___ne__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**ne**'"> |
| BuiltinTest.test_divmod | PASS | |
| BuiltinTest.test_eval | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'locals must be a mapping'"> |
| BuiltinTest.test_general_eval | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'locals must be a mapping'"> |
| BuiltinTest.test_exec | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.warnings_helper'"> |
| BuiltinTest.test_exec_kwargs | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'exec() takes no keyword arguments'"> |
| BuiltinTest.test_exec_globals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "object can\'t be sent"'> |
| BuiltinTest.test_exec_globals_error_on_get | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "object can\'t be sent"'> |
| BuiltinTest.test_exec_globals_dict_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'superglobal\' is not defined"'> |
| BuiltinTest.test_eval_builtins_mapping | PASS | |
| BuiltinTest.test_exec_builtins_mapping_import | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "object can\'t be sent"'> |
| BuiltinTest.test_eval_builtins_mapping_reduce | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (<built-in function iter>, (<function_jac_make_host_iterator.<locals>._next at 0x7f4ddc412cf0>, <object object at 0x7f4ddbae0670>)), (<built-in function iter>, ([1, 2],), 0))"'> |
| BuiltinTest.test_exec_redirected | PASS | |
| BuiltinTest.test_exec_closure | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**globals**'"> |
| BuiltinTest.test_filter | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Squares\' object is not iterable"'> |
| BuiltinTest.test_filter_pickle | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'"> |
| BuiltinTest.test_getattr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError ''"> |
| BuiltinTest.test_hasattr | PASS | |
| BuiltinTest.test_hash | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError '**hash** method should return an integer'"> |
| BuiltinTest.test_invalid_hash_typeerror | PASS | |
| BuiltinTest.test_hex | PASS | |
| BuiltinTest.test_id | PASS | |
| BuiltinTest.test_iter | PASS | |
| BuiltinTest.test_isinstance | PASS | |
| BuiltinTest.test_issubclass | PASS | |
| BuiltinTest.test_len | PASS | |
| BuiltinTest.test_map | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Squares\' object is not iterable"'> |
| BuiltinTest.test_map_pickle | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'"> |
| BuiltinTest.test_map_pickle_strict | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'"> |
| BuiltinTest.test_map_pickle_strict_fail | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'"> |
| BuiltinTest.test_map_strict | PASS | |
| BuiltinTest.test_map_strict_iterators | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 4, 2)"'> |
| BuiltinTest.test_map_strict_error_handling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Iter\' object is not iterable"'> |
| BuiltinTest.test_map_strict_error_handling_stopiteration | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Iter\' object is not iterable"'> |
| BuiltinTest.test_max | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| BuiltinTest.test_min | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| BuiltinTest.test_next | PASS | |
| BuiltinTest.test_oct | PASS | |
| BuiltinTest.test_ord | PASS | |
| BuiltinTest.test_input_gh130163 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| BuiltinTest.test_repr | PASS | |
| BuiltinTest.test_repr_blocked | PASS | |
| BuiltinTest.test_round | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "type TestRound doesn\'t define **round** method"'> |
| BuiltinTest.test_bug_27936 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "type Fraction doesn\'t define **round** method"'> |
| BuiltinTest.test_setattr | PASS | |
| BuiltinTest.test_type | PASS | |
| BuiltinTest.test_zip | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'I\' object is not iterable"'> |
| BuiltinTest.test_zip_pickle | PASS | |
| BuiltinTest.test_zip_pickle_strict | PASS | |
| BuiltinTest.test_zip_pickle_strict_fail | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| BuiltinTest.test_zip_strict | PASS | |
| BuiltinTest.test_zip_strict_iterators | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 4, 2)"'> |
| BuiltinTest.test_zip_strict_error_handling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Iter\' object is not iterable"'> |
| BuiltinTest.test_zip_strict_error_handling_stopiteration | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'Iter\' object is not iterable"'> |
| BuiltinTest.test_bin | PASS | |
| BuiltinTest.test_bytearray_translate | PASS | |
| BuiltinTest.test_bytearray_extend_error | PASS | |
| BuiltinTest.test_bytearray_join_with_misbehaving_iterator | PASS | |
| BuiltinTest.test_bytearray_join_with_custom_iterator | PASS | |
| BuiltinTest.test_construct_singletons | PASS | |
| BuiltinTest.test_bool_notimplemented | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| BuiltinTest.test_singleton_attribute_access | PASS | |
| TestSorted.test_basic | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSorted.test_bad_arguments | PASS | |
| TestSorted.test_inputtypes | PASS | |
| TestSorted.test_baddecorator | PASS | |
| ShutdownTest.test_cleanup | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'"> |
| TestType.test_new_type | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'ceval\', \'**main**\')"'> |
| TestType.test_type_nokwargs | PASS | |
| TestType.test_type_name | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'ceval\', \'**main**\')"'> |
| TestType.test_type_qualname | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'ceval\', \'**main**\')"'> |
| TestType.test_type_firstlineno | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'ceval\', \'**main**\')"'> |
| TestType.test_type_doc | PASS | |
| TestType.test_bad_args | PASS | |
| TestType.test_bad_slots | PASS | |
| TestType.test_namespace_order | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| BuiltinTest.test_filter_dealloc | decorator:support.skip_wasi_stack_overflow |
| BuiltinTest.test_open_default_encoding | decorator:unittest.skipIf |
| BuiltinTest.test_open_non_inheritable | decorator:support.requires_subprocess |
| BuiltinTest.test_round_large | decorator:unittest.skipIf |
| BuiltinTest.test_sum_accuracy | decorator:unittest.skipIf |
| BuiltinTest.test_zip_result_gc | decorator:support.cpython_only |
| TestBreakpoint.test_envar_good_path_builtin | decorator:unittest.skipIf |
| TestBreakpoint.test_envar_good_path_other | decorator:unittest.skipIf |
| TestBreakpoint.test_envar_good_path_noop_0 | decorator:unittest.skipIf |
| TestBreakpoint.test_envar_unimportable | decorator:unittest.skipIf |
| PtyTests.test_input_tty | decorator:unittest.skipUnless |
| PtyTests.test_input_tty_non_ascii | decorator:unittest.skipUnless |
| PtyTests.test_input_tty_non_ascii_unicode_errors | decorator:unittest.skipUnless |
| PtyTests.test_input_tty_null_in_prompt | decorator:unittest.skipUnless |
| PtyTests.test_input_tty_nonencodable_prompt | decorator:unittest.skipUnless |
| PtyTests.test_input_tty_nondecodable_input | decorator:unittest.skipUnless |
| PtyTests.test_input_no_stdout_fileno | decorator:unittest.skipUnless |
| BuiltinTest.test_import | uses-self.assertWarns |
| BuiltinTest.test_callable | unresolved-name:**builtins** |
| BuiltinTest.test_exec_globals_frozen | unresolved-name:**builtins** |
| BuiltinTest.test_open | helper:write_testfile(self.addCleanup) |
| BuiltinTest.test_input | helper:write_testfile(self.addCleanup) |
| BuiltinTest.test_sum | self.assertComplexesAreIdentical |
| BuiltinTest.test_vars | helper:get_vars_f0(decorated-helper) |
| BuiltinTest.test_zip_bad_iterable | unresolved-name:cm |
| BuiltinTest.test_format | self.assertStartsWith |
| TestBreakpoint.test_breakpoint | helper:setUp(self.addCleanup) |
| TestBreakpoint.test_breakpoint_with_breakpointhook_set | helper:setUp(self.addCleanup) |
| TestBreakpoint.test_breakpoint_with_breakpointhook_reset | helper:setUp(self.addCleanup) |
| TestBreakpoint.test_breakpoint_with_args_and_keywords | helper:setUp(self.addCleanup) |
| TestBreakpoint.test_breakpoint_with_passthru_error | helper:setUp(self.addCleanup) |
| TestBreakpoint.test_envar_good_path_empty_string | helper:setUp(self.addCleanup) |
| TestBreakpoint.test_envar_ignored_when_hook_is_set | helper:setUp(self.addCleanup) |
| TestBreakpoint.test_runtime_error_when_hook_is_lost | helper:setUp(self.addCleanup) |
| BuiltinTest.test_eval_kwargs | host-raised:KeyError: 'A_GLOBAL_VALUE' |
| BuiltinTest.test_pow | host-raised:TypeError: type complex doesn't define **round** method |
| ImmortalTests.test_immortals | host-raised:NameError: name 'self' is not defined |
| ImmortalTests.test_list_repeat_respect_immortality | host-raised:NameError: name 'self' is not defined |
| ImmortalTests.test_tuple_repeat_respect_immortality | host-raised:NameError: name 'self' is not defined |
| TestType.test_type_typeparams | harness-error:SyntaxError: invalid syntax |

## Expected vs got

### BuiltinTest.test___ne__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**ne**'">

### BuiltinTest.test_abs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bad operand type for abs(): \'AbsClass\'"'>

### BuiltinTest.test_all (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'TestFailingIter\' object is not iterable"'>

### BuiltinTest.test_all_any_tuple_optimization (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 4, 1)"'>

### BuiltinTest.test_any (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'TestFailingIter\' object is not iterable"'>

### BuiltinTest.test_ascii (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'">

### BuiltinTest.test_bool_notimplemented (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### BuiltinTest.test_bug_27936 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "type Fraction doesn\'t define **round** method"'>

### BuiltinTest.test_builtin_call_async_genexpr_no_crash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'async_yield' from '<unknown>'">

### BuiltinTest.test_compile_top_level_await (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'TypeError: expected code object'>

### BuiltinTest.test_compile_top_level_await_no_coro (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'TypeError: expected code object'>

### BuiltinTest.test_delattr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError ''">

### BuiltinTest.test_dir (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertNotIn\', \'**repr**\', [\'**class**\', \'**delattr**\', \'**dict**\', \'**dir**\', \'**doc**\', \'**eq**\', \'**firstlineno**\', \'**format**\', \'**ge**\', \'**getattribute**\', \'**getstate**\', \'**gt**\', \'**hash**\', \'**init**\', \'**init_subclass**\', \'**le**\', \'**lt**\', \'**module**\', \'**ne**\', \'**new**\', \'**reduce**\', \'**reduce_ex**\', \'**repr**\', \'**setattr**\', \'**sizeof**\', \'**slots**\', \'**static_attributes**\', \'**str**\', \'**subclasshook**\', \'**weakref**\', \'bar\'])"'>

### BuiltinTest.test_eval (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'locals must be a mapping'">

### BuiltinTest.test_eval_builtins_mapping_reduce (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (<built-in function iter>, (<function_jac_make_host_iterator.<locals>._next at 0x7f4ddc412cf0>, <object object at 0x7f4ddbae0670>)), (<built-in function iter>, ([1, 2],), 0))"'>

### BuiltinTest.test_exec (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.warnings_helper'">

### BuiltinTest.test_exec_builtins_mapping_import (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "object can\'t be sent"'>

### BuiltinTest.test_exec_closure (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**globals**'">

### BuiltinTest.test_exec_globals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "object can\'t be sent"'>

### BuiltinTest.test_exec_globals_dict_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'superglobal\' is not defined"'>

### BuiltinTest.test_exec_globals_error_on_get (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "object can\'t be sent"'>

### BuiltinTest.test_exec_kwargs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'exec() takes no keyword arguments'">

### BuiltinTest.test_filter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Squares\' object is not iterable"'>

### BuiltinTest.test_filter_pickle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'">

### BuiltinTest.test_general_eval (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'locals must be a mapping'">

### BuiltinTest.test_getattr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError ''">

### BuiltinTest.test_hash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError '**hash** method should return an integer'">

### BuiltinTest.test_input_gh130163 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### BuiltinTest.test_map (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Squares\' object is not iterable"'>

### BuiltinTest.test_map_pickle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'">

### BuiltinTest.test_map_pickle_strict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'">

### BuiltinTest.test_map_pickle_strict_fail (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'PicklingError'">

### BuiltinTest.test_map_strict_error_handling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Iter\' object is not iterable"'>

### BuiltinTest.test_map_strict_error_handling_stopiteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Iter\' object is not iterable"'>

### BuiltinTest.test_map_strict_iterators (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 4, 2)"'>

### BuiltinTest.test_max (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### BuiltinTest.test_min (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### BuiltinTest.test_round (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "type TestRound doesn\'t define **round** method"'>

### BuiltinTest.test_zip (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'I\' object is not iterable"'>

### BuiltinTest.test_zip_pickle_strict_fail (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### BuiltinTest.test_zip_strict_error_handling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Iter\' object is not iterable"'>

### BuiltinTest.test_zip_strict_error_handling_stopiteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'Iter\' object is not iterable"'>

### BuiltinTest.test_zip_strict_iterators (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 4, 2)"'>

### ShutdownTest.test_cleanup (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.script_helper'">

### TestSorted.test_basic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestType.test_new_type (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'ceval\', \'**main**\')"'>

### TestType.test_type_firstlineno (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'ceval\', \'**main**\')"'>

### TestType.test_type_name (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'ceval\', \'**main**\')"'>

### TestType.test_type_qualname (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'ceval\', \'**main**\')"'>
