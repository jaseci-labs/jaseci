# Triage report: `conv_configparser_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_configparser.py
- guest leg: 0/31 marks
- pins: **0 passed** / 31 run (+63 quarantined of 94 extracted)

| pin | result | got |
|---|---|---|
| ConfigParserTestCaseInvalidInterpolationType.test_error_on_wrong_type_for_interpolation | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| Issue7005TestCase.test_none_as_value_stringified | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ReadFileTestCase.test_file | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ReadFileTestCase.test_iterable | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoverageOneHundredTestCase.test_duplicate_option_error | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoverageOneHundredTestCase.test_interpolation_depth_error | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoverageOneHundredTestCase.test_parsing_error | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoverageOneHundredTestCase.test_sectionproxy_repr | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoverageOneHundredTestCase.test_inconsistent_converters_state | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_error | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_nosectionerror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_nooptionerror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_duplicatesectionerror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_duplicateoptionerror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_interpolationerror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_interpolationmissingoptionerror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_interpolationsyntaxerror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_interpolationdeptherror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_parsingerror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExceptionPicklingTestCase.test_missingsectionheadererror | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| InlineCommentStrippingTestCase.test_stripping | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SectionlessTestCase.test_no_first_section | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SectionlessTestCase.test_no_section | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SectionlessTestCase.test_empty_unnamed_section | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SectionlessTestCase.test_add_section | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SectionlessTestCase.test_disabled_error | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SectionlessTestCase.test_multiple_configs | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| InvalidInputTestCase.test_delimiter_in_key | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| InvalidInputTestCase.test_section_bracket_in_key | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ReDoSTestCase.test_option_regex_does_not_backtrack | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ReDoSTestCase.test_option_regex_no_value_does_not_backtrack | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |

## Quarantined at conversion

