# Triage report: `conv_string_literals_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_string_literals.py
- guest leg: 0/10 marks
- pins: **0 passed** / 10 run (+10 quarantined of 20 extracted)

| pin | result | got |
|---|---|---|
| TestLiterals.test_template | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_eval_str_normal | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_eval_str_incomplete | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_invalid_escape_locations_with_offset | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_eval_str_raw | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_eval_bytes_normal | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_eval_bytes_incomplete | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_eval_bytes_raw | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_eval_str_u | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestLiterals.test_uppercase_prefixes | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestLiterals.test_eval_str_invalid_escape | self.assertRegex |
| TestLiterals.test_eval_str_invalid_octal_escape | uses-self.assertWarns |
| TestLiterals.test_eval_bytes_invalid_escape | uses-self.assertWarns |
| TestLiterals.test_eval_bytes_invalid_octal_escape | uses-self.assertWarns |
| TestLiterals.test_file_utf_8_error | uses-self.check_encoding |
| TestLiterals.test_file_utf_8 | host-raised:NameError: name 'self' is not defined |
| TestLiterals.test_file_utf8 | host-raised:NameError: name 'self' is not defined |
| TestLiterals.test_file_iso_8859_1 | host-raised:NameError: name 'self' is not defined |
| TestLiterals.test_file_latin_1 | host-raised:NameError: name 'self' is not defined |
| TestLiterals.test_file_latin9 | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### TestLiterals.test_eval_bytes_incomplete (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_eval_bytes_normal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_eval_bytes_raw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_eval_str_incomplete (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_eval_str_normal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_eval_str_raw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_eval_str_u (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_invalid_escape_locations_with_offset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_template (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestLiterals.test_uppercase_prefixes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">
