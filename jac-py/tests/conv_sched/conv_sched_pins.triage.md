# Triage report: `conv_sched_pins.jac`

- source: reference/cpython/Lib/test/test_sched.py
- guest leg: 0/8 marks
- pins: **7 passed** / 8 run (+3 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| TestCase.test_enter | PASS | |
| TestCase.test_enterabs | PASS | |
| TestCase.test_cancel | PASS | |
| TestCase.test_cancel_correct_event | PASS | |
| TestCase.test_empty | PASS | |
| TestCase.test_queue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'heapq_fn\' has policy BridgePolicy.FAIL but no to_host conversion arm"'> |
| TestCase.test_args_kwargs | PASS | |
| TestCase.test_run_non_blocking | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCase.test_enter_concurrent | decorator:threading_helper.requires_working_threading |
| TestCase.test_cancel_concurrent | decorator:threading_helper.requires_working_threading |
| TestCase.test_priority | uses-self.subTest |

## Expected vs got

### TestCase.test_queue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'heapq_fn\' has policy BridgePolicy.FAIL but no to_host conversion arm"'>
