# Triage report: `conv_reprlib_pins.jac`

- source: reference/cpython/Lib/test/test_reprlib.py
- guest leg: 0/7 marks
- pins: **5 passed** / 7 run (+26 quarantined of 33 extracted)

| pin | result | got |
|---|---|---|
| ReprTests.test_init_kwargs | PASS | |
| ReprTests.test_unsortable | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC KeyError 'host:1000003'"> |
| ReprTests.test_shadowed_stdlib_array | PASS | |
| ReprTests.test_shadowed_builtin | PASS | |
| ReprTests.test_custom_repr | PASS | |
| ReprTests.test_custom_repr_class_with_spaces | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'TypeWithSpaces\', \'type with spaces\')"'> |
| TestRecursiveRepr.test__wrapped__ | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| LongReprTest.test_object | decorator:unittest.skip |
| LongReprTest.test_builtin_function | decorator:unittest.skip |
| ReprTests.test_string | uses-self.assertEqual |
| ReprTests.test_tuple | uses-self.assertEqual |
| ReprTests.test_container | uses-self.assertEqual |
| ReprTests.test_set_literal | uses-self.assertEqual |
| ReprTests.test_frozenset | uses-self.assertEqual |
| ReprTests.test_numbers | self.assertRegex |
| ReprTests.test_instance | self.assertStartsWith |
| ReprTests.test_lambda | self.assertStartsWith |
| ReprTests.test_builtin_function | self.assertStartsWith |
| ReprTests.test_range | uses-self.assertEqual |
| ReprTests.test_nesting | uses-self.assertEqual |
| ReprTests.test_cell | self.assertRegex |
| ReprTests.test_descriptors | uses-self.assertEqual |
| ReprTests.test_valid_indent | uses-self.subTest |
| ReprTests.test_invalid_indent | uses-self.subTest |
| LongReprTest.test_module | helper:setUp(uses-self.pkgname) |
| LongReprTest.test_type | helper:setUp(uses-self.pkgname) |
| LongReprTest.test_class | helper:setUp(uses-self.pkgname) |
| LongReprTest.test_instance | helper:setUp(uses-self.pkgname) |
| LongReprTest.test_method | helper:setUp(uses-self.pkgname) |
| TestRecursiveRepr.test_recursive_repr | unresolved-name:MyContainer |
| TestRecursiveRepr.test_assigned_attributes | unresolved-name:MyContainer3 |
| TestRecursiveRepr.test__type_params__ | unresolved-name:T |
| TestRecursiveRepr.test_annotations | unresolved-name:undefined |

## Expected vs got

### ReprTests.test_custom_repr_class_with_spaces (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'TypeWithSpaces\', \'type with spaces\')"'>

### ReprTests.test_unsortable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC KeyError 'host:1000003'">
