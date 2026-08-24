# Triage report: `conv_csv_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_csv.py
- guest leg: 0/66 marks
- pins: **32 passed** / 66 run (+62 quarantined of 128 extracted)

| pin | result | got |
|---|---|---|
| Test_Csv.test_writer_arg_valid | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError \'argument 1 must have a "write" method\''> |
| Test_Csv.test_reader_attrs | PASS | |
| Test_Csv.test_writer_attrs | PASS | |
| Test_Csv.test_reader_kw_attrs | PASS | |
| Test_Csv.test_writer_kw_attrs | PASS | |
| Test_Csv.test_reader_dialect_attrs | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \',\', \'-\')"'> |
| Test_Csv.test_writer_dialect_attrs | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \',\', \'-\')"'> |
| Test_Csv.test_write_bigfield | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_write_quoting | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_write_escape | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_write_lineterminator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'StringIO.**enter**() takes no arguments (1 given)'"> |
| Test_Csv.test_write_iterable | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_writerows | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_writerows_with_none | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_write_empty_fields | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_write_empty_fields_space_delimiter | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_read_eol | PASS | |
| Test_Csv.test_read_nul | PASS | |
| Test_Csv.test_read_delimiter | PASS | |
| Test_Csv.test_read_escape | PASS | |
| Test_Csv.test_read_skipinitialspace | PASS | |
| Test_Csv.test_read_space_delimiter | PASS | |
| Test_Csv.test_read_linenum | PASS | |
| Test_Csv.test_roundtrip_quoteed_newlines | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_roundtrip_escaped_unquoted_newlines | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| Test_Csv.test_reader_reentrant_iterator | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'ReentrantIter\' object is not iterable"'> |
| TestDialectRegistry.test_registry_badargs | PASS | |
| TestDialectRegistry.test_incomplete_dialect | PASS | |
| TestDialectRegistry.test_space_dialect | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDialectRegistry.test_dialect_apply | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDialectRegistry.test_copy | PASS | |
| TestDialectRegistry.test_pickle | PASS | |
| TestDictFields.test_writeheader_return_value | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_write_simple_dict | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_write_multiple_dict_rows | PASS | |
| TestDictFields.test_write_no_fields | PASS | |
| TestDictFields.test_typo_in_extrasaction_raises_error | PASS | |
| TestDictFields.test_write_field_not_in_field_names_raise | PASS | |
| TestDictFields.test_write_field_not_in_field_names_ignore | PASS | |
| TestDictFields.test_dict_reader_fieldnames_accepts_iter | PASS | |
| TestDictFields.test_dict_reader_fieldnames_accepts_list | PASS | |
| TestDictFields.test_dict_reader_set_fieldnames | PASS | |
| TestDictFields.test_dict_writer_fieldnames_rejects_iter | PASS | |
| TestDictFields.test_dict_writer_fieldnames_accepts_list | PASS | |
| TestDictFields.test_dict_reader_fieldnames_is_optional | PASS | |
| TestDictFields.test_read_dict_fields | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_read_dict_no_fieldnames | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_read_dict_fieldnames_from_file | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_read_dict_fieldnames_chain | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_read_long | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_read_long_with_rest | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_read_long_with_rest_no_fieldnames | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_read_short | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDictFields.test_read_multi | PASS | |
| TestDictFields.test_read_with_blanks | PASS | |
| TestDictFields.test_read_semi_sep | PASS | |
| TestArrayWrites.test_int_write | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestArrayWrites.test_double_write | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestArrayWrites.test_float_write | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestArrayWrites.test_char_write | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| TestDialectValidity.test_invalid_chars | PASS | |
| TestSniffer.test_guess_quote_and_delimiter | PASS | |
| KeyOrderingTest.test_ordering_for_the_dict_reader_and_writer | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| KeyOrderingTest.test_ordered_dict_reader | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [{\'FirstName\': \'Eric\', \'LastName\': \'Idle\'}, {\'FirstName\': \'Graham\', \'LastName\': \'Chapman\', None: [\'Over1\', \'Over2\']}, {\'FirstName\': \'Under1\', \'LastName\': None}, {\'FirstName\': \'John\', \'LastName\': \'Cleese\'}], [OrderedDict({\'FirstName\': \'Eric\', \'LastName\': \'Idle\'}), OrderedDict({\'FirstName\': \'Graham\', \'LastName\': \'Chapman\', None: [\'Over1\', \'Over2\']}), OrderedDict({\'FirstName\': \'Under1\', \'LastName\': None}), OrderedDict({\'FirstName\': \'John\', \'LastName\': \'Cleese\'})])"'> |
| MiscTestCase.test_lazy_import | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| MiscTestCase.test_subclassable | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestLeaks.test_create_read | decorator:unittest.skipUnless |
| TestLeaks.test_create_write | decorator:unittest.skipUnless |
| TestLeaks.test_read | decorator:unittest.skipUnless |
| TestLeaks.test_write | decorator:unittest.skipUnless |
| MiscTestCase.test_disallow_instantiation | decorator:support.cpython_only |
| Test_Csv.test_reader_arg_valid | unresolved-name:BadIterable |
| Test_Csv.test_write_arg_valid | unresolved-name:BadIterable |
| Test_Csv.test_writerows_errors | unresolved-name:BadIterable |
| Test_Csv.test_read_oddinputs | uses-self._read_test |
| Test_Csv.test_read_eof | uses-self._read_test |
| Test_Csv.test_read_quoting | uses-self._read_test |
| Test_Csv.test_read_bigfield | uses-self._read_test |
| TestDialectRegistry.test_registry | self.addCleanup |
| TestDialectRegistry.test_register_kwargs | self.addCleanup |
| TestDialectRegistry.test_register_kwargs_override | self.addCleanup |
| TestDictFields.test_write_fields_not_in_fieldnames | unresolved-name:cx |
| TestDialectValidity.test_quoting | unresolved-name:cm |
| TestDialectValidity.test_delimiter | unresolved-name:cm |
| TestDialectValidity.test_escapechar | unresolved-name:cm |
| TestDialectValidity.test_lineterminator | unresolved-name:cm |
| TestSniffer.test_delimiters | assertRaisesRegex call form |
| TestDialectExcel.test_single | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_simple | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_blankline | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_empty_fields | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_singlequoted | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_singlequoted_left_empty | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_singlequoted_right_empty | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_single_quoted_quote | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_quoted_quotes | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_inline_quote | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_inline_quotes | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_quotes_and_more | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_lone_quote | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_quote_and_quote | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_space_and_quote | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_quoted | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_quoted_quote | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_quoted_nl | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_dubious_quote | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_null | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_single_writer | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_simple_writer | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_quotes | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_quote_fieldsep | host-raised:NameError: name 'self' is not defined |
| TestDialectExcel.test_newlines | host-raised:NameError: name 'self' is not defined |
| TestEscapedExcel.test_escape_fieldsep | host-raised:NameError: name 'self' is not defined |
| TestEscapedExcel.test_read_escape_fieldsep | host-raised:NameError: name 'self' is not defined |
| TestDialectUnix.test_simple_writer | host-raised:NameError: name 'self' is not defined |
| TestDialectUnix.test_simple_reader | host-raised:NameError: name 'self' is not defined |
| TestQuotedEscapedExcel.test_write_escape_fieldsep | host-raised:NameError: name 'self' is not defined |
| TestQuotedEscapedExcel.test_read_escape_fieldsep | host-raised:NameError: name 'self' is not defined |
| TestSniffer.test_issue43625 | host-raised:AttributeError: '_SelfNS' object has no attribute 'sample12' |
| TestSniffer.test_has_header_strings | host-raised:AttributeError: '_SelfNS' object has no attribute 'sample10' |
| TestSniffer.test_has_header | host-raised:AttributeError: '_SelfNS' object has no attribute 'sample1' |
| TestSniffer.test_has_header_regex_special_delimiter | host-raised:AttributeError: '_SelfNS' object has no attribute 'sample8' |
| TestSniffer.test_has_header_checks_20_rows | host-raised:AttributeError: '_SelfNS' object has no attribute 'sample17' |
| TestSniffer.test_sniff | host-raised:AttributeError: '_SelfNS' object has no attribute 'sample1' |
| TestSniffer.test_doublequote | host-raised:AttributeError: '_SelfNS' object has no attribute 'header1' |
| TestUnicode.test_unicode_read | host-raised:AttributeError: '_SelfNS' object has no attribute 'names' |
| TestUnicode.test_unicode_write | host-raised:AttributeError: '_SelfNS' object has no attribute 'names' |
| MiscTestCase.test__all__ | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### KeyOrderingTest.test_ordered_dict_reader (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [{\'FirstName\': \'Eric\', \'LastName\': \'Idle\'}, {\'FirstName\': \'Graham\', \'LastName\': \'Chapman\', None: [\'Over1\', \'Over2\']}, {\'FirstName\': \'Under1\', \'LastName\': None}, {\'FirstName\': \'John\', \'LastName\': \'Cleese\'}], [OrderedDict({\'FirstName\': \'Eric\', \'LastName\': \'Idle\'}), OrderedDict({\'FirstName\': \'Graham\', \'LastName\': \'Chapman\', None: [\'Over1\', \'Over2\']}), OrderedDict({\'FirstName\': \'Under1\', \'LastName\': None}), OrderedDict({\'FirstName\': \'John\', \'LastName\': \'Cleese\'})])"'>

### KeyOrderingTest.test_ordering_for_the_dict_reader_and_writer (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### MiscTestCase.test_lazy_import (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### TestArrayWrites.test_char_write (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestArrayWrites.test_double_write (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestArrayWrites.test_float_write (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestArrayWrites.test_int_write (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDialectRegistry.test_dialect_apply (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDialectRegistry.test_space_dialect (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_read_dict_fieldnames_chain (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_read_dict_fieldnames_from_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_read_dict_fields (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_read_dict_no_fieldnames (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_read_long (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_read_long_with_rest (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_read_long_with_rest_no_fieldnames (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_read_short (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_write_simple_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TestDictFields.test_writeheader_return_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_reader_dialect_attrs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \',\', \'-\')"'>

### Test_Csv.test_reader_reentrant_iterator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'ReentrantIter\' object is not iterable"'>

### Test_Csv.test_roundtrip_escaped_unquoted_newlines (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_roundtrip_quoteed_newlines (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_write_bigfield (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_write_empty_fields (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_write_empty_fields_space_delimiter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_write_escape (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_write_iterable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_write_lineterminator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'StringIO.**enter**() takes no arguments (1 given)'">

### Test_Csv.test_write_quoting (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_writer_arg_valid (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError \'argument 1 must have a "write" method\''>

### Test_Csv.test_writer_dialect_attrs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \',\', \'-\')"'>

### Test_Csv.test_writerows (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### Test_Csv.test_writerows_with_none (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">
