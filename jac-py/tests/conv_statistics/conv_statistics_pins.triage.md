# Triage report: `conv_statistics_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_statistics.py
- guest leg: 0/270 marks
- pins: **15 passed** / 270 run (+108 quarantined of 378 extracted)

| pin | result | got |
|---|---|---|
| TestModules.test_py_functions | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
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
| TestNumericTestCase.test_numerictestcase_is_testcase | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| TestNumericTestCase.test_error_msg_numeric | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| TestNumericTestCase.test_error_msg_sequence | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| GlobalsTest.test_meta | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| StatisticsErrorTest.test_has_exception | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ExactRatioTest.test_int | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ExactRatioTest.test_fraction | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ExactRatioTest.test_float | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ExactRatioTest.test_decimal | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ExactRatioTest.test_inf | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ExactRatioTest.test_float_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ExactRatioTest.test_decimal_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DecimalToRatioTest.test_infinity | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DecimalToRatioTest.test_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DecimalToRatioTest.test_sign | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DecimalToRatioTest.test_negative_exponent | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DecimalToRatioTest.test_positive_exponent | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| DecimalToRatioTest.test_regression_20536 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| IsFiniteTest.test_finite | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| IsFiniteTest.test_infinity | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| IsFiniteTest.test_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CoerceTest.test_bool | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CoerceTest.test_int | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CoerceTest.test_fraction | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CoerceTest.test_decimal | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CoerceTest.test_float | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CoerceTest.test_non_numeric_types | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CoerceTest.test_incompatible_types | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ConvertTest.test_int | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ConvertTest.test_inf | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ConvertTest.test_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| ConvertTest.test_invalid_input_type | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| FailNegTest.test_pass_through | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| FailNegTest.test_negatives_raise | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| FailNegTest.test_error_msg | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSumCommon.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_no_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSumCommon.test_empty_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSumCommon.test_no_inplace_modifications | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSumCommon.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_order_doesnt_matter | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSumCommon.test_type_of_data_collection | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSumCommon.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSum.test_empty_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSum.test_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSum.test_floats | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSum.test_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSum.test_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSum.test_strings_fail | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSum.test_bytes_fail | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSum.test_mixed_sum | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| SumSpecialValues.test_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| SumSpecialValues.test_float_inf | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| SumSpecialValues.test_decimal_inf | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| SumSpecialValues.test_float_mismatched_infs | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| SumSpecialValues.test_decimal_extendedcontext_mismatched_infs_to_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| SumSpecialValues.test_decimal_basiccontext_mismatched_infs_to_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| SumSpecialValues.test_decimal_snan_raises | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_repeated_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_torture_pep | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_floats | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_inf | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_mismatched_infs | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_big_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_regression_20561 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMean.test_regression_25177 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_zero | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_negative_error | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_invalid_type_error | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_floats_exact | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_singleton_lists | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_decimals_exact | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_inf | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_nan | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_multiply_data_points | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestHarmonicMean.test_with_weights | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_even_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_odd_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_odd_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_odd_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_odd_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_odd_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_odd_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_odd_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_even_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_even_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianLow.test_even_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_even_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_even_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianHigh.test_even_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_repeated_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_odd_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_even_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_odd_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_even_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMedianGrouped.test_data_type_error | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_range_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_nominal_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_discrete_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_bimodal_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_unique_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_none_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMode.test_counter_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestMultiMode.test_basics | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestFMean.test_basics | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestFMean.test_error_cases | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestFMean.test_special_values | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestFMean.test_weights | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_repeated_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_repeated_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_repeated_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_repeated_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_shift_data_exact | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_shift_data_exact | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_shift_data_exact | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_shift_data_exact | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_iter_list_same | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_iter_list_same | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_iter_list_same | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_iter_list_same | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_exact_uniform | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPVariance.test_accuracy_bug_20499 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_ints | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_fractions | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_decimals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_center_not_at_mean | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestVariance.test_accuracy_bug_20499 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_compare_to_variance | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_center_not_at_mean | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestPStdev.test_gh_140938 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSqrtHelpers.test_integer_sqrt_of_frac_rto | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestSqrtHelpers.test_decimal_sqrt_of_frac | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_single_value | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_compare_to_variance | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestStdev.test_center_not_at_mean | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestGeometricMean.test_basics | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestGeometricMean.test_various_input_types | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestGeometricMean.test_big_and_small | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestGeometricMean.test_error_cases | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestGeometricMean.test_special_values | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestGeometricMean.test_mixed_int_and_float | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestKDE.test_kde_kernel_specs | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestQuantiles.test_specific_cases | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestQuantiles.test_specific_cases_inclusive | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestQuantiles.test_equal_inputs | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestQuantiles.test_equal_sized_groups | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestQuantiles.test_error_cases | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestBivariateStatistics.test_unequal_size_error | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestBivariateStatistics.test_small_sample_error | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestCorrelationAndCovariance.test_results | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestCorrelationAndCovariance.test_different_scales | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestCorrelationAndCovariance.test_sqrtprod_helper_function_fundamentals | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestCorrelationAndCovariance.test_correlation_spearman | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestLinearRegression.test_constant_input_error | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestLinearRegression.test_results | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestLinearRegression.test_proportional | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestLinearRegression.test_float_output | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestNormalDistPython.test_slots | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_slots | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_instantiation_and_attributes | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_instantiation_and_attributes | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_alternative_constructor | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_alternative_constructor | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_sample_generation | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_sample_generation | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_pdf | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_pdf | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_cdf | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_cdf | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_quantiles | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_quantiles | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_overlap | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_overlap | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_zscore | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_zscore | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_properties | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_properties | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_same_type_addition_and_subtraction | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_same_type_addition_and_subtraction | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_translation_and_scaling | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_translation_and_scaling | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_unary_operations | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_unary_operations | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_equality | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_equality | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_copy | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_copy | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_pickle | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_pickle | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_hashability | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_hashability | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistPython.test_repr | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| TestNormalDistC.test_repr | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestModules.test_c_functions | decorator:unittest.skipUnless |
| TestSqrtHelpers.test_float_sqrt_of_frac | decorator:support.requires_resource |
| TestKDE.test_kde | decorator:support.requires_resource |
| TestKDE.test_kde_random | decorator:support.requires_resource |
| TestCorrelationAndCovariance.test_sqrtprod_helper_function_improved_accuracy | decorator:unittest.skipIf |
| TestNormalDist.test_inv_cdf | decorator:support.skip_if_pgo_task |
| GlobalsTest.test_check_all | self.assertNotStartsWith |
| ConvertTest.test_fraction | uses-self.**class** |
| ConvertTest.test_float | uses-self.**class** |
| ConvertTest.test_decimal | uses-self.**class** |
| TestMean.test_empty_data | self.func |
| TestHarmonicMean.test_empty_data | self.func |
| TestMedianLow.test_empty_data | self.func |
| TestMedianHigh.test_empty_data | self.func |
| TestMedianGrouped.test_empty_data | self.func |
| TestMode.test_empty_data | self.func |
| TestPVariance.test_empty_data | self.func |
| TestVariance.test_empty_data | self.func |
| TestPStdev.test_empty_data | self.func |
| TestStdev.test_empty_data | self.func |
| TestMean.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestHarmonicMean.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestMedianLow.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestMedianHigh.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestMedianGrouped.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestMode.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestPVariance.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestVariance.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestPStdev.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestStdev.test_no_inplace_modifications | unresolved-name:prepare_data |
| TestMean.test_type_of_data_collection | unresolved-name:prepare_data |
| TestHarmonicMean.test_type_of_data_collection | unresolved-name:prepare_data |
| TestMedianLow.test_type_of_data_collection | unresolved-name:prepare_data |
| TestMedianHigh.test_type_of_data_collection | unresolved-name:prepare_data |
| TestMedianGrouped.test_type_of_data_collection | unresolved-name:prepare_data |
| TestMode.test_type_of_data_collection | unresolved-name:prepare_data |
| TestPVariance.test_type_of_data_collection | unresolved-name:prepare_data |
| TestVariance.test_type_of_data_collection | unresolved-name:prepare_data |
| TestPStdev.test_type_of_data_collection | unresolved-name:prepare_data |
| TestStdev.test_type_of_data_collection | unresolved-name:prepare_data |
| TestMean.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestHarmonicMean.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestMedianLow.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestMedianHigh.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestMedianGrouped.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestMode.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestPVariance.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestVariance.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestPStdev.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestStdev.test_bad_arg_types | unresolved-name:check_for_type_error |
| TestMean.test_type_of_data_element | unresolved-name:prepare_data |
| TestHarmonicMean.test_type_of_data_element | unresolved-name:prepare_data |
| TestMedianLow.test_type_of_data_element | unresolved-name:prepare_data |
| TestMedianHigh.test_type_of_data_element | unresolved-name:prepare_data |
| TestMedianGrouped.test_type_of_data_element | unresolved-name:prepare_data |
| TestMode.test_type_of_data_element | unresolved-name:prepare_data |
| TestPVariance.test_type_of_data_element | unresolved-name:prepare_data |
| TestVariance.test_type_of_data_element | unresolved-name:prepare_data |
| TestPStdev.test_type_of_data_element | unresolved-name:prepare_data |
| TestStdev.test_type_of_data_element | unresolved-name:prepare_data |
| TestMean.test_types_conserved | unresolved-name:prepare_data |
| TestHarmonicMean.test_types_conserved | unresolved-name:prepare_data |
| TestMedianDataType.test_types_conserved | unresolved-name:prepare_data |
| TestMedianLow.test_types_conserved | unresolved-name:prepare_data |
| TestMedianHigh.test_types_conserved | unresolved-name:prepare_data |
| TestMode.test_types_conserved | unresolved-name:prepare_data |
| TestPVariance.test_types_conserved | unresolved-name:prepare_data |
| TestVariance.test_types_conserved | unresolved-name:prepare_data |
| TestHarmonicMean.test_repeated_single_value | unresolved-name:prepare_values_for_repeated_single_test |
| TestMedianLow.test_repeated_single_value | unresolved-name:prepare_values_for_repeated_single_test |
| TestMedianHigh.test_repeated_single_value | unresolved-name:prepare_values_for_repeated_single_test |
| TestMedianGrouped.test_repeated_single_value | unresolved-name:prepare_values_for_repeated_single_test |
| TestMode.test_repeated_single_value | unresolved-name:prepare_values_for_repeated_single_test |
| TestVariance.test_domain_error_regression | unresolved-name:assertApproxEqual |
| TestPStdev.test_domain_error_regression | unresolved-name:assertApproxEqual |
| TestStdev.test_domain_error_regression | unresolved-name:assertApproxEqual |
| TestVariance.test_shift_data | unresolved-name:assertApproxEqual |
| TestPStdev.test_shift_data | unresolved-name:assertApproxEqual |
| TestStdev.test_shift_data | unresolved-name:assertApproxEqual |
| ApproxEqualInexactTest.test_approx_equal_both1 | host-raised:NameError: name 'self' is not defined |
| ApproxEqualInexactTest.test_approx_equal_both2 | host-raised:NameError: name 'self' is not defined |
| ApproxEqualInexactTest.test_approx_equal_both3 | host-raised:NameError: name 'self' is not defined |
| ApproxEqualInexactTest.test_approx_equal_both4 | host-raised:NameError: name 'self' is not defined |
| TestSumCommon.test_bad_arg_types | host-raised:NameError: name 'self' is not defined |
| TestSumCommon.test_type_of_data_element | host-raised:TypeError: issubclass() arg 2 must be a class, a tuple of classes, or a union |
| TestSumCommon.test_types_conserved | host-raised:TypeError: issubclass() arg 2 must be a class, a tuple of classes, or a union |
| TestSum.test_compare_with_math_fsum | host-raised:NameError: name 'self' is not defined |
| SumTortureTest.test_torture | host-raised:NameError: name 'self' is not defined |
| TestMedianGrouped.test_single_value | host-raised:AssertionError: ('assertEqual', 0.7894736842105263, Fraction(15, 19)) |
| TestMean.test_doubled_data | host-raised:NameError: name 'self' is not defined |
| TestHarmonicMean.test_doubled_data | host-raised:NameError: name 'self' is not defined |
| TestMedianLow.test_even_ints | host-raised:AssertionError: ('assertEqual', 3, 3.5) |
| TestMedianHigh.test_even_ints | host-raised:AssertionError: ('assertEqual', 4, 3.5) |
| TestMedianGrouped.test_odd_fractions | host-raised:AssertionError: ('assertEqual', 0.42857142857142855, Fraction(3, 7)) |
| TestMedianLow.test_even_fractions | host-raised:AssertionError: ('assertEqual', Fraction(3, 7), Fraction(1, 2)) |
| TestMedianHigh.test_even_fractions | host-raised:AssertionError: ('assertEqual', Fraction(4, 7), Fraction(1, 2)) |
| TestMedianGrouped.test_even_fractions | host-raised:AssertionError: ('assertEqual', 0.0714285714285714, Fraction(1, 2)) |
| TestMedianGrouped.test_odd_decimals | host-raised:AssertionError: ('assertEqual', 4.2, Decimal('4.2')) |
| TestMedianLow.test_even_decimals | host-raised:AssertionError: ('assertEqual', Decimal('3.1'), Decimal('3.65')) |
| TestMedianHigh.test_even_decimals | host-raised:AssertionError: ('assertEqual', Decimal('4.2'), Decimal('3.65')) |
| TestMedianGrouped.test_even_decimals | host-raised:AssertionError: ('assertEqual', 3.7, Decimal('3.65')) |
| TestMedianGrouped.test_odd_number_repeated | host-raised:NameError: name 'self' is not defined |
| TestMedianGrouped.test_even_number_repeated | host-raised:NameError: name 'self' is not defined |
| TestMedianGrouped.test_interval | host-raised:NameError: name 'self' is not defined |
| TestVariance.test_single_value | host-raised:StatisticsError: variance requires at least two data points |
| TestStdev.test_single_value | host-raised:StatisticsError: stdev requires at least two data points |
| TestPVariance.test_domain_error_regression | host-raised:NameError: name 'self' is not defined |
| TestPVariance.test_shift_data | host-raised:NameError: name 'self' is not defined |

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
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CoerceTest.test_decimal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CoerceTest.test_float (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CoerceTest.test_fraction (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CoerceTest.test_incompatible_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CoerceTest.test_int (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### CoerceTest.test_non_numeric_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ConvertTest.test_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ConvertTest.test_int (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ConvertTest.test_invalid_input_type (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ConvertTest.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DecimalToRatioTest.test_infinity (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DecimalToRatioTest.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DecimalToRatioTest.test_negative_exponent (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DecimalToRatioTest.test_positive_exponent (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DecimalToRatioTest.test_regression_20536 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### DecimalToRatioTest.test_sign (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ExactRatioTest.test_decimal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ExactRatioTest.test_decimal_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ExactRatioTest.test_float (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ExactRatioTest.test_float_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ExactRatioTest.test_fraction (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ExactRatioTest.test_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### ExactRatioTest.test_int (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### FailNegTest.test_error_msg (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### FailNegTest.test_negatives_raise (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### FailNegTest.test_pass_through (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### GlobalsTest.test_meta (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### IsFiniteTest.test_finite (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### IsFiniteTest.test_infinity (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### IsFiniteTest.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### StatisticsErrorTest.test_has_exception (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### SumSpecialValues.test_decimal_basiccontext_mismatched_infs_to_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### SumSpecialValues.test_decimal_extendedcontext_mismatched_infs_to_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### SumSpecialValues.test_decimal_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### SumSpecialValues.test_decimal_snan_raises (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### SumSpecialValues.test_float_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### SumSpecialValues.test_float_mismatched_infs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### SumSpecialValues.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestBivariateStatistics.test_small_sample_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestBivariateStatistics.test_unequal_size_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestCorrelationAndCovariance.test_correlation_spearman (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestCorrelationAndCovariance.test_different_scales (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestCorrelationAndCovariance.test_results (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestCorrelationAndCovariance.test_sqrtprod_helper_function_fundamentals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestFMean.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestFMean.test_error_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestFMean.test_special_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestFMean.test_weights (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestGeometricMean.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestGeometricMean.test_big_and_small (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestGeometricMean.test_error_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestGeometricMean.test_mixed_int_and_float (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestGeometricMean.test_special_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestGeometricMean.test_various_input_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_decimals_exact (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_floats_exact (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_invalid_type_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_multiply_data_points (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_negative_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_singleton_lists (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_with_weights (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestHarmonicMean.test_zero (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestKDE.test_kde_kernel_specs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestLinearRegression.test_constant_input_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestLinearRegression.test_float_output (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestLinearRegression.test_proportional (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestLinearRegression.test_results (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_big_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_floats (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_inf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_mismatched_infs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_nan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_regression_20561 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_regression_25177 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_repeated_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMean.test_torture_pep (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_data_type_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_even_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_even_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_even_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_odd_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_odd_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_odd_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_repeated_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianGrouped.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_even_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_even_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_even_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_odd_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_odd_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_odd_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianHigh.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_even_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_even_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_even_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_odd_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_odd_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_odd_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMedianLow.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_bimodal_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_counter_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_discrete_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_nominal_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_none_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestMode.test_unique_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestModules.test_py_functions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestMultiMode.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestNormalDistC.test_alternative_constructor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_cdf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_equality (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_hashability (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_instantiation_and_attributes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_overlap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_pdf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_pickle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_properties (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_quantiles (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_same_type_addition_and_subtraction (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_sample_generation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_slots (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_translation_and_scaling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_unary_operations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistC.test_zscore (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_alternative_constructor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_cdf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_equality (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_hashability (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_instantiation_and_attributes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_overlap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_pdf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_pickle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_properties (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_quantiles (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_same_type_addition_and_subtraction (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_sample_generation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_slots (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_translation_and_scaling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_unary_operations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNormalDistPython.test_zscore (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### TestNumericTestCase.test_error_msg_numeric (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### TestNumericTestCase.test_error_msg_sequence (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### TestNumericTestCase.test_numerictestcase_is_testcase (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### TestPStdev.test_center_not_at_mean (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_compare_to_variance (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_gh_140938 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_iter_list_same (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_repeated_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_shift_data_exact (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPStdev.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_accuracy_bug_20499 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_exact_uniform (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_iter_list_same (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_repeated_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_shift_data_exact (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestPVariance.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestQuantiles.test_equal_inputs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestQuantiles.test_equal_sized_groups (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestQuantiles.test_error_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestQuantiles.test_specific_cases (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestQuantiles.test_specific_cases_inclusive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSqrtHelpers.test_decimal_sqrt_of_frac (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSqrtHelpers.test_integer_sqrt_of_frac_rto (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_center_not_at_mean (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_compare_to_variance (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_iter_list_same (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_repeated_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_shift_data_exact (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestStdev.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSum.test_bytes_fail (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSum.test_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSum.test_empty_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSum.test_floats (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSum.test_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSum.test_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSum.test_mixed_sum (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSum.test_strings_fail (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSumCommon.test_empty_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSumCommon.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSumCommon.test_no_inplace_modifications (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSumCommon.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSumCommon.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestSumCommon.test_type_of_data_collection (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_accuracy_bug_20499 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_center_not_at_mean (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_decimals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_fractions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_ints (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_iter_list_same (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_no_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_order_doesnt_matter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_range_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_repeated_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_shift_data_exact (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestVariance.test_single_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">
