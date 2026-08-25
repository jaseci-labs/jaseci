# Triage report: `conv_codecs_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_codecs.py
- guest leg: 0/200 marks
- pins: **83 passed** / 200 run (+79 quarantined of 279 extracted)

| pin | result | got |
|---|---|---|
| UTF32Test.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'"> |
| UTF32LETest.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'"> |
| UTF32BETest.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'"> |
| UTF16Test.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'"> |
| UTF16LETest.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| UTF16BETest.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'"> |
| UTF8SigTest.test_readline | PASS | |
| UTF7Test.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'"> |
| UnicodeEscapeTest.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'"> |
| RawUnicodeEscapeTest.test_readline | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'"> |
| UTF32Test.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'"> |
| UTF32LETest.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'"> |
| UTF32BETest.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'"> |
| UTF16Test.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'"> |
| UTF16LETest.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| UTF16BETest.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'"> |
| UTF8SigTest.test_mixed_readline_and_read | PASS | |
| UTF7Test.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'"> |
| UnicodeEscapeTest.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'"> |
| RawUnicodeEscapeTest.test_mixed_readline_and_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'"> |
| UTF32Test.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'"> |
| UTF32LETest.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'"> |
| UTF32BETest.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'"> |
| UTF16Test.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'"> |
| UTF16LETest.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| UTF16BETest.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'"> |
| UTF8SigTest.test_bug1175396 | PASS | |
| UTF7Test.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'"> |
| UnicodeEscapeTest.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'"> |
| RawUnicodeEscapeTest.test_bug1175396 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'"> |
| UTF32Test.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UTF32LETest.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UTF32BETest.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UTF16Test.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UTF16LETest.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UTF16BETest.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UTF8SigTest.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UTF7Test.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UnicodeEscapeTest.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| RawUnicodeEscapeTest.test_readlinequeue | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| UTF32Test.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'"> |
| UTF32LETest.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'"> |
| UTF32BETest.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'"> |
| UTF16Test.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'"> |
| UTF16LETest.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| UTF16BETest.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'"> |
| UTF8SigTest.test_bug1098990_a | PASS | |
| UTF7Test.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'"> |
| UnicodeEscapeTest.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'"> |
| RawUnicodeEscapeTest.test_bug1098990_a | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'"> |
| UTF32Test.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'"> |
| UTF32LETest.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'"> |
| UTF32BETest.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'"> |
| UTF16Test.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'"> |
| UTF16LETest.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| UTF16BETest.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'"> |
| UTF8SigTest.test_bug1098990_b | PASS | |
| UTF7Test.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'"> |
| UnicodeEscapeTest.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'"> |
| RawUnicodeEscapeTest.test_bug1098990_b | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'"> |
| UTF32LETest.test_lone_surrogates | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'"> |
| UTF32BETest.test_lone_surrogates | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'"> |
| UTF16LETest.test_lone_surrogates | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| UTF16BETest.test_lone_surrogates | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'"> |
| UTF32Test.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'"> |
| UTF32LETest.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'"> |
| UTF32BETest.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'"> |
| UTF16Test.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'"> |
| UTF16LETest.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| UTF16BETest.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'"> |
| UTF8SigTest.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogatepass\'"'> |
| UTF7Test.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'"> |
| UnicodeEscapeTest.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'"> |
| RawUnicodeEscapeTest.test_incremental_surrogatepass | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'"> |
| UTF32Test.test_only_one_bom | PASS | |
| UTF32Test.test_badbom | PASS | |
| UTF32Test.test_handlers | PASS | |
| UTF32Test.test_errors | PASS | |
| UTF32Test.test_decoder_state | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| UTF32Test.test_issue8941 | PASS | |
| UTF32LETest.test_simple | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'"> |
| UTF32LETest.test_errors | PASS | |
| UTF32LETest.test_issue8941 | PASS | |
| UTF32BETest.test_simple | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'"> |
| UTF32BETest.test_errors | PASS | |
| UTF32BETest.test_issue8941 | PASS | |
| UTF16Test.test_only_one_bom | PASS | |
| UTF16Test.test_badbom | PASS | |
| UTF16Test.test_handlers | PASS | |
| UTF16Test.test_errors | PASS | |
| UTF16Test.test_decoder_state | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| UTF16LETest.test_errors | PASS | |
| UTF16LETest.test_nonbmp | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| UTF16BETest.test_errors | PASS | |
| UTF16BETest.test_nonbmp | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'"> |
| UTF8SigTest.test_decoder_state | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| UTF8SigTest.test_decode_error | PASS | |
| UTF8SigTest.test_surrogatepass_handler | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogatepass\'"'> |
| UTF8SigTest.test_incremental_errors | PASS | |
| UTF7Test.test_ascii | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'"> |
| UTF7Test.test_errors | PASS | |
| UTF7Test.test_nonbmp | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'"> |
| UTF7Test.test_lone_surrogates | PASS | |
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
| CodecsModuleTest.test_unregister | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| CodecsModuleTest.test_lookup | PASS | |
| CodecsModuleTest.test_getencoder | PASS | |
| CodecsModuleTest.test_getdecoder | PASS | |
| CodecsModuleTest.test_getreader | PASS | |
| CodecsModuleTest.test_getwriter | PASS | |
| CodecsModuleTest.test_all | PASS | |
| CodecsModuleTest.test_undefined | PASS | |
| CodecsModuleTest.test_file_closes_if_lookup_error_raised | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| CodecsModuleTest.test_copy | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, \'utf-8\')"'> |
| CodecsModuleTest.test_deepcopy | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, \'utf-8\')"'> |
| CodecsModuleTest.test_pickle | PASS | |
| StreamReaderWriterTest.test_copy | PASS | |
| StreamReaderWriterTest.test_pickle | PASS | |
| EncodedFileTest.test_basic | PASS | |
| BasicUnicodeTest.test_basics | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'> |
| BasicUnicodeTest.test_seek | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: big5'"> |
| BasicUnicodeTest.test_bad_decode_args | PASS | |
| BasicUnicodeTest.test_bad_encode_args | PASS | |
| BasicUnicodeTest.test_encoding_map_type_initialized | PASS | |
| BasicUnicodeTest.test_decoder_state | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| CharmapTest.test_decode_with_string_map | PASS | |
| CharmapTest.test_decode_with_int2str_map | PASS | |
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
| EscapeEncodeTest.test_escape_encode | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'> |
| SurrogateEscapeTest.test_utf8 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| SurrogateEscapeTest.test_ascii | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| SurrogateEscapeTest.test_charmap | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-3'"> |
| SurrogateEscapeTest.test_latin1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| TransformCodecTest.test_basics | PASS | |
| TransformCodecTest.test_read | PASS | |
| TransformCodecTest.test_readline | PASS | |
| TransformCodecTest.test_buffer_api_usage | PASS | |
| TransformCodecTest.test_text_to_binary_denylists_text_transforms | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| TransformCodecTest.test_binary_to_text_denylists_binary_transforms | PASS | |
| TransformCodecTest.test_aliases | PASS | |
| TransformCodecTest.test_quopri_stateless | PASS | |
| TransformCodecTest.test_uu_invalid | PASS | |
| ASCIITest.test_encode | PASS | |
| ASCIITest.test_encode_error | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| ASCIITest.test_encode_surrogateescape_error | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| ASCIITest.test_decode | PASS | |
| ASCIITest.test_decode_error | PASS | |
| Latin1Test.test_encode | PASS | |
| Latin1Test.test_encode_errors | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| Latin1Test.test_encode_surrogateescape_error | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'> |
| Latin1Test.test_decode | PASS | |
| StreamRecoderTest.test_writelines | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'ascii'"> |
| StreamRecoderTest.test_write | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'utf_8'"> |
| StreamRecoderTest.test_seeking_read | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| StreamRecoderTest.test_seeking_write | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'"> |
| StreamRecoderTest.test_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'ascii'"> |
| StreamRecoderTest.test_pickle | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'ascii'"> |
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
| UTF16Test.test_bug691291 | self.addCleanup |
| UTF16Test.test_invalid_modes | unresolved-name:cm |
| UTF8SigTest.test_lone_surrogates | unresolved-name:cm |
| EscapeDecodeTest.test_warnings | uses-self.assertWarns |
| PunycodeTest.test_decode_invalid | unresolved-name:cm |
| IDNACodecTest.test_builtin_decode_invalid | unresolved-name:cm |
| IDNACodecTest.test_builtin_encode_invalid | unresolved-name:cm |
| IDNACodecTest.test_incremental_decode_invalid | unresolved-name:cm |
| IDNACodecTest.test_incremental_encode_invalid | unresolved-name:cm |
| CodecsModuleTest.test_open | self.addCleanup |
| StreamReaderTest.test_readlines | uses-self.reader |
| StreamReaderTest.test_copy | uses-self.reader |
| StreamReaderTest.test_pickle | uses-self.reader |
| StreamWriterTest.test_copy | uses-self.writer |
| StreamWriterTest.test_pickle | uses-self.writer |
| UnicodeEscapeTest.test_decode_warnings | uses-self.assertWarns |
| BomTest.test_seek0 | self.addCleanup |
| TransformCodecTest.test_text_to_binary_denylists_binary_transforms | unresolved-name:failure |
| TransformCodecTest.test_binary_to_text_denylists_text_transforms | unresolved-name:failure |
| TransformCodecTest.test_custom_hex_error_is_noted | unresolved-name:failure |
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
| CodecNameNormalizationTest.test_codecs_lookup | self.addCleanup |
| UTF32Test.test_lone_surrogates | host-raised:AttributeError: '_SelfNS' object has no attribute 'ill_formed_sequence' |
| UTF16Test.test_lone_surrogates | host-raised:AttributeError: '_SelfNS' object has no attribute 'ill_formed_sequence' |
| UTF8SigTest.test_lone_surrogates | host-raised:AssertionError: ('assertEqual', '\U00010fffA', '\U00010fffA') |
| UTF7Test.test_lone_surrogates | host-raised:AssertionError: ('assertEqual', b'[+3IA]', b'[+AFw-udc80]') |
| UnicodeEscapeTest.test_lone_surrogates | host-raised:AssertionError: ('assertEqual', b'[\\udc80]', b'[\\\\udc80]') |
| RawUnicodeEscapeTest.test_lone_surrogates | host-raised:AssertionError: ('assertEqual', b'[\\udc80]', b'[&#56448;]') |
| UTF32Test.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF32LETest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF32BETest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF16Test.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF16LETest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF16BETest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF8SigTest.test_partial | host-raised:NameError: name 'self' is not defined |
| UTF7Test.test_partial | host-raised:NameError: name 'self' is not defined |
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

