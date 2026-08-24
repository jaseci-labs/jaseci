# Triage report: `conv_picklebuffer_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_picklebuffer.py
- guest leg: 0/3 marks
- pins: **2 passed** / 3 run (+6 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| PickleBufferTest.test_constructor_failure | PASS | |
| PickleBufferTest.test_basics | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'memoryview.**enter**() takes no arguments (1 given)'"> |
| PickleBufferTest.test_raw_released | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| PickleBufferTest.test_release | unresolved-name:raises |
| PickleBufferTest.test_cycle | unresolved-name:B |
| PickleBufferTest.test_raw | uses-self.subTest |
| PickleBufferTest.test_ndarray_2d | host-raised:SkipTest: No module named '_testbuffer' |
| PickleBufferTest.test_raw_ndarray | host-raised:SkipTest: No module named '_testbuffer' |
| PickleBufferTest.test_raw_non_contiguous | host-raised:SkipTest: No module named '_testbuffer' |

## Expected vs got

### PickleBufferTest.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'memoryview.**enter**() takes no arguments (1 given)'">
