# Triage report: `conv_opcodes_pins.jac`

- source: reference/cpython/Lib/test/test_opcodes.py
- guest leg: 0/6 marks
- pins: **2 passed** / 6 run (+2 quarantined of 8 extracted)

| pin | result | got |
|---|---|---|
| OpcodeTest.test_try_inside_for_loop | PASS | |
| OpcodeTest.test_default_annotations_exist | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**annotations**'"> |
| OpcodeTest.test_use_existing_annotations | PASS | |
| OpcodeTest.test_raise_class_exceptions | VM-CRASH | 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac ✖ Error: name 'registered_exc_base' is not defined   314 \|     if not (isinstance(t, type) and issubclass(t, BaseException)):   315 \|         t = _jac_make_module_exc_type(qname, registered_exc_base(qname))   316 \|     try:        |
| OpcodeTest.test_compare_function_objects | VM-CRASH | 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac ✖ Error: name 'registered_exc_base' is not defined   314 \|     if not (isinstance(t, type) and issubclass(t, BaseException)):   315 \|         t = _jac_make_module_exc_type(qname, registered_exc_base(qname))   316 \|     try:        |
| OpcodeTest.test_modulo_of_string_subclasses | VM-CRASH | 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac ✖ Error: name 'registered_exc_base' is not defined   314 \|     if not (isinstance(t, type) and issubclass(t, BaseException)):   315 \|         t = _jac_make_module_exc_type(qname, registered_exc_base(qname))   316 \|     try:        |

## Quarantined at conversion

| test | reason |
|---|---|
| OpcodeTest.test_setup_annotations_line | harness-error:ModuleNotFoundError: No module named 'test' |
| OpcodeTest.test_do_not_recreate_annotations | harness-error:ModuleNotFoundError: No module named 'test' |

## Expected vs got

### OpcodeTest.test_compare_function_objects (VM-CRASH)

- expected: host oracle = `ok`
- got: 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac
✖ Error: name 'registered_exc_base' is not defined
  314 |     if not (isinstance(t, type) and issubclass(t, BaseException)):
  315 |         t = _jac_make_module_exc_type(qname, registered_exc_base(qname))
  316 |     try:

### OpcodeTest.test_default_annotations_exist (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**annotations**'">

### OpcodeTest.test_modulo_of_string_subclasses (VM-CRASH)

- expected: host oracle = `ok`
- got: 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac
✖ Error: name 'registered_exc_base' is not defined
  314 |     if not (isinstance(t, type) and issubclass(t, BaseException)):
  315 |         t = _jac_make_module_exc_type(qname, registered_exc_base(qname))
  316 |     try:

### OpcodeTest.test_raise_class_exceptions (VM-CRASH)

- expected: host oracle = `ok`
- got: 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac
✖ Error: name 'registered_exc_base' is not defined
  314 |     if not (isinstance(t, type) and issubclass(t, BaseException)):
  315 |         t = _jac_make_module_exc_type(qname, registered_exc_base(qname))
  316 |     try:
