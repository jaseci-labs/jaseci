# Triage report: `conv_codeccallbacks_pins.jac`

- source: reference/cpython/Lib/test/test_codeccallbacks.py
- guest leg: 0/27 marks
- pins: **14 passed** / 27 run (+16 quarantined of 43 extracted)

| pin | result | got |
|---|---|---|
| CodecCallbackTest.test_xmlcharrefreplace | PASS | |
| CodecCallbackTest.test_xmlcharnamereplace | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.xmlcharnamereplace\'"'> |
| CodecCallbackTest.test_uninamereplace | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.uninamereplace\'"'> |
| CodecCallbackTest.test_backslashescape | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-15'"> |
| CodecCallbackTest.test_nameescape | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'namereplace\'"'> |
| CodecCallbackTest.test_decoding_callbacks | PASS | |
| CodecCallbackTest.test_charmapencode | PASS | |
| CodecCallbackTest.test_callbacks | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.handler1\'"'> |
| CodecCallbackTest.test_longstrings | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-15'"> |
| CodecCallbackTest.test_unicodeencodeerror | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError \'(\\\'assertEqual\\\', "\\\'ascii\\\' codec can\\\'t encode character \\\\\\\\u00fc in position 1: ouch", "\\\'ascii\\\' codec can\\\'t encode character \\\'\\\\\\\\xfc\\\' in position 1: ouch")\''> |
| CodecCallbackTest.test_unicodedecodeerror | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError \'(\\\'assertEqual\\\', "(ascii, bytearray(b\\\'g\\\\\\\\xfcrk\\\'), 1, 2, ouch)", "\\\'ascii\\\' codec can\\\'t decode byte 0xfc in position 1: ouch")\''> |
| CodecCallbackTest.test_unicodetranslateerror | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'"> |
| CodecCallbackTest.test_badandgoodstrictexceptions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'"> |
| CodecCallbackTest.test_badandgoodignoreexceptions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'"> |
| CodecCallbackTest.test_badandgoodxmlcharrefreplaceexceptions | PASS | |
| CodecCallbackTest.test_badhandlerresults | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.badhandler\'"'> |
| CodecCallbackTest.test_lookup | PASS | |
| CodecCallbackTest.test_badregistercall | PASS | |
| CodecCallbackTest.test_badlookupcall | PASS | |
| CodecCallbackTest.test_unknownhandler | PASS | |
| CodecCallbackTest.test_xmlcharrefvalues | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.xmlcharrefreplace\'"'> |
| CodecCallbackTest.test_translatehelper | PASS | |
| CodecCallbackTest.test_bug828737 | PASS | |
| CodecCallbackTest.test_mutating_decode_handler | PASS | |
| CodecCallbackTest.test_crashing_decode_handler | PASS | |
| CodecCallbackTest.test_unregister_custom_error_handler | PASS | |
| CodecCallbackTest.test_unregister_custom_unknown_error_handler | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| CodecCallbackTest.test_badandgoodreplaceexceptions | unresolved-name:BadObjectUnicodeDecodeError |
| CodecCallbackTest.test_badandgoodbackslashreplaceexceptions | uses-self.subTest |
| CodecCallbackTest.test_badandgoodnamereplaceexceptions | uses-self.subTest |
| CodecCallbackTest.test_badandgoodsurrogateescapeexceptions | uses-self.subTest |
| CodecCallbackTest.test_badandgoodsurrogatepassexceptions | uses-self.subTest |
| CodecCallbackTest.test_encode_nonascii_replacement | uses-self.subTest |
| CodecCallbackTest.test_encode_unencodable_replacement | uses-self.subTest |
| CodecCallbackTest.test_encode_bytes_replacement | uses-self.subTest |
| CodecCallbackTest.test_encode_odd_bytes_replacement | uses-self.subTest |
| CodecCallbackTest.test_decodehelper | unresolved-name:PosReturn |
| CodecCallbackTest.test_encodehelper | unresolved-name:PosReturn |
| CodecCallbackTest.test_decodehelper_bug36819 | uses-self.subTest |
| CodecCallbackTest.test_encodehelper_bug36819 | uses-self.subTest |
| CodecCallbackTest.test_mutating_decode_handler_unicode_escape | uses-self.assertWarns |
| CodecCallbackTest.test_fake_error_class | uses-self.subTest |
| CodecCallbackTest.test_reject_unregister_builtin_error_handler | uses-self.subTest |

## Expected vs got

### CodecCallbackTest.test_backslashescape (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-15'">

### CodecCallbackTest.test_badandgoodignoreexceptions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'">

### CodecCallbackTest.test_badandgoodstrictexceptions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'">

### CodecCallbackTest.test_badhandlerresults (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.badhandler\'"'>

### CodecCallbackTest.test_callbacks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.handler1\'"'>

### CodecCallbackTest.test_longstrings (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-15'">

### CodecCallbackTest.test_nameescape (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'namereplace\'"'>

### CodecCallbackTest.test_unicodedecodeerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError \'(\\\'assertEqual\\\', "(ascii, bytearray(b\\\'g\\\\\\\\xfcrk\\\'), 1, 2, ouch)", "\\\'ascii\\\' codec can\\\'t decode byte 0xfc in position 1: ouch")\''>

### CodecCallbackTest.test_unicodeencodeerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError \'(\\\'assertEqual\\\', "\\\'ascii\\\' codec can\\\'t encode character \\\\\\\\u00fc in position 1: ouch", "\\\'ascii\\\' codec can\\\'t encode character \\\'\\\\\\\\xfc\\\' in position 1: ouch")\''>

### CodecCallbackTest.test_unicodetranslateerror (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'">

### CodecCallbackTest.test_uninamereplace (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.uninamereplace\'"'>

### CodecCallbackTest.test_xmlcharnamereplace (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.xmlcharnamereplace\'"'>

### CodecCallbackTest.test_xmlcharrefvalues (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.xmlcharrefreplace\'"'>