### ASCIITest.test_encode_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### ASCIITest.test_encode_surrogateescape_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### BasicUnicodeTest.test_basics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

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
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### CodecsModuleTest.test_unregister (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### EscapeDecodeTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### EscapeDecodeTest.test_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'[]\', 6), (b\'[]\', 6))"'>

### EscapeDecodeTest.test_raw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\\\\x000\', 2), (b\'\\\\x000\', 2))"'>

### EscapeEncodeTest.test_escape_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### IDNACodecTest.test_builtin_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: idna'">

### IDNACodecTest.test_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: idna'">

### Latin1Test.test_encode_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### Latin1Test.test_encode_surrogateescape_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogateescape\'"'>

### PunycodeTest.test_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: punycode'">

### RawUnicodeEscapeTest.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'">

### RawUnicodeEscapeTest.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'">

### RawUnicodeEscapeTest.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'">

### RawUnicodeEscapeTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### RawUnicodeEscapeTest.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'">

### RawUnicodeEscapeTest.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'">

### RawUnicodeEscapeTest.test_raw_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\\\\x00\', 1), (b\'\\\\x00\', 1))"'>

### RawUnicodeEscapeTest.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: raw-unicode-escape'">

### RawUnicodeEscapeTest.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### ReadBufferTest.test_array (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'spam\', 4), (b\'spam\', 4))"'>

### ReadBufferTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### StreamRecoderTest.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'ascii'">

### StreamRecoderTest.test_pickle (GUEST-WRONG-OUTPUT)

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

### UTF16BETest.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'">

### UTF16BETest.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'">

### UTF16BETest.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'">

### UTF16BETest.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'">

### UTF16BETest.test_lone_surrogates (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'">

### UTF16BETest.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'">

### UTF16BETest.test_nonbmp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'">

### UTF16BETest.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-be'">

### UTF16BETest.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### UTF16LETest.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### UTF16LETest.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### UTF16LETest.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### UTF16LETest.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### UTF16LETest.test_lone_surrogates (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### UTF16LETest.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### UTF16LETest.test_nonbmp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### UTF16LETest.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16-le'">

### UTF16LETest.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### UTF16Test.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'">

### UTF16Test.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'">

### UTF16Test.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'">

### UTF16Test.test_decoder_state (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### UTF16Test.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'">

### UTF16Test.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'">

### UTF16Test.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'">

### UTF16Test.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### UTF32BETest.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'">

### UTF32BETest.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'">

### UTF32BETest.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'">

### UTF32BETest.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'">

### UTF32BETest.test_lone_surrogates (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'">

### UTF32BETest.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'">

### UTF32BETest.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'">

### UTF32BETest.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### UTF32BETest.test_simple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-be'">

