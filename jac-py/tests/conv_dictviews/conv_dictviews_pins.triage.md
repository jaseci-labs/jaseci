# Triage report: `conv_dictviews_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_dictviews.py
- guest leg: 0/16 marks
- pins: **10 passed** / 16 run (+0 quarantined of 16 extracted)

| pin | result | got |
|---|---|---|
| DictSetTest.test_constructors_not_callable | PASS | |
| DictSetTest.test_dict_keys | PASS | |
| DictSetTest.test_dict_items | PASS | |
| DictSetTest.test_dict_mixed_keys_items | PASS | |
| DictSetTest.test_dict_values | PASS | |
| DictSetTest.test_dict_repr | PASS | |
| DictSetTest.test_keys_set_operations | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', frozenset({\'d\'}), <class \'set\'>)"'> |
| DictSetTest.test_items_set_operations | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'isdisjoint'"> |
| DictSetTest.test_set_operations_with_iterator | PASS | |
| DictSetTest.test_set_operations_with_noniterable | PASS | |
| DictSetTest.test_recursive_repr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'"> |
| DictSetTest.test_deeply_nested_repr | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'skip_emscripten_stack_overflow' from '<unknown>'"> |
| DictSetTest.test_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| DictSetTest.test_compare_error | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Exc ''"> |
| DictSetTest.test_pickle | PASS | |
| DictSetTest.test_abc_registry | PASS | |

## Expected vs got

### DictSetTest.test_compare_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Exc ''">

### DictSetTest.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### DictSetTest.test_deeply_nested_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'skip_emscripten_stack_overflow' from '<unknown>'">

### DictSetTest.test_items_set_operations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'isdisjoint'">

### DictSetTest.test_keys_set_operations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', frozenset({\'d\'}), <class \'set\'>)"'>

### DictSetTest.test_recursive_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'maximum recursion depth exceeded'">
