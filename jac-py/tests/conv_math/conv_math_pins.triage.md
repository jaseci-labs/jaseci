# Triage report: `conv_math_pins.jac`

- source: reference/cpython/Lib/test/test_math.py
- guest leg: 0/19 marks
- pins: **18 passed** / 19 run (+69 quarantined of 88 extracted)

| pin | result | got |
|---|---|---|
| MathTests.testCopysign | PASS | |
| MathTests.testFactorial | PASS | |
| MathTests.testFactorialNonIntegers | PASS | |
| MathTests.testFrexp | PASS | |
| MathTests.test_math_dist_leak | PASS | |
| MathTests.testLdexp_denormal | PASS | |
| MathTests.testLog1p | PASS | |
| MathTests.testLog2 | PASS | |
| MathTests.testModf | PASS | |
| MathTests.testTanhSign | PASS | |
| MathTests.testIsfinite | PASS | |
| MathTests.testIsnan | PASS | |
| MathTests.testIsinf | PASS | |
| MathTests.test_nan_constant | PASS | |
| MathTests.test_inf_constant | PASS | |
| MathTests.test_input_exceptions | PASS | |
| MathTests.test_exception_messages | GUEST-WRONG-OUTPUT | RUN<'AttributeError: register'> |
| FMATests.test_fma_overflow | PASS | |
| FMATests.test_fma_single_round | PASS | |

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
| MathTests.testConstants | self.ftest |
| MathTests.testAcos | self.ftest |
| MathTests.testAcosh | self.ftest |
| MathTests.testAsin | self.ftest |
| MathTests.testAsinh | self.ftest |
| MathTests.testAtan | self.ftest |
| MathTests.testAtanh | self.ftest |
| MathTests.testCbrt | self.ftest |
| MathTests.testCeil | unresolved-name:BadDescr |
| MathTests.testCos | self.ftest |
| MathTests.testDegrees | self.ftest |
| MathTests.testExp | self.ftest |
| MathTests.testExp2 | self.ftest |
| MathTests.testFabs | self.ftest |
| MathTests.testFloor | unresolved-name:BadDescr |
| MathTests.testFmod | self.ftest |
| MathTests.testGcd | unresolved-name:MyIndexable |
| MathTests.testHypot | unresolved-name:FloatLike |
| MathTests.testDist | unresolved-name:BadDescr |
| MathTests.testIsqrt | uses-self.value |
| MathTests.test_lcm | unresolved-name:MyIndexable |
| MathTests.testLdexp | self.ftest |
| MathTests.testLog | self.ftest |
| MathTests.testLog10 | self.ftest |
| MathTests.testSumProd | uses-self.subTest |
| MathTests.testPow | self.ftest |
| MathTests.testRadians | self.ftest |
| MathTests.testRemainder | self.assertIsNaN |
| MathTests.testSin | self.ftest |
| MathTests.testSinh | self.ftest |
| MathTests.testSqrt | self.ftest |
| MathTests.testTan | self.ftest |
| MathTests.testTanh | self.ftest |
| MathTests.test_trunc | unresolved-name:BadDescr |
| MathTests.test_prod | self.assertIsNaN |
| MathTests.testPerm | unresolved-name:IntSubclass |
| MathTests.testComb | unresolved-name:IntSubclass |
| MathTests.test_nextafter | self.assertEqualSign |
| MathTests.test_ulp | self.assertIsNaN |
| MathTests.test_issue39871 | uses-self.converted |
| IsCloseTests.test_negative_tolerances | uses-self.assertIsClose |
| IsCloseTests.test_identical | self.assertAllClose |
| IsCloseTests.test_eight_decimal_places | self.assertAllClose |
| IsCloseTests.test_near_zero | self.assertAllNotClose |
| IsCloseTests.test_identical_infinite | self.assertIsClose |
| IsCloseTests.test_inf_ninf_nan | self.assertAllNotClose |
| IsCloseTests.test_zero_tolerance | self.assertAllClose |
| IsCloseTests.test_asymmetry | self.assertAllClose |
| IsCloseTests.test_integers | self.assertAllClose |
| IsCloseTests.test_decimals | self.assertAllClose |
| IsCloseTests.test_fractions | self.assertAllClose |
| FMATests.test_fma_nan_results | self.assertIsNaN |
| FMATests.test_fma_infinities | uses-self.subTest |
| FMATests.test_random | uses-self.subTest |
| MathTests.test_testfile | harness-error:NameError: name 'file' is not defined. Did you mean: 'filter'? |
| MathTests.test_mtestfile | harness-error:NameError: name 'file' is not defined. Did you mean: 'filter'? |

## Expected vs got

### MathTests.test_exception_messages (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: register'>
