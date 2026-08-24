# Triage report: `conv_raise_pins.jac`

- source: reference/cpython/Lib/test/test_raise.py
- guest leg: 0/32 marks
- pins: **23 passed** / 32 run (+5 quarantined of 37 extracted)

| pin | result | got |
|---|---|---|
| TestRaise.test_invalid_reraise | PASS | |
| TestRaise.test_reraise | PASS | |
| TestRaise.test_except_reraise | PASS | |
| TestRaise.test_finally_reraise | PASS | |
| TestRaise.test_nested_reraise | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC RuntimeError 'No active exception to re-raise'"> |
| TestRaise.test_raise_from_None | PASS | |
| TestRaise.test_yield_reraise | PASS | |
| TestRaise.test_erroneous_exception | PASS | |
| TestRaise.test_new_returns_invalid_instance | PASS | |
| TestRaise.test_assert_with_tuple_arg | PASS | |
| TestCause.testCauseSyntax | PASS | |
| TestCause.test_invalid_cause | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError ''"> |
| TestCause.test_class_cause | PASS | |
| TestCause.test_class_cause_nonexception_result | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError ''"> |
| TestCause.test_instance_cause | PASS | |
| TestCause.test_erroneous_cause | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError ''"> |
| TestTraceback.test_sets_traceback | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| TestTraceback.test_accepts_traceback | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'with_traceback'"> |
| TestTracebackType.test_attrs | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| TestTracebackType.test_constructor | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'traceback\' has policy BridgePolicy.FAIL but no to_host conversion arm"'> |
| TestContext.test_instance_context_instance_raise | PASS | |
| TestContext.test_class_context_instance_raise | PASS | |
| TestContext.test_class_context_class_raise | PASS | |
| TestContext.test_c_exception_context | PASS | |
| TestContext.test_noraise_finally | PASS | |
| TestContext.test_raise_finally | PASS | |
| TestContext.test_cycle_broken | PASS | |
| TestContext.test_not_last | PASS | |
| TestContext.test_3118 | PASS | |
| TestContext.test_3611 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'catch_unraisable_exception'"> |
| TestRemovedFunctionality.test_tuples | PASS | |
| TestRemovedFunctionality.test_strings | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestRaise.test_with_reraise1 | unresolved-name:Context |
| TestRaise.test_with_reraise2 | unresolved-name:Context |
| TestContext.test_c_exception_raise | unresolved-name:xyzzy |
| TestContext.test_context_manager | unresolved-name:xyzzy |
| TestContext.test_reraise_cycle_broken | unresolved-name:xyzzy |

## Expected vs got

### TestCause.test_class_cause_nonexception_result (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError ''">

### TestCause.test_erroneous_cause (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError ''">

### TestCause.test_invalid_cause (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError ''">

### TestContext.test_3611 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'catch_unraisable_exception'">

### TestRaise.test_nested_reraise (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC RuntimeError 'No active exception to re-raise'">

### TestTraceback.test_accepts_traceback (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'with_traceback'">

### TestTraceback.test_sets_traceback (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### TestTracebackType.test_attrs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### TestTracebackType.test_constructor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'traceback\' has policy BridgePolicy.FAIL but no to_host conversion arm"'>
