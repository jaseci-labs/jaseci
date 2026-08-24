# Triage report: `conv_opcodes_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_opcodes.py
- guest leg: 0/8 marks
- pins: **3 passed** / 8 run (+0 quarantined of 8 extracted)

| pin | result | got |
|---|---|---|
| OpcodeTest.test_try_inside_for_loop | PASS | |
| OpcodeTest.test_setup_annotations_line | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.typinganndata'"> |
| OpcodeTest.test_default_annotations_exist | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**annotations**'"> |
| OpcodeTest.test_use_existing_annotations | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'"> |
| OpcodeTest.test_do_not_recreate_annotations | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'swap_item'"> |
| OpcodeTest.test_raise_class_exceptions | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', BClass(), BClass())"'> |
| OpcodeTest.test_compare_function_objects | PASS | |
| OpcodeTest.test_modulo_of_string_subclasses | PASS | |

## Expected vs got

### OpcodeTest.test_default_annotations_exist (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**annotations**'">

### OpcodeTest.test_do_not_recreate_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'swap_item'">

### OpcodeTest.test_raise_class_exceptions (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', BClass(), BClass())"'>

### OpcodeTest.test_setup_annotations_line (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.typinganndata'">

### OpcodeTest.test_use_existing_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'">
