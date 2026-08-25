# Triage report: `conv_type_aliases_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_type_aliases.py
- guest leg: 0/4 marks
- pins: **0 passed** / 4 run (+26 quarantined of 30 extracted)

| pin | result | got |
|---|---|---|
| TypeParamsAliasValueTest.test_recursive_repr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object is not subscriptable'"> |
| TypeParamsAliasValueTest.test_raising | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 62'"> |
| TypeAliasConstructorTest.test_attributes_with_exec | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**module**'"> |
| TypeParamsExoticGlobalsTest.test_exec_with_unusual_globals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "exec() argument 2 must be a dict, not \'customdict\'"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| TypeParamsAliasValueTest.test_alias_value_02 | unresolved-name:A |
| TypeParamsAliasValueTest.test_alias_value_03 | unresolved-name:A |
| TypeParamsAliasValueTest.test_subscripting | unresolved-name:A |
| TypeParamsAliasValueTest.test_repr | unresolved-name:P |
| TypeAliasPickleTest.test_pickling | unresolved-name:AllTypesAlias |
| TypeParamsInvalidTest.test_name_collisions | host-raised:NameError: name 'self' is not defined |
| TypeParamsInvalidTest.test_name_non_collision_02 | harness-error:SyntaxError: invalid syntax |
| TypeParamsInvalidTest.test_name_non_collision_03 | host-raised:SyntaxError: invalid syntax (typing.py, line 1991) |
| TypeParamsAccessTest.test_alias_access_01 | harness-error:SyntaxError: invalid syntax |
| TypeParamsAccessTest.test_alias_access_02 | harness-error:SyntaxError: invalid syntax |
| TypeParamsAccessTest.test_alias_access_03 | harness-error:SyntaxError: invalid syntax |
| TypeParamsAliasValueTest.test_alias_value_01 | harness-error:SyntaxError: invalid syntax |
| TypeParamsAliasValueTest.test_alias_value_04 | harness-error:SyntaxError: invalid syntax |
| TypeAliasConstructorTest.test_basic | harness-error:SyntaxError: invalid syntax |
| TypeAliasConstructorTest.test_generic | harness-error:SyntaxError: invalid syntax |
| TypeAliasConstructorTest.test_not_generic | harness-error:SyntaxError: invalid syntax |
| TypeAliasConstructorTest.test_type_params_order_with_defaults | harness-error:SyntaxError: invalid syntax |
| TypeAliasConstructorTest.test_expects_type_like | harness-error:SyntaxError: invalid syntax |
| TypeAliasConstructorTest.test_keywords | harness-error:SyntaxError: invalid syntax |
| TypeAliasConstructorTest.test_errors | harness-error:SyntaxError: invalid syntax |
| TypeAliasTypeTest.test_immutable | harness-error:SyntaxError: invalid syntax |
| TypeAliasTypeTest.test_no_subclassing | harness-error:SyntaxError: invalid syntax |
| TypeAliasTypeTest.test_union | harness-error:SyntaxError: invalid syntax |
| TypeAliasTypeTest.test_module | harness-error:SyntaxError: invalid syntax |
| TypeAliasTypeTest.test_unpack | harness-error:SyntaxError: invalid syntax |
| TypeAliasPickleTest.test_pickling_local | host-raised:AttributeError: '_SelfNS' object has no attribute 'ClassLevel' |

## Expected vs got

### TypeAliasConstructorTest.test_attributes_with_exec (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**module**'">

### TypeParamsAliasValueTest.test_raising (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 62'">

### TypeParamsAliasValueTest.test_recursive_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object is not subscriptable'">

### TypeParamsExoticGlobalsTest.test_exec_with_unusual_globals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "exec() argument 2 must be a dict, not \'customdict\'"'>
