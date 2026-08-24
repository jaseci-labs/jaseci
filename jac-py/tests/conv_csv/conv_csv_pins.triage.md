# Triage report: `conv_csv_pins.jac`

- source: reference/cpython/Lib/test/test_csv.py
- guest leg: 0/60 marks
- pins: **30 passed** / 60 run (+68 quarantined of 128 extracted)

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
| Test_Csv.test_write_lineterminator | uses-self.subTest |
| Test_Csv.test_writerows_errors | unresolved-name:BadIterable |
| Test_Csv.test_read_oddinputs | uses-self._read_test |
| Test_Csv.test_read_eof | uses-self._read_test |
| Test_Csv.test_read_quoting | uses-self._read_test |
| Test_Csv.test_read_bigfield | uses-self._read_test |
| Test_Csv.test_roundtrip_quoteed_newlines | uses-self.subTest |
| Test_Csv.test_roundtrip_escaped_unquoted_newlines | uses-self.subTest |
| Test_Csv.test_reader_reentrant_iterator | uses-self.reader |
| TestDialectRegistry.test_registry | self.addCleanup |
| TestDialectRegistry.test_register_kwargs | self.addCleanup |
| TestDialectRegistry.test_register_kwargs_override | self.addCleanup |
| TestDialectExcel.test_single | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_simple | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_blankline | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_empty_fields | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_singlequoted | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_singlequoted_left_empty | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_singlequoted_right_empty | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_single_quoted_quote | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_quoted_quotes | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_inline_quote | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_inline_quotes | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_quotes_and_more | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_lone_quote | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_quote_and_quote | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_space_and_quote | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_quoted | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_quoted_quote | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_quoted_nl | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_dubious_quote | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_null | helper:writerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_single_writer | helper:writerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_simple_writer | helper:writerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_quotes | helper:writerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_quote_fieldsep | helper:writerAssertEqual(uses-self.dialect) |
| TestDialectExcel.test_newlines | helper:writerAssertEqual(uses-self.dialect) |
| TestEscapedExcel.test_escape_fieldsep | helper:writerAssertEqual(uses-self.dialect) |
| TestEscapedExcel.test_read_escape_fieldsep | helper:readerAssertEqual(uses-self.dialect) |
| TestDialectUnix.test_simple_writer | helper:writerAssertEqual(uses-self.dialect) |
| TestDialectUnix.test_simple_reader | helper:readerAssertEqual(uses-self.dialect) |
| TestQuotedEscapedExcel.test_write_escape_fieldsep | helper:writerAssertEqual(uses-self.dialect) |
| TestQuotedEscapedExcel.test_read_escape_fieldsep | helper:readerAssertEqual(uses-self.dialect) |
| TestDictFields.test_write_fields_not_in_fieldnames | unresolved-name:cx |
| TestDialectValidity.test_quoting | unresolved-name:cm |
| TestDialectValidity.test_delimiter | unresolved-name:cm |
| TestDialectValidity.test_escapechar | unresolved-name:cm |
| TestDialectValidity.test_lineterminator | unresolved-name:cm |
| TestDialectValidity.test_invalid_chars | uses-self.subTest |
| TestSniffer.test_issue43625 | uses-self.sample12 |
| TestSniffer.test_has_header_strings | uses-self.sample10 |
| TestSniffer.test_has_header | uses-self.sample1 |
| TestSniffer.test_has_header_regex_special_delimiter | uses-self.sample8 |
| TestSniffer.test_has_header_checks_20_rows | uses-self.sample18 |
| TestSniffer.test_guess_quote_and_delimiter | uses-self.subTest |
| TestSniffer.test_sniff | uses-self.sample1 |
| TestSniffer.test_delimiters | assertRaisesRegex call form |
| TestSniffer.test_doublequote | uses-self.header1 |
| TestUnicode.test_unicode_read | uses-self.names |
| TestUnicode.test_unicode_write | uses-self.names |
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
