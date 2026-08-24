# Triage report: `conv_copy_pins.jac`

- source: reference/cpython/Lib/test/test_copy.py
- guest leg: 0/41 marks
- pins: **0 passed** / 41 run (+40 quarantined of 81 extracted)

| pin | result | got |
|---|---|---|
| TestCopy.test_copy_basic | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_registry | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_reduce | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_cant | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_atomic | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_list | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_tuple | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_dict | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_set | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_frozenset | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_bytearray | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_basic | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_memo | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_issubclass | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_registry | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_reduce | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_cant | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_atomic | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_list | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_empty_tuple | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_tuple | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_tuple_of_immutables | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_dict | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_keepalive | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_dont_memo_immutable | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_reflexive_inst | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_reconstruct_string | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_reconstruct_nostate | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_reconstruct_reflexive | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_slots | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_slots | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_list_subclass | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_list_subclass | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_tuple_subclass | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_tuple_subclass | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_getstate_exc | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_copy_function | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_function | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestCopy.test_deepcopy_bound_method | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestReplace.test_unsupported | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |
| TestReplace.test_dataclass | GUEST-WRONG-OUTPUT | RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCopy.test_deepcopy_reflexive_list | decorator:support.skip_emscripten_stack_overflow |
| TestCopy.test_deepcopy_reflexive_tuple | decorator:support.skip_emscripten_stack_overflow |
| TestCopy.test_deepcopy_reflexive_dict | decorator:support.skip_emscripten_stack_overflow |
| TestCopy.test_exceptions | self.assertIsSubclass |
| TestCopy.test_copy_copy | uses-self.foo |
| TestCopy.test_copy_reduce_ex | uses-self.fail |
| TestCopy.test_copy_inst_vanilla | uses-self.foo |
| TestCopy.test_copy_inst_copy | uses-self.foo |
| TestCopy.test_copy_inst_getinitargs | uses-self.foo |
| TestCopy.test_copy_inst_getnewargs | uses-self.foo |
| TestCopy.test_copy_inst_getnewargs_ex | uses-self.foo |
| TestCopy.test_copy_inst_getstate | uses-self.foo |
| TestCopy.test_copy_inst_setstate | uses-self.foo |
| TestCopy.test_copy_inst_getstate_setstate | uses-self.foo |
| TestCopy.test_deepcopy_deepcopy | uses-self.foo |
| TestCopy.test_deepcopy_reduce_ex | uses-self.fail |
| TestCopy.test_deepcopy_inst_vanilla | uses-self.foo |
| TestCopy.test_deepcopy_inst_deepcopy | uses-self.foo |
| TestCopy.test_deepcopy_inst_getinitargs | uses-self.foo |
| TestCopy.test_deepcopy_inst_getnewargs | uses-self.foo |
| TestCopy.test_deepcopy_inst_getnewargs_ex | uses-self.foo |
| TestCopy.test_deepcopy_inst_getstate | uses-self.foo |
| TestCopy.test_deepcopy_inst_setstate | uses-self.foo |
| TestCopy.test_deepcopy_inst_getstate_setstate | uses-self.foo |
| TestCopy.test_reconstruct_state | uses-self.**dict** |
| TestCopy.test_reconstruct_state_setstate | uses-self.**dict** |
| TestCopy.test_reduce_4tuple | uses-self.**dict** |
| TestCopy.test_reduce_5tuple | uses-self.**dict** |
| TestCopy.test_reduce_6tuple | uses-self.**dict** |
| TestCopy.test_reduce_6tuple_none | uses-self.**dict** |
| TestCopy.test_deepcopy_dict_subclass | uses-self._keys |
| TestCopy.test_copy_weakref | self._check_weakref |
| TestCopy.test_deepcopy_weakref | self._check_weakref |
| TestCopy.test_copy_weakkeydict | self._check_copy_weakdict |
| TestCopy.test_copy_weakvaluedict | self._check_copy_weakdict |
| TestCopy.test_deepcopy_weakkeydict | uses-self.i |
| TestCopy.test_deepcopy_weakvaluedict | uses-self.i |
| TestReplace.test_replace_method | uses-self.x |
| TestReplace.test_namedtuple | uses-self.subTest |
| MiscTestCase.test__all__ | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### TestCopy.test_copy_atomic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_basic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_bytearray (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_cant (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_frozenset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_list (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_list_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_reduce (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_registry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_set (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_slots (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_tuple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_copy_tuple_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_atomic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_basic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_bound_method (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_cant (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_dont_memo_immutable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_empty_tuple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_function (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_issubclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_keepalive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_list (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_list_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_memo (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_reduce (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_reflexive_inst (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_registry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_slots (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_tuple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_tuple_of_immutables (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_deepcopy_tuple_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_getstate_exc (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_reconstruct_nostate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_reconstruct_reflexive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestCopy.test_reconstruct_string (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestReplace.test_dataclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">

### TestReplace.test_unsupported (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: cannot use 'property_ctor' as a set element (unhashable type: 'property_ctor')">
