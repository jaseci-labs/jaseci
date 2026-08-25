# Triage report: `conv_defaultdict_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_defaultdict.py
- guest leg: 0/13 marks
- pins: **6 passed** / 13 run (+0 quarantined of 13 extracted)

| pin | result | got |
|---|---|---|
| TestDefaultDict.test_basic | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', defaultdict(<class \'list\'>, {12: []}), {12: [42]})"'> |
| TestDefaultDict.test_missing | PASS | |
| TestDefaultDict.test_repr | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'defaultdict\' is not defined"'> |
| TestDefaultDict.test_copy | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', defaultdict(None, {}), {})"'> |
| TestDefaultDict.test_shallow_copy | PASS | |
| TestDefaultDict.test_deep_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| TestDefaultDict.test_keyerror_without_factory | PASS | |
| TestDefaultDict.test_recursive_repr | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertRegex\', \'<**main**.sub object at 0x7fc4090ee850>\', \'sub\\\\\\\\(<bound method .*sub\\\\\\\\._factory of sub\\\\\\\\(\\\\\\\\.\\\\\\\\.\\\\\\\\., \\\\\\\\{\\\\\\\\}\\\\\\\\)>, \\\\\\\\{\\\\\\\\}\\\\\\\\)\')"'> |
| TestDefaultDict.test_callable_arg | PASS | |
| TestDefaultDict.test_pickling | PASS | |
| TestDefaultDict.test_union | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertDictEqual\', defaultdict(<class \'int\'>, {1: \'one\', 2: 2, 0: \'zero\'}), {1: \'one\', 2: 2, 0: \'zero\'})"'> |
| TestDefaultDict.test_factory_conflict_with_set_value | PASS | |
| TestDefaultDict.test_repr_recursive_factory | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'first argument must be callable or None'"> |

## Expected vs got

### TestDefaultDict.test_basic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', defaultdict(<class \'list\'>, {12: []}), {12: [42]})"'>

### TestDefaultDict.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', defaultdict(None, {}), {})"'>

### TestDefaultDict.test_deep_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### TestDefaultDict.test_recursive_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertRegex\', \'<**main**.sub object at 0x7fc4090ee850>\', \'sub\\\\\\\\(<bound method .*sub\\\\\\\\._factory of sub\\\\\\\\(\\\\\\\\.\\\\\\\\.\\\\\\\\., \\\\\\\\{\\\\\\\\}\\\\\\\\)>, \\\\\\\\{\\\\\\\\}\\\\\\\\)\')"'>

### TestDefaultDict.test_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'defaultdict\' is not defined"'>

### TestDefaultDict.test_repr_recursive_factory (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'first argument must be callable or None'">

### TestDefaultDict.test_union (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertDictEqual\', defaultdict(<class \'int\'>, {1: \'one\', 2: 2, 0: \'zero\'}), {1: \'one\', 2: 2, 0: \'zero\'})"'>
