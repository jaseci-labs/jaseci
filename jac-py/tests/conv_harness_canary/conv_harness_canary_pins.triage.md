# Triage report: `conv_harness_canary_pins.jac`

- source: (none - hand-written harness canary)
- guest leg: 0/5 marks
- pins: **1 passed** / 5 run (+0 quarantined of 5 extracted)

| pin | result | got |
|---|---|---|
| HarnessCanary.test_pprint_import | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HarnessCanary.test_ordereddict_repr_surface | GUEST-WRONG-OUTPUT | RUN<'AttributeError: **repr**'> |
| HarnessCanary.test_guest_class_dunder_fallback | PASS | |
| HarnessCanary.test_functools_cache_present | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |
| HarnessCanary.test_typing_import | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |

## Expected vs got

### HarnessCanary.test_functools_cache_present (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>

### HarnessCanary.test_ordereddict_repr_surface (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HarnessCanary.test_pprint_import (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: **repr**'>

### HarnessCanary.test_typing_import (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>
