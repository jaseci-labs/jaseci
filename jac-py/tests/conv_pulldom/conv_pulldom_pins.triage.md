# Triage report: `conv_pulldom_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_pulldom.py
- guest leg: 0/7 marks
- pins: **4 passed** / 7 run (+4 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| PullDOMTestCase.test_parse_semantics | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'PullDOM\' object has no attribute \'processingInstruction\'"'> |
| PullDOMTestCase.test_expandItem | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'PullDOM\' object has no attribute \'processingInstruction\'"'> |
| PullDOMTestCase.test_external_ges_default | PASS | |
| ThoroughTestCase.test_thorough_parse | PASS | |
| ThoroughTestCase.test_thorough_sax2dom | PASS | |
| SAX2DOMTestCase.test_basic | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'StringIO.**enter**() takes no arguments (1 given)'"> |
| SAX2DOMTestCase.testSAX2DOM | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| PullDOMTestCase.test_comment | decorator:unittest.expectedFailure |
| PullDOMTestCase.test_end_document | decorator:unittest.expectedFailure |
| ThoroughTestCase.test_sax2dom_fail | decorator:unittest.expectedFailure |
| PullDOMTestCase.test_parse | self.addCleanup |

## Expected vs got

### PullDOMTestCase.test_expandItem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'PullDOM\' object has no attribute \'processingInstruction\'"'>

### PullDOMTestCase.test_parse_semantics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'PullDOM\' object has no attribute \'processingInstruction\'"'>

### SAX2DOMTestCase.test_basic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'StringIO.**enter**() takes no arguments (1 given)'">
