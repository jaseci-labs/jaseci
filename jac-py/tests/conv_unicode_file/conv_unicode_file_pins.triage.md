# Triage report: `conv_unicode_file_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_unicode_file.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+0 quarantined of 2 extracted)

| pin | result | got |
|---|---|---|
| TestUnicodeFiles.test_single_files | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestUnicodeFiles.test_directories | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |

## Expected vs got

### TestUnicodeFiles.test_directories (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestUnicodeFiles.test_single_files (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">
