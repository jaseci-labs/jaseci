# Triage report: `conv_codecs_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_codecs.py
- guest leg: 0/90 marks
- pins: **57 passed** / 90 run (+117 quarantined of 207 extracted)

| pin | result | got |
|---|---|---|
| UTF32Test.test_handlers | PASS | |
| UTF32Test.test_errors | PASS | |
| UTF32Test.test_issue8941 | PASS | |
| UTF32LETest.test_errors | PASS | |
| UTF32LETest.test_issue8941 | PASS | |
| UTF32BETest.test_errors | PASS | |
| UTF32BETest.test_issue8941 | PASS | |
| UTF16Test.test_handlers | PASS | |
| UTF16Test.test_errors | PASS | |
| UTF16LETest.test_errors | PASS | |
| UTF16BETest.test_errors | PASS | |
| UTF16ExTest.test_errors | PASS | |
| UTF16ExTest.test_bad_args | PASS | |
| ReadBufferTest.test_array | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'spam\', 4), (b\'spam\', 4))"'> |
| ReadBufferTest.test_empty | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| ReadBufferTest.test_bad_args | PASS | |
| UTF8SigTest.test_bug1601501 | PASS | |
| UTF8SigTest.test_bom | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-8-sig'"> |
| UTF8SigTest.test_stream_bom | PASS | |
| UTF8SigTest.test_stream_bare | PASS | |
| EscapeDecodeTest.test_empty | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| EscapeDecodeTest.test_raw | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\\\\x000\', 2), (b\'\\\\x000\', 2))"'> |
| EscapeDecodeTest.test_errors | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'[]\', 6), (b\'[]\', 6))"'> |
| PunycodeTest.test_encode | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: punycode'"> |
| PunycodeTest.test_decode | PASS | |
| NameprepTest.test_nameprep | PASS | |
| IDNACodecTest.test_builtin_decode | PASS | |
| IDNACodecTest.test_builtin_encode | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: idna'"> |
| IDNACodecTest.test_builtin_decode_length_limit | PASS | |
| IDNACodecTest.test_stream | PASS | |
| IDNACodecTest.test_incremental_decode | PASS | |
| IDNACodecTest.test_incremental_encode | PASS | |
| IDNACodecTest.test_errors | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: idna'"> |
| CodecsModuleTest.test_decode | PASS | |
| CodecsModuleTest.test_encode | PASS | |
| CodecsModuleTest.test_register | PASS | |
| CodecsModuleTest.test_unregister | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| CodecsModuleTest.test_lookup | PASS | |
| CodecsModuleTest.test_getencoder | PASS | |
| CodecsModuleTest.test_getdecoder | PASS | |
| CodecsModuleTest.test_getreader | PASS | |
| CodecsModuleTest.test_getwriter | PASS | |
| CodecsModuleTest.test_all | PASS | |
| CodecsModuleTest.test_undefined | PASS | |
| CodecsModuleTest.test_file_closes_if_lookup_error_raised | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| CodecsModuleTest.test_copy | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, \'utf-8\')"'> |
| CodecsModuleTest.test_deepcopy | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, \'utf-8\')"'> |
| EncodedFileTest.test_basic | PASS | |
| BasicUnicodeTest.test_seek | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: big5'"> |
| BasicUnicodeTest.test_bad_decode_args | PASS | |
| BasicUnicodeTest.test_bad_encode_args | PASS | |
| BasicUnicodeTest.test_encoding_map_type_initialized | PASS | |
| BasicUnicodeTest.test_decoder_state | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| CharmapTest.test_decode_with_string_map | PASS | |
| CharmapTest.test_decode_with_int2int_map | PASS | |
| WithStmtTest.test_encodedfile | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'StreamRecoder.**enter**() takes 1 positional argument but 2 were given'"> |
| WithStmtTest.test_streamreaderwriter | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'StreamReaderWriter.**enter**() takes 1 positional argument but 2 were given'"> |
| TypesTest.test_decode_unicode | PASS | |
| TypesTest.test_unicode_escape | PASS | |
| UnicodeEscapeTest.test_empty | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| UnicodeEscapeTest.test_raw_encode | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\' \', 1), (b\' \', 1))"'> |
| UnicodeEscapeTest.test_raw_decode | PASS | |
| UnicodeEscapeTest.test_decode_errors | PASS | |
| RawUnicodeEscapeTest.test_empty | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| RawUnicodeEscapeTest.test_raw_encode | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\\\\x00\', 1), (b\'\\\\x00\', 1))"'> |
| RawUnicodeEscapeTest.test_raw_decode | PASS | |
| RawUnicodeEscapeTest.test_decode_errors | PASS | |
| SurrogateEscapeTest.test_utf8 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| SurrogateEscapeTest.test_ascii | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| SurrogateEscapeTest.test_charmap | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-3'"> |
| SurrogateEscapeTest.test_latin1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| TransformCodecTest.test_text_to_binary_denylists_text_transforms | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| TransformCodecTest.test_quopri_stateless | PASS | |
| TransformCodecTest.test_uu_invalid | PASS | |
| ASCIITest.test_encode | PASS | |
| ASCIITest.test_encode_surrogateescape_error | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| ASCIITest.test_decode | PASS | |
| Latin1Test.test_encode_surrogateescape_error | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| StreamRecoderTest.test_writelines | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'ascii'"> |
| StreamRecoderTest.test_write | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'utf_8'"> |
| StreamRecoderTest.test_seeking_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| StreamRecoderTest.test_seeking_write | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| StreamRecoderTest.test_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'ascii'"> |
| Rot13Test.test_encode | PASS | |
| Rot13Test.test_decode | PASS | |
| Rot13Test.test_incremental_encode | PASS | |
| Rot13Test.test_incremental_decode | PASS | |
| Rot13UtilTest.test_rot13_func | PASS | |
| CodecNameNormalizationTest.test_encodings_normalize_encoding | PASS | |
| CodecCacheTest.test_cache_bounded | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| CodecsModuleTest.test_lookup_issue1813 | decorator:support.run_with_locale |
| BasicUnicodeTest.test_basics_capi | decorator:support.cpython_only |
| TransformCodecTest.test_custom_zlib_error_is_noted | decorator:unittest.skipUnless |
| CodePageTest.test_invalid_code_page | decorator:unittest.skipUnless |
| CodePageTest.test_code_page_name | decorator:unittest.skipUnless |
| CodePageTest.test_cp932 | decorator:unittest.skipUnless |
| CodePageTest.test_cp1252 | decorator:unittest.skipUnless |
| CodePageTest.test_cp708 | decorator:unittest.skipUnless |
| CodePageTest.test_cp20106 | decorator:unittest.skipUnless |
| CodePageTest.test_cp_utf7 | decorator:unittest.skipUnless |
| CodePageTest.test_multibyte_encoding | decorator:unittest.skipUnless |
| CodePageTest.test_code_page_decode_flags | decorator:unittest.skipUnless |
| CodePageTest.test_incremental | decorator:unittest.skipUnless |
| CodePageTest.test_mbcs_code_page | decorator:unittest.skipUnless |
| CodePageTest.test_large_input | decorator:unittest.skipUnless |
| CodePageTest.test_large_utf8_input | decorator:unittest.skipUnless |
| LocaleCodecTest.test_encode_strict | decorator:unittest.skipIf |
| LocaleCodecTest.test_encode_surrogateescape | decorator:unittest.skipIf |
| LocaleCodecTest.test_encode_surrogatepass | decorator:unittest.skipIf |
| LocaleCodecTest.test_encode_unsupported_error_handler | decorator:unittest.skipIf |
| LocaleCodecTest.test_decode_strict | decorator:unittest.skipIf |
| LocaleCodecTest.test_decode_surrogateescape | decorator:unittest.skipIf |
| LocaleCodecTest.test_decode_surrogatepass | decorator:unittest.skipIf |
| LocaleCodecTest.test_decode_unsupported_error_handler | decorator:unittest.skipIf |
| ReadTest.test_readlinequeue | unresolved-name:Queue |
| UTF16Test.test_bug691291 | self.addCleanup |
| UTF16Test.test_invalid_modes | unresolved-name:cm |
| UTF8Test.test_decode_error | uses-self.subTest |
| UTF8Test.test_lone_surrogates | unresolved-name:cm |
| UTF8Test.test_incremental_errors | uses-self.subTest |
| UTF7Test.test_errors | uses-self.subTest |
| UTF7Test.test_lone_surrogates | uses-self.subTest |
| EscapeDecodeTest.test_warnings | uses-self.assertWarns |
| PunycodeTest.test_decode_invalid | uses-self.subTest |
| IDNACodecTest.test_builtin_decode_invalid | uses-self.subTest |
| IDNACodecTest.test_builtin_encode_invalid | uses-self.subTest |
| IDNACodecTest.test_incremental_decode_invalid | uses-self.subTest |
| IDNACodecTest.test_incremental_encode_invalid | uses-self.subTest |
| CodecsModuleTest.test_open | self.addCleanup |
| CodecsModuleTest.test_pickle | uses-self.subTest |
| StreamReaderTest.test_readlines | uses-self.reader |
| StreamReaderTest.test_copy | uses-self.reader |
| StreamReaderTest.test_pickle | uses-self.reader |
| StreamWriterTest.test_copy | uses-self.writer |
| StreamWriterTest.test_pickle | uses-self.subTest |
| StreamReaderWriterTest.test_copy | unresolved-name:Queue |
| StreamReaderWriterTest.test_pickle | uses-self.subTest |
| BasicUnicodeTest.test_basics | unresolved-name:Queue |
| CharmapTest.test_decode_with_int2str_map | assertRaisesRegex call form |
| UnicodeEscapeTest.test_decode_warnings | uses-self.assertWarns |
| EscapeEncodeTest.test_escape_encode | uses-self.subTest |
| BomTest.test_seek0 | self.addCleanup |
| TransformCodecTest.test_basics | uses-self.subTest |
| TransformCodecTest.test_read | uses-self.subTest |
| TransformCodecTest.test_readline | uses-self.subTest |
| TransformCodecTest.test_buffer_api_usage | uses-self.subTest |
| TransformCodecTest.test_text_to_binary_denylists_binary_transforms | uses-self.subTest |
| TransformCodecTest.test_binary_to_text_denylists_binary_transforms | uses-self.subTest |
| TransformCodecTest.test_binary_to_text_denylists_text_transforms | uses-self.subTest |
| TransformCodecTest.test_custom_hex_error_is_noted | unresolved-name:failure |
| TransformCodecTest.test_aliases | uses-self.subTest |
| ExceptionNotesTest.test_raise_by_type | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_raise_by_value | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_raise_grandchild_subclass_exact_size | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_raise_subclass_with_weakref_support | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_init_override | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_new_override | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_instance_attribute | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_non_str_arg | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_multiple_args | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_codec_lookup_failure | helper:setUp(self.addCleanup) |
| ExceptionNotesTest.test_unflagged_non_text_codec_handling | helper:setUp(self.addCleanup) |
| ASCIITest.test_encode_error | uses-self.subTest |
| ASCIITest.test_decode_error | uses-self.subTest |
| Latin1Test.test_encode | uses-self.subTest |
| Latin1Test.test_encode_errors | uses-self.subTest |
| Latin1Test.test_decode | uses-self.subTest |
| StreamRecoderTest.test_pickle | uses-self.subTest |
| CodecNameNormalizationTest.test_codecs_lookup | self.addCleanup |
| ReadTest.test_readline | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| ReadTest.test_mixed_readline_and_read | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| ReadTest.test_bug1175396 | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| ReadTest.test_bug1098990_a | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| ReadTest.test_bug1098990_b | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| ReadTest.test_lone_surrogates | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| ReadTest.test_incremental_surrogatepass | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF32Test.test_only_one_bom | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF32Test.test_badbom | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF32Test.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF32Test.test_decoder_state | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF32LETest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF32LETest.test_simple | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF32BETest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF32BETest.test_simple | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF16Test.test_only_one_bom | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF16Test.test_badbom | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF16Test.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF16Test.test_decoder_state | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF16LETest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF16LETest.test_nonbmp | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF16BETest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF16BETest.test_nonbmp | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF8Test.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF8Test.test_decoder_state | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF8Test.test_surrogatepass_handler | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF7Test.test_ascii | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF7Test.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF7Test.test_nonbmp | host-raised:AttributeError: '_SelfNS' object has no attribute 'encoding' |
| UTF8SigTest.test_partial | host-raised:NameError: name 'self' is not defined |
| EscapeDecodeTest.test_escape | host-raised:NameError: name 'self' is not defined |
| UnicodeEscapeTest.test_escape_encode | host-raised:NameError: name 'self' is not defined |
| UnicodeEscapeTest.test_escape_decode | host-raised:NameError: name 'self' is not defined |
| UnicodeEscapeTest.test_partial | host-raised:NameError: name 'self' is not defined |
| RawUnicodeEscapeTest.test_escape_encode | host-raised:NameError: name 'self' is not defined |
| RawUnicodeEscapeTest.test_escape_decode | host-raised:NameError: name 'self' is not defined |
| RawUnicodeEscapeTest.test_partial | host-raised:NameError: name 'self' is not defined |
| TransformCodecTest.test_alias_modules_exist | host-raised:AttributeError: module 'importlib' has no attribute 'util' |

