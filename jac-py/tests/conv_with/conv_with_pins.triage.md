# Triage report: `conv_with_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_with.py
- guest leg: 0/18 marks
- pins: **12 passed** / 18 run (+36 quarantined of 54 extracted)

| pin | result | got |
|---|---|---|
| FailureTestCase.testEnterAttributeError | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**enter**'"> |
| FailureTestCase.testExitAttributeError | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'object\' object has no attribute \'**exit**\'"'> |
| FailureTestCase.testWithForAsyncManager | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**exit**'"> |
| FailureTestCase.testAssignmentToNoneError | PASS | |
| FailureTestCase.testAssignmentToTupleOnlyContainingNoneError | PASS | |
| FailureTestCase.testAssignmentToTupleContainingNoneError | PASS | |
| FailureTestCase.testEnterThrows | PASS | |
| FailureTestCase.testExitThrows | PASS | |
| ExceptionalTestCase.testRaisedStopIteration1 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC RuntimeError 'generator raised StopIteration'"> |
| ExceptionalTestCase.testRaisedStopIteration2 | PASS | |
| ExceptionalTestCase.testRaisedStopIteration3 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC RuntimeError 'generator raised StopIteration'"> |
| ExceptionalTestCase.testRaisedGeneratorExit1 | PASS | |
| ExceptionalTestCase.testRaisedGeneratorExit2 | PASS | |
| ExceptionalTestCase.testErrorsInBool | PASS | |
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
| NestedNonexceptionalTestCase.testSingleArgInlineGeneratorSyntax | unresolved-name:Nested |
| NestedNonexceptionalTestCase.testSingleArgBoundToNonTuple | unresolved-name:Nested |
| NestedNonexceptionalTestCase.testSingleArgBoundToSingleElementParenthesizedList | unresolved-name:Nested |
| NestedNonexceptionalTestCase.testSingleArgBoundToMultipleElementTupleError | unresolved-name:Nested |
| NestedNonexceptionalTestCase.testSingleArgUnbound | unresolved-name:MockNested |
| NestedNonexceptionalTestCase.testMultipleArgUnbound | unresolved-name:MockNested |
| NestedNonexceptionalTestCase.testMultipleArgBound | unresolved-name:MockNested |
| ExceptionalTestCase.testMultipleResourcesInSingleStatement | unresolved-name:MockNested |
| AssignmentTargetTestCase.testSingleComplexTarget | self.assertHasAttr |
| NestedWith.testNoExceptions | uses-self.Dummy |
| NestedWith.testExceptionInExprList | uses-self.Dummy |
| NestedWith.testExceptionInEnter | uses-self.Dummy |
| NestedWith.testExceptionInExit | uses-self.Dummy |
| NestedWith.testEnterReturnsTuple | uses-self.Dummy |
| NestedWith.testExceptionLocation | uses-self.Dummy |
| NonexceptionalTestCase.testInlineGeneratorSyntax | host-raised:NameError: name 'MockContextManager' is not defined |
| NonexceptionalTestCase.testUnboundGenerator | host-raised:NameError: name 'MockContextManager' is not defined |
| NonexceptionalTestCase.testInlineGeneratorBoundSyntax | host-raised:NameError: name 'MockContextManager' is not defined |
| NonexceptionalTestCase.testInlineGeneratorBoundToExistingVariable | host-raised:NameError: name 'MockContextManager' is not defined |
| NonexceptionalTestCase.testInlineGeneratorBoundToDottedVariable | host-raised:NameError: name 'MockContextManager' is not defined |
| NonexceptionalTestCase.testBoundGenerator | host-raised:NameError: name 'MockContextManager' is not defined |
| NonexceptionalTestCase.testNestedSingleStatements | host-raised:NameError: name 'MockContextManager' is not defined |
| ExceptionalTestCase.testSingleResource | host-raised:NameError: name 'MockContextManager' is not defined |
| ExceptionalTestCase.testExceptionNormalized | host-raised:NameError: name 'MockContextManager' is not defined |
| ExceptionalTestCase.testNestedSingleStatements | host-raised:NameError: name 'MockContextManager' is not defined |
| ExceptionalTestCase.testNestedExceptionBeforeInnerStatement | host-raised:NameError: name 'MockContextManager' is not defined |
| ExceptionalTestCase.testNestedExceptionAfterInnerStatement | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithBreak | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithContinue | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithReturn | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithYield | host-raised:NameError: name 'MockContextManager' is not defined |
| NonLocalFlowControlTestCase.testWithRaise | host-raised:NameError: name 'MockContextManager' is not defined |

## Expected vs got

### AssignmentTargetTestCase.testWithExtendedTargets (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC ValueError 'not enough values to unpack (expected at least 2, got 0)'">

### ExceptionalTestCase.testRaisedStopIteration1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC RuntimeError 'generator raised StopIteration'">

### ExceptionalTestCase.testRaisedStopIteration3 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC RuntimeError 'generator raised StopIteration'">

### FailureTestCase.testEnterAttributeError (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**enter**'">

### FailureTestCase.testExitAttributeError (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'object\' object has no attribute \'**exit**\'"'>

### FailureTestCase.testWithForAsyncManager (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**exit**'">