### UTF32LETest.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'">

### UTF32LETest.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'">

### UTF32LETest.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'">

### UTF32LETest.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'">

### UTF32LETest.test_lone_surrogates (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'">

### UTF32LETest.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'">

### UTF32LETest.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'">

### UTF32LETest.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### UTF32LETest.test_simple (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32-le'">

### UTF32Test.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'">

### UTF32Test.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'">

### UTF32Test.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'">

### UTF32Test.test_decoder_state (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### UTF32Test.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'">

### UTF32Test.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'">

### UTF32Test.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-32'">

### UTF32Test.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### UTF7Test.test_ascii (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'">

### UTF7Test.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'">

### UTF7Test.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'">

### UTF7Test.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'">

### UTF7Test.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'">

### UTF7Test.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'">

### UTF7Test.test_nonbmp (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'">

### UTF7Test.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-7'">

### UTF7Test.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### UTF8SigTest.test_bom (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-8-sig'">

### UTF8SigTest.test_decoder_state (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### UTF8SigTest.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogatepass\'"'>

### UTF8SigTest.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### UTF8SigTest.test_surrogatepass_handler (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'surrogatepass\'"'>

### UnicodeEscapeTest.test_bug1098990_a (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'">

### UnicodeEscapeTest.test_bug1098990_b (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'">

### UnicodeEscapeTest.test_bug1175396 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'">

### UnicodeEscapeTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\', 0), (b\'\', 0))"'>

### UnicodeEscapeTest.test_incremental_surrogatepass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'">

### UnicodeEscapeTest.test_mixed_readline_and_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'">

### UnicodeEscapeTest.test_raw_encode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\' \', 1), (b\' \', 1))"'>

### UnicodeEscapeTest.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: unicode-escape'">

### UnicodeEscapeTest.test_readlinequeue (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AttributeError "\'Queue\' object has no attribute \'write\'"'>

### WithStmtTest.test_encodedfile (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'StreamRecoder.**enter**() takes 1 positional argument but 2 were given'">

### WithStmtTest.test_streamreaderwriter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'StreamReaderWriter.**enter**() takes 1 positional argument but 2 were given'">
