# Triage report: `conv_weakset_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_weakset.py
- guest leg: 0/40 marks
- pins: **0 passed** / 40 run (+6 quarantined of 46 extracted)

| pin | result | got |
|---|---|---|
| TestWeakSet.test_methods | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_new_or_init | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_len | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_contains | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_union | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_or | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_intersection | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_isdisjoint | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_and | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_difference | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_sub | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_symmetric_difference | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_xor | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_sub_and_super | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_lt | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_gt | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_subclass_with_custom_hash | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_init | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_constructor_identity | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_hash | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_clear | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_copy | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_remove | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_discard | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_pop | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_update_set | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_ior | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_intersection_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_iand | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_difference_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_isub | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_symmetric_difference_update | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_ixor | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_inplace_on_self | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_ne | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_weak_destroy_while_iterating | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_weak_destroy_and_mutate_while_iterating | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_repr | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |
| TestWeakSet.test_abc | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestWeakSet.test_gc | unresolved-name:Foo |
| TestWeakSet.test_add | unresolved-name:Foo |
| TestWeakSet.test_eq | unresolved-name:Foo |
| TestWeakSet.test_len_cycles | unresolved-name:RefCycle |
| TestWeakSet.test_len_race | self.addCleanup |
| TestWeakSet.test_copying | self.assertNotHasAttr |

## Expected vs got

### TestWeakSet.test_abc (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_and (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_clear (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_constructor_identity (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_contains (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_difference (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_difference_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_discard (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_gt (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_hash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_iand (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_init (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_inplace_on_self (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_intersection (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_intersection_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_ior (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_isdisjoint (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_isub (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_ixor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_len (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_lt (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_methods (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_ne (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_new_or_init (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_or (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_pop (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_remove (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_sub (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_sub_and_super (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_subclass_with_custom_hash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_symmetric_difference (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_symmetric_difference_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_union (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_update_set (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_weak_destroy_and_mutate_while_iterating (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_weak_destroy_while_iterating (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">

### TestWeakSet.test_xor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'WeakSet' from '<unknown>'">
