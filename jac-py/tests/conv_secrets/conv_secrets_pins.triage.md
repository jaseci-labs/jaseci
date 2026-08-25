# Triage report: `conv_secrets_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_secrets.py
- guest leg: 0/11 marks
- pins: **0 passed** / 11 run (+0 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| Compare_Digest_Tests.test_equal | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Compare_Digest_Tests.test_unequal | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Compare_Digest_Tests.test_bad_types | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Compare_Digest_Tests.test_bool | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Random_Tests.test_randbits | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Random_Tests.test_choice | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Random_Tests.test_randbelow | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Token_Tests.test_token_defaults | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Token_Tests.test_token_bytes | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Token_Tests.test_token_hex | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| Token_Tests.test_token_urlsafe | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |

## Expected vs got

### Compare_Digest_Tests.test_bad_types (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Compare_Digest_Tests.test_bool (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Compare_Digest_Tests.test_equal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Compare_Digest_Tests.test_unequal (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Random_Tests.test_choice (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Random_Tests.test_randbelow (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Random_Tests.test_randbits (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Token_Tests.test_token_bytes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Token_Tests.test_token_defaults (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Token_Tests.test_token_hex (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### Token_Tests.test_token_urlsafe (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">
