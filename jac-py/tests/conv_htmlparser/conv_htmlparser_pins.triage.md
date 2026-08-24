# Triage report: `conv_htmlparser_pins.jac`

- source: reference/cpython/Lib/test/test_htmlparser.py
- guest leg: 0/0 marks
- pins: **0 passed** / 0 run (+67 quarantined of 67 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion

| test | reason |
|---|---|
| HTMLParserTestCase.test_script_content | decorator:support.subTests |
| HTMLParserTestCase.test_style_content | decorator:support.subTests |
| HTMLParserTestCase.test_rcdata_content | decorator:support.subTests |
| HTMLParserTestCase.test_rawtext_content | decorator:support.subTests |
| HTMLParserTestCase.test_script_closing_tag | decorator:support.subTests |
| HTMLParserTestCase.test_closing_tag | decorator:support.subTests |
| HTMLParserTestCase.test_invalid_closing_tag | decorator:support.subTests |
| HTMLParserTestCase.test_invalid_nonascii_closing_tag | decorator:support.subTests |
| HTMLParserTestCase.test_eof_in_script | decorator:support.subTests |
| HTMLParserTestCase.test_eof_in_title | decorator:support.subTests |
| HTMLParserTestCase.test_eof_in_cdata | decorator:support.subTests |
| HTMLParserTestCase.test_cdata_section_content | decorator:support.subTests |
| HTMLParserTestCase.test_eof_no_quadratic_complexity | decorator:support.requires_resource |
| HTMLParserTestCase.test_processing_instruction_only | self._run_check |
| HTMLParserTestCase.test_simple_html | self._run_check |
| HTMLParserTestCase.test_malformatted_charref | self._run_check |
| HTMLParserTestCase.test_unclosed_entityref | self._run_check |
| HTMLParserTestCase.test_eof_in_entityref | self._run_check |
| HTMLParserTestCase.test_unclosed_charref | self._run_check |
| HTMLParserTestCase.test_eof_in_charref | self._run_check |
| HTMLParserTestCase.test_bad_nesting | self._run_check |
| HTMLParserTestCase.test_bare_ampersands | self._run_check |
| HTMLParserTestCase.test_bare_pointy_brackets | self._run_check |
| HTMLParserTestCase.test_starttag_end_boundary | self._run_check |
| HTMLParserTestCase.test_buffer_artefacts | self._run_check |
| HTMLParserTestCase.test_valid_doctypes | self._run_check |
| HTMLParserTestCase.test_startendtag | self._run_check |
| HTMLParserTestCase.test_get_starttag_text | self._run_check_extra |
| HTMLParserTestCase.test_noscript_content | self._run_check |
| HTMLParserTestCase.test_plaintext_content | self._run_check |
| HTMLParserTestCase.test_comments | self._run_check |
| HTMLParserTestCase.test_condcoms | self._run_check |
| HTMLParserTestCase.test_convert_charrefs | self._run_check |
| HTMLParserTestCase.test_convert_charrefs_in_attribute_values | self._run_check |
| HTMLParserTestCase.test_tolerant_parsing | self._run_check |
| HTMLParserTestCase.test_starttag_junk_chars | self._run_check |
| HTMLParserTestCase.test_slashes_in_starttag | self._run_check |
| HTMLParserTestCase.test_slashes_in_endtag | self._run_check |
| HTMLParserTestCase.test_declaration_junk_chars | self._run_check |
| HTMLParserTestCase.test_illegal_declarations | self._run_check |
| HTMLParserTestCase.test_invalid_end_tags | self._run_check |
| HTMLParserTestCase.test_broken_invalid_end_tag | self._run_check |
| HTMLParserTestCase.test_correct_detection_of_start_tags | self._run_check |
| HTMLParserTestCase.test_eof_in_comments | self._run_check |
| HTMLParserTestCase.test_eof_in_declarations | self._run_check |
| HTMLParserTestCase.test_bogus_comments | self._run_check |
| HTMLParserTestCase.test_broken_condcoms | self._run_check |
| HTMLParserTestCase.test_cdata_section | self._run_check |
| HTMLParserTestCase.test_convert_charrefs_dropped_text | unresolved-name:EventCollector |
| AttributesTestCase.test_attr_syntax | self._run_check |
| AttributesTestCase.test_attr_values | self._run_check |
| AttributesTestCase.test_attr_nonascii | self._run_check |
| AttributesTestCase.test_attr_entity_replacement | self._run_check |
| AttributesTestCase.test_attr_funky_names | self._run_check |
| AttributesTestCase.test_entityrefs_in_attributes | self._run_check |
| AttributesTestCase.test_attr_funky_names2 | self._run_check |
| AttributesTestCase.test_entities_in_attribute_value | self._run_check |
| AttributesTestCase.test_malformed_attributes | self._run_check |
| AttributesTestCase.test_malformed_adjacent_attributes | self._run_check |
| AttributesTestCase.test_adjacent_attributes | self._run_check |
| AttributesTestCase.test_missing_attribute_value | self._run_check |
| AttributesTestCase.test_javascript_attribute_value | self._run_check |
| AttributesTestCase.test_end_tag_in_attribute_value | self._run_check |
| AttributesTestCase.test_with_unquoted_attributes | self._run_check |
| AttributesTestCase.test_comma_between_attributes | self._run_check |
| AttributesTestCase.test_weird_chars_in_unquoted_attribute_values | self._run_check |
| TestInheritance.test_base_class_methods_called | unresolved-name:EventCollector |
