# Triage report: `conv_binop_pins.jac`

- source: reference/cpython/Lib/test/test_binop.py
- guest leg: 0/1 marks
- pins: **1 passed** / 1 run (+11 quarantined of 12 extracted)

| pin | result | got |
|---|---|---|
| RatTestCase.test_gcd | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| RatTestCase.test_constructor | unresolved-name:Rat |
| RatTestCase.test_add | unresolved-name:Rat |
| RatTestCase.test_sub | unresolved-name:Rat |
| RatTestCase.test_mul | unresolved-name:Rat |
| RatTestCase.test_div | unresolved-name:Rat |
| RatTestCase.test_floordiv | unresolved-name:Rat |
| RatTestCase.test_eq | unresolved-name:Rat |
| RatTestCase.test_true_div | unresolved-name:Rat |
| OperationOrderTests.test_comparison_orders | self.assertIsSubclass |
| FallbackBlockingTests.test_fallback_rmethod_blocking | unresolved-name:F |
| FallbackBlockingTests.test_fallback_ne_blocking | unresolved-name:SN |
