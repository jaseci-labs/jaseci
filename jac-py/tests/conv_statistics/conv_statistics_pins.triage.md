# Triage report: `conv_statistics_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_statistics.py
- guest leg: 0/100 marks
- pins: **15 passed** / 100 run (+132 quarantined of 232 extracted)

| pin | result | got |
|---|---|---|
| TestSign.testZeroes | PASS | |
| ApproxEqualSymmetryTest.test_relative_symmetry | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'> |
| ApproxEqualSymmetryTest.test_symmetry | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'> |
| ApproxEqualExactTest.test_exactly_equal_ints | PASS | |
| ApproxEqualExactTest.test_exactly_equal_floats | PASS | |
| ApproxEqualExactTest.test_exactly_equal_fractions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'must be real number, not Fraction'"> |
| ApproxEqualExactTest.test_exactly_equal_decimals | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'"> |
| ApproxEqualExactTest.test_exactly_equal_absolute | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'must be real number, not Fraction'"> |
| ApproxEqualExactTest.test_exactly_equal_absolute_decimals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'> |
| ApproxEqualExactTest.test_exactly_equal_relative | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'must be real number, not Fraction'"> |
| ApproxEqualExactTest.test_exactly_equal_both | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'must be real number, not Fraction'"> |
| ApproxEqualUnequalTest.test_exactly_unequal_ints | PASS | |
| ApproxEqualUnequalTest.test_exactly_unequal_floats | PASS | |
| ApproxEqualUnequalTest.test_exactly_unequal_fractions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'"> |
| ApproxEqualUnequalTest.test_exactly_unequal_decimals | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'"> |
| ApproxEqualInexactTest.test_approx_equal_absolute_ints | PASS | |
| ApproxEqualInexactTest.test_approx_equal_absolute_floats | PASS | |
| ApproxEqualInexactTest.test_approx_equal_absolute_fractions | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for *: \'int\' and \'Fraction\'"'> |
| ApproxEqualInexactTest.test_approx_equal_absolute_decimals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'> |
| ApproxEqualInexactTest.test_cross_zero | PASS | |
| ApproxEqualInexactTest.test_approx_equal_relative_ints | PASS | |
| ApproxEqualInexactTest.test_approx_equal_relative_floats | PASS | |
| ApproxEqualInexactTest.test_approx_equal_relative_fractions | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for +: \'int\' and \'Fraction\'"'> |
| ApproxEqualInexactTest.test_approx_equal_relative_decimals | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'> |
| ApproxEqualSpecialsTest.test_inf | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'"> |
| ApproxEqualSpecialsTest.test_nan | PASS | |
| ApproxEqualSpecialsTest.test_float_zeroes | PASS | |
| ApproxEqualSpecialsTest.test_decimal_zeroes | PASS | |
| TestApproxEqualErrors.test_bad_tol | PASS | |
| TestApproxEqualErrors.test_bad_rel | PASS | |
| TestNumericTestCase.test_error_msg_numeric | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute '**init_subclass**'"> |
| TestNumericTestCase.test_error_msg_sequence | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'result' from 'unittest' (/home/jac/.cache/jac/rt/553c250071fd962f-c152554fd6e7fdad/python/lib/python3.14/unittest/**init**.py)"> |
| ExactRatioTest.test_int | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExactRatioTest.test_fraction | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExactRatioTest.test_float | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ExactRatioTest.test_decimal | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExactRatioTest.test_inf | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExactRatioTest.test_float_nan | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ExactRatioTest.test_decimal_nan | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| DecimalToRatioTest.test_infinity | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| DecimalToRatioTest.test_nan | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| DecimalToRatioTest.test_sign | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| DecimalToRatioTest.test_negative_exponent | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| DecimalToRatioTest.test_positive_exponent | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| DecimalToRatioTest.test_regression_20536 | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| IsFiniteTest.test_finite | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| IsFiniteTest.test_infinity | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| IsFiniteTest.test_nan | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoerceTest.test_bool | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoerceTest.test_int | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoerceTest.test_fraction | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoerceTest.test_decimal | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoerceTest.test_float | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoerceTest.test_non_numeric_types | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| CoerceTest.test_incompatible_types | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ConvertTest.test_int | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ConvertTest.test_inf | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ConvertTest.test_nan | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| ConvertTest.test_invalid_input_type | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| FailNegTest.test_pass_through | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| FailNegTest.test_negatives_raise | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| FailNegTest.test_error_msg | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| SumSpecialValues.test_nan | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SumSpecialValues.test_float_inf | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SumSpecialValues.test_decimal_inf | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SumSpecialValues.test_float_mismatched_infs | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SumSpecialValues.test_decimal_extendedcontext_mismatched_infs_to_nan | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SumSpecialValues.test_decimal_basiccontext_mismatched_infs_to_nan | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| SumSpecialValues.test_decimal_snan_raises | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestMean.test_regression_20561 | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestMean.test_regression_25177 | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestMultiMode.test_basics | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestFMean.test_basics | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestFMean.test_error_cases | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestFMean.test_special_values | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestFMean.test_weights | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestSqrtHelpers.test_integer_sqrt_of_frac_rto | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestSqrtHelpers.test_decimal_sqrt_of_frac | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestGeometricMean.test_basics | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestGeometricMean.test_various_input_types | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestGeometricMean.test_big_and_small | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestGeometricMean.test_error_cases | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestGeometricMean.test_special_values | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestGeometricMean.test_mixed_int_and_float | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestKDE.test_kde_kernel_specs | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestQuantiles.test_specific_cases | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestQuantiles.test_specific_cases_inclusive | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestQuantiles.test_equal_inputs | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestQuantiles.test_equal_sized_groups | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestQuantiles.test_error_cases | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestBivariateStatistics.test_unequal_size_error | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestBivariateStatistics.test_small_sample_error | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestCorrelationAndCovariance.test_results | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestCorrelationAndCovariance.test_different_scales | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestCorrelationAndCovariance.test_sqrtprod_helper_function_fundamentals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestCorrelationAndCovariance.test_correlation_spearman | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestLinearRegression.test_constant_input_error | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestLinearRegression.test_results | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestLinearRegression.test_proportional | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |
| TestLinearRegression.test_float_output | GUEST-WRONG-OUTPUT | RUN<'SystemError: unsupported opcode 36'> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestModules.test_c_functions | decorator:unittest.skipUnless |
| TestSqrtHelpers.test_float_sqrt_of_frac | decorator:support.requires_resource |
| TestKDE.test_kde | decorator:support.requires_resource |
| TestKDE.test_kde_random | decorator:support.requires_resource |
| TestCorrelationAndCovariance.test_sqrtprod_helper_function_improved_accuracy | decorator:unittest.skipIf |
| TestNormalDist.test_inv_cdf | decorator:support.skip_if_pgo_task |
| TestNumericTestCase.test_numerictestcase_is_testcase | self.assertIsSubclass |
| GlobalsTest.test_meta | self.assertHasAttr |
| GlobalsTest.test_check_all | self.assertNotStartsWith |
| StatisticsErrorTest.test_has_exception | self.assertHasAttr |
| ConvertTest.test_fraction | uses-self.**class** |
| ConvertTest.test_float | uses-self.**class** |
| ConvertTest.test_decimal | uses-self.**class** |
| UnivariateCommonMixin.test_no_args | uses-self.func |
| UnivariateCommonMixin.test_empty_data | uses-self.func |
| UnivariateCommonMixin.test_no_inplace_modifications | uses-self.func |
| UnivariateCommonMixin.test_order_doesnt_matter | uses-self.func |
| UnivariateCommonMixin.test_type_of_data_collection | uses-self.func |
| UnivariateCommonMixin.test_range_data | uses-self.func |
| UnivariateCommonMixin.test_bad_arg_types | helper:check_for_type_error(uses-self.func) |
| UnivariateCommonMixin.test_type_of_data_element | uses-self.func |
| UnivariateTypeMixin.test_types_conserved | uses-self.func |
| TestSum.test_empty_data | uses-self.func |
| TestSum.test_ints | uses-self.func |
| TestSum.test_floats | uses-self.func |
| TestSum.test_fractions | uses-self.func |
| TestSum.test_decimals | uses-self.func |
| TestSum.test_compare_with_math_fsum | uses-self.func |
| TestSum.test_strings_fail | uses-self.func |
| TestSum.test_bytes_fail | uses-self.func |
| TestSum.test_mixed_sum | uses-self.func |
| AverageMixin.test_single_value | uses-self.func |
| AverageMixin.test_repeated_single_value | uses-self.func |
| TestMean.test_torture_pep | uses-self.func |
| TestMean.test_ints | uses-self.func |
| TestMean.test_floats | uses-self.func |
| TestMean.test_decimals | uses-self.func |
| TestMean.test_fractions | uses-self.func |
| TestMean.test_inf | uses-self.func |
| TestMean.test_mismatched_infs | uses-self.func |
| TestMean.test_nan | uses-self.func |
| TestMean.test_big_data | uses-self.func |
| TestMean.test_doubled_data | uses-self.func |
| TestHarmonicMean.test_zero | uses-self.func |
| TestHarmonicMean.test_negative_error | uses-self.func |
| TestHarmonicMean.test_invalid_type_error | uses-self.func |
| TestHarmonicMean.test_ints | uses-self.func |
| TestHarmonicMean.test_floats_exact | uses-self.func |
| TestHarmonicMean.test_singleton_lists | uses-self.func |
| TestHarmonicMean.test_decimals_exact | uses-self.func |
| TestHarmonicMean.test_fractions | uses-self.func |
| TestHarmonicMean.test_inf | uses-self.func |
| TestHarmonicMean.test_nan | uses-self.func |
| TestHarmonicMean.test_multiply_data_points | uses-self.func |
| TestHarmonicMean.test_doubled_data | uses-self.func |
| TestHarmonicMean.test_with_weights | uses-self.func |
| TestMedian.test_even_ints | uses-self.func |
| TestMedian.test_odd_ints | uses-self.func |
| TestMedian.test_odd_fractions | uses-self.func |
| TestMedian.test_even_fractions | uses-self.func |
| TestMedian.test_odd_decimals | uses-self.func |
| TestMedian.test_even_decimals | uses-self.func |
| TestMedianLow.test_even_ints | uses-self.func |
| TestMedianLow.test_even_fractions | uses-self.func |
| TestMedianLow.test_even_decimals | uses-self.func |
| TestMedianHigh.test_even_ints | uses-self.func |
| TestMedianHigh.test_even_fractions | uses-self.func |
| TestMedianHigh.test_even_decimals | uses-self.func |
| TestMedianGrouped.test_odd_number_repeated | uses-self.func |
| TestMedianGrouped.test_even_number_repeated | uses-self.func |
| TestMedianGrouped.test_repeated_single_value | uses-self.func |
| TestMedianGrouped.test_single_value | uses-self.func |
| TestMedianGrouped.test_odd_fractions | uses-self.func |
| TestMedianGrouped.test_even_fractions | uses-self.func |
| TestMedianGrouped.test_odd_decimals | uses-self.func |
| TestMedianGrouped.test_even_decimals | uses-self.func |
| TestMedianGrouped.test_interval | uses-self.func |
| TestMedianGrouped.test_data_type_error | uses-self.func |
| TestMode.test_range_data | uses-self.func |
| TestMode.test_nominal_data | uses-self.func |
| TestMode.test_discrete_data | uses-self.func |
| TestMode.test_bimodal_data | uses-self.func |
| TestMode.test_unique_data | uses-self.func |
| TestMode.test_none_data | uses-self.func |
| TestMode.test_counter_data | uses-self.func |
| VarianceStdevMixin.test_single_value | uses-self.func |
| VarianceStdevMixin.test_repeated_single_value | uses-self.func |
| VarianceStdevMixin.test_domain_error_regression | self.assertApproxEqual |
| VarianceStdevMixin.test_shift_data | self.assertApproxEqual |
| VarianceStdevMixin.test_shift_data_exact | uses-self.func |
| VarianceStdevMixin.test_iter_list_same | uses-self.func |
| TestPVariance.test_exact_uniform | uses-self.func |
| TestPVariance.test_ints | uses-self.func |
| TestPVariance.test_fractions | uses-self.func |
| TestPVariance.test_decimals | uses-self.func |
| TestPVariance.test_accuracy_bug_20499 | uses-self.func |
| TestVariance.test_single_value | uses-self.func |
| TestVariance.test_ints | uses-self.func |
| TestVariance.test_fractions | uses-self.func |
| TestVariance.test_decimals | uses-self.func |
| TestVariance.test_center_not_at_mean | uses-self.func |
| TestVariance.test_accuracy_bug_20499 | uses-self.func |
| TestPStdev.test_compare_to_variance | uses-self.func |
| TestPStdev.test_center_not_at_mean | uses-self.func |
| TestPStdev.test_gh_140938 | uses-self.func |
| TestStdev.test_single_value | uses-self.func |
| TestStdev.test_compare_to_variance | uses-self.func |
| TestStdev.test_center_not_at_mean | uses-self.func |
| TestModules.test_py_functions | host-raised:AttributeError: '_SelfNS' object has no attribute 'func_names' |
| ApproxEqualInexactTest.test_approx_equal_both1 | host-raised:NameError: name 'self' is not defined |
| ApproxEqualInexactTest.test_approx_equal_both2 | host-raised:NameError: name 'self' is not defined |
| ApproxEqualInexactTest.test_approx_equal_both3 | host-raised:NameError: name 'self' is not defined |
| ApproxEqualInexactTest.test_approx_equal_both4 | host-raised:NameError: name 'self' is not defined |
| SumTortureTest.test_torture | host-raised:NameError: name 'self' is not defined |
| TestNormalDist.test_slots | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_instantiation_and_attributes | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_alternative_constructor | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_sample_generation | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_pdf | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_cdf | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_quantiles | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_overlap | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_zscore | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_properties | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_same_type_addition_and_subtraction | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_translation_and_scaling | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_unary_operations | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_equality | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_copy | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_pickle | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_hashability | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |
| TestNormalDist.test_repr | host-raised:AttributeError: '_SelfNS' object has no attribute 'module' |

## Expected vs got

### ApproxEqualExactTest.test_exactly_equal_absolute (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'must be real number, not Fraction'">

### ApproxEqualExactTest.test_exactly_equal_absolute_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'>

### ApproxEqualExactTest.test_exactly_equal_both (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'must be real number, not Fraction'">

### ApproxEqualExactTest.test_exactly_equal_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'">

### ApproxEqualExactTest.test_exactly_equal_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'must be real number, not Fraction'">

### ApproxEqualExactTest.test_exactly_equal_relative (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'must be real number, not Fraction'">

### ApproxEqualInexactTest.test_approx_equal_absolute_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'>

### ApproxEqualInexactTest.test_approx_equal_absolute_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for *: \'int\' and \'Fraction\'"'>

### ApproxEqualInexactTest.test_approx_equal_relative_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'>

### ApproxEqualInexactTest.test_approx_equal_relative_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for +: \'int\' and \'Fraction\'"'>

### ApproxEqualSpecialsTest.test_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'">

### ApproxEqualSymmetryTest.test_relative_symmetry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'>

### ApproxEqualSymmetryTest.test_symmetry (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'<\' not supported between instances of \'host\' and \'int\'"'>

### ApproxEqualUnequalTest.test_exactly_unequal_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'">

### ApproxEqualUnequalTest.test_exactly_unequal_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'bad operand type for unary -'">

### CoerceTest.test_bool (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoerceTest.test_decimal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoerceTest.test_float (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoerceTest.test_fraction (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoerceTest.test_incompatible_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoerceTest.test_int (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### CoerceTest.test_non_numeric_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ConvertTest.test_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ConvertTest.test_int (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ConvertTest.test_invalid_input_type (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ConvertTest.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### DecimalToRatioTest.test_infinity (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### DecimalToRatioTest.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### DecimalToRatioTest.test_negative_exponent (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### DecimalToRatioTest.test_positive_exponent (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### DecimalToRatioTest.test_regression_20536 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### DecimalToRatioTest.test_sign (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExactRatioTest.test_decimal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExactRatioTest.test_decimal_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExactRatioTest.test_float (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ExactRatioTest.test_float_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExactRatioTest.test_fraction (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExactRatioTest.test_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### ExactRatioTest.test_int (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### FailNegTest.test_error_msg (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### FailNegTest.test_negatives_raise (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### FailNegTest.test_pass_through (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### IsFiniteTest.test_finite (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### IsFiniteTest.test_infinity (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### IsFiniteTest.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SumSpecialValues.test_decimal_basiccontext_mismatched_infs_to_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SumSpecialValues.test_decimal_extendedcontext_mismatched_infs_to_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SumSpecialValues.test_decimal_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SumSpecialValues.test_decimal_snan_raises (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SumSpecialValues.test_float_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SumSpecialValues.test_float_mismatched_infs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### SumSpecialValues.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestBivariateStatistics.test_small_sample_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestBivariateStatistics.test_unequal_size_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestCorrelationAndCovariance.test_correlation_spearman (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestCorrelationAndCovariance.test_different_scales (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestCorrelationAndCovariance.test_results (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestCorrelationAndCovariance.test_sqrtprod_helper_function_fundamentals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestFMean.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestFMean.test_error_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestFMean.test_special_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestFMean.test_weights (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestGeometricMean.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestGeometricMean.test_big_and_small (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestGeometricMean.test_error_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestGeometricMean.test_mixed_int_and_float (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestGeometricMean.test_special_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestGeometricMean.test_various_input_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestKDE.test_kde_kernel_specs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestLinearRegression.test_constant_input_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestLinearRegression.test_float_output (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestLinearRegression.test_proportional (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestLinearRegression.test_results (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestMean.test_regression_20561 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestMean.test_regression_25177 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestMultiMode.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestNumericTestCase.test_error_msg_numeric (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute '**init_subclass**'">

### TestNumericTestCase.test_error_msg_sequence (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'result' from 'unittest' (/home/jac/.cache/jac/rt/553c250071fd962f-c152554fd6e7fdad/python/lib/python3.14/unittest/**init**.py)">

### TestQuantiles.test_equal_inputs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestQuantiles.test_equal_sized_groups (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestQuantiles.test_error_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestQuantiles.test_specific_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestQuantiles.test_specific_cases_inclusive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSqrtHelpers.test_decimal_sqrt_of_frac (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>

### TestSqrtHelpers.test_integer_sqrt_of_frac_rto (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'SystemError: unsupported opcode 36'>
