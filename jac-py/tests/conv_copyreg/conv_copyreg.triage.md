# Triage report: `conv_copyreg_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_copyreg.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+4 quarantined of 6 extracted)

| pin | result | got |
|---|---|---|
| CopyRegTestCase.test_bool | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "cannot use \'property_ctor\' as a set element (unhashable type: \'property_ctor\')"'> |
| CopyRegTestCase.test_extension_registry | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.pickletester'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| CopyRegTestCase.test_class | unresolved-name:C |
| CopyRegTestCase.test_noncallable_reduce | unresolved-name:C |
| CopyRegTestCase.test_noncallable_constructor | unresolved-name:C |
| CopyRegTestCase.test_slotnames | unresolved-name:WithInherited |

## Expected vs got

### CopyRegTestCase.test_bool (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "cannot use \'property_ctor\' as a set element (unhashable type: \'property_ctor\')"'>

### CopyRegTestCase.test_extension_registry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.pickletester'">
