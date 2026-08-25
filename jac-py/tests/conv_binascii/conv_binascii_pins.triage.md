# Triage report: `conv_binascii_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_binascii.py
- guest leg: 0/15 marks
- pins: **15 passed** / 15 run (+55 quarantined of 70 extracted)

| pin | result | got |
|---|---|---|
| ArrayBinASCIITest.test_exceptions | PASS | |
| ArrayBinASCIITest.test_functions | PASS | |
| ArrayBinASCIITest.test_returned_value | PASS | |
| ArrayBinASCIITest.test_base64valid | PASS | |
| ArrayBinASCIITest.test_base64invalid | PASS | |
| ArrayBinASCIITest.test_uu | PASS | |
| ArrayBinASCIITest.test_crc_hqx | PASS | |
| ArrayBinASCIITest.test_crc32 | PASS | |
| ArrayBinASCIITest.test_hex | PASS | |
| ArrayBinASCIITest.test_hex_separator | PASS | |
| ArrayBinASCIITest.test_empty_string | PASS | |
| ArrayBinASCIITest.test_unicode_b2a | PASS | |
| ArrayBinASCIITest.test_unicode_a2b | PASS | |
| ArrayBinASCIITest.test_b2a_base64_newline | PASS | |
| ArrayBinASCIITest.test_c_contiguity | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| BytearrayBinASCIITest.test_exceptions | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_exceptions | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_functions | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_functions | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_returned_value | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_returned_value | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_base64valid | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_base64valid | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_base64invalid | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_base64invalid | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_base64_strict_mode | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_base64_strict_mode | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_base64_excess_data | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_base64_excess_data | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_base64errors | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_base64errors | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_uu | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_uu | helper:setUp(uses-self.type2test) |
| ArrayBinASCIITest.test_b2a_roundtrip | unresolved-name:backtick |
| BytearrayBinASCIITest.test_b2a_roundtrip | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_b2a_roundtrip | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_crc_hqx | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_crc_hqx | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_crc32 | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_crc32 | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_hex | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_hex | helper:setUp(uses-self.type2test) |
| ArrayBinASCIITest.test_hex_roundtrip | unresolved-name:binary |
| BytearrayBinASCIITest.test_hex_roundtrip | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_hex_roundtrip | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_hex_separator | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_hex_separator | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_qp | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_qp | helper:setUp(uses-self.type2test) |
| ArrayBinASCIITest.test_b2a_qp_a2b_qp_round_trip | unresolved-name:binary |
| BytearrayBinASCIITest.test_b2a_qp_a2b_qp_round_trip | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_b2a_qp_a2b_qp_round_trip | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_empty_string | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_empty_string | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_unicode_b2a | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_unicode_b2a | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_unicode_a2b | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_unicode_a2b | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_b2a_base64_newline | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_b2a_base64_newline | helper:setUp(uses-self.type2test) |
| ArrayBinASCIITest.test_base64_roundtrip | unresolved-name:binary |
| BytearrayBinASCIITest.test_base64_roundtrip | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_base64_roundtrip | helper:setUp(uses-self.type2test) |
| BytearrayBinASCIITest.test_c_contiguity | helper:setUp(uses-self.type2test) |
| MemoryviewBinASCIITest.test_c_contiguity | helper:setUp(uses-self.type2test) |
| ArrayBinASCIITest.test_base64_strict_mode | harness-error:AssertionError: SRE module mismatch |
| ArrayBinASCIITest.test_base64_excess_data | harness-error:AssertionError: SRE module mismatch |
| ArrayBinASCIITest.test_base64errors | harness-error:AssertionError: SRE module mismatch |
| ArrayBinASCIITest.test_qp | host-raised:UnboundLocalError: cannot access local variable 'type2test' where it is not associated with a value |
| ChecksumBigBufferTestCase.test_big_buffer | harness-error:SyntaxError: invalid syntax |
