# Triage report: `conv_htmlparser_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_htmlparser.py
- guest leg: 0/50 marks
- pins: **0 passed** / 50 run (+17 quarantined of 67 extracted)

| pin | result | got |
|---|---|---|
| HTMLParserTestCase.test_processing_instruction_only | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_simple_html | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_malformatted_charref | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_unclosed_entityref | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_eof_in_entityref | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_unclosed_charref | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_eof_in_charref | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_bad_nesting | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_bare_ampersands | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_bare_pointy_brackets | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_starttag_end_boundary | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_buffer_artefacts | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_valid_doctypes | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_startendtag | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_get_starttag_text | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_noscript_content | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_plaintext_content | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_comments | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_condcoms | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_tolerant_parsing | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_starttag_junk_chars | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_slashes_in_starttag | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_slashes_in_endtag | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_declaration_junk_chars | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_illegal_declarations | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_invalid_end_tags | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_broken_invalid_end_tag | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_correct_detection_of_start_tags | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_eof_in_comments | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_eof_in_declarations | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_bogus_comments | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_broken_condcoms | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HTMLParserTestCase.test_cdata_section | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_attr_syntax | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_attr_values | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_attr_nonascii | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_attr_entity_replacement | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_attr_funky_names | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_entityrefs_in_attributes | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_attr_funky_names2 | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_entities_in_attribute_value | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_malformed_attributes | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_malformed_adjacent_attributes | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_adjacent_attributes | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_missing_attribute_value | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_javascript_attribute_value | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_end_tag_in_attribute_value | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_with_unquoted_attributes | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_comma_between_attributes | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| AttributesTestCase.test_weird_chars_in_unquoted_attribute_values | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |

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

## Expected vs got

### AttributesTestCase.test_adjacent_attributes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_attr_entity_replacement (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_attr_funky_names (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_attr_funky_names2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_attr_nonascii (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_attr_syntax (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_attr_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_comma_between_attributes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_end_tag_in_attribute_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_entities_in_attribute_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_entityrefs_in_attributes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_javascript_attribute_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_malformed_adjacent_attributes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_malformed_attributes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_missing_attribute_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_weird_chars_in_unquoted_attribute_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### AttributesTestCase.test_with_unquoted_attributes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_bad_nesting (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_bare_ampersands (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_bare_pointy_brackets (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_bogus_comments (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_broken_condcoms (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_broken_invalid_end_tag (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_buffer_artefacts (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_cdata_section (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_comments (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_condcoms (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_correct_detection_of_start_tags (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_declaration_junk_chars (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_eof_in_charref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_eof_in_comments (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_eof_in_declarations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_eof_in_entityref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_get_starttag_text (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_illegal_declarations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_invalid_end_tags (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_malformatted_charref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_noscript_content (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_plaintext_content (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_processing_instruction_only (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_simple_html (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_slashes_in_endtag (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_slashes_in_starttag (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_startendtag (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_starttag_end_boundary (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_starttag_junk_chars (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_tolerant_parsing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_unclosed_charref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_unclosed_entityref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HTMLParserTestCase.test_valid_doctypes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>
