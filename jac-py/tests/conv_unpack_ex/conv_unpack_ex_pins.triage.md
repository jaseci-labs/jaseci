# Triage report: `conv_unpack_ex_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_unpack_ex.py
- guest leg: 0/1 marks
- pins: **0 passed** / 1 run (+8 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| unpack_ex.doctests:doctests | VM-CRASH |   jac dev mode - using compiler source at /var/tmp/lane8/jac  Error: 'int' object is not iterable 14178 \|                 return hiter_r[1] as PyObj; 14179 \|             } 14180 \|             for hostel in hiter {       \|                      ^^^^^ 14181 \|                 target_set.set_add(from_h |

## Quarantined at conversion

| test | reason |
|---|---|
| unpack_ex.doctests:doctests.ex66 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex67 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex68 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex69 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex70 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex76 | doctest-module-qualified-expected |
| unpack_ex.doctests:doctests.ex81 | doctest-depends-on-dropped:['a'] |
| unpack_ex.doctests:doctests.ex83 | doctest-depends-on-dropped:['a'] |

## Expected vs got

### unpack_ex.doctests:doctests (VM-CRASH)

- expected: host oracle = `ok`
- got:   jac dev mode - using compiler source at /var/tmp/lane8/jac
 Error: 'int' object is not iterable
14178 |                 return hiter_r[1] as PyObj;
14179 |             }
14180 |             for hostel in hiter {
      |                      ^^^^^
14181 |                 target_set.set_add(from_h
