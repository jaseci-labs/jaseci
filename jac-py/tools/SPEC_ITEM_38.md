# FIX SPEC -- TODO Item 38 (MED): `super().__init_subclass__()` recurses infinitely

**Status:** spec only, NOT started.
**Files needed:** `jac-py/jacpython/ceval.jac` ONLY.
**RESERVED-FILE FLAG: ceval.jac is RESERVED (mid-flight lane) → QUEUE THIS FIX, do not start.**
(objects.jac / abstract_protocol.jac not required.)

## Minimal repro

```python
class A:
    def __init_subclass__(cls, **kw):
        super().__init_subclass__()

class B(A):   # <-- recursion here
    pass
```

## Current guest behavior (probed on this tree)

`exec_code` of the compiled repro does not return a catchable guest error: the
recursion blows the NATIVE stack and the whole `jac run` dies with a host
`RecursionError` traceback whose tail is thousands of repeated frames:

```
at py_invoke()   ceval.jac:<py_invoke>
at run_frame()   ceval.jac:<run_frame>
... (repeated)
at apply_init_subclass() ceval.jac:4795-ish
at py_build_class()      ceval.jac:4874-ish
```

Control probe (same harness): zero-arg `super()` inside a normally OVERRIDDEN
method (`B2.f` calling `super().f()`) works fine -- the bug needs the method
being executed to be inherited relative to the receiver's class (which is
always the case for `apply_init_subclass`, since it calls `A.__init_subclass__`
with `cls=B`).

Host oracle (CPython 3.14.6, pinned): prints nothing; subclass creation is
accepted silently (object.**init_subclass** is a no-op accepting kwargs).

## Root cause (confirmed, two layers)

Layer 1 -- the `__class__` cell is never populated.

- The host compiler emits real CPython bytecode: the class body stores
  `__classcell__` into the namespace dict and each method captures freevar
  `__class__`. Verified by unmarshalling `class A:\n def f(self): return super()\n`:
  body `names=[... '__classdictcell__', '__classcell__']`,
  body `cellvars=['__class__','__classdict__']`, method `freevars=['__class__']`.
- The runtime never reads `__classcell__`: grep over jac-py/jacpython finds zero
  occurrences of `classcell`. `py_build_class` (ceval.jac:4874) executes the
  body via `exec_code_frame(...)` into a plain str-map namespace and hands it to
  `make_pyclass_from_map`; same for `build_class_via_metaclass` (ceval.jac:4928)
  and `type_new` (ceval.jac:4746).
- So every `__class__` cell keeps its initial value `py_none()`
  (`exec_code_frame` cell seeding, ceval.jac:~6858-6866).

Layer 2 -- `super_lookup` falls back to the receiver's class.

`super_lookup(defining_cls, instance, name)` (ceval.jac:4411): when
`defining_cls` is not a PyClass (it is `py_none()`), `start = walk_cls`, i.e. the
RECEIVER's class B. The MRO walk then skips only B and immediately returns
`A.__init_subclass__` -- the defining method itself. Calling it re-runs the body,
whose `super().__init_subclass__()` resolves to itself again → infinite
recursion. Caller: `apply_init_subclass` (ceval.jac:4795), invoked from
`py_build_class` after the class is built.

This also predicts (unprobed, same family): any `super().x()` inside an
INHERITED method recurses the same way (`class A: def f(self): super().f()`;
`class B(A): pass`; `B().f()`).

Secondary gap: even with a correct `start=A`, `class_mro(B)` past A is empty --
`class_mro` (ceval.jac:4211) contains only user PyClasses, never `object`.
CPython answers with `object.__init_subclass__` (a no-op classmethod accepting
kwargs). Without an object-level default, the fixed lookup would raise
AttributeError instead of recursing.

## Proposed fix

1. Populate the `__classcell__` after class construction (primary, fixes the
   whole family):
   - In `py_build_class`, `build_class_via_metaclass`, and `type_new`, after the
     PyClass exists, look up `"__classcell__"` in the executed namespace and set
     that shared cell's value to `cls`. The method closures already share the
     class-body frame's cell (captured at OP_SET_FUNCTION_ATTRIBUTE,
     ceval.jac:~7175-7195 via `find_cell(cells, co.cellvars, '__class__')`), so
     one write makes every method's `super_class` correct.
   - Note: inspect what the class body actually STORES under `__classcell__`
     (a PyCell or a boxed copy) before wiring; the store path for cells into the
     ns map may box the cell (mirroring SET_FUNCTION_ATTRIBUTE's fallback
     `PyCell(t="cell", val=item)` branch). If boxed, recover the live cell the
     same way `find_cell` does instead of trusting the ns entry.
   - Also strip `__classcell__`/`__classdictcell__` from the stored class attrs
     so they do not leak into `C.__dict__` / `dir(C)` parity.
2. Object-tail defaults in `super_lookup`: when the MRO walk past `start`
   exhausts without finding `name`, answer CPython's object defaults for the
   known no-op dunders instead of raising AttributeError -- minimally
   `__init_subclass__` (no-op accepting kwargs) -- or introduce a synthetic
   `object` PyClass appended to every MRO. Prefer the narrow name-keyed table;
   a synthetic object class touches every MRO consumer (blast radius).

## Risks

- `super_lookup`'s receiver-class fallback is load-bearing TODAY precisely
  because the cell is always empty (enum, functools, internal lifts all call
  super()). Fixing layer 1 changes `defining_cls` from None to the real class
  for EVERY method -- mostly strictly more correct, but walk-start semantics
  change wherever a method is called through a subclass (that is exactly the
  bug, but expect corpus churn in modules relying on the accidental fallback).
- Setting the cell post-construction means super() during class-BODY execution
  stays undefined (matches CPython: **class** is unavailable in the body).
- Recursion currently escapes as a native crash; after the fix ensure the
  no-error path leaves `x = 'ok38'` set and no attrs leak of `__classcell__`.

## Acceptance probes

1. Repro above completes; `x == 'ok38'`; oracle: silent acceptance.
2. `except Exception` around `class B(A)` construction never fires.
3. Control: `B2().f()` override chain still `'B+A'`.
4. Family: inherited-method super (`A.f -> super().f()` reached via `B().f()`
   where f defined on A and base provides it) resolves to the base, not itself.
