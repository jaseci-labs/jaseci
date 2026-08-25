# Triage report: `conv_doctest_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_doctest/test_doctest.py
- guest leg: 0/25 marks
- pins: **22 passed** / 25 run (+5 quarantined of 30 extracted)

| pin | result | got |
|---|---|---|
| test_Example | PASS | |
| test_DocTest | PASS | |
| TestDocTest.test_run | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDocTestFinder.test_issue35753 | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDocTestFinder.test_empty_namespace_package | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| test_DocTestParser | PASS | |
| test_testsource | PASS | |
| test_debug | PASS | |
| test_DocTestSuite | PASS | |
| test_DocTestSuite_errors | PASS | |
| test_DocFileSuite | PASS | |
| test_DocFileSuite_errors | PASS | |
| test_trailing_space_in_test | PASS | |
| test_look_in_unwrapped | PASS | |
| test_wrapped_c_func | PASS | |
| test_unittest_reportflags | PASS | |
| test_testfile | PASS | |
| test_testfile_errors | PASS | |
| test_lineendings | PASS | |
| test_testmod | PASS | |
| test_testmod_errors | PASS | |
| test_CLI | PASS | |
| test_no_trailing_whitespace_stripping | PASS | |
| test_run_doctestsuite_multiple_times | PASS | |
| test_syntax_error_with_incorrect_expected_note | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| test_hook | unresolved-name:TestHook |
| test_exception_with_note | host-raised:NameError: name 'note' is not defined |
| test_exception_with_multiple_notes | host-raised:ValueError: Text |
| test_syntax_error_with_note | host-raised:NameError: name 'cls' is not defined |
| test_syntax_error_subclass_from_stdlib | host-raised:ParseError: error error |

## Expected vs got

### TestDocTest.test_run (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDocTestFinder.test_empty_namespace_package (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestDocTestFinder.test_issue35753 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">
