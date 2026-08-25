# Triage report: `conv_isinstance_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_isinstance.py
- guest leg: 0/11 marks
- pins: **9 passed** / 11 run (+12 quarantined of 23 extracted)

| pin | result | got |
|---|---|---|
| TestIsInstanceExceptions.test_class_has_no_bases | PASS | |
| TestIsInstanceExceptions.test_bases_raises_other_than_attribute_error | PASS | |
| TestIsInstanceExceptions.test_dont_mask_non_attribute_error | PASS | |
| TestIsInstanceExceptions.test_mask_attribute_error | PASS | |
| TestIsInstanceExceptions.test_isinstance_dont_mask_non_attribute_error | PASS | |
| TestIsSubclassExceptions.test_dont_mask_non_attribute_error | PASS | |
| TestIsSubclassExceptions.test_mask_attribute_error | PASS | |
| TestIsSubclassExceptions.test_dont_mask_non_attribute_error_in_cls_arg | PASS | |
| TestIsSubclassExceptions.test_mask_attribute_error_in_cls_arg | PASS | |
| TestIsInstanceIsSubclass.test_issubclass_refcount_handling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', True, False)"'> |
| TestIsInstanceIsSubclass.test_infinite_recursion_in_bases | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'infinite_recursion'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestIsInstanceIsSubclass.test_subclass_recursion_limit | decorator:support.skip_wasi_stack_overflow |
| TestIsInstanceIsSubclass.test_isinstance_recursion_limit | decorator:support.skip_wasi_stack_overflow |
| TestIsInstanceIsSubclass.test_infinite_recursion_via_bases_tuple | decorator:support.skip_if_unlimited_stack_size |
| TestIsInstanceIsSubclass.test_infinite_cycle_in_bases | decorator:support.skip_if_unlimited_stack_size |
| TestIsInstanceIsSubclass.test_isinstance_normal | unresolved-name:Child |
| TestIsInstanceIsSubclass.test_isinstance_abstract | unresolved-name:Child |
| TestIsInstanceIsSubclass.test_isinstance_with_or_union | unresolved-name:Super |
| TestIsInstanceIsSubclass.test_subclass_normal | unresolved-name:Child |
| TestIsInstanceIsSubclass.test_subclass_abstract | unresolved-name:Child |
| TestIsInstanceIsSubclass.test_subclass_tuple | unresolved-name:Child |
| TestIsInstanceIsSubclass.test_subclass_with_union | unresolved-name:Child |
| TestIsInstanceIsSubclass.test_infinitely_many_bases | uses-self.assertEqual |

## Expected vs got

### TestIsInstanceIsSubclass.test_infinite_recursion_in_bases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'infinite_recursion'">

### TestIsInstanceIsSubclass.test_issubclass_refcount_handling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', True, False)"'>
