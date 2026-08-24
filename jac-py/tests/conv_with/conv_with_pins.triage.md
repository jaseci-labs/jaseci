# Triage report: `conv_with_pins.jac`

- source: reference/cpython/Lib/test/test_with.py
- guest leg: 0/11 marks
- pins: **7 passed** / 11 run (+43 quarantined of 54 extracted)

| pin | result | got |
|---|---|---|
| FailureTestCase.testEnterAttributeError | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**enter**'"> |
| FailureTestCase.testExitAttributeError | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'object\' object has no attribute \'**exit**\'"'> |
| FailureTestCase.testWithForAsyncManager | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**exit**'"> |
| FailureTestCase.testAssignmentToNoneError | PASS | |
| FailureTestCase.testAssignmentToTupleOnlyContainingNoneError | PASS | |
| FailureTestCase.testAssignmentToTupleContainingNoneError | PASS | |
| FailureTestCase.testExitThrows | PASS | |
| AssignmentTargetTestCase.testMultipleComplexTargets | PASS | |
| AssignmentTargetTestCase.testWithExtendedTargets | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC ValueError 'not enough values to unpack (expected at least 2, got 0)'"> |
| ExitSwallowsExceptionTestCase.testExitTrueSwallowsException | PASS | |
| ExitSwallowsExceptionTestCase.testExitFalseDoesntSwallowException | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| FailureTestCase.testNameError | unresolved-name:foo |
| FailureTestCase.testAsyncEnterAttributeError | unresolved-name:do_async_with |
| FailureTestCase.testAsyncExitAttributeError | unresolved-name:do_async_with |
| FailureTestCase.testAsyncWithForSyncManager | unresolved-name:do_async_with |
| FailureTestCase.testEnterThrows | uses-self.foo |
| NonexceptionalTestCase.testInlineGeneratorSyntax | helper:setUp(uses-self.TEST_EXCEPTION) |
| NonexceptionalTestCase.testUnboundGenerator | helper:setUp(uses-self.TEST_EXCEPTION) |
| NonexceptionalTestCase.testInlineGeneratorBoundSyntax | helper:setUp(uses-self.TEST_EXCEPTION) |
| NonexceptionalTestCase.testInlineGeneratorBoundToExistingVariable | helper:setUp(uses-self.TEST_EXCEPTION) |
| NonexceptionalTestCase.testInlineGeneratorBoundToDottedVariable | helper:setUp(uses-self.TEST_EXCEPTION) |
| NonexceptionalTestCase.testBoundGenerator | helper:setUp(uses-self.TEST_EXCEPTION) |
| NonexceptionalTestCase.testNestedSingleStatements | helper:setUp(uses-self.TEST_EXCEPTION) |
| NestedNonexceptionalTestCase.testSingleArgInlineGeneratorSyntax | helper:setUp(uses-self.TEST_EXCEPTION) |
| NestedNonexceptionalTestCase.testSingleArgBoundToNonTuple | helper:setUp(uses-self.TEST_EXCEPTION) |
| NestedNonexceptionalTestCase.testSingleArgBoundToSingleElementParenthesizedList | helper:setUp(uses-self.TEST_EXCEPTION) |
| NestedNonexceptionalTestCase.testSingleArgBoundToMultipleElementTupleError | helper:setUp(uses-self.TEST_EXCEPTION) |
| NestedNonexceptionalTestCase.testSingleArgUnbound | helper:setUp(uses-self.TEST_EXCEPTION) |
| NestedNonexceptionalTestCase.testMultipleArgUnbound | helper:setUp(uses-self.TEST_EXCEPTION) |
| NestedNonexceptionalTestCase.testMultipleArgBound | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testSingleResource | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testExceptionNormalized | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testNestedSingleStatements | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testMultipleResourcesInSingleStatement | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testNestedExceptionBeforeInnerStatement | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testNestedExceptionAfterInnerStatement | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testRaisedStopIteration1 | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testRaisedStopIteration2 | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testRaisedStopIteration3 | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testRaisedGeneratorExit1 | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testRaisedGeneratorExit2 | helper:setUp(uses-self.TEST_EXCEPTION) |
| ExceptionalTestCase.testErrorsInBool | helper:setUp(uses-self.TEST_EXCEPTION) |
| AssignmentTargetTestCase.testSingleComplexTarget | self.assertHasAttr |
| NestedWith.testNoExceptions | uses-self.Dummy |
| NestedWith.testExceptionInExprList | uses-self.Dummy |
| NestedWith.testExceptionInEnter | uses-self.Dummy |
| NestedWith.testExceptionInExit | uses-self.Dummy |
| NestedWith.testEnterReturnsTuple | uses-self.Dummy |
| NestedWith.testExceptionLocation | uses-self.subTest |
| NonLocalFlowControlTestCase.testWithBreak | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithContinue | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithReturn | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithYield | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithRaise | host-raised:NameError: name 'MockContextManager' is not defined |

## Expected vs got

### AssignmentTargetTestCase.testWithExtendedTargets (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC ValueError 'not enough values to unpack (expected at least 2, got 0)'">

### FailureTestCase.testEnterAttributeError (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**enter**'">

### FailureTestCase.testExitAttributeError (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'object\' object has no attribute \'**exit**\'"'>

### FailureTestCase.testWithForAsyncManager (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**exit**'">
