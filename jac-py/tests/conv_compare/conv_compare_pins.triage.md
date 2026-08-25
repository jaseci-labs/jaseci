# Triage report: `conv_compare_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_compare.py
- guest leg: 0/9 marks
- pins: **7 passed** / 9 run (+7 quarantined of 16 extracted)

| pin | result | got |
|---|---|---|
| ComparisonSimpleTest.test_other_delegation | PASS | |
| ComparisonSimpleTest.test_issue_1393 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'ALWAYS_EQ' from '<unknown>'"> |
| ComparisonFullTest.test_objects | PASS | |
| ComparisonFullTest.test_str_subclass | PASS | |
| ComparisonFullTest.test_numbers | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'int\' and \'Fraction\'"'> |
| ComparisonFullTest.test_sequences | PASS | |
| ComparisonFullTest.test_bytes | PASS | |
| ComparisonFullTest.test_sets | PASS | |
| ComparisonFullTest.test_mappings | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| ComparisonSimpleTest.test_id_comparisons | uses-self.Empty |
| ComparisonSimpleTest.test_ne_defaults_to_not_eq | uses-self.Cmp |
| ComparisonSimpleTest.test_ne_high_priority | self.assertSequenceEqual |
| ComparisonSimpleTest.test_ne_low_priority | self.assertSequenceEqual |
| ComparisonSimpleTest.test_comparisons | host-raised:AttributeError: '_SelfNS' object has no attribute 'candidates' |
| ComparisonFullTest.test_comp_classes_same | host-raised:AttributeError: '_SelfNS' object has no attribute 'all_comp_classes' |
| ComparisonFullTest.test_comp_classes_different | host-raised:AttributeError: '_SelfNS' object has no attribute 'all_comp_classes' |

## Expected vs got

### ComparisonFullTest.test_numbers (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'int\' and \'Fraction\'"'>

### ComparisonSimpleTest.test_issue_1393 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'ALWAYS_EQ' from '<unknown>'">
