# Triage report: `conv_scope_pins.jac`

- source: reference/cpython/Lib/test/test_scope.py
- guest leg: 0/32 marks
- pins: **23 passed** / 32 run (+9 quarantined of 41 extracted)

| pin | result | got |
|---|---|---|
| ScopeTests.testSimpleNesting | PASS | |
| ScopeTests.testExtraNesting | PASS | |
| ScopeTests.testSimpleAndRebinding | PASS | |
| ScopeTests.testNestingGlobalNoFree | PASS | |
| ScopeTests.testNestingThroughClass | PASS | |
| ScopeTests.testNestingPlusFreeRefToGlobal | PASS | |
| ScopeTests.testNearestEnclosingScope | PASS | |
| ScopeTests.testMixedFreevarsAndCellvars | PASS | |
| ScopeTests.testFreeVarInMethod | PASS | |
| ScopeTests.testCellIsKwonlyArg | PASS | |
| ScopeTests.testCellIsArgAndEscapes | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**closure**'"> |
| ScopeTests.testCellIsLocalAndEscapes | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**closure**'"> |
| ScopeTests.testRecursion | PASS | |
| ScopeTests.testLambdas | PASS | |
| ScopeTests.testUnboundLocal | PASS | |
| ScopeTests.testUnboundLocal_AfterDel | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 62'"> |
| ScopeTests.testComplexDefinitions | PASS | |
| ScopeTests.testLeaks | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'"> |
| ScopeTests.testLocalsFunction | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIn\', \'h\', {\'fn\': <built-in function locals>, \'args\': [], \'kwargs\': {}})"'> |
| ScopeTests.testLocalsClass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIn\', \'y\', [\'fn\', \'args\', \'kwargs\'])"'> |
| ScopeTests.testBoundAndFree | PASS | |
| ScopeTests.testEvalExecFreeVars | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC NameError 'free variable is not set'"> |
| ScopeTests.testListCompLocalVars | PASS | |
| ScopeTests.testEvalFreeVars | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'> |
| ScopeTests.testNonLocalFunction | PASS | |
| ScopeTests.testNonLocalMethod | PASS | |
| ScopeTests.testGlobalInParallelNestedFunctions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'exec() argument 1 must be a code object'"> |
| ScopeTests.testNonLocalClass | PASS | |
| ScopeTests.testNonLocalGenerator | PASS | |
| ScopeTests.testNestedNonLocal | PASS | |
| ScopeTests.testTopIsNotSignificant | PASS | |
| ScopeTests.test_multiple_nesting | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| ScopeTests.testUnboundLocal_AugAssign | uses-self.fail |
| ScopeTests.testLocalsClass_WithTrace | self.addCleanup |
| ScopeTests.testInteractionWithTraceFunc | self.addCleanup |
| ScopeTests.testFreeingCell | unresolved-name:nestedcell_get |
| ScopeTests.testClassNamespaceOverridesClosure | self.assertNotHasAttr |
| ScopeTests.testCellLeak | uses-self.exc |
| ScopeTests.testUnoptimizedNamespaces | host-raised:NameError: name 'self' is not defined |
| ScopeTests.testScopeOfGlobalStmt | host-raised:NameError: name 'self' is not defined |
| ScopeTests.testClassAndGlobal | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### ScopeTests.testCellIsArgAndEscapes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**closure**'">

### ScopeTests.testCellIsLocalAndEscapes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**closure**'">

### ScopeTests.testEvalExecFreeVars (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC NameError 'free variable is not set'">

### ScopeTests.testEvalFreeVars (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'>

### ScopeTests.testGlobalInParallelNestedFunctions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'exec() argument 1 must be a code object'">

### ScopeTests.testLeaks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'">

### ScopeTests.testLocalsClass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIn\', \'y\', [\'fn\', \'args\', \'kwargs\'])"'>

### ScopeTests.testLocalsFunction (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIn\', \'h\', {\'fn\': <built-in function locals>, \'args\': [], \'kwargs\': {}})"'>

### ScopeTests.testUnboundLocal_AfterDel (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 62'">
