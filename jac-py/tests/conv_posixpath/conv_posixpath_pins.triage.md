# Triage report: `conv_posixpath_pins.jac`

- source: reference/cpython/Lib/test/test_posixpath.py
- guest leg: 0/22 marks
- pins: **16 passed** / 22 run (+42 quarantined of 64 extracted)

| pin | result | got |
|---|---|---|
| PosixPathTest.test_join | PASS | |
| PosixPathTest.test_split | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'/foo\', b\'bar\'), (b\'/foo\', b\'bar\'))"'> |
| PosixPathTest.test_splitroot | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', b\'\', b\'\'), (b\'\', b\'\', b\'\'))"'> |
| PosixPathTest.test_isabs | PASS | |
| PosixPathTest.test_basename | PASS | |
| PosixPathTest.test_dirname | PASS | |
| PosixPathTest.test_islink_invalid_paths | PASS | |
| PosixPathTest.test_ismount | PASS | |
| PosixPathTest.test_ismount_non_existent | PASS | |
| PosixPathTest.test_ismount_invalid_paths | PASS | |
| PosixPathTest.test_ismount_symlinks | PASS | |
| PosixPathTest.test_isjunction | PASS | |
| PosixPathTest.test_expanduser | PASS | |
| PosixPathTest.test_realpath_strict | PASS | |
| PosixPathTest.test_realpath_invalid_paths | PASS | |
| PosixPathTest.test_realpath_symlink_loops | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'change_cwd'"> |
| PosixPathTest.test_realpath_nonterminal_file | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'TextIOWrapper.**enter**() takes no arguments (1 given)'"> |
| PosixPathTest.test_realpath_nonterminal_symlink_to_file | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'TextIOWrapper.**enter**() takes no arguments (1 given)'"> |
| PosixPathTest.test_realpath_nonterminal_symlink_to_symlinks_to_file | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'TextIOWrapper.**enter**() takes no arguments (1 given)'"> |
| PosixPathTest.test_relpath | PASS | |
| PosixPathTest.test_relpath_bytes | PASS | |
| PosixPathTest.test_commonpath | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| PosixPathTest.test_ismount_different_device | decorator:unittest.skipIf |
| PosixPathTest.test_ismount_directory_not_readable | decorator:unittest.skipIf |
| PosixPathTest.test_fast_paths_in_use | decorator:unittest.skipIf |
| PosixPathTest.test_expanduser_pwd | decorator:unittest.skipIf |
| PosixPathTest.test_expanduser_pwd2 | decorator:unittest.skipIf |
| PosixPathTest.test_realpath_unreadable_symlink | decorator:unittest.skipIf |
| PosixPathTest.test_realpath_unreadable_symlink_strict | decorator:unittest.skipIf |
| PosixPathTest.test_splitext | self.splitextTest |
| PosixPathTest.test_islink | self.addCleanup |
| PosixPathTest.test_expanduser_home_envvar | uses-self.subTest |
| PosixPathTest.test_normpath | uses-self.NORMPATH_CASES |
| PosixPathTest.test_realpath_curdir | unresolved-name:kwargs |
| PosixPathTest.test_realpath_pardir | unresolved-name:kwargs |
| PosixPathTest.test_realpath_basic | unresolved-name:kwargs |
| PosixPathTest.test_realpath_relative | unresolved-name:kwargs |
| PosixPathTest.test_realpath_missing_pardir | unresolved-name:kwargs |
| PosixPathTest.test_realpath_symlink_loops_strict | unresolved-name:kwargs |
| PosixPathTest.test_realpath_repeated_indirect_symlinks | unresolved-name:kwargs |
| PosixPathTest.test_realpath_deep_recursion | unresolved-name:kwargs |
| PosixPathTest.test_realpath_resolve_parents | unresolved-name:kwargs |
| PosixPathTest.test_realpath_resolve_before_normalizing | unresolved-name:kwargs |
| PosixPathTest.test_realpath_resolve_first | unresolved-name:kwargs |
| PosixPathTest.test_realpath_unreadable_directory | self.skipTest |
| PathLikeTests.test_path_normcase | self.assertPathEqual |
| PathLikeTests.test_path_isabs | self.assertPathEqual |
| PathLikeTests.test_path_join | uses-self.path |
| PathLikeTests.test_path_split | self.assertPathEqual |
| PathLikeTests.test_path_splitext | self.assertPathEqual |
| PathLikeTests.test_path_splitdrive | self.assertPathEqual |
| PathLikeTests.test_path_splitroot | self.assertPathEqual |
| PathLikeTests.test_path_basename | self.assertPathEqual |
| PathLikeTests.test_path_dirname | self.assertPathEqual |
| PathLikeTests.test_path_islink | self.assertPathEqual |
| PathLikeTests.test_path_lexists | self.assertPathEqual |
| PathLikeTests.test_path_ismount | self.assertPathEqual |
| PathLikeTests.test_path_expanduser | self.assertPathEqual |
| PathLikeTests.test_path_expandvars | self.assertPathEqual |
| PathLikeTests.test_path_normpath | self.assertPathEqual |
| PathLikeTests.test_path_abspath | self.assertPathEqual |
| PathLikeTests.test_path_realpath | self.assertPathEqual |
| PathLikeTests.test_path_relpath | self.assertPathEqual |
| PathLikeTests.test_path_commonpath | uses-self.file_name |

## Expected vs got

### PosixPathTest.test_realpath_nonterminal_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'TextIOWrapper.**enter**() takes no arguments (1 given)'">

### PosixPathTest.test_realpath_nonterminal_symlink_to_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'TextIOWrapper.**enter**() takes no arguments (1 given)'">

### PosixPathTest.test_realpath_nonterminal_symlink_to_symlinks_to_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'TextIOWrapper.**enter**() takes no arguments (1 given)'">

### PosixPathTest.test_realpath_symlink_loops (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'change_cwd'">

### PosixPathTest.test_split (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'/foo\', b\'bar\'), (b\'/foo\', b\'bar\'))"'>

### PosixPathTest.test_splitroot (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', b\'\', b\'\'), (b\'\', b\'\', b\'\'))"'>
