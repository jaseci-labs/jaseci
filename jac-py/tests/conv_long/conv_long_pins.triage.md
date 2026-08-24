# conv_long reland triage (post int->float overflow fix)

Root cause of the original 5 VM-CRASHes: NB_TRUE_DIVIDE converted operands
via float(a)/float(b), so huge-int division escaped a HOST OverflowError
("int too large to convert to float") as a fatal runtime error instead of
guest-exact semantics.

Fixes (fix/exc-context-selfref branch):

- objects.jac int_true_divide: port of CPython long_true_divide (bit-shift
  scaling, round-half-even, guest OverflowError
  "integer division result too large for a float" when the quotient exceeds
  double range). Wired into NB_TRUE_DIVIDE.
- ceval.jac py_convert_float: PyInt arm guards the host conversion ->
  OverflowError "int too large to convert to float".
- objects.jac NB_LSHIFT: zero left operand short-circuits before digit
  allocation (0 << huge == 0).

Pin statuses after fixes: 81/82 pass. Remaining:

| LongTest.test_round | BLOCKED-ELSEWHERE | super() on host-proxied random.Random lacks seed (known facade gap, random cluster -- owner-family fix first, see WORK-QUEUE converter section) |

Harness notes: small_ints snippet rewritten for CPython 3.14 syntax
(`is` with int literals is a SyntaxError); identity intent preserved via
bound-name singletons.
