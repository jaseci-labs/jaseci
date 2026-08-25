# Triage report: `conv_positional_only_arg_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_positional_only_arg.py
- guest leg: 0/25 marks
- pins: **9 passed** / 25 run (+3 quarantined of 28 extracted)

| pin | result | got |
|---|---|---|
| PositionalOnlyTestCase.test_optional_positional_only_args | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_syntax_for_many_positional_only | PASS | |
| PositionalOnlyTestCase.test_pos_only_definition | PASS | |
| PositionalOnlyTestCase.test_pos_only_call_via_unpacking | PASS | |
| PositionalOnlyTestCase.test_use_positional_as_keyword | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_positional_only_and_arg_invalid_calls | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_positional_only_and_optional_arg_invalid_calls | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_positional_only_and_kwonlyargs_invalid_calls | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_positional_only_invalid_calls | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_positional_only_with_optional_invalid_calls | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_no_standard_args_usage | PASS | |
| PositionalOnlyTestCase.test_change_default_pos_only | PASS | |
| PositionalOnlyTestCase.test_lambdas | PASS | |
| PositionalOnlyTestCase.test_posonly_methods | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_module_function | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_closures | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_annotations_in_closures | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**annotations**'"> |
| PositionalOnlyTestCase.test_same_keyword_as_positional_with_kwargs | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_mangling | PASS | |
| PositionalOnlyTestCase.test_too_many_arguments | PASS | |
| PositionalOnlyTestCase.test_serialization | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle <function global_pos_only_f at 0x7fd26ee13690>: it\'s not found as ceval.global_pos_only_f"'> |
| PositionalOnlyTestCase.test_async | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_generator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| PositionalOnlyTestCase.test_super | PASS | |
| PositionalOnlyTestCase.test_annotations_constant_fold | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |

## Quarantined at conversion

| test | reason |
|---|---|
| PositionalOnlyTestCase.test_invalid_syntax_errors | host-raised:NameError: name 'self' is not defined |
| PositionalOnlyTestCase.test_invalid_syntax_errors_async | host-raised:NameError: name 'self' is not defined |
| PositionalOnlyTestCase.test_invalid_syntax_lambda | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### PositionalOnlyTestCase.test_annotations_constant_fold (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### PositionalOnlyTestCase.test_annotations_in_closures (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**annotations**'">

### PositionalOnlyTestCase.test_async (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_closures (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_generator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_module_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_optional_positional_only_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_positional_only_and_arg_invalid_calls (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_positional_only_and_kwonlyargs_invalid_calls (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_positional_only_and_optional_arg_invalid_calls (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_positional_only_invalid_calls (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_positional_only_with_optional_invalid_calls (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_posonly_methods (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_same_keyword_as_positional_with_kwargs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### PositionalOnlyTestCase.test_serialization (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle <function global_pos_only_f at 0x7fd26ee13690>: it\'s not found as ceval.global_pos_only_f"'>

### PositionalOnlyTestCase.test_use_positional_as_keyword (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">
