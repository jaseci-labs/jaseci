# Triage report: `conv_getopt_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_getopt.py
- guest leg: 0/2 marks
- pins: **1 passed** / 2 run (+7 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| GetoptTests.test_issue4629 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'globals\' has policy BridgePolicy.FAIL but no to_host conversion arm"'> |
| test_libref_examples | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| GetoptTests.test_short_has_arg | self.assertError |
| GetoptTests.test_long_has_args | self.assertError |
| GetoptTests.test_do_shorts | self.assertError |
| GetoptTests.test_do_longs | self.assertError |
| GetoptTests.test_getopt | self.assertError |
| GetoptTests.test_gnu_getopt | uses-self.env |
| TestTranslations.test_translations | self.assertMsgidsEqual |

## Expected vs got

### GetoptTests.test_issue4629 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'globals\' has policy BridgePolicy.FAIL but no to_host conversion arm"'>
