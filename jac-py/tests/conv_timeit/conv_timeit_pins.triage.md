# Triage report: `conv_timeit_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_timeit.py
- guest leg: 0/7 marks
- pins: **7 passed** / 7 run (+34 quarantined of 41 extracted)

| pin | result | got |
|---|---|---|
| TestTimeit.test_reindent_empty | PASS | |
| TestTimeit.test_reindent_single | PASS | |
| TestTimeit.test_reindent_multi_empty | PASS | |
| TestTimeit.test_reindent_multi | PASS | |
| TestTimeit.test_timer_invalid_stmt | PASS | |
| TestTimeit.test_timer_invalid_setup | PASS | |
| TestTimeit.test_timer_empty_stmt | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestTimeit.test_main_help | decorator:unittest.skipIf |
| TestTimeit.test_timeit_function_zero_iters | unresolved-name:FakeTimer |
| TestTimeit.test_timeit_globals_args | unresolved-name:FakeTimer |
| TestTimeit.test_repeat_function_zero_reps | unresolved-name:FakeTimer |
| TestTimeit.test_repeat_function_zero_iters | unresolved-name:FakeTimer |
| TestTimeit.test_print_exc | helper:assert_exc_string(self.assertStartsWith) |
| TestTimeit.test_main_exception | helper:assert_exc_string(self.assertStartsWith) |
| TestTimeit.test_main_exception_fixed_reps | helper:assert_exc_string(self.assertStartsWith) |
| TestTimeit.test_timeit_zero_iters | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_stmt' |
| TestTimeit.test_timeit_few_iters | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_stmt' |
| TestTimeit.test_timeit_callable_stmt | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_callable_stmt' |
| TestTimeit.test_timeit_callable_setup | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_stmt' |
| TestTimeit.test_timeit_callable_stmt_and_setup | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_callable_stmt' |
| TestTimeit.test_repeat_zero_reps | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_stmt' |
| TestTimeit.test_repeat_zero_iters | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_stmt' |
| TestTimeit.test_repeat_few_reps_and_iters | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_stmt' |
| TestTimeit.test_repeat_callable_stmt | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_callable_stmt' |
| TestTimeit.test_repeat_callable_setup | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_stmt' |
| TestTimeit.test_repeat_callable_stmt_and_setup | host-raised:AttributeError: '_SelfNS' object has no attribute 'fake_callable_stmt' |
| TestTimeit.test_main_bad_switch | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_seconds | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_milliseconds | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_microseconds | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_fixed_iters | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_setup | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_multiple_setups | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_fixed_reps | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_negative_reps | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_verbose | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_very_verbose | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_main_with_time_unit | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_autorange | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_autorange_second | host-raised:NameError: name 'self' is not defined |
| TestTimeit.test_autorange_with_callback | host-raised:NameError: name 'self' is not defined |
