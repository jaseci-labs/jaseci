# Triage report: `conv_csv_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_csv.py
- guest leg: 0/34 marks
- pins: **29 passed** / 34 run (+94 quarantined of 128 extracted)

| pin | result | got |
|---|---|---|
| Test_Csv.test_reader_arg_valid | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'BadIterable\' object is not iterable"'> |
| Test_Csv.test_writer_arg_valid | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError \'argument 1 must have a "write" method\''> |
| Test_Csv.test_reader_attrs | PASS | |
| Test_Csv.test_writer_attrs | PASS | |
| Test_Csv.test_reader_kw_attrs | PASS | |
| Test_Csv.test_writer_kw_attrs | PASS | |
| Test_Csv.test_reader_dialect_attrs | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \',\', \'-\')"'> |
| Test_Csv.test_writer_dialect_attrs | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \',\', \'-\')"'> |
| Test_Csv.test_write_lineterminator | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'StringIO.__enter__() takes no arguments (1 given)'">` |
| Test_Csv.test_read_nul | PASS | |
| Test_Csv.test_read_delimiter | PASS | |
| Test_Csv.test_read_escape | PASS | |
| Test_Csv.test_read_space_delimiter | PASS | |
| Test_Csv.test_read_linenum | PASS | |
| TestDialectRegistry.test_registry_badargs | PASS | |
| TestDialectRegistry.test_incomplete_dialect | PASS | |
| TestDialectRegistry.test_copy | PASS | |
| TestDialectRegistry.test_pickle | PASS | |
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
| TestDictFields.test_read_multi | PASS | |
| TestDictFields.test_read_with_blanks | PASS | |
| TestDictFields.test_read_semi_sep | PASS | |
| TestDialectValidity.test_invalid_chars | PASS | |
| MiscTestCase.test_subclassable | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestLeaks.test_create_read | decorator:unittest.skipUnless |
| TestLeaks.test_create_write | decorator:unittest.skipUnless |
| TestLeaks.test_read | decorator:unittest.skipUnless |
| TestLeaks.test_write | decorator:unittest.skipUnless |
| MiscTestCase.test_disallow_instantiation | decorator:support.cpython_only |
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
| TestSniffer.test_issue43625 | unresolved-name:sample17 |
| TestSniffer.test_has_header_strings | unresolved-name:sample17 |
| TestSniffer.test_has_header | unresolved-name:sample17 |
| TestSniffer.test_has_header_regex_special_delimiter | unresolved-name:sample17 |
| TestSniffer.test_has_header_checks_20_rows | unresolved-name:sample17 |
| TestSniffer.test_sniff | unresolved-name:sample17 |
| TestSniffer.test_delimiters | unresolved-name:sample17 |
| TestSniffer.test_doublequote | unresolved-name:sample17 |
| Test_Csv.test_write_arg_valid | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_write_bigfield | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_write_quoting | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_write_escape | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_write_iterable | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_writerows | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_writerows_with_none | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_write_empty_fields | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_write_empty_fields_space_delimiter | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_writerows_errors | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_read_eol | harness-error:AssertionError: SRE module mismatch |
| Test_Csv.test_read_skipinitialspace | host-raised:AssertionError: ('assertEqual', [['', '', '']], [[None, None, None]]) |
| Test_Csv.test_roundtrip_quoteed_newlines | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_roundtrip_escaped_unquoted_newlines | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| Test_Csv.test_reader_reentrant_iterator | harness-error:exit -11 |
| TestDialectRegistry.test_space_dialect | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectRegistry.test_dialect_apply | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_single | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_simple | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_blankline | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_empty_fields | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_singlequoted | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_singlequoted_left_empty | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_singlequoted_right_empty | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_single_quoted_quote | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_quoted_quotes | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_inline_quote | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_inline_quotes | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_quotes_and_more | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_lone_quote | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_quote_and_quote | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_space_and_quote | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_quoted | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_quoted_quote | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_quoted_nl | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_dubious_quote | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_null | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_single_writer | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_simple_writer | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_quotes | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_quote_fieldsep | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectExcel.test_newlines | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestEscapedExcel.test_escape_fieldsep | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestEscapedExcel.test_read_escape_fieldsep | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectUnix.test_simple_writer | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDialectUnix.test_simple_reader | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestQuotedEscapedExcel.test_write_escape_fieldsep | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestQuotedEscapedExcel.test_read_escape_fieldsep | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_writeheader_return_value | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_write_simple_dict | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_read_dict_fields | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_read_dict_no_fieldnames | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_read_dict_fieldnames_from_file | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_read_dict_fieldnames_chain | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_read_long | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_read_long_with_rest | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_read_long_with_rest_no_fieldnames | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestDictFields.test_read_short | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestArrayWrites.test_int_write | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestArrayWrites.test_double_write | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestArrayWrites.test_float_write | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestArrayWrites.test_char_write | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestSniffer.test_guess_quote_and_delimiter | host-raised:AssertionError: SRE module mismatch |
| TestUnicode.test_unicode_read | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| TestUnicode.test_unicode_write | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| KeyOrderingTest.test_ordering_for_the_dict_reader_and_writer | harness-error:AttributeError: 'sys.flags' object has no attribute 'context_aware_warnings' |
| KeyOrderingTest.test_ordered_dict_reader | harness-error:AssertionError: SRE module mismatch |
| MiscTestCase.test__all__ | harness-error:SyntaxError: invalid syntax |
| MiscTestCase.test_lazy_import | harness-error:SyntaxError: invalid syntax |

## Expected vs got

### Test_Csv.test_reader_arg_valid (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'BadIterable\' object is not iterable"'>

### Test_Csv.test_reader_dialect_attrs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \',\', \'-\')"'>

### Test_Csv.test_write_lineterminator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'StringIO.__enter__() takes no arguments (1 given)'">`

### Test_Csv.test_writer_arg_valid (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError \'argument 1 must have a "write" method\''>

### Test_Csv.test_writer_dialect_attrs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \',\', \'-\')"'>
