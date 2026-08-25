# Triage report: `conv_type_annotations_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_type_annotations.py
- guest leg: 0/46 marks
- pins: **7 passed** / 46 run (+2 quarantined of 48 extracted)

| pin | result | got |
|---|---|---|
| TypeAnnotationTests.test_lazy_create_annotations | PASS | |
| TypeAnnotationTests.test_setting_annotations | PASS | |
| TypeAnnotationTests.test_annotations_getset_raises | PASS | |
| TypeAnnotationTests.test_annotations_are_created_correctly | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'"> |
| TypeAnnotationTests.test_pep563_annotations | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_inspect'"> |
| TypeAnnotationTests.test_explicitly_set_annotations | PASS | |
| TypeAnnotationTests.test_explicitly_set_annotate | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TypeAnnotationTests.test_del_annotations_and_annotate | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**annotations**'"> |
| TypeAnnotationTests.test_descriptor_still_works | PASS | |
| TypeAnnotationTests.test_partially_executed_module | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| TypeAnnotationTests.test_no_cell | PASS | |
| TestSetupAnnotations.test_top_level | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| TestSetupAnnotations.test_blocks | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| TestSetupAnnotations.test_try | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| TestSetupAnnotations.test_try_star | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| TestSetupAnnotations.test_match | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| AnnotateTests.test_manual_annotate | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| AnnotateTests.test_user_defined_annotate | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| DeferredEvaluationTests.test_function | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**annotations**'"> |
| DeferredEvaluationTests.test_async_function | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**annotations**'"> |
| DeferredEvaluationTests.test_class | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'"> |
| DeferredEvaluationTests.test_module | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| DeferredEvaluationTests.test_class_scoping | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'"> |
| DeferredEvaluationTests.test_ignore_non_simple_annotations | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| DeferredEvaluationTests.test_generated_annotate | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| DeferredEvaluationTests.test_comprehension_in_annotation | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| DeferredEvaluationTests.test_class_annotation_dunder_classdict | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| DeferredEvaluationTests.test_future_annotations | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| DeferredEvaluationTests.test_set_annotations | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| DeferredEvaluationTests.test_name_clash_with_format | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| ConditionalAnnotationTests.test_with | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_simple_if | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_if_elif | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_try | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_try_star | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_while | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_for | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_match | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_nesting_override | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_nesting_outer | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_nesting_inner | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ConditionalAnnotationTests.test_non_name_annotations | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| RegressionTests.test_complex_comprehension_inlining | PASS | |
| RegressionTests.test_complex_comprehension_inlining_exec | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| RegressionTests.test_annotate_qualname | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |
| RegressionTests.test_module_level_annotation_plus_listcomp | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'run_code' from '<unknown>'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| DeferredEvaluationTests.test_no_exotic_expressions | host-raised:NameError: name 'self' is not defined |
| DeferredEvaluationTests.test_no_exotic_expressions_in_unevaluated_annotations | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### AnnotateTests.test_manual_annotate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### AnnotateTests.test_user_defined_annotate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_for (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_if_elif (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_match (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_nesting_inner (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_nesting_outer (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_nesting_override (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_non_name_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_simple_if (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_try (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_try_star (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_while (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ConditionalAnnotationTests.test_with (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### DeferredEvaluationTests.test_async_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**annotations**'">

### DeferredEvaluationTests.test_class (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'">

### DeferredEvaluationTests.test_class_annotation_dunder_classdict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### DeferredEvaluationTests.test_class_scoping (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'">

### DeferredEvaluationTests.test_comprehension_in_annotation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### DeferredEvaluationTests.test_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**annotations**'">

### DeferredEvaluationTests.test_future_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### DeferredEvaluationTests.test_generated_annotate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### DeferredEvaluationTests.test_ignore_non_simple_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### DeferredEvaluationTests.test_module (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### DeferredEvaluationTests.test_name_clash_with_format (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### DeferredEvaluationTests.test_set_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### RegressionTests.test_annotate_qualname (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### RegressionTests.test_complex_comprehension_inlining_exec (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### RegressionTests.test_module_level_annotation_plus_listcomp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### TestSetupAnnotations.test_blocks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### TestSetupAnnotations.test_match (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### TestSetupAnnotations.test_top_level (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### TestSetupAnnotations.test_try (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### TestSetupAnnotations.test_try_star (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### TypeAnnotationTests.test_annotations_are_created_correctly (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'">

### TypeAnnotationTests.test_del_annotations_and_annotate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**annotations**'">

### TypeAnnotationTests.test_explicitly_set_annotate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TypeAnnotationTests.test_partially_executed_module (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'run_code' from '<unknown>'">

### TypeAnnotationTests.test_pep563_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_inspect'">
