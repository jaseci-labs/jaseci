# Triage report: `conv_genericclass_pins.jac`

- source: reference/cpython/Lib/test/test_genericclass.py
- guest leg: 0/20 marks
- pins: **14 passed** / 20 run (+2 quarantined of 22 extracted)

| pin | result | got |
|---|---|---|
| TestMROEntry.test_mro_entry_signature | PASS | |
| TestMROEntry.test_mro_entry_none | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (), (<class \'object\'>,))"'> |
| TestMROEntry.test_mro_entry_with_builtins | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| TestMROEntry.test_mro_entry_with_builtins_2 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC object ''"> |
| TestMROEntry.test_mro_entry_errors | PASS | |
| TestMROEntry.test_mro_entry_errors_2 | PASS | |
| TestMROEntry.test_mro_entry_metaclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**orig_bases**'"> |
| TestMROEntry.test_mro_entry_type_call | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| TestClassGetitem.test_class_getitem | PASS | |
| TestClassGetitem.test_class_getitem_format | PASS | |
| TestClassGetitem.test_class_getitem_inheritance | PASS | |
| TestClassGetitem.test_class_getitem_inheritance_2 | PASS | |
| TestClassGetitem.test_class_getitem_classmethod | PASS | |
| TestClassGetitem.test_class_getitem_patched | PASS | |
| TestClassGetitem.test_class_getitem_with_builtins | PASS | |
| TestClassGetitem.test_class_getitem_errors | PASS | |
| TestClassGetitem.test_class_getitem_errors_2 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| TestClassGetitem.test_class_getitem_metaclass | PASS | |
| TestClassGetitem.test_class_getitem_with_metaclass | PASS | |
| TestClassGetitem.test_class_getitem_metaclass_first | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| CAPITest.test_c_class | decorator:support.cpython_only |
| TestMROEntry.test_mro_entry | uses-self.**class** |

## Expected vs got

### TestClassGetitem.test_class_getitem_errors_2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### TestMROEntry.test_mro_entry_metaclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**orig_bases**'">

### TestMROEntry.test_mro_entry_none (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (), (<class \'object\'>,))"'>

### TestMROEntry.test_mro_entry_type_call (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### TestMROEntry.test_mro_entry_with_builtins (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">

### TestMROEntry.test_mro_entry_with_builtins_2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC object ''">
