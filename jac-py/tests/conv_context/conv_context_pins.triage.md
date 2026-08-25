# Triage report: `conv_context_pins.jac`

- source: reference/cpython/Lib/test/test_context.py
- guest leg: 0/27 marks
- pins: **17 passed** / 27 run (+29 quarantined of 56 extracted)

| pin | result | got |
|---|---|---|
| ContextTest.test_context_var_new_1 | PASS | |
| ContextTest.test_context_var_repr_1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError \'(\\\'assertIn\\\', \\\'...\\\', "<ContextVar name=\\\'a\\\' default=[] at 0x7f20173c32e0>")\''> |
| ContextTest.test_context_subclassing_1 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| ContextTest.test_context_new_1 | PASS | |
| ContextTest.test_context_new_unhashable_str_subclass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| ContextTest.test_context_typerrors_1 | PASS | |
| ContextTest.test_context_get_context_1 | PASS | |
| ContextTest.test_context_run_1 | PASS | |
| ContextTest.test_context_run_2 | PASS | |
| ContextTest.test_context_run_3 | PASS | |
| ContextTest.test_context_run_4 | PASS | |
| ContextTest.test_context_run_5 | PASS | |
| ContextTest.test_context_run_6 | PASS | |
| ContextTest.test_context_run_7 | PASS | |
| ContextTest.test_context_getset_1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'> |
| ContextTest.test_context_getset_2 | PASS | |
| ContextTest.test_context_getset_3 | PASS | |
| ContextTest.test_context_getset_4 | PASS | |
| ContextTest.test_context_getset_5 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [42])"'> |
| ContextTest.test_context_copy_1 | PASS | |
| ContextTest.test_token_contextmanager_with_default | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'"> |
| ContextTest.test_token_contextmanager_without_default | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'"> |
| ContextTest.test_token_contextmanager_on_exception | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'"> |
| ContextTest.test_token_contextmanager_multiple_c_set | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'"> |
| ContextTest.test_token_contextmanager_with_explicit_reset_another_token | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'"> |
| ContextTest.test_context_eq_reentrant_contextvar_set | PASS | |
| ContextTest.test_context_eq_reentrant_contextvar_set_in_hash | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| ContextTest.test_context_threads_1 | decorator:threading_helper.requires_working_threading |
| ContextTest.test_context_thread_inherit | decorator:threading_helper.requires_working_threading |
| HamtTest.test_hashkey_helper_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_basics_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_basics_2 | decorator:unittest.skipIf |
| HamtTest.test_hamt_basics_3 | decorator:unittest.skipIf |
| HamtTest.test_hamt_basics_4 | decorator:unittest.skipIf |
| HamtTest.test_hamt_collision_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_collision_3 | decorator:unittest.skipIf |
| HamtTest.test_hamt_stress | decorator:unittest.skipIf |
| HamtTest.test_hamt_delete_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_delete_2 | decorator:unittest.skipIf |
| HamtTest.test_hamt_delete_3 | decorator:unittest.skipIf |
| HamtTest.test_hamt_delete_4 | decorator:unittest.skipIf |
| HamtTest.test_hamt_delete_5 | decorator:unittest.skipIf |
| HamtTest.test_hamt_items_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_items_2 | decorator:unittest.skipIf |
| HamtTest.test_hamt_keys_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_items_3 | decorator:unittest.skipIf |
| HamtTest.test_hamt_eq_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_eq_2 | decorator:unittest.skipIf |
| HamtTest.test_hamt_gc_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_gc_2 | decorator:unittest.skipIf |
| HamtTest.test_hamt_in_1 | decorator:unittest.skipIf |
| HamtTest.test_hamt_getitem_1 | decorator:unittest.skipIf |
| ContextTest.test_token_repr_1 | self.assertRegex |
| ContextTest.test_context_isinstance | uses-self.subTest |
| ContextTest.test_token_contextmanager_reentrant | uses-self.assertEqual |
| ContextTest.test_token_contextmanager_with_explicit_reset_the_same_token | uses-self.assertEqual |

## Expected vs got

### ContextTest.test_context_getset_1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 2, 1)"'>

### ContextTest.test_context_getset_5 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [42])"'>

### ContextTest.test_context_new_unhashable_str_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### ContextTest.test_context_subclassing_1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### ContextTest.test_context_var_repr_1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError \'(\\\'assertIn\\\', \\\'...\\\', "<ContextVar name=\\\'a\\\' default=[] at 0x7f20173c32e0>")\''>

### ContextTest.test_token_contextmanager_multiple_c_set (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'">

### ContextTest.test_token_contextmanager_on_exception (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'">

### ContextTest.test_token_contextmanager_with_default (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'">

### ContextTest.test_token_contextmanager_with_explicit_reset_another_token (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'">

### ContextTest.test_token_contextmanager_without_default (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'Token.**enter**() takes no arguments (1 given)'">