## Expected vs got

### ASCIITest.test_encode_surrogateescape_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### BasicUnicodeTest.test_decoder_state (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### BasicUnicodeTest.test_seek (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: big5'">

### CodecsModuleTest.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, \'utf-8\')"'>

### CodecsModuleTest.test_deepcopy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, \'utf-8\')"'>

### CodecsModuleTest.test_file_closes_if_lookup_error_raised (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### CodecsModuleTest.test_unregister (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### EscapeDecodeTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### EscapeDecodeTest.test_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'[]\', 6), (b\'[]\', 6))"'>

### EscapeDecodeTest.test_raw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\\\\x000\', 2), (b\'\\\\x000\', 2))"'>

### IDNACodecTest.test_builtin_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: idna'">

### IDNACodecTest.test_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: idna'">

### Latin1Test.test_encode_surrogateescape_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### PunycodeTest.test_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: punycode'">

### RawUnicodeEscapeTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### RawUnicodeEscapeTest.test_raw_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\\\\x00\', 1), (b\'\\\\x00\', 1))"'>

### ReadBufferTest.test_array (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'spam\', 4), (b\'spam\', 4))"'>

### ReadBufferTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### StreamRecoderTest.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'ascii'">

### StreamRecoderTest.test_seeking_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### StreamRecoderTest.test_seeking_write (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### StreamRecoderTest.test_write (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'utf_8'">

### StreamRecoderTest.test_writelines (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'ascii'">

### SurrogateEscapeTest.test_ascii (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### SurrogateEscapeTest.test_charmap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-3'">

### SurrogateEscapeTest.test_latin1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### SurrogateEscapeTest.test_utf8 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### TransformCodecTest.test_text_to_binary_denylists_text_transforms (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### UTF8SigTest.test_bom (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-8-sig'">

### UnicodeEscapeTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### UnicodeEscapeTest.test_raw_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\' \', 1), (b\' \', 1))"'>

### WithStmtTest.test_encodedfile (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'StreamRecoder.**enter**() takes 1 positional argument but 2 were given'">

### WithStmtTest.test_streamreaderwriter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'StreamReaderWriter.**enter**() takes 1 positional argument but 2 were given'">