| test | reason |
|---|---|
| BasicTestCase.test_basic | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| BasicTestCase.test_basic_from_dict | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_case_sensitivity | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_case_sensitivity_mapping_access | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_default_case_sensitivity | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_parse_errors | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_query_errors | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_boolean | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| BasicTestCase.test_weird_errors | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_get_after_duplicate_option_error | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_write | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| BasicTestCase.test_set_string_types | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| BasicTestCase.test_read_returns_file_list | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_read_returns_file_list_with_bytestring_path | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_popitem | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| BasicTestCase.test_clear | helper:newconfig(uses-self.config_class) |
| BasicTestCase.test_setitem | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| BasicTestCase.test_invalid_multiline_value | helper:newconfig(uses-self.config_class) |
| ConfigParserTestCase.test_interpolation | helper:get_interpolation_config(helper:fromstring(helper:newconfig(uses-self.config_class))) |
| ConfigParserTestCase.test_interpolation_missing_value | helper:get_interpolation_config(helper:fromstring(helper:newconfig(uses-self.config_class))) |
| ConfigParserTestCase.test_items | helper:check_items_config(helper:fromstring(helper:newconfig(uses-self.config_class))) |
| ConfigParserTestCase.test_safe_interpolation | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCase.test_set_malformatted_interpolation | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCase.test_set_nonstring_types | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCase.test_add_section_default | helper:newconfig(uses-self.config_class) |
| ConfigParserTestCase.test_defaults_keyword | helper:newconfig(uses-self.config_class) |
| ConfigParserTestCaseNoInterpolation.test_no_interpolation | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCaseNoInterpolation.test_empty_case | helper:newconfig(uses-self.config_class) |
| MultilineValuesTestCase.test_dominating_multiline_values | helper:setUp(helper:newconfig(uses-self.config_class)) |
| RawConfigParserTestCase.test_interpolation | helper:get_interpolation_config(helper:fromstring(helper:newconfig(uses-self.config_class))) |
| RawConfigParserTestCase.test_items | helper:check_items_config(helper:fromstring(helper:newconfig(uses-self.config_class))) |
| RawConfigParserTestCase.test_set_nonstring_types | helper:newconfig(uses-self.config_class) |
| RawConfigParserTestCase.test_defaults_keyword | helper:newconfig(uses-self.config_class) |
| RawConfigParserTestSambaConf.test_reading | helper:newconfig(uses-self.config_class) |
| ConfigParserTestCaseExtendedInterpolation.test_extended_interpolation | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCaseExtendedInterpolation.test_endless_loop | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCaseExtendedInterpolation.test_strange_options | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCaseExtendedInterpolation.test_case_sensitivity_basic | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCaseExtendedInterpolation.test_case_sensitivity_conflicts | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCaseExtendedInterpolation.test_other_errors | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| NoValueAndExtendedInterpolation.test_interpolation_with_allow_no_value | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| NoValueAndExtendedInterpolation.test_explicit_none | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ConfigParserTestCaseTrickyFile.test_cfgparser_dot_3 | helper:newconfig(uses-self.config_class) |
| ConfigParserTestCaseTrickyFile.test_unicode_failure | helper:newconfig(uses-self.config_class) |
| SortedTestCase.test_sorted | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| CompatibleTestCase.test_comment_handling | helper:fromstring(helper:newconfig(uses-self.config_class)) |
| ReadFileTestCase.test_readline_generator | unresolved-name:FakeFile |
| ReadFileTestCase.test_source_as_bytes | unresolved-name:dse |
| ReadFileTestCase.test_keys_without_value_with_extra_whitespace | unresolved-name:dse |
| CoverageOneHundredTestCase.test_interpolation_validation | unresolved-name:cm |
| ExceptionPicklingTestCase.test_combine_error_linear_complexity | self.assertStartsWith |
| ExceptionContextTestCase.test_get_basic_interpolation | uses-self.assertRaises |
| ExceptionContextTestCase.test_get_extended_interpolation | uses-self.assertRaises |
| ExceptionContextTestCase.test_missing_options | unresolved-name:cm |
| ExceptionContextTestCase.test_missing_section | unresolved-name:cm |
| ExceptionContextTestCase.test_remove_option | unresolved-name:cm |
| BlatantOverrideConvertersTestCase.test_inheritance | uses-self._get_conv |
| BlatantOverrideConvertersTestCase.test_instance_assignment | uses-self.assertEqual |
| ConfigParserTestCaseNoInterpolation.test_none_as_default_interpolation | host-raised:AttributeError: '_SelfNS' object has no attribute 'ini' |
| Issue7005TestCase.test_none_as_value_stringified_raw | host-raised:AttributeError: '_SelfNS' object has no attribute 'expected_output' |
| ConvertersTestCase.test_converters | host-raised:RuntimeError: super(): **class** cell not found |
| BlatantOverrideConvertersTestCase.test_converters_at_init | host-raised:AttributeError: '_SelfNS' object has no attribute 'config' |
| MiscTestCase.test__all__ | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### ConfigParserTestCaseInvalidInterpolationType.test_error_on_wrong_type_for_interpolation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoverageOneHundredTestCase.test_duplicate_option_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoverageOneHundredTestCase.test_inconsistent_converters_state (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoverageOneHundredTestCase.test_interpolation_depth_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoverageOneHundredTestCase.test_parsing_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoverageOneHundredTestCase.test_sectionproxy_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_duplicateoptionerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_duplicatesectionerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_interpolationdeptherror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_interpolationerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_interpolationmissingoptionerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_interpolationsyntaxerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_missingsectionheadererror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_nooptionerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_nosectionerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExceptionPicklingTestCase.test_parsingerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### InlineCommentStrippingTestCase.test_stripping (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### InvalidInputTestCase.test_delimiter_in_key (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### InvalidInputTestCase.test_section_bracket_in_key (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### Issue7005TestCase.test_none_as_value_stringified (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ReDoSTestCase.test_option_regex_does_not_backtrack (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ReDoSTestCase.test_option_regex_no_value_does_not_backtrack (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ReadFileTestCase.test_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ReadFileTestCase.test_iterable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SectionlessTestCase.test_add_section (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SectionlessTestCase.test_disabled_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SectionlessTestCase.test_empty_unnamed_section (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SectionlessTestCase.test_multiple_configs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SectionlessTestCase.test_no_first_section (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SectionlessTestCase.test_no_section (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>
