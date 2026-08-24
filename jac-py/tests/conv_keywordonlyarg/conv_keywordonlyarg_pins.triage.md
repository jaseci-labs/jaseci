# Triage report: `conv_keywordonlyarg_pins.jac`

- source: reference/cpython/Lib/test/test_keywordonlyarg.py
- guest leg: 0/5 marks
- pins: **3 passed** / 5 run (+6 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| KeywordOnlyArgTestCase.testSyntaxForManyArguments | PASS | |
| KeywordOnlyArgTestCase.testKwDefaults | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**kwdefaults**'"> |
| KeywordOnlyArgTestCase.test_kwonly_methods | PASS | |
| KeywordOnlyArgTestCase.test_issue13343 | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'collections.abc'"> |
| KeywordOnlyArgTestCase.test_mangling | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| KeywordOnlyArgTestCase.testSyntaxErrorForFunctionDefinition | self.assertRaisesSyntaxError |
| KeywordOnlyArgTestCase.testTooManyPositionalErrorMessage | unresolved-name:exc |
| KeywordOnlyArgTestCase.testSyntaxErrorForFunctionCall | self.assertRaisesSyntaxError |
| KeywordOnlyArgTestCase.testRaiseErrorFuncallWithUnexpectedKeywordArgument | unresolved-name:Foo |
| KeywordOnlyArgTestCase.testFunctionCall | unresolved-name:Foo |
| KeywordOnlyArgTestCase.test_default_evaluation_order | unresolved-name:c |

## Expected vs got

### KeywordOnlyArgTestCase.testKwDefaults (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**kwdefaults**'">

### KeywordOnlyArgTestCase.test_issue13343 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'collections.abc'">
