# Triage report: `conv_posixpath_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_posixpath.py
- guest leg: 0/25 marks
- pins: **17 passed** / 25 run (+39 quarantined of 64 extracted)

| pin | result | got |
|---|---|---|
| PosixPathTest.test_join | PASS | |
| PosixPathTest.test_split | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'/foo\', b\'bar\'), (b\'/foo\', b\'bar\'))"'> |
| PosixPathTest.test_splitext | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'foo\', b\'.bar\'), (b\'foo\', b\'.bar\'))"'> |
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
| PosixPathTest.test_expanduser_home_envvar | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'EnvironmentVarGuard'"> |
| PosixPathTest.test_normpath | PASS | |
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
| PosixPathTest.test_islink | self.addCleanup |
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
| PathLikeTests.test_path_normcase | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_isabs | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_join | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_split | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_splitext | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_splitdrive | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_splitroot | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_basename | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_dirname | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_islink | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_lexists | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_ismount | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_expanduser | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_expandvars | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_normpath | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_abspath | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_realpath | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_relpath | helper:setUp(self.addCleanup) |
| PathLikeTests.test_path_commonpath | helper:setUp(self.addCleanup) |

## Expected vs got

### PosixPathTest.test_expanduser_home_envvar (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'EnvironmentVarGuard'">

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

### PosixPathTest.test_splitext (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'foo\', b\'.bar\'), (b\'foo\', b\'.bar\'))"'>

### PosixPathTest.test_splitroot (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', b\'\', b\'\'), (b\'\', b\'\', b\'\'))"'>
