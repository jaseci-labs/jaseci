# Triage report: `conv_pulldom_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_pulldom.py
- guest leg: 0/3 marks
- pins: **2 passed** / 3 run (+8 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| PullDOMTestCase.test_expandItem | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'PullDOM\' object has no attribute \'processingInstruction\'"'> |
| PullDOMTestCase.test_external_ges_default | PASS | |
| SAX2DOMTestCase.testSAX2DOM | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| PullDOMTestCase.test_comment | decorator:unittest.expectedFailure |
| PullDOMTestCase.test_end_document | decorator:unittest.expectedFailure |
| ThoroughTestCase.test_sax2dom_fail | decorator:unittest.expectedFailure |
| PullDOMTestCase.test_parse | self.addCleanup |
| PullDOMTestCase.test_parse_semantics | self.assertHasAttr |
| ThoroughTestCase.test_thorough_parse | helper:_test_thorough(self.assertHasAttr) |
| ThoroughTestCase.test_thorough_sax2dom | helper:_test_thorough(self.assertHasAttr) |
| SAX2DOMTestCase.test_basic | unresolved-name:SAX2DOMTestHelper |

## Expected vs got

### PullDOMTestCase.test_expandItem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'PullDOM\' object has no attribute \'processingInstruction\'"'>
