# Triage report: `conv_robotparser_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_robotparser.py
- guest leg: 0/3 marks
- pins: **0 passed** / 3 run (+14 quarantined of 17 extracted)

| pin | result | got |
|---|---|---|
| ConstructedStringFormattingTest.test_empty | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConstructedStringFormattingTest.test_group_without_rules | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConstructedStringFormattingTest.test_group_without_user_agent | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |

## Quarantined at conversion

| test | reason |
|---|---|
| NetworkTestCase.test_basic | decorator:support.requires_working_socket |
| NetworkTestCase.test_can_fetch | decorator:support.requires_working_socket |
| NetworkTestCase.test_read_404 | decorator:support.requires_working_socket |
| BaseRobotTest.test_good_urls | helper:setUp(uses-self.parser) |
| BaseRobotTest.test_bad_urls | helper:setUp(uses-self.parser) |
| BaseRobotTest.test_site_maps | helper:setUp(uses-self.parser) |
| BaseRobotTest.test_string_formatting | helper:setUp(uses-self.parser) |
| BaseRequestRateTest.test_request_rate | helper:setUp(uses-self.parser) |
| LocalNetworkTestCase.testRead | uses-self.server |
| HttpErrorsTestCase.testUnauthorized | helper:setUp(uses-self.server) |
| HttpErrorsTestCase.testForbidden | helper:setUp(uses-self.server) |
| HttpErrorsTestCase.testNotFound | helper:setUp(uses-self.server) |
| HttpErrorsTestCase.testTeapot | helper:setUp(uses-self.server) |
| HttpErrorsTestCase.testServiceUnavailable | helper:setUp(uses-self.server) |

## Expected vs got

### ConstructedStringFormattingTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConstructedStringFormattingTest.test_group_without_rules (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConstructedStringFormattingTest.test_group_without_user_agent (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">
