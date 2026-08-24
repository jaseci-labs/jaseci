# Triage report: `conv_time_pins.jac`

- source: reference/cpython/Lib/test/test_time.py
- guest leg: 0/15 marks
- pins: **14 passed** / 15 run (+48 quarantined of 63 extracted)

| pin | result | got |
|---|---|---|
| TimeTestCase.test_data_attributes | PASS | |
| TimeTestCase.test_time | PASS | |
| TimeTestCase.test_time_ns_type | PASS | |
| TimeTestCase.test_epoch | PASS | |
| TimeTestCase.test_strftime_format_check | PASS | |
| TimeTestCase.test_default_values_for_zero | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'warnings_helper' from '<unknown>'"> |
| TimeTestCase.test_strptime_bytes | PASS | |
| TimeTestCase.test_ctime | PASS | |
| TimeTestCase.test_insane_timestamps | PASS | |
| TimeTestCase.test_ctime_without_arg | PASS | |
| TimeTestCase.test_gmtime_without_arg | PASS | |
| TimeTestCase.test_localtime_without_arg | PASS | |
| TimeTestCase.test_mktime | PASS | |
| TimeTestCase.test_monotonic | PASS | |
| TimeTestCase.test_perf_counter | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TimeTestCase.test_clock_realtime | decorator:unittest.skipUnless |
| TimeTestCase.test_clock_monotonic | decorator:unittest.skipUnless |
| TimeTestCase.test_pthread_getcpuclockid | decorator:unittest.skipUnless |
| TimeTestCase.test_clock_getres | decorator:unittest.skipUnless |
| TimeTestCase.test_clock_settime | decorator:unittest.skipUnless |
| TimeTestCase.test_tzset | decorator:unittest.skipUnless |
| TimeTestCase.test_mktime_error | decorator:unittest.skipUnless |
| TimeTestCase.test_process_time | decorator:unittest.skipIf |
| TimeTestCase.test_monotonic_settime | decorator:unittest.skipUnless |
| TestLocale.test_bug_3061 | decorator:support.run_with_locale |
| _TestStrftimeYear.test_4dyear | decorator:unittest.skipUnless |
| TestPytime.test_localtime_timezone | decorator:unittest.skipUnless |
| TestPytime.test_strptime_timezone | decorator:unittest.skipUnless |
| TestPytime.test_short_times | decorator:unittest.skipUnless |
| TestCPyTime.test_AsTimespec | decorator:unittest.skipUnless |
| TestCPyTime.test_AsTimeval_clamp | decorator:unittest.skipUnless |
| TestCPyTime.test_AsTimespec_clamp | decorator:unittest.skipUnless |
| TestTimeWeaklinking.test_clock_functions | decorator:unittest.skipUnless |
| TimeTestCase.test_conversions | uses-self.t |
| TimeTestCase.test_sleep_exceptions | unresolved-name:errmsg |
| TimeTestCase.test_sleep | uses-self.subTest |
| TimeTestCase.test_strftime | uses-self.t |
| TimeTestCase.test_strftime_invalid_format | uses-self.t |
| TimeTestCase.test_strftime_special | uses-self.t |
| TimeTestCase.test_strftime_bounding_check | self._bounds_checking |
| TimeTestCase.test_strptime | uses-self.t |
| TimeTestCase.test_strptime_exception_context | unresolved-name:e |
| TimeTestCase.test_strptime_leap_year | uses-self.assertWarnsRegex |
| TimeTestCase.test_asctime | uses-self.t |
| TimeTestCase.test_asctime_bounding_check | self._bounds_checking |
| TimeTestCase.test_thread_time | self.skipTest |
| TimeTestCase.test_localtime_failure | self.skipTest |
| TimeTestCase.test_get_clock_info | uses-self.subTest |
| _TestAsctimeYear.test_large_year | uses-self.yearstr |
| _Test4dYear.test_year | uses-self._format |
| _Test4dYear.test_large_year | uses-self.yearstr |
| _Test4dYear.test_negative | uses-self.yearstr |
| TestCPyTime.test_FromSeconds | self.check_int_rounding |
| TestCPyTime.test_FromSecondsObject | self.check_int_rounding |
| TestCPyTime.test_AsSecondsDouble | self.check_int_rounding |
| TestCPyTime.test_AsTimeval | self.check_int_rounding |
| TestCPyTime.test_AsMilliseconds | self.check_int_rounding |
| TestCPyTime.test_AsMicroseconds | self.check_int_rounding |
| TestOldPyTime.test_object_to_time_t | self.check_int_rounding |
| TestOldPyTime.test_object_to_timeval | self.check_int_rounding |
| TestOldPyTime.test_object_to_timespec | self.check_int_rounding |
| _TestStrftimeYear.test_large_year | host-raised:RuntimeError: super(): no arguments |
| _TestStrftimeYear.test_negative | host-raised:RuntimeError: super(): no arguments |

## Expected vs got

### TimeTestCase.test_default_values_for_zero (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'warnings_helper' from '<unknown>'">
