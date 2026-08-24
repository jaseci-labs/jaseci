# Triage report: `conv_fnmatch_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_fnmatch.py
- guest leg: 0/12 marks
- pins: **11 passed** / 12 run (+12 quarantined of 24 extracted)

| pin | result | got |
|---|---|---|
| FnmatchTestCase.test_mix_bytes_str | PASS | |
| FnmatchTestCase.test_bytes | PASS | |
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
| TranslateTestCase.test_translate_wildcards | uses-self.subTest |
| TranslateTestCase.test_translate_expressions | uses-self.subTest |
| FnmatchTestCase.test_fnmatch | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_slow_fnmatch | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_fnmatchcase | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_case | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_sep | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_char_set | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_range | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_sep_in_char_set | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_sep_in_range | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |
| FnmatchTestCase.test_warnings | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_match' |

## Expected vs got

### FilterFalseTestCase.test_filterfalse (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertListEqual\', [b\'Ruby\', b\'Tcl\'], [b\'Ruby\', b\'Tcl\'])"'>
