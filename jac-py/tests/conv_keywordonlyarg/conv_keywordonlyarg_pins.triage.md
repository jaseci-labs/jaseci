# Triage report: `conv_keywordonlyarg_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_keywordonlyarg.py
- guest leg: 0/7 marks
- pins: **6 passed** / 7 run (+4 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| KeywordOnlyArgTestCase.testSyntaxErrorForFunctionDefinition | PASS | |
| KeywordOnlyArgTestCase.testSyntaxForManyArguments | PASS | |
| KeywordOnlyArgTestCase.testSyntaxErrorForFunctionCall | PASS | |
| KeywordOnlyArgTestCase.testKwDefaults | PASS | |
| KeywordOnlyArgTestCase.test_kwonly_methods | PASS | |
| KeywordOnlyArgTestCase.test_issue13343 | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| KeywordOnlyArgTestCase.test_mangling | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| KeywordOnlyArgTestCase.testTooManyPositionalErrorMessage | unresolved-name:exc |
| KeywordOnlyArgTestCase.testRaiseErrorFuncallWithUnexpectedKeywordArgument | unresolved-name:Foo |
| KeywordOnlyArgTestCase.testFunctionCall | unresolved-name:Foo |
| KeywordOnlyArgTestCase.test_default_evaluation_order | unresolved-name:c |

## Expected vs got

### KeywordOnlyArgTestCase.test_issue13343 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>
