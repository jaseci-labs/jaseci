# Triage report: `conv_math_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_math.py
- guest leg: 0/53 marks
- pins: **48 passed** / 53 run (+35 quarantined of 88 extracted)

| pin | result | got |
|---|---|---|
| MathTests.testConstants | PASS | |
| MathTests.testAcos | PASS | |
| MathTests.testAcosh | PASS | |
| MathTests.testAsin | PASS | |
| MathTests.testAsinh | PASS | |
| MathTests.testAtan | PASS | |
| MathTests.testAtanh | PASS | |
| MathTests.testCbrt | PASS | |
| MathTests.testCopysign | PASS | |
| MathTests.testCos | PASS | |
| MathTests.testDegrees | PASS | |
| MathTests.testExp | PASS | |
| MathTests.testExp2 | PASS | |
| MathTests.testFabs | PASS | |
| MathTests.testFactorial | PASS | |
| MathTests.testFactorialNonIntegers | PASS | |
| MathTests.testFmod | PASS | |
| MathTests.testFrexp | PASS | |
| MathTests.test_math_dist_leak | PASS | |
| MathTests.testIsqrt | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'IntegerLike\' object cannot be interpreted as an integer"'> |
| MathTests.testLdexp | PASS | |
| MathTests.testLdexp_denormal | PASS | |
| MathTests.testLog | PASS | |
| MathTests.testLog1p | PASS | |
| MathTests.testLog2 | PASS | |
| MathTests.testLog10 | PASS | |
| MathTests.testSumProd | GUEST-WRONG-OUTPUT | RUN<'AttributeError: register'> |
| MathTests.testModf | PASS | |
| MathTests.testPow | PASS | |
| MathTests.testRadians | PASS | |
| MathTests.testRemainder | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'register'"> |
| MathTests.testSin | PASS | |
| MathTests.testSinh | PASS | |
| MathTests.testSqrt | PASS | |
| MathTests.testTan | PASS | |
| MathTests.testTanh | PASS | |
| MathTests.testTanhSign | PASS | |
| MathTests.testIsfinite | PASS | |
| MathTests.testIsnan | PASS | |
| MathTests.testIsinf | PASS | |
| MathTests.test_nan_constant | PASS | |
| MathTests.test_inf_constant | PASS | |
| MathTests.test_prod | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'register'"> |
| MathTests.test_nextafter | PASS | |
| MathTests.test_ulp | PASS | |
| MathTests.test_issue39871 | PASS | |
| MathTests.test_input_exceptions | PASS | |
| MathTests.test_exception_messages | GUEST-WRONG-OUTPUT | RUN<'AttributeError: register'> |
| FMATests.test_fma_nan_results | PASS | |
| FMATests.test_fma_infinities | PASS | |
| FMATests.test_fma_overflow | PASS | |
| FMATests.test_fma_single_round | PASS | |
| FMATests.test_random | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| MathTests.testAtan2 | decorator:unittest.skipIf |
| MathTests.testCosh | decorator:unittest.skipIf |
| MathTests.testFactorialHugeInputs | decorator:support.cpython_only |
| MathTests.testFsum | decorator:unittest.skipIf |
| MathTests.testHypotAccuracy | decorator:unittest.skipIf |
| MathTests.test_isqrt_huge | decorator:support.bigmemtest |
| MathTests.testLog2Exact | decorator:support.requires_mac_ver |
| MathTests.test_log_huge_integer | decorator:support.bigmemtest |
| MathTests.test_sumprod_accuracy | decorator:unittest.skipIf |
| MathTests.test_sumprod_stress | decorator:support.requires_resource |
| MathTests.test_sumprod_extended_precision_accuracy | decorator:unittest.skipIf |
| MathTests.test_exceptions | decorator:unittest.skipUnless |
| FMATests.test_fma_zero_result | decorator:unittest.skipIf |
| MathTests.testCeil | unresolved-name:BadDescr |
| MathTests.testFloor | unresolved-name:BadDescr |
| MathTests.testGcd | unresolved-name:MyIndexable |
| MathTests.testHypot | unresolved-name:FloatLike |
| MathTests.testDist | unresolved-name:BadDescr |
| MathTests.test_lcm | unresolved-name:MyIndexable |
| MathTests.test_trunc | unresolved-name:BadDescr |
| MathTests.testPerm | unresolved-name:IntSubclass |
| MathTests.testComb | unresolved-name:IntSubclass |
| IsCloseTests.test_negative_tolerances | helper:assertIsClose(uses-self.isclose) |
| IsCloseTests.test_identical | helper:assertAllClose(helper:assertIsClose(uses-self.isclose)) |
| IsCloseTests.test_eight_decimal_places | helper:assertAllClose(helper:assertIsClose(uses-self.isclose)) |
| IsCloseTests.test_near_zero | helper:assertAllNotClose(helper:assertIsNotClose(uses-self.isclose)) |
| IsCloseTests.test_identical_infinite | helper:assertIsClose(uses-self.isclose) |
| IsCloseTests.test_inf_ninf_nan | helper:assertAllNotClose(helper:assertIsNotClose(uses-self.isclose)) |
| IsCloseTests.test_zero_tolerance | helper:assertAllClose(helper:assertIsClose(uses-self.isclose)) |
| IsCloseTests.test_asymmetry | helper:assertAllClose(helper:assertIsClose(uses-self.isclose)) |
| IsCloseTests.test_integers | helper:assertAllClose(helper:assertIsClose(uses-self.isclose)) |
| IsCloseTests.test_decimals | helper:assertAllClose(helper:assertIsClose(uses-self.isclose)) |
| IsCloseTests.test_fractions | helper:assertAllClose(helper:assertIsClose(uses-self.isclose)) |
| MathTests.test_testfile | harness-error:NameError: name 'file' is not defined. Did you mean: 'filter'? |
| MathTests.test_mtestfile | harness-error:NameError: name 'file' is not defined. Did you mean: 'filter'? |

## Expected vs got

### MathTests.testIsqrt (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'IntegerLike\' object cannot be interpreted as an integer"'>

### MathTests.testRemainder (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'register'">

### MathTests.testSumProd (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: register'>

### MathTests.test_exception_messages (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: register'>

### MathTests.test_prod (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'register'">
