# Triage report: `conv_dynamicclassattribute_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_dynamicclassattribute.py
- guest leg: 0/1 marks
- pins: **1 passed** / 1 run (+11 quarantined of 12 extracted)

| pin | result | got |
|---|---|---|
| PropertyTests.test_property___isabstractmethod__descriptor | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| PropertyTests.test_property_decorator_subclass_doc | decorator:unittest.skipIf |
| PropertyTests.test_property_decorator_baseclass_doc | decorator:unittest.skipIf |
| PropertyTests.test_property_getter_doc_override | decorator:unittest.skipIf |
| PropertySubclassTests.test_slots_docstring_copy_exception | decorator:unittest.skipIf |
| PropertySubclassTests.test_docstring_copy | decorator:unittest.skipIf |
| PropertySubclassTests.test_property_setter_copies_getter_docstring | decorator:unittest.skipIf |
| PropertySubclassTests.test_property_new_getter_new_docstring | decorator:unittest.skipIf |
| PropertyTests.test_property_decorator_baseclass | self.assertNotHasAttr |
| PropertyTests.test_property_decorator_subclass | unresolved-name:PropertyDel |
| PropertyTests.test_property_decorator_doc | unresolved-name:PropertyDocBase |
| PropertyTests.test_abstract_virtual | unresolved-name:ClassWithAbstractVirtualProperty |
