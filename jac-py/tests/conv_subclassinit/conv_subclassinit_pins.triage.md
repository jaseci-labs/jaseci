# Triage report: `conv_subclassinit_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_subclassinit.py
- guest leg: 0/14 marks
- pins: **8 passed** / 14 run (+3 quarantined of 17 extracted)

| pin | result | got |
|---|---|---|
| Test.test_init_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| Test.test_init_subclass_dict | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| Test.test_init_subclass_kwargs | PASS | |
| Test.test_init_subclass_error | PASS | |
| Test.test_init_subclass_wrong | PASS | |
| Test.test_init_subclass_skipped | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| Test.test_init_subclass_diamond | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| Test.test_set_name | PASS | |
| Test.test_set_name_lookup | PASS | |
| Test.test_set_name_init_subclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'owner'"> |
| Test.test_set_name_modifying_dict | PASS | |
| Test.test_errors | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'metaclass conflict: the metaclass of a derived class must be a (non-strict) subclass of the metaclasses of all its bases'"> |
| Test.test_errors_changed_pep487 | PASS | |
| Test.test_type | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| Test.test_set_name_metaclass | uses-self.assertEqual |
| Test.test_set_name_error | self.assertRegex |
| Test.test_set_name_wrong | self.assertRegex |

## Expected vs got

### Test.test_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'metaclass conflict: the metaclass of a derived class must be a (non-strict) subclass of the metaclasses of all its bases'">

### Test.test_init_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### Test.test_init_subclass_diamond (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### Test.test_init_subclass_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### Test.test_init_subclass_skipped (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### Test.test_set_name_init_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'owner'">
