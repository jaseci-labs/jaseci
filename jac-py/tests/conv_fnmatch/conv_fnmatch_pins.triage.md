# Triage report: `conv_fnmatch_pins.jac`

- source: reference/cpython/Lib/test/test_fnmatch.py
- guest leg: 0/11 marks
- pins: **10 passed** / 11 run (+13 quarantined of 24 extracted)

| pin | result | got |
|---|---|---|
| FnmatchTestCase.test_mix_bytes_str | PASS | |
| TranslateTestCase.test_translate | PASS | |
| TranslateTestCase.test_star_indices_locations | PASS | |
| FilterTestCase.test_filter | PASS | |
| FilterTestCase.test_mix_bytes_str | PASS | |
| FilterTestCase.test_case | PASS | |
| FilterTestCase.test_sep | PASS | |
| FilterFalseTestCase.test_filterfalse | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertListEqual\', [b\'Ruby\', b\'Tcl\'], [b\'Ruby\', b\'Tcl\'])"'> |
| FilterFalseTestCase.test_mix_bytes_str | PASS | |
| FilterFalseTestCase.test_case | PASS | |
| FilterFalseTestCase.test_sep | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| FnmatchTestCase.test_fnmatch | uses-self.check_match |
| FnmatchTestCase.test_slow_fnmatch | uses-self.check_match |
| FnmatchTestCase.test_fnmatchcase | uses-self.check_match |
| FnmatchTestCase.test_bytes | self.check_match |
| FnmatchTestCase.test_case | uses-self.check_match |
| FnmatchTestCase.test_sep | uses-self.check_match |
| FnmatchTestCase.test_char_set | uses-self.check_match |
| FnmatchTestCase.test_range | uses-self.check_match |
| FnmatchTestCase.test_sep_in_char_set | uses-self.check_match |
| FnmatchTestCase.test_sep_in_range | uses-self.check_match |
| FnmatchTestCase.test_warnings | uses-self.check_match |
| TranslateTestCase.test_translate_wildcards | uses-self.subTest |
| TranslateTestCase.test_translate_expressions | uses-self.subTest |

## Expected vs got

### FilterFalseTestCase.test_filterfalse (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertListEqual\', [b\'Ruby\', b\'Tcl\'], [b\'Ruby\', b\'Tcl\'])"'>
