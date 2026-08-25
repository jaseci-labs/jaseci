# Triage report: `conv_pyclbr_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_pyclbr.py
- guest leg: 0/2 marks
- pins: **1 passed** / 2 run (+4 quarantined of 6 extracted)

| pin | result | got |
|---|---|---|
| PyclbrTest.test_nested | PASS | |
| ReadmoduleTests.test_dotted_name_not_a_package | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'sys\' is not defined"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| PyclbrTest.test_easy | helper:checkModule(self.assertHasAttr) |
| PyclbrTest.test_cases | helper:checkModule(self.assertHasAttr) |
| PyclbrTest.test_others | host-raised:AttributeError: '_SelfNS' object has no attribute 'checkModule' |
| ReadmoduleTests.test_module_has_no_spec | harness-error:unittest.case.SkipTest: No module named '_testmultiphase' |

## Expected vs got

### ReadmoduleTests.test_dotted_name_not_a_package (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'sys\' is not defined"'>
