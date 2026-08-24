# Triage report: `conv_shlex_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_shlex.py
- guest leg: 0/17 marks
- pins: **3 passed** / 17 run (+2 quarantined of 19 extracted)

| pin | result | got |
|---|---|---|
| ShlexTest.testSplitNone | PASS | |
| ShlexTest.testSplitPosix | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testCompat | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testSyntaxSplitAmpersandAndPipe | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testSyntaxSplitSemicolon | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testSyntaxSplitRedirect | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testSyntaxSplitParen | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testSyntaxSplitCustom | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testTokenTypes | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testPunctuationInWordChars | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testPunctuationWithWhitespaceSplit | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testPunctuationWithPosix | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testEmptyStringHandling | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testUnicodeHandling | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC IndexError 'pop from an empty deque'"> |
| ShlexTest.testQuote | PASS | |
| ShlexTest.testPunctuationCharsReadOnly | PASS | |
| ShlexTest.test_lazy_imports | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| ShlexTest.testJoin | uses-self.subTest |
| ShlexTest.testJoinRoundtrip | uses-self.subTest |

## Expected vs got

### ShlexTest.testCompat (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testEmptyStringHandling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testPunctuationInWordChars (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testPunctuationWithPosix (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testPunctuationWithWhitespaceSplit (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testSplitPosix (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testSyntaxSplitAmpersandAndPipe (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testSyntaxSplitCustom (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testSyntaxSplitParen (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testSyntaxSplitRedirect (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testSyntaxSplitSemicolon (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testTokenTypes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.testUnicodeHandling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC IndexError 'pop from an empty deque'">

### ShlexTest.test_lazy_imports (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">
