# Triage report: `conv_userlist_pins.jac`

- source: reference/cpython/Lib/test/test_userlist.py
- guest leg: 0/3 marks
- pins: **2 passed** / 3 run (+6 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| UserListTest.test_data | PASS | |
| UserListTest.test_slice_type | PASS | |
| UserListTest.test_implementation | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'swap_attr'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| UserListTest.test_getslice | uses-self.type2test |
| UserListTest.test_mixed_add | uses-self.subTest |
| UserListTest.test_mixed_iadd | uses-self.subTest |
| UserListTest.test_mixed_cmp | self._assert_cmp |
| UserListTest.test_getitemoverwriteiter | uses-self.type2test |
| UserListTest.test_userlist_copy | uses-self.type2test |

## Expected vs got

### UserListTest.test_implementation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'swap_attr'">
