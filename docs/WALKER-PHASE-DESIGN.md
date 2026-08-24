# Walker-phase design: unified dunder resolution

Status: DRAFT, accumulating. Owner: GoldLion (review lane). Inputs: BrightTiger
adversarial findings 1-21, runtime-worker landings through e1c668204.

## Problem

User-class dunder protocols are handled by per-path ad-hoc code: ~6 separate
tp_getattro implementations in objects.jac, plus slot overrides (tp_call,
tp_iter, mp_subscript, nb_binop, tp_richcompare, to_index, tp_bool) each doing
their own MRO walk. Items 4/5/12/13/14/18 landed as point fixes; the shared
machinery they duplicated is now the refactor target.

## Decision 1 -- one core walker, two policies

One core MRO walker; two lookup flavors on top:

- IMPLICIT protocol lookup (call, iter, subscript, binops): type-only search
  over MRO. Instance dict is INVISIBLE (CPython _PyObject_LookupSpecial
  semantics). Guards: pin-item5-inverse-inst-dict, pin-item15-inverse-not-
  implicit, pin-item4-inverse-inst-dict-call -- all must STAY green.
- EXPLICIT attribute access (tp_getattro): full precedence chain --
  data descriptor > instance dict > non-data class attr > __getattr__ tail.
  Precedence encoded ONCE in the core so the flavors cannot drift.
  IMPLICIT FLAVOR SCOPE: call, iter, subscript READ AND WRITE/DELETE
  (mp_subscript, mp_ass_subscript, mp_del_subscript), binops. Store/delete
  are implicit-flavor -- never re-walk MRO per-site. Drift evidence: item 18's
  landed fix duplicated property-fdel precedence in py_del_attr outside
  tp_setattro -- exactly what encode-once prevents.

Subject level is an explicit parameter: instance / type / metaclass.
callable(C) consults type(C) (metaclass MRO), not C's own dict.

### Native structural surfaces (WildRaven ruling)

Leaf-type tp_getattros serving FIELD READS (PySlice start/stop/step,
PyExceptionType name/args) are not MRO lookups and do NOT stay as sanctioned
special cases, nor run before the walk. Ruling: a per-type STRUCTURAL FIELD
MAP joins the explicit-flavor walk as the leaf type's namespace at the
NON-DATA tier -- shadowable by instance dict, overridable by data descriptors
(CPython semantics: class L(list) with instance 'append' shadows the method).
The walker consults the map when the walked type is native; no 7th getattro.

## Decision 2 -- synthesis at value exit points

__class__/__dict__/__module__ synthesis applies wherever a value FLOWS OUT,
not only on direct attribute reads of well-known objects:

- attribute reads (item 12, landed)
- container element reads: lst[0].__class__ when lst[0] holds an exception
  (item 21 gap)
- StopIteration.value carriers (item 14 path)
- exception CHAINING carriers (__cause__/__context__ on PyException) --
  attribute-carried values, distinct from container reads and iter carriers;
- host-proxy unwraps / from_host materialization results (slices added by
  e1c668204 need __class__ too). KNOWN OPEN: native PySlice does NOT answer
  __class__ today (tp_getattro has no synthesis path) -- exit-point pin #1.
  Test strategy for from-host-adjacent constructors: after any materialization
  arm lands, probe __class__/__dict__ on the produced value in the same pin
  family, not as a one-off.

Pin-family taxonomy parameterizes over FIVE kinds: attr / container /
carrier(iter) / chain / proxy-materialization.

Third silent-wrongness family alongside synthesis + message fidelity:
ARG-COUNT/ARITY STRICTNESS -- native surfaces silently tolerating wrong arity
(WildRaven's isinstance extra-args find, 401b15b07) are their own class.
Rule: leaf-native callables reject extra/missing args with CPython-exact
TypeError text; pins assert rejection, not just acceptance paths.

Synthesis rules:

- __class__ DELEGATES to py_type_of -- single source of truth. Never mint an
  independent answer: today py_type_of(native slice) round-trips to_host, so
  independent synthesis would give type(s) != s.__class__. Pin assertion:
  type(x).__name__ == x.__class__.__name__ for every family member.
- __dict__/__module__ are PER-TYPE allowlist: synthesize only what CPython's
  type actually exposes (slice has NO __dict__; blanket synthesis over-exposes).
- OUT OF SCOPE: outward boundary crossings (to_host trampolines wrapping guest
  callables -- whether the host side sees __class__). Guest-side synthesis
  contract ends at guest-visible values; do not pin host-side views.

Implementation shape: ONE parametrized pin family "synthesis-at-exit-points"
covering the five kinds above -- not per-site pins.

## Decision 3 -- __getattr__ tail hook composition

The hook fires on normal-lookup miss AND when a data descriptor's __get__
raises AttributeError (CPython slot_tp_getattr_hook fall-through) -- and only
AFTER item-12-style synthesis attempts: a miss on __class__ must synthesize,
never fall through to user __getattr__, or user code could hijack identity
dunders via the tail hook. Guard pin belongs in the exit-point family.
It NEVER
participates in implicit protocol lookup. Pins: pin-item15-descr-miss-to-
getattr (composition), inverse pins (boundary).

## Decision 4 -- binding via existing machinery

The walker returns the resolved artifact; binding goes through bind_attribute
(the machinery that makes g.__next__() work today). Non-callable artifacts
surface via normal TypeError machinery (verified by pin-item4-noncallable-call).

## Collapse targets

1. The ~6 tp_getattro implementations delegate to the explicit-flavor policy;
   slot overrides delegate to the implicit flavor. No new ad-hoc walks.
2. Double MRO walk pattern (user_has_dunder + class_lookup_attr) collapses
   into a single walk returning found/not-found.
3. Keyword args at call sites for optional-heavy signatures (visit_stmts
   arg-order bug class, c93e6b5d5) -- standing rule for all new walker call
   sites.

## Landing state (updated as items close)

| Item | State |
|------|-------|
| 12 __class__/dict/module | LANDED |
| 4 tp_call | LANDED (0694fda4d) |
| 13 callable() | LANDED (2f34f3bfb) |
| 14 StopIteration.value | LANDED (590fc18c6) |
| 18 property fdel | LANDED (6d599e94f) |
| 5 iteration consumers | PARTIAL (list ctor done; matrix rewire in flight) |
| 1 generic descriptors | open -- walker phase proper |
| 15 __getattr__ tail | open -- walker phase proper |
| 21 exit-point synthesis | open -- walker phase proper |
| 10/20 slice family | LANDED (e1c668204), nits in flight |
| 19 range | UNOWNED / DESIGN-FIRST -- same materialization family as 10/20; construction still bridges (type(range)=='list') |
| 21 exit-point synthesis incl. exception attr VALUES (e.__cause__.__class__) | open -- walker phase proper; value-row and object-row land together |

## Acceptance gate (unchanged)

Every landing: full pinned corpus green-or-mapped, healthy-behavior pins stay
green, differential-vs-existing-explicit-path on the green corpus, HEAD sha
recorded per run.
