# Triage report: `conv_keyword_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_keyword.py
- guest leg: 0/9 marks
- pins: **9 passed** / 9 run (+2 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| Test_iskeyword.test_true_is_a_keyword | PASS | |
| Test_iskeyword.test_uppercase_true_is_not_a_keyword | PASS | |
| Test_iskeyword.test_none_value_is_not_a_keyword | PASS | |
| Test_iskeyword.test_all_keywords_fail_to_be_used_as_names | PASS | |
| Test_iskeyword.test_all_soft_keywords_can_be_used_as_names | PASS | |
| Test_iskeyword.test_async_and_await_are_keywords | PASS | |
| Test_iskeyword.test_soft_keywords | PASS | |
| Test_iskeyword.test_keywords_are_sorted | PASS | |
| Test_iskeyword.test_softkeywords_are_sorted | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| Test_iskeyword.test_changing_the_kwlist_does_not_affect_iskeyword | self.addCleanup |
| Test_iskeyword.test_changing_the_softkwlist_does_not_affect_issoftkeyword | self.addCleanup |
