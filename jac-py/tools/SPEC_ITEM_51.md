# FIX SPEC -- TODO Item 51 (MED): `__slots__` not enforced, no `__dict__` suppression

**Status:** spec only, NOT started.
**Files needed (implementation):** `jac-py/jacpython/ceval.jac` (PyClass,
PyUserObj.tp_getattro/tp_setattro, make_pyclass_from_map / type_new /
build_class_via_metaclass).
**RESERVED-FILE FLAG: ceval.jac is RESERVED → QUEUE THIS FIX, do not start.**
Secondary touch if member descriptors are in scope: `jac-py/jacpython/type_slots.jac`
(UNTRACKED leaf, currently unwired) and optionally `objects.jac` (cycles free;
not required for the minimal fix).

## Minimal repro

```python
class C:
    __slots__ = ('x',)

c = C()
c.z = 3      # guest: succeeds; CPython: AttributeError
d = c.__dict__  # guest: returns a dict; CPython: AttributeError
```

## Current guest behavior (probed on this tree)

- `c.z = 3; x = c.z` -> OK (attribute stored on the instance dict)
- `c.__dict__` -> OK (returns the live attr map as a dict)
- `hasattr(c, '__dict__')` -> True
- declared slot `c.x = 5; c.x` -> OK (trivially, via the same instance dict)
- `C.__slots__` -> `('x',)` (the class body assignment is stored verbatim)

Host oracle (CPython 3.14.6 pinned):

- `c.z = 3` -> `AttributeError: 'C' object has no attribute 'z' and no __dict__ for setting new attributes`
- `hasattr(c, '__dict__')` -> False
- `c.__dict__` -> `AttributeError: 'C' object has no attribute '__dict__'`
- `c.x = 5` -> OK

## Root cause

Compiler side is FINE -- nothing to do there. `__slots__ = (...)` is an ordinary
class-body name binding; it lands in the class namespace and reads back through
the normal class getattr (probed above).

The runtime never consumes it:

1. `PyClass` (ceval.jac:1273) has NO slots state at all -- no member-name list,
   no has-dict/has-weakref flags. `make_pyclass_from_map` (ceval.jac:4660),
   `type_new` (ceval.jac:4746) and `build_class_via_metaclass` (ceval.jac:4928)
   copy the namespace wholesale and ignore `"__slots__"`.
2. `PyUserObj.tp_setattro` (ceval.jac:~1536) checks only PyProperty data
   descriptors, then unconditionally writes `self.attrs[name] = value`.
3. `PyUserObj.tp_getattro` (ceval.jac:~1524) answers `__dict__` with
   `dict_from_str_map(self.attrs)` unconditionally.
4. The layout helpers that SHOULD drive this exist but are dead code:
   `jac-py/jacpython/type_slots.jac` (UNTRACKED file) provides
   `type_slots_filter_members`, `type_slots_wants_dict`, `type_slots_has_dict`,
   `type_slots_merge_names`, `type_slots_attr_allowed`, etc., exercised only by
   `test_type_slots.jac` / `test_p3_deepen_cores.jac`. No non-test module
   imports them.
   NOTE: TODO.md's "done" line claims `finalize_class_slots` + `PyMemberDescr`
   landed -- they do NOT exist anywhere in the repo (grep). Treat that claim as
   stale; only the pure helpers are real.

## Proposed fix shape (minimal)

1. Add slots state to `PyClass`: `slot_members: list[str]`,
   `slots_has_dict: bool`, `slots_has_weakrefs: bool` (defaults keep today's
   permissive behavior for every existing construction site).
2. Compute it wherever a class is finalized from a namespace map --
   `make_pyclass_from_map` is the single choke point for py_build_class,
   type_new, and the metaclass path; read `namespace["__slots__"]` when present
   and run it through the existing type_slots.jac helpers (filter members,
   merge inherited members by walking `bases`, has_dict/has_weakrefs rules).
   Strip `__slots__` from... no -- CPython KEEPS `__slots__` readable on the
   class (probed oracle agrees), so leave the attr in place.
3. Enforce in `PyUserObj.tp_setattro`: if the class declares slots, no
   property/data-descriptor hit, name not in merged slot members AND
   `not slots_has_dict` -> return
   `py_error("AttributeError", "'" + cls.name + "' object has no attribute '" + name + "' and no __dict__ for setting new attributes")`.
4. Suppress in `PyUserObj.tp_getattro`: the `name == "__dict__"` fallback
   returns the error instead when `not slots_has_dict` (keep serving it when
   slots declare `__dict__` or any base has a dict -- the helpers already encode
   these rules).
5. Defer real slot descriptors (`PyMemberDescr`, per-slot storage, `member`
   repr) to a later slice; storing declared slots in the instance dict keeps
   this fix behavior-compatible for reads/writes of DECLARED attrs while making
   undeclared writes and `__dict__` parity-correct.

## Blast radius / risks

- Every class-building path flows through `make_pyclass_from_map`; adding
  defaulted fields is additive, but the metaclass path (enum!) builds classes
  via `metaclass(...) -> PyUserObj`-shaped returns -- verify enum's EnumType
  classes still allow attribute plumbing after enforcement (enum defines
  members via setattr on instances/classes, not slotted instances; low risk but
  run the enum corpus slice).
- Classes that mix `__slots__` with a builtin boxed base or assign
  `cls.__dict__` dynamically (`__dict__` listed in slots) must keep working --
  covered by `type_slots_*` rules; wire them rather than re-implementing.
- `py_del_attr` (ceval.jac:~3230) should mirror the same restriction for
  completeness (`del c.x` on a slotted instance); CPython raises AttributeError
  for non-members.
- Corpus modules using `__slots__` for perf (e.g. argparse lifts) will start
  surfacing latent mis-typed writes -- that is the point, but expect churn.

## Acceptance probes

1. Repro above: all three surfaces match the pinned-oracle messages exactly.
2. `class D(C): pass` (no own slots) still has a dict (inheritance rule).
3. `__slots__ = ('x', '__dict__')` keeps `__dict__` working.
4. Non-slotted classes unchanged (defaulted fields).
