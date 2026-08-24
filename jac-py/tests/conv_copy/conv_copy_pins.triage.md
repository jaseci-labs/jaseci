# Triage report: `conv_copy_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_copy.py
- guest leg: 0/73 marks
- pins: **33 passed** / 73 run (+8 quarantined of 81 extracted)

| pin | result | got |
|---|---|---|
| TestCopy.test_copy_basic | PASS | |
| TestCopy.test_copy_copy | PASS | |
| TestCopy.test_copy_registry | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_copy_reduce | PASS | |
| TestCopy.test_copy_cant | PASS | |
| TestCopy.test_copy_atomic | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_copy_list | PASS | |
| TestCopy.test_copy_tuple | PASS | |
| TestCopy.test_copy_dict | PASS | |
| TestCopy.test_copy_set | PASS | |
| TestCopy.test_copy_frozenset | PASS | |
| TestCopy.test_copy_bytearray | PASS | |
| TestCopy.test_copy_inst_vanilla | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_copy_inst_copy | PASS | |
| TestCopy.test_copy_inst_getinitargs | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_copy_inst_getnewargs | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', 0, <class \'**main**.C\'>)"'> |
| TestCopy.test_copy_inst_getnewargs_ex | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', 0, <class \'**main**.C\'>)"'> |
| TestCopy.test_copy_inst_getstate | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_copy_inst_setstate | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_copy_inst_getstate_setstate | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_basic | PASS | |
| TestCopy.test_deepcopy_memo | PASS | |
| TestCopy.test_deepcopy_issubclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object.**reduce_ex**() takes exactly one argument (0 given)'"> |
| TestCopy.test_deepcopy_deepcopy | PASS | |
| TestCopy.test_deepcopy_registry | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_reduce | PASS | |
| TestCopy.test_deepcopy_cant | PASS | |
| TestCopy.test_deepcopy_atomic | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_list | PASS | |
| TestCopy.test_deepcopy_empty_tuple | PASS | |
| TestCopy.test_deepcopy_tuple | PASS | |
| TestCopy.test_deepcopy_tuple_of_immutables | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIs\', ((1, 2), 3), ((1, 2), 3))"'> |
| TestCopy.test_deepcopy_dict | PASS | |
| TestCopy.test_deepcopy_keepalive | PASS | |
| TestCopy.test_deepcopy_dont_memo_immutable | PASS | |
| TestCopy.test_deepcopy_inst_vanilla | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_inst_deepcopy | PASS | |
| TestCopy.test_deepcopy_inst_getinitargs | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_inst_getnewargs | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', 0, <class \'**main**.C\'>)"'> |
| TestCopy.test_deepcopy_inst_getnewargs_ex | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', 0, <class \'**main**.C\'>)"'> |
| TestCopy.test_deepcopy_inst_getstate | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_inst_setstate | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_inst_getstate_setstate | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_reflexive_inst | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_reconstruct_string | PASS | |
| TestCopy.test_reconstruct_nostate | PASS | |
| TestCopy.test_reconstruct_state | PASS | |
| TestCopy.test_reconstruct_state_setstate | PASS | |
| TestCopy.test_reconstruct_reflexive | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_reduce_4tuple | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'list\' object has no attribute \'**dict**\'"'> |
| TestCopy.test_reduce_6tuple | PASS | |
| TestCopy.test_reduce_6tuple_none | PASS | |
| TestCopy.test_copy_slots | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_slots | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_dict_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'dict\' object has no attribute \'_keys\'"'> |
| TestCopy.test_copy_list_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'list\' object has no attribute \'foo\'"'> |
| TestCopy.test_deepcopy_list_subclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'list\' object has no attribute \'foo\'"'> |
| TestCopy.test_copy_tuple_subclass | PASS | |
| TestCopy.test_deepcopy_tuple_subclass | PASS | |
| TestCopy.test_getstate_exc | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_copy_function | PASS | |
| TestCopy.test_deepcopy_function | PASS | |
| TestCopy.test_copy_weakref | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'"> |
| TestCopy.test_deepcopy_weakref | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopy.test_copy_weakkeydict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| TestCopy.test_copy_weakvaluedict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| TestCopy.test_deepcopy_weakkeydict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| TestCopy.test_deepcopy_weakvaluedict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| TestCopy.test_deepcopy_bound_method | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestReplace.test_unsupported | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**class**'"> |
| TestReplace.test_replace_method | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'A\' object has no attribute \'x\'"'> |
| TestReplace.test_namedtuple | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'cache'"> |
| TestReplace.test_dataclass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCopy.test_deepcopy_reflexive_list | decorator:support.skip_emscripten_stack_overflow |
| TestCopy.test_deepcopy_reflexive_tuple | decorator:support.skip_emscripten_stack_overflow |
| TestCopy.test_deepcopy_reflexive_dict | decorator:support.skip_emscripten_stack_overflow |
| TestCopy.test_exceptions | self.assertIsSubclass |
| TestCopy.test_copy_reduce_ex | uses-self.fail |
| TestCopy.test_deepcopy_reduce_ex | uses-self.fail |
| TestCopy.test_reduce_5tuple | uses-self.items |
| MiscTestCase.test__all__ | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### TestCopy.test_copy_atomic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_inst_getinitargs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_inst_getnewargs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', 0, <class \'**main**.C\'>)"'>

### TestCopy.test_copy_inst_getnewargs_ex (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', 0, <class \'**main**.C\'>)"'>

### TestCopy.test_copy_inst_getstate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_inst_getstate_setstate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_inst_setstate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_inst_vanilla (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_list_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'list\' object has no attribute \'foo\'"'>

### TestCopy.test_copy_registry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_slots (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_weakkeydict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### TestCopy.test_copy_weakref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_copy_weakvaluedict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### TestCopy.test_deepcopy_atomic (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_bound_method (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_dict_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'dict\' object has no attribute \'_keys\'"'>

### TestCopy.test_deepcopy_inst_getinitargs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_inst_getnewargs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', 0, <class \'**main**.C\'>)"'>

### TestCopy.test_deepcopy_inst_getnewargs_ex (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsInstance\', 0, <class \'**main**.C\'>)"'>

### TestCopy.test_deepcopy_inst_getstate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_inst_getstate_setstate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_inst_setstate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_inst_vanilla (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_issubclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object.**reduce_ex**() takes exactly one argument (0 given)'">

### TestCopy.test_deepcopy_list_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'list\' object has no attribute \'foo\'"'>

### TestCopy.test_deepcopy_reflexive_inst (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_registry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_slots (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_tuple_of_immutables (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIs\', ((1, 2), 3), ((1, 2), 3))"'>

### TestCopy.test_deepcopy_weakkeydict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### TestCopy.test_deepcopy_weakref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_deepcopy_weakvaluedict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### TestCopy.test_getstate_exc (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(shallow)copyable object of type <object>'">

### TestCopy.test_reconstruct_reflexive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopy.test_reduce_4tuple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'list\' object has no attribute \'**dict**\'"'>

### TestReplace.test_dataclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "<enum \'IntFlag\'> cannot extend <class \'ceval.Flag\'>"'>

### TestReplace.test_namedtuple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'cache'">

### TestReplace.test_replace_method (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'A\' object has no attribute \'x\'"'>

### TestReplace.test_unsupported (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**class**'">
