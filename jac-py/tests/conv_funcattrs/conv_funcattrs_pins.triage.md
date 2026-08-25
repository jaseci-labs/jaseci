# Triage report: `conv_funcattrs_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_funcattrs.py
- guest leg: 0/30 marks
- pins: **12 passed** / 30 run (+5 quarantined of 35 extracted)

| pin | result | got |
|---|---|---|
| FunctionPropertiesTest.test_module | PASS | |
| FunctionPropertiesTest.test_dir_includes_correct_attrs | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'known_attr'"> |
| FunctionPropertiesTest.test_duplicate_function_equality | PASS | |
| FunctionPropertiesTest.test_copying___code__ | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, 3)"'> |
| FunctionPropertiesTest.test___globals__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**globals**'"> |
| FunctionPropertiesTest.test___closure__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**closure**'"> |
| FunctionPropertiesTest.test_cell_new | PASS | |
| FunctionPropertiesTest.test_empty_cell | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**closure**'"> |
| FunctionPropertiesTest.test_set_cell | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**closure**'"> |
| FunctionPropertiesTest.test___name__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**name**'"> |
| FunctionPropertiesTest.test___code__ | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <class \'object\'>, <class \'code\'>)"'> |
| FunctionPropertiesTest.test_blank_func_defaults | PASS | |
| FunctionPropertiesTest.test_func_default_args | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**defaults**'"> |
| InstancemethodAttrTest.test___class__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**class**'"> |
| InstancemethodAttrTest.test___func__ | PASS | |
| InstancemethodAttrTest.test___self__ | PASS | |
| InstancemethodAttrTest.test___func___non_method | PASS | |
| ArbitraryFunctionAttrTest.test_set_attr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'known_attr'"> |
| ArbitraryFunctionAttrTest.test_delete_unknown_attr | PASS | |
| ArbitraryFunctionAttrTest.test_unset_attr | PASS | |
| FunctionDictsTest.test_setting_dict_to_invalid | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**dict**'"> |
| FunctionDictsTest.test_setting_dict_to_valid | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**dict**'"> |
| FunctionDictsTest.test_delete___dict__ | PASS | |
| FunctionDictsTest.test_unassigned_dict | PASS | |
| FunctionDictsTest.test_func_as_dict_key | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "cannot use \'bound_method\' as a dict key (unhashable type: \'bound_method\')"'> |
| FunctionDocstringTest.test_set_docstring_attr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**doc**'"> |
| FunctionDocstringTest.test_delete_docstring | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**doc**'"> |
| CellTest.test_comparison | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**closure**'"> |
| StaticMethodAttrsTest.test_func_attribute | PASS | |
| BuiltinFunctionPropertiesTest.test_builtin__qualname__ | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**qualname**'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| BuiltinFunctionPropertiesTest.test_builtin__self__ | decorator:support.cpython_only |
| FunctionPropertiesTest.test_invalid___code___assignment | uses-self.assertWarnsRegex |
| FunctionPropertiesTest.test___builtins__ | unresolved-name:**builtins** |
| FunctionPropertiesTest.test___qualname__ | unresolved-name:FuncAttrsTest |
| FunctionPropertiesTest.test___type_params__ | harness-error:SyntaxError: invalid syntax |

## Expected vs got

### ArbitraryFunctionAttrTest.test_set_attr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'known_attr'">

### BuiltinFunctionPropertiesTest.test_builtin__qualname__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**qualname**'">

### CellTest.test_comparison (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**closure**'">

### FunctionDictsTest.test_func_as_dict_key (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "cannot use \'bound_method\' as a dict key (unhashable type: \'bound_method\')"'>

### FunctionDictsTest.test_setting_dict_to_invalid (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**dict**'">

### FunctionDictsTest.test_setting_dict_to_valid (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**dict**'">

### FunctionDocstringTest.test_delete_docstring (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**doc**'">

### FunctionDocstringTest.test_set_docstring_attr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**doc**'">

### FunctionPropertiesTest.test___closure__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**closure**'">

### FunctionPropertiesTest.test___code__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <class \'object\'>, <class \'code\'>)"'>

### FunctionPropertiesTest.test___globals__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**globals**'">

### FunctionPropertiesTest.test___name__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**name**'">

### FunctionPropertiesTest.test_copying___code__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, 3)"'>

### FunctionPropertiesTest.test_dir_includes_correct_attrs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'known_attr'">

### FunctionPropertiesTest.test_empty_cell (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**closure**'">

### FunctionPropertiesTest.test_func_default_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**defaults**'">

### FunctionPropertiesTest.test_set_cell (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**closure**'">

### InstancemethodAttrTest.test___class__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**class**'">
