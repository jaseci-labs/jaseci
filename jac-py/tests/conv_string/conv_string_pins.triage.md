# Triage report: `conv_string_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_string/test_string.py
- guest leg: 0/25 marks
- pins: **13 passed** / 25 run (+16 quarantined of 41 extracted)

| pin | result | got |
|---|---|---|
| LazyImportTest.test_lazy_import | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| ModuleTest.test_attrs | PASS | |
| ModuleTest.test_capwords | PASS | |
| ModuleTest.test_basic_formatter | PASS | |
| ModuleTest.test_format_keyword_arguments | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| ModuleTest.test_auto_numbering | PASS | |
| ModuleTest.test_conversion_specifiers | PASS | |
| ModuleTest.test_name_lookup | PASS | |
| ModuleTest.test_index_lookup | PASS | |
| ModuleTest.test_auto_numbering_lookup | PASS | |
| ModuleTest.test_override_get_value | PASS | |
| ModuleTest.test_override_format_field | PASS | |
| ModuleTest.test_override_convert_field | PASS | |
| ModuleTest.test_override_parse | PASS | |
| ModuleTest.test_check_unused_args | PASS | |
| TestTemplate.test_regular_templates | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'sub'"> |
| TestTemplate.test_regular_templates_with_braces | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'sub'"> |
| TestTemplate.test_regular_templates_with_upper_case | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'sub'"> |
| TestTemplate.test_regular_templates_with_non_letters | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'sub'"> |
| TestTemplate.test_flags_override | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| TestTemplate.test_idpattern_override_inside_outside | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| TestTemplate.test_idpattern_override_inside_outside_invalid_unbraced | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| TestTemplate.test_braced_override | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| TestTemplate.test_braced_override_safe | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'> |
| TestTemplate.test_unicode_values | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'sub'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| ModuleTest.test_auto_numbering_reenterability | uses-self.format |
| ModuleTest.test_vformat_recursion_limit | unresolved-name:err |
| TestTemplate.test_idpattern_override | unresolved-name:Bag |
| TestTemplate.test_pattern_override | unresolved-name:Bag |
| TestTemplate.test_invalid_with_no_lines | unresolved-name:err |
| TestTemplate.test_escapes | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_percents | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_stringification | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_tupleargs | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_SafeTemplate | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_invalid_placeholders | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertRaises' |
| TestTemplate.test_keyword_arguments | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_keyword_arguments_safe | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_delimiter_override | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_is_valid | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| TestTemplate.test_get_identifiers | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |

## Expected vs got

### LazyImportTest.test_lazy_import (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### ModuleTest.test_format_keyword_arguments (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### TestTemplate.test_braced_override (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### TestTemplate.test_braced_override_safe (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### TestTemplate.test_flags_override (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### TestTemplate.test_idpattern_override_inside_outside (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### TestTemplate.test_idpattern_override_inside_outside_invalid_unbraced (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'super\' object has no attribute \'**init_subclass**\'"'>

### TestTemplate.test_regular_templates (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'sub'">

### TestTemplate.test_regular_templates_with_braces (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'sub'">

### TestTemplate.test_regular_templates_with_non_letters (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'sub'">

### TestTemplate.test_regular_templates_with_upper_case (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'sub'">

### TestTemplate.test_unicode_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'sub'">
