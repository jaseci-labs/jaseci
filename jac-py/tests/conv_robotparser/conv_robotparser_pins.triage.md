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
| BaseRobotTest.test_good_urls | host-raised:AttributeError: '_SelfNS' object has no attribute 'robots_txt' |
| BaseRobotTest.test_bad_urls | host-raised:AttributeError: '_SelfNS' object has no attribute 'robots_txt' |
| BaseRobotTest.test_site_maps | host-raised:AttributeError: '_SelfNS' object has no attribute 'robots_txt' |
| BaseRobotTest.test_string_formatting | host-raised:AttributeError: '_SelfNS' object has no attribute 'robots_txt' |
| BaseRequestRateTest.test_request_rate | host-raised:AttributeError: '_SelfNS' object has no attribute 'robots_txt' |
| LocalNetworkTestCase.testRead | host-raised:AttributeError: '_SelfNS' object has no attribute 'server' |
| HttpErrorsTestCase.testUnauthorized | host-raised:AttributeError: '_SelfNS' object has no attribute 'server' |
| HttpErrorsTestCase.testForbidden | host-raised:AttributeError: '_SelfNS' object has no attribute 'server' |
| HttpErrorsTestCase.testNotFound | host-raised:AttributeError: '_SelfNS' object has no attribute 'server' |
| HttpErrorsTestCase.testTeapot | host-raised:AttributeError: '_SelfNS' object has no attribute 'server' |
| HttpErrorsTestCase.testServiceUnavailable | host-raised:AttributeError: '_SelfNS' object has no attribute 'server' |

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
