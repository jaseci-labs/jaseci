# Triage report: `conv_pkgutil_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_pkgutil.py
- guest leg: 0/8 marks
- pins: **0 passed** / 8 run (+13 quarantined of 21 extracted)

| pin | result | got |
|---|---|---|
| ExtendPathTests.test_simple | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ExtendPathTests.test_iter_importers | GUEST-WRONG-OUTPUT | RUN<'AttributeError: WeakKeyDictionary'> |
| ExtendPathTests.test_mixed_namespace | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| ExtendPathTests.test_extend_path_argument_types | GUEST-WRONG-OUTPUT | RUN<'AttributeError: WeakKeyDictionary'> |
| ExtendPathTests.test_extend_path_pkg_files | GUEST-WRONG-OUTPUT | RUN<'AttributeError: WeakKeyDictionary'> |
| ImportlibMigrationTests.test_get_importer_avoids_emulation | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.warnings_helper'"> |
| ImportlibMigrationTests.test_issue44061 | GUEST-WRONG-OUTPUT | RUN<'TypeError: multiple bases have instance lay-out conflict'> |
| ImportlibMigrationTests.test_iter_importers_avoids_emulation | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.warnings_helper'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| PkgutilTests.test_getdata_filesys | helper:setUp(self.addCleanup) |
| PkgutilTests.test_getdata_zipfile | helper:setUp(self.addCleanup) |
| PkgutilTests.test_issue44061_iter_modules | helper:setUp(self.addCleanup) |
| PkgutilTests.test_unreadable_dir_on_syspath | helper:setUp(self.addCleanup) |
| PkgutilTests.test_walkpackages_filesys | helper:setUp(self.addCleanup) |
| PkgutilTests.test_walkpackages_zipfile | helper:setUp(self.addCleanup) |
| PkgutilTests.test_walk_packages_raises_on_string_or_bytes_input | helper:setUp(self.addCleanup) |
| PkgutilTests.test_name_resolution | helper:setUp(self.addCleanup) |
| PkgutilTests.test_name_resolution_import_rebinding | helper:setUp(self.addCleanup) |
| PkgutilTests.test_name_resolution_import_rebinding2 | helper:setUp(self.addCleanup) |
| PkgutilPEP302Tests.test_getdata_pep302 | helper:setUp(uses-self.MyTestImporter) |
| PkgutilPEP302Tests.test_alreadyloaded | helper:setUp(uses-self.MyTestImporter) |
| NestedNamespacePackageTest.test_nested | self.addCleanup |

## Expected vs got

### ExtendPathTests.test_extend_path_argument_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: WeakKeyDictionary'>

### ExtendPathTests.test_extend_path_pkg_files (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: WeakKeyDictionary'>

### ExtendPathTests.test_iter_importers (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: WeakKeyDictionary'>

### ExtendPathTests.test_mixed_namespace (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ExtendPathTests.test_simple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### ImportlibMigrationTests.test_get_importer_avoids_emulation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.warnings_helper'">

### ImportlibMigrationTests.test_issue44061 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'TypeError: multiple bases have instance lay-out conflict'>

### ImportlibMigrationTests.test_iter_importers_avoids_emulation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.warnings_helper'">
