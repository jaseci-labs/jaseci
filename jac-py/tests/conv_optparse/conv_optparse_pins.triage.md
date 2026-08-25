# Triage report: `conv_optparse_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_optparse.py
- guest leg: 0/43 marks
- pins: **42 passed** / 43 run (+111 quarantined of 154 extracted)

| pin | result | got |
|---|---|---|
| TestOptionChecks.test_opt_string_empty | PASS | |
| TestOptionChecks.test_opt_string_too_short | PASS | |
| TestOptionChecks.test_opt_string_short_invalid | PASS | |
| TestOptionChecks.test_opt_string_long_invalid | PASS | |
| TestOptionChecks.test_attr_invalid | PASS | |
| TestOptionChecks.test_action_invalid | PASS | |
| TestOptionChecks.test_type_invalid | PASS | |
| TestOptionChecks.test_no_type_for_action | PASS | |
| TestOptionChecks.test_no_choices_list | PASS | |
| TestOptionChecks.test_bad_choices_list | PASS | |
| TestOptionChecks.test_no_choices_for_type | PASS | |
| TestOptionChecks.test_no_const_for_action | PASS | |
| TestOptionChecks.test_no_nargs_for_action | PASS | |
| TestOptionChecks.test_callback_not_callable | PASS | |
| TestOptionChecks.test_no_callback_for_action | PASS | |
| TestOptionChecks.test_no_callback_args_for_action | PASS | |
| TestOptionChecks.test_no_callback_kwargs_for_action | PASS | |
| TestOptionChecks.test_no_single_dash | PASS | |
| TestOptionParser.test_add_option_no_Option | PASS | |
| TestOptionParser.test_add_option_invalid_arguments | PASS | |
| TestOptionParser.test_get_option | PASS | |
| TestOptionParser.test_get_option_equals | PASS | |
| TestOptionParser.test_has_option | PASS | |
| TestOptionParser.test_remove_nonexistent | PASS | |
| TestOptionValues.test_basics | PASS | |
| TestTypeAliases.test_str_aliases_string | PASS | |
| TestTypeAliases.test_type_object | PASS | |
| TestDefaultValues.test_basic_defaults | PASS | |
| TestDefaultValues.test_mixed_defaults_post | PASS | |
| TestDefaultValues.test_mixed_defaults_pre | PASS | |
| TestStandard.test_defaults | PASS | |
| TestChoice.test_add_choice_option | PASS | |
| TestOptionGroup.test_add_group_no_group | PASS | |
| TestOptionGroup.test_add_group_invalid_arguments | PASS | |
| TestOptionGroup.test_add_group_wrong_parser | PASS | |
| TestOptionGroup.test_group_manipulate | PASS | |
| TestConflict.test_no_such_conflict_handler | PASS | |
| TestConflictOverride.test_conflict_override_opts | PASS | |
| TestMatchAbbrev.test_match_abbrev | PASS | |
| TestMatchAbbrev.test_match_abbrev_error | PASS | |
| TestParseNumber.test_parse_num_fail | PASS | |
| TestParseNumber.test_parse_num_ok | PASS | |
| MiscTestCase.test_lazy_import | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestOptionParser.test_refleak | decorator:support.impl_detail |
| TestDefaultValues.test_process_default | unresolved-name:DurationOption |
| TestProgName.test_default_progname | helper:assertHelp(uses-self.failureException) |
| TestProgName.test_custom_progname | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_option_default | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_parser_default_1 | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_parser_default_2 | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_no_default | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_default_none_1 | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_default_none_2 | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_float_default | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_alt_expand | helper:assertHelp(uses-self.failureException) |
| TestExpandDefaults.test_no_expand | helper:assertHelp(uses-self.failureException) |
| TestVersion.test_version | unresolved-name:InterceptingOptionParser |
| TestVersion.test_no_version | unresolved-name:InterceptingOptionParser |
| TestExtendAddActions.test_extend_add_action | helper:setUp(uses-self.MyOption) |
| TestExtendAddActions.test_extend_add_action_normal | helper:setUp(uses-self.MyOption) |
| TestCallback.test_callback_help | helper:assertHelp(uses-self.failureException) |
| TestTranslations.test_translations | self.assertMsgidsEqual |
| TestOptionChecks.test_callback_args_no_tuple | host-raised:AttributeError: '_SelfNS' object has no attribute 'dummy' |
| TestOptionChecks.test_callback_kwargs_no_dict | host-raised:AttributeError: '_SelfNS' object has no attribute 'dummy' |
| TestOptionParser.test_remove_short_opt | host-raised:NameError: name 'self' is not defined |
| TestOptionParser.test_remove_long_opt | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_required_value | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_invalid_integer | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_no_such_option | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_long_invalid_integer | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_empty | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_shortopt_empty_longopt_append | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_long_option_append | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_option_argument_joined | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_option_argument_split | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_option_argument_joined_integer | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_option_argument_split_negative_integer | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_long_option_argument_joined | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_long_option_argument_split | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_long_option_short_option | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_abbrev_long_option | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_ambiguous_option | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_short_and_long_option_split | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_short_option_split_long_option_append | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_short_option_split_one_positional_arg | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_short_option_consumes_separator | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_short_option_joined_and_separator | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_hyphen_becomes_positional_arg | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_no_append_versus_append | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_option_consumes_optionlike_string | host-raised:NameError: name 'self' is not defined |
| TestStandard.test_combined_single_invalid_option | host-raised:NameError: name 'self' is not defined |
| TestBool.test_bool_default | host-raised:NameError: name 'self' is not defined |
| TestBool.test_bool_false | host-raised:NameError: name 'self' is not defined |
| TestBool.test_bool_true | host-raised:NameError: name 'self' is not defined |
| TestBool.test_bool_flicker_on_and_off | host-raised:NameError: name 'self' is not defined |
| TestChoice.test_valid_choice | host-raised:NameError: name 'self' is not defined |
| TestChoice.test_invalid_choice | host-raised:NameError: name 'self' is not defined |
| TestCount.test_empty | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_one | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_three | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_three_apart | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_override_amount | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_override_quiet | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_overriding | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_interspersed_args | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_no_interspersed_args | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_no_such_option | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_option_no_value | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_with_default | host-raised:NameError: name 'self' is not defined |
| TestCount.test_count_overriding_default | host-raised:NameError: name 'self' is not defined |
| TestMultipleArgs.test_nargs_with_positional_args | host-raised:NameError: name 'self' is not defined |
| TestMultipleArgs.test_nargs_long_opt | host-raised:NameError: name 'self' is not defined |
| TestMultipleArgs.test_nargs_invalid_float_value | host-raised:NameError: name 'self' is not defined |
| TestMultipleArgs.test_nargs_required_values | host-raised:NameError: name 'self' is not defined |
| TestMultipleArgsAppend.test_nargs_append | host-raised:NameError: name 'self' is not defined |
| TestMultipleArgsAppend.test_nargs_append_required_values | host-raised:NameError: name 'self' is not defined |
| TestMultipleArgsAppend.test_nargs_append_simple | host-raised:NameError: name 'self' is not defined |
| TestMultipleArgsAppend.test_nargs_append_const | host-raised:NameError: name 'self' is not defined |
| TestConflictingDefaults.test_conflict_default | host-raised:NameError: name 'self' is not defined |
| TestConflictingDefaults.test_conflict_default_none | host-raised:NameError: name 'self' is not defined |
| TestOptionGroup.test_option_group_create_instance | host-raised:NameError: name 'self' is not defined |
| TestExtendAddTypes.test_filetype_ok | host-raised:AttributeError: '_SelfNS' object has no attribute 'MyOption' |
| TestExtendAddTypes.test_filetype_noexist | host-raised:AttributeError: '_SelfNS' object has no attribute 'MyOption' |
| TestExtendAddTypes.test_filetype_notfile | host-raised:AttributeError: '_SelfNS' object has no attribute 'MyOption' |
| TestCallback.test_callback | host-raised:AttributeError: '_SelfNS' object has no attribute 'process_opt' |
| TestCallbackExtraArgs.test_callback_extra_args | host-raised:AttributeError: '_SelfNS' object has no attribute 'process_tuple' |
| TestCallbackMeddleArgs.test_callback_meddle_args | host-raised:AttributeError: '_SelfNS' object has no attribute 'process_n' |
| TestCallbackMeddleArgs.test_callback_meddle_args_separator | host-raised:AttributeError: '_SelfNS' object has no attribute 'process_n' |
| TestCallbackManyArgs.test_many_args | host-raised:AttributeError: '_SelfNS' object has no attribute 'process_many' |
| TestCallbackCheckAbbrev.test_abbrev_callback_expansion | host-raised:AttributeError: '_SelfNS' object has no attribute 'check_abbrev' |
| TestCallbackVarArgs.test_variable_args | host-raised:AttributeError: '_SelfNS' object has no attribute 'variable_args' |
| TestCallbackVarArgs.test_consume_separator_stop_at_option | host-raised:AttributeError: '_SelfNS' object has no attribute 'variable_args' |
| TestCallbackVarArgs.test_positional_arg_and_variable_args | host-raised:AttributeError: '_SelfNS' object has no attribute 'variable_args' |
| TestCallbackVarArgs.test_stop_at_option | host-raised:AttributeError: '_SelfNS' object has no attribute 'variable_args' |
| TestCallbackVarArgs.test_stop_at_invalid_option | host-raised:AttributeError: '_SelfNS' object has no attribute 'variable_args' |
| TestConflict.test_conflict_error | host-raised:NameError: name 'self' is not defined |
| TestConflict.test_conflict_error_group | host-raised:NameError: name 'self' is not defined |
| TestConflictResolve.test_conflict_resolve | harness-error:NameError: name 'BaseTest' is not defined |
| TestConflictResolve.test_conflict_resolve_help | harness-error:NameError: name 'BaseTest' is not defined |
| TestConflictResolve.test_conflict_resolve_short_opt | harness-error:NameError: name 'BaseTest' is not defined |
| TestConflictResolve.test_conflict_resolve_long_opt | harness-error:NameError: name 'BaseTest' is not defined |
| TestConflictResolve.test_conflict_resolve_long_opts | harness-error:NameError: name 'BaseTest' is not defined |
| TestConflictOverride.test_conflict_override_help | host-raised:NameError: name 'self' is not defined |
| TestConflictOverride.test_conflict_override_args | host-raised:NameError: name 'self' is not defined |
| TestHelp.test_help | host-raised:NameError: name 'self' is not defined |
| TestHelp.test_help_old_usage | host-raised:NameError: name 'self' is not defined |
| TestHelp.test_help_long_opts_first | host-raised:NameError: name 'self' is not defined |
| TestHelp.test_help_title_formatter | host-raised:NameError: name 'self' is not defined |
| TestHelp.test_wrap_columns | host-raised:NameError: name 'self' is not defined |
| TestHelp.test_help_unicode | host-raised:NameError: name 'self' is not defined |
| TestHelp.test_help_unicode_description | host-raised:NameError: name 'self' is not defined |
| TestHelp.test_help_description_groups | host-raised:NameError: name 'self' is not defined |
| TestParseNumber.test_numeric_options | host-raised:NameError: name 'self' is not defined |
| MiscTestCase.test__all__ | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### MiscTestCase.test_lazy_import (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">
