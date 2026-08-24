# Triage report: `conv_htmlparser_pins.jac`

- source: reference/cpython/Lib/test/test_htmlparser.py
- guest leg: 0/50 marks
- pins: **50 passed** / 50 run (+17 quarantined of 67 extracted)

| pin | result | got |
|---|---|---|
| HTMLParserTestCase.test_processing_instruction_only | PASS | |
| HTMLParserTestCase.test_simple_html | PASS | |
| HTMLParserTestCase.test_malformatted_charref | PASS | |
| HTMLParserTestCase.test_unclosed_entityref | PASS | |
| HTMLParserTestCase.test_eof_in_entityref | PASS | |
| HTMLParserTestCase.test_unclosed_charref | PASS | |
| HTMLParserTestCase.test_eof_in_charref | PASS | |
| HTMLParserTestCase.test_bad_nesting | PASS | |
| HTMLParserTestCase.test_bare_ampersands | PASS | |
| HTMLParserTestCase.test_bare_pointy_brackets | PASS | |
| HTMLParserTestCase.test_starttag_end_boundary | PASS | |
| HTMLParserTestCase.test_buffer_artefacts | PASS | |
| HTMLParserTestCase.test_valid_doctypes | PASS | |
| HTMLParserTestCase.test_startendtag | PASS | |
| HTMLParserTestCase.test_get_starttag_text | PASS | |
| HTMLParserTestCase.test_noscript_content | PASS | |
| HTMLParserTestCase.test_plaintext_content | PASS | |
| HTMLParserTestCase.test_comments | PASS | |
| HTMLParserTestCase.test_condcoms | PASS | |
| HTMLParserTestCase.test_tolerant_parsing | PASS | |
| HTMLParserTestCase.test_starttag_junk_chars | PASS | |
| HTMLParserTestCase.test_slashes_in_starttag | PASS | |
| HTMLParserTestCase.test_slashes_in_endtag | PASS | |
| HTMLParserTestCase.test_declaration_junk_chars | PASS | |
| HTMLParserTestCase.test_illegal_declarations | PASS | |
| HTMLParserTestCase.test_invalid_end_tags | PASS | |
| HTMLParserTestCase.test_broken_invalid_end_tag | PASS | |
| HTMLParserTestCase.test_correct_detection_of_start_tags | PASS | |
| HTMLParserTestCase.test_eof_in_comments | PASS | |
| HTMLParserTestCase.test_eof_in_declarations | PASS | |
| HTMLParserTestCase.test_bogus_comments | PASS | |
| HTMLParserTestCase.test_broken_condcoms | PASS | |
| HTMLParserTestCase.test_cdata_section | PASS | |
| AttributesTestCase.test_attr_syntax | PASS | |
| AttributesTestCase.test_attr_values | PASS | |
| AttributesTestCase.test_attr_nonascii | PASS | |
| AttributesTestCase.test_attr_entity_replacement | PASS | |
| AttributesTestCase.test_attr_funky_names | PASS | |
| AttributesTestCase.test_entityrefs_in_attributes | PASS | |
| AttributesTestCase.test_attr_funky_names2 | PASS | |
| AttributesTestCase.test_entities_in_attribute_value | PASS | |
| AttributesTestCase.test_malformed_attributes | PASS | |
| AttributesTestCase.test_malformed_adjacent_attributes | PASS | |
| AttributesTestCase.test_adjacent_attributes | PASS | |
| AttributesTestCase.test_missing_attribute_value | PASS | |
| AttributesTestCase.test_javascript_attribute_value | PASS | |
| AttributesTestCase.test_end_tag_in_attribute_value | PASS | |
| AttributesTestCase.test_with_unquoted_attributes | PASS | |
| AttributesTestCase.test_comma_between_attributes | PASS | |
| AttributesTestCase.test_weird_chars_in_unquoted_attribute_values | PASS | |

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
| HTMLParserTestCase.test_convert_charrefs | unresolved-name:EventCollectorCharrefs |
| HTMLParserTestCase.test_convert_charrefs_in_attribute_values | unresolved-name:EventCollectorCharrefs |
| HTMLParserTestCase.test_convert_charrefs_dropped_text | unresolved-name:EventCollector |
| TestInheritance.test_base_class_methods_called | unresolved-name:EventCollector |
