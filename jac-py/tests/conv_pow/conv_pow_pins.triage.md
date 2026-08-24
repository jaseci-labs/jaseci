# Triage report: `conv_pow_pins.jac`

- source: reference/cpython/Lib/test/test_pow.py
- guest leg: 0/3 marks
- pins: **2 passed** / 3 run (+4 quarantined of 7 extracted)

| pin | result | got |
|---|---|---|
| PowTest.test_other | PASS | |
| PowTest.test_big_exp | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'seed\'"'> |
| PowTest.test_bug643260 | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| PowTest.test_powint | self.powtest |
| PowTest.test_powfloat | self.powtest |
| PowTest.test_bug705231 | uses-self.assertEqual |
| PowTest.test_negative_exponent | uses-self.subTest |

## Expected vs got

### PowTest.test_big_exp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'seed\'"'>
