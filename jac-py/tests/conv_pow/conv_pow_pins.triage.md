# Triage report: `conv_pow_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_pow.py
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
| PowTest.test_negative_exponent | uses-self.subTest |
| PowTest.test_powint | host-raised:NameError: name 'self' is not defined |
| PowTest.test_powfloat | host-raised:NameError: name 'self' is not defined |
| PowTest.test_bug705231 | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |

## Expected vs got

### PowTest.test_big_exp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'seed\'"'>
