# Triage report: `conv_yield_from_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_yield_from.py
- guest leg: 0/34 marks
- pins: **26 passed** / 34 run (+9 quarantined of 43 extracted)

| pin | result | got |
|---|---|---|
| TestPEP380Operation.test_delegation_of_initial_next_to_subgenerator | PASS | |
| TestPEP380Operation.test_raising_exception_in_initial_next_call | PASS | |
| TestPEP380Operation.test_delegation_of_next_call_to_subgenerator | PASS | |
| TestPEP380Operation.test_raising_exception_in_delegated_next_call | PASS | |
| TestPEP380Operation.test_delegation_of_send | PASS | |
| TestPEP380Operation.test_handling_exception_while_delegating_send | PASS | |
| TestPEP380Operation.test_delegating_close | PASS | |
| TestPEP380Operation.test_handing_exception_while_delegating_close | PASS | |
| TestPEP380Operation.test_delegating_throw | PASS | |
| TestPEP380Operation.test_value_attribute_of_StopIteration_exception | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'value'"> |
| TestPEP380Operation.test_exception_value_crash | PASS | |
| TestPEP380Operation.test_generator_return_value | PASS | |
| TestPEP380Operation.test_delegation_of_next_to_non_generator | PASS | |
| TestPEP380Operation.test_conversion_of_sendNone_to_next | PASS | |
| TestPEP380Operation.test_delegation_of_close_to_non_generator | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'captured_stderr' from '<unknown>'"> |
| TestPEP380Operation.test_delegating_throw_to_non_generator | PASS | |
| TestPEP380Operation.test_attempting_to_send_to_non_generator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'tuple index out of range'"> |
| TestPEP380Operation.test_exception_in_initial_next_call | PASS | |
| TestPEP380Operation.test_attempted_yield_from_loop | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'tuple index out of range'"> |
| TestPEP380Operation.test_returning_value_from_delegated_throw | PASS | |
| TestPEP380Operation.test_next_and_return_with_value | PASS | |
| TestPEP380Operation.test_send_and_return_with_value | PASS | |
| TestPEP380Operation.test_catching_exception_from_subgen_and_returning | PASS | |
| TestPEP380Operation.test_throwing_GeneratorExit_into_subgen_that_returns | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC StopIteration ''"> |
| TestPEP380Operation.test_throwing_GeneratorExit_into_subgenerator_that_yields | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'subgenerator failed to raise GeneratorExit'"> |
| TestPEP380Operation.test_throwing_GeneratorExit_into_subgen_that_raises | PASS | |
| TestPEP380Operation.test_yield_from_empty | PASS | |
| TestPEP380Operation.test_delegating_generators_claim_to_be_running | PASS | |
| TestPEP380Operation.test_delegating_generators_claim_to_be_running_with_throw | PASS | |
| TestPEP380Operation.test_delegator_is_visible_to_debugger | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestPEP380Operation.test_custom_iterator_return | PASS | |
| TestPEP380Operation.test_close_with_cleared_frame | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'captured_stderr' from '<unknown>'"> |
| TestPEP380Operation.test_send_tuple_with_custom_generator | PASS | |
| TestInterestingEdgeCases.test_throws_in_iter | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestPEP380Operation.test_broken_getattr_handling | uses-self.assertEqual |
| TestPEP380Operation.test_delegating_generators_claim_to_be_running_with_close | uses-self.assertRaises |
| TestInterestingEdgeCases.test_close_and_throw_work | helper:assert_stop_iteration(unresolved-name:caught) |
| TestInterestingEdgeCases.test_close_and_throw_raise_generator_exit | helper:assert_stop_iteration(unresolved-name:caught) |
| TestInterestingEdgeCases.test_close_and_throw_raise_stop_iteration | helper:assert_generator_raised_stop_iteration(uses-self.assertRaisesRegex) |
| TestInterestingEdgeCases.test_close_and_throw_raise_base_exception | helper:assert_stop_iteration(unresolved-name:caught) |
| TestInterestingEdgeCases.test_close_and_throw_raise_exception | helper:assert_stop_iteration(unresolved-name:caught) |
| TestInterestingEdgeCases.test_close_and_throw_yield | helper:assert_generator_ignored_generator_exit(uses-self.assertRaisesRegex) |
| TestInterestingEdgeCases.test_close_and_throw_return | helper:assert_stop_iteration(unresolved-name:caught) |

## Expected vs got

### TestPEP380Operation.test_attempted_yield_from_loop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'tuple index out of range'">

### TestPEP380Operation.test_attempting_to_send_to_non_generator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'tuple index out of range'">

### TestPEP380Operation.test_close_with_cleared_frame (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'captured_stderr' from '<unknown>'">

### TestPEP380Operation.test_delegation_of_close_to_non_generator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'captured_stderr' from '<unknown>'">

### TestPEP380Operation.test_delegator_is_visible_to_debugger (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestPEP380Operation.test_throwing_GeneratorExit_into_subgen_that_returns (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC StopIteration ''">

### TestPEP380Operation.test_throwing_GeneratorExit_into_subgenerator_that_yields (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'subgenerator failed to raise GeneratorExit'">

### TestPEP380Operation.test_value_attribute_of_StopIteration_exception (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'value'">
