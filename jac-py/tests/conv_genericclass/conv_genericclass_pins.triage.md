# Triage report: `conv_genericclass_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_genericclass.py
- guest leg: 0/21 marks
- pins: **21 passed** / 21 run (+1 quarantined of 22 extracted)

| pin | result | got |
|---|---|---|
| TestMROEntry.test_mro_entry_signature | PASS | |
| TestMROEntry.test_mro_entry | PASS | |
| TestMROEntry.test_mro_entry_none | PASS | |
| TestMROEntry.test_mro_entry_with_builtins | PASS | |
| TestMROEntry.test_mro_entry_with_builtins_2 | PASS | |
| TestMROEntry.test_mro_entry_errors | PASS | |
| TestMROEntry.test_mro_entry_errors_2 | PASS | |
| TestMROEntry.test_mro_entry_metaclass | PASS | |
| TestMROEntry.test_mro_entry_type_call | PASS | |
| TestClassGetitem.test_class_getitem | PASS | |
| TestClassGetitem.test_class_getitem_format | PASS | |
| TestClassGetitem.test_class_getitem_inheritance | PASS | |
| TestClassGetitem.test_class_getitem_inheritance_2 | PASS | |
| TestClassGetitem.test_class_getitem_classmethod | PASS | |
| TestClassGetitem.test_class_getitem_patched | PASS | |
| TestClassGetitem.test_class_getitem_with_builtins | PASS | |
| TestClassGetitem.test_class_getitem_errors | PASS | |
| TestClassGetitem.test_class_getitem_errors_2 | PASS | |
| TestClassGetitem.test_class_getitem_metaclass | PASS | |
| TestClassGetitem.test_class_getitem_with_metaclass | PASS | |
| TestClassGetitem.test_class_getitem_metaclass_first | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| CAPITest.test_c_class | decorator:support.cpython_only |
