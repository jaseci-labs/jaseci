# Triage report: `conv_bisect_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_bisect.py
- guest leg: 0/42 marks
- pins: **0 passed** / 42 run (+4 quarantined of 46 extracted)

| pin | result | got |
|---|---|---|
| TestBisectPython.test_precomputed | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_precomputed | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_negative_lo | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_negative_lo | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_large_range | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_large_range | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_large_pyrange | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_large_pyrange | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_optionalSlicing | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_optionalSlicing | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_backcompatibility | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_backcompatibility | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_keyword_args | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_keyword_args | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_lookups_with_key_function | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_lookups_with_key_function | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_insort | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_insort | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_insort_keynotNone | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_insort_keynotNone | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_lt_returns_non_bool | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_lt_returns_non_bool | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectPython.test_lt_returns_notimplemented | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestBisectC.test_lt_returns_notimplemented | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestInsortPython.test_backcompatibility | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestInsortC.test_backcompatibility | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestInsortPython.test_listDerived | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestInsortC.test_listDerived | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingPython.test_non_sequence | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingC.test_non_sequence | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingPython.test_len_only | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingC.test_len_only | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingPython.test_get_only | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingC.test_get_only | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingPython.test_cmp_err | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingC.test_cmp_err | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingPython.test_arg_parsing | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestErrorHandlingC.test_arg_parsing | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestDocExamplePython.test_grades | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestDocExampleC.test_grades | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestDocExamplePython.test_colors | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestDocExampleC.test_colors | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestBisectPython.test_random | unresolved-name:n |
| TestBisectC.test_random | unresolved-name:n |
| TestInsortPython.test_vsBuiltinSort | unresolved-name:n |
| TestInsortC.test_vsBuiltinSort | unresolved-name:n |

## Expected vs got

### TestBisectC.test_backcompatibility (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_insort (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_insort_keynotNone (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_keyword_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_large_pyrange (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_large_range (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_lookups_with_key_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_lt_returns_non_bool (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_lt_returns_notimplemented (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_negative_lo (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_optionalSlicing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectC.test_precomputed (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_backcompatibility (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_insort (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_insort_keynotNone (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_keyword_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_large_pyrange (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_large_range (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_lookups_with_key_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_lt_returns_non_bool (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_lt_returns_notimplemented (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_negative_lo (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_optionalSlicing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestBisectPython.test_precomputed (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestDocExampleC.test_colors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestDocExampleC.test_grades (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestDocExamplePython.test_colors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestDocExamplePython.test_grades (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingC.test_arg_parsing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingC.test_cmp_err (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingC.test_get_only (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingC.test_len_only (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingC.test_non_sequence (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingPython.test_arg_parsing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingPython.test_cmp_err (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingPython.test_get_only (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingPython.test_len_only (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestErrorHandlingPython.test_non_sequence (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestInsortC.test_backcompatibility (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestInsortC.test_listDerived (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestInsortPython.test_backcompatibility (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestInsortPython.test_listDerived (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">
