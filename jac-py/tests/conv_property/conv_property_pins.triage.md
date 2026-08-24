# Triage report: `conv_property_pins.jac`

- source: reference/cpython/Lib/test/test_property.py
- guest leg: 0/5 marks
- pins: **1 passed** / 5 run (+23 quarantined of 28 extracted)

| pin | result | got |
|---|---|---|
| PropertyTests.test_property___isabstractmethod__descriptor | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**isabstractmethod**'"> |
| PropertyTests.test_property_name | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**name**'"> |
| PropertyTests.test_property_set_name_incorrect_args | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**set_name**'"> |
| PropertyTests.test_property_setname_on_property_subclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**set_name**'"> |
| PropertySubclassTests.test_property_with_slots_no_docstring | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| PropertyTests.test_property_decorator_subclass_doc | decorator:unittest.skipIf |
| PropertyTests.test_property_decorator_baseclass_doc | decorator:unittest.skipIf |
| PropertyTests.test_property_getter_doc_override | decorator:unittest.skipIf |
| PropertyTests.test_property_builtin_doc_writable | decorator:unittest.skipIf |
| PropertyTests.test_property_decorator_doc_writable | decorator:unittest.skipIf |
| PropertyTests.test_refleaks_in___init__ | decorator:support.refcount_test |
| PropertyTests.test_gh_115618 | decorator:support.refcount_test |
| PropertySubclassTests.test_slots_docstring_copy_exception | decorator:support.requires_docstrings |
| PropertySubclassTests.test_property_with_slots_docstring_silently_dropped | decorator:unittest.skipIf |
| PropertySubclassTests.test_property_with_slots_and_doc_slot_docstring_present | decorator:unittest.skipIf |
| PropertySubclassTests.test_issue41287 | decorator:unittest.skipIf |
| PropertySubclassTests.test_docstring_copy | decorator:unittest.skipIf |
| PropertySubclassTests.test_docstring_copy2 | decorator:unittest.skipIf |
| PropertySubclassTests.test_prefer_explicit_doc | decorator:unittest.skipIf |
| PropertySubclassTests.test_property_setter_copies_getter_docstring | decorator:unittest.skipIf |
| PropertySubclassTests.test_property_new_getter_new_docstring | decorator:unittest.skipIf |
| PropertyTests.test_property_decorator_baseclass | self.assertNotHasAttr |
| PropertyTests.test_property_decorator_subclass | unresolved-name:PropertyDel |
| PropertyTests.test_property_decorator_doc | unresolved-name:PropertyDocBase |
| PropertySubclassTests.test_property_no_doc_on_getter | unresolved-name:PropertySub |
| _PropertyUnreachableAttribute.test_get_property | uses-self.obj |
| _PropertyUnreachableAttribute.test_set_property | uses-self.obj |
| _PropertyUnreachableAttribute.test_del_property | uses-self.obj |

## Expected vs got

### PropertyTests.test_property___isabstractmethod__descriptor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**isabstractmethod**'">

### PropertyTests.test_property_name (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**name**'">

### PropertyTests.test_property_set_name_incorrect_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**set_name**'">

### PropertyTests.test_property_setname_on_property_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**set_name**'">
