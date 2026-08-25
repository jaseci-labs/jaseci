# Triage report: `conv_generators_pins.jac`

- source: reference/cpython/Lib/test/test_generators.py
- guest leg: 0/37 marks
- pins: **20 passed** / 37 run (+22 quarantined of 59 extracted)

| pin | result | got |
|---|---|---|
| FinalizationTest.test_frame_resurrect | GUEST-WRONG-OUTPUT | RUN<'compile failed'> |
| FinalizationTest.test_refcycle | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'gc_collect'"> |
| FinalizationTest.test_generator_resurrect | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'gc_collect'"> |
| FinalizationTest.test_exhausted_generator_frame_cycle | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'f_back'"> |
| GeneratorTest.test_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| GeneratorTest.test_pickle | PASS | |
| GeneratorTest.test_send_non_none_to_new_gen | PASS | |
| GeneratorTest.test_handle_frame_object_in_creation | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| GeneratorTest.test_ag_frame_f_back | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'f_back'"> |
| GeneratorTest.test_cr_frame_f_back | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'cr_frame'"> |
| GeneratorTest.test_gi_frame_f_back | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'f_back'"> |
| GeneratorTest.test_issue103488 | PASS | |
| GeneratorTest.test_close_clears_frame | PASS | |
| ExceptionTest.test_except_next | PASS | |
| ExceptionTest.test_except_gen_except | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError ''"> |
| ExceptionTest.test_nested_gen_except_loop | PASS | |
| ExceptionTest.test_except_throw_exception_context | PASS | |
| ExceptionTest.test_except_throw_bad_exception | PASS | |
| ExceptionTest.test_stopiteration_error | PASS | |
| ExceptionTest.test_tutorial_stopiteration | PASS | |
| GeneratorCloseTest.test_close_no_return_value | PASS | |
| GeneratorCloseTest.test_close_return_value | PASS | |
| GeneratorCloseTest.test_close_not_catching_exit | PASS | |
| GeneratorCloseTest.test_close_not_started | PASS | |
| GeneratorCloseTest.test_close_exhausted | PASS | |
| GeneratorCloseTest.test_close_closed | PASS | |
| GeneratorCloseTest.test_close_raises | PASS | |
| GeneratorCloseTest.test_close_releases_frame_locals | GUEST-WRONG-OUTPUT | RUN<'compile failed'> |
| GeneratorDeallocTest.test_frame_locals_outlive_generator_with_exec | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'exec() takes no keyword arguments'"> |
| GeneratorThrowTest.test_exception_context_with_yield_inside_generator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'args'"> |
| GeneratorThrowTest.test_exception_context_with_yield_from_with_context_cycle | PASS | |
| GeneratorThrowTest.test_throw_after_none_exc_type | PASS | |
| YieldFromTests.test_generator_gi_yieldfrom | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| generators.doctests:tut | PASS | |
| generators.doctests:fun | GUEST-WRONG-OUTPUT | RUN<'RuntimeError: cannot re-enter the tee iterator'> |
| generators.doctests:syntax | GUEST-WRONG-OUTPUT | RUN<'AttributeError: gi_code'> |
| generators.doctests:weakref | GUEST-WRONG-OUTPUT | RUN<'AttributeError: proxy'> |

## Quarantined at conversion

| test | reason |
|---|---|
| SignalAndYieldFromTest.test_raise_and_yield_from | decorator:unittest.skipUnless |
| FinalizationTest.test_lambda_generator | unresolved-name:cm |
| GeneratorTest.test_genexpr_only_calls_dunder_iter_once | uses-self.val |
| ModifyUnderlyingIterableTest.test_modify_f_locals | self.process_tests |
| ModifyUnderlyingIterableTest.test_new_gen_from_gi_code | self.process_tests |
| ExceptionTest.test_except_throw | unresolved-name:cm |
| ExceptionTest.test_gen_3_arg_deprecation_warning | uses-self.assertWarns |
| ExceptionTest.test_return_tuple | unresolved-name:cm |
| ExceptionTest.test_return_stopiteration | unresolved-name:cm |
| GeneratorDeallocTest.test_frame_outlives_generator | uses-self.frame |
| GeneratorDeallocTest.test_frame_locals_outlive_generator | uses-self.subTest |
| GeneratorThrowTest.test_exception_context_with_yield | unresolved-name:cm |
| GeneratorThrowTest.test_exception_context_with_yield_from | unresolved-name:cm |
| GeneratorStackTraceTest.test_send_with_yield_from | self.check_yield_from_example |
| GeneratorStackTraceTest.test_throw_with_yield_from | self.check_yield_from_example |
| GeneratorStackTraceTest.test_throw_with_yield_from_custom_generator | uses-self.test |
| GeneratorTest.test_name | host-raised:AssertionError: ('assertEqual', '_t.<locals>.func', 'GeneratorTest.test_name.<locals>.func') |
| generators.doctests:pep | harness-error:TypeError: _d_print() got an unexpected keyword argument 'end' |
| generators.doctests:email | harness-error:TypeError: _d_print() got an unexpected keyword argument 'end' |
| generators.doctests:conjoin | harness-error:AssertionError: ('doctest', 6, 'Solution 1\nSolution 2', 'Solution 1\n+-+-+-+-+-+-+-+-+\n\|Q\| \| \| \| \| \| \| \|\n+-+-+-+-+-+- |
| generators.doctests:coroutine | harness-error:AssertionError: ('doctest', 83, '', 'True\nTrue\nTrue\nTrue') |
| generators.doctests:refleaks | harness-error:AssertionError: ('doctest', 8, '', 'True\nTrue\nTrue\nTrue') |

## Expected vs got

### ExceptionTest.test_except_gen_except (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError ''">

### FinalizationTest.test_exhausted_generator_frame_cycle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'f_back'">

### FinalizationTest.test_frame_resurrect (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'compile failed'>

### FinalizationTest.test_generator_resurrect (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'gc_collect'">

### FinalizationTest.test_refcycle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'gc_collect'">

### GeneratorCloseTest.test_close_releases_frame_locals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'compile failed'>

### GeneratorDeallocTest.test_frame_locals_outlive_generator_with_exec (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'exec() takes no keyword arguments'">

### GeneratorTest.test_ag_frame_f_back (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'f_back'">

### GeneratorTest.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### GeneratorTest.test_cr_frame_f_back (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'cr_frame'">

### GeneratorTest.test_gi_frame_f_back (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'f_back'">

### GeneratorTest.test_handle_frame_object_in_creation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### GeneratorThrowTest.test_exception_context_with_yield_inside_generator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'args'">

### YieldFromTests.test_generator_gi_yieldfrom (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### generators.doctests:fun (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'RuntimeError: cannot re-enter the tee iterator'>

### generators.doctests:syntax (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: gi_code'>

### generators.doctests:weakref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: proxy'>
