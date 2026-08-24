# Live View Bridge Policy (fp-e87c)

## Problem

`to_host`'s default policy for plain `list` / `dict` / `set` is MUTABLE_COPY: a
guest container crossing the host bridge becomes an independent host snapshot.
Mutations on either side are invisible to the other. For most crossings that
isolation is a feature, but for consumers that must hold a LIVE reference to
guest state across the bridge (the ContextVar cluster, fp-e87c), a snapshot is
semantically wrong: CPython's `ContextVar.set`/token machinery stores and
compares real object references.

## Pattern

The `PyGlobalsProxy` arm of `to_host` already established the pattern:
`_jac_make_live_ns_view(proxy)` builds a host-side `collections.abc.Mapping`
that delegates every read/write back into guest storage through the guest
protocol surface (`mp_subscript`, `mp_ass_subscript`) with per-access
`to_host` (guest -> host) / `from_host` (host -> guest) marshalling. The live
container views extend the same pattern to the three mutable containers:

| shim                     | guest type | host base class            | read slot        | write slot                    | delete slot       |
|--------------------------|------------|----------------------------|------------------|-------------------------------|-------------------|
| `_jac_make_live_list`    | PyList     | MutableSequence            | mp_subscript     | mp_ass_subscript + items.insert | mp_del_subscript |
| `_jac_make_live_dict`    | PyDict     | MutableMapping             | mp_subscript     | mp_ass_subscript              | mp_del_subscript  |
| `_jac_make_live_set`     | PySet      | MutableSet                 | set_contains     | set_add                       | set_discard       |

All shims live in the `::py::` embedded section of `jacpython/ceval.jac`,
next to `_jac_make_live_ns_view`.

Direction discipline (the known leak hazard): reads marshal outward with
`to_host`, writes marshal inward with `from_host`. Mixing them leaks
`PyHostProxy` wrappers into guest data or raw `PyObj` internals into host
data. Error results re-raise through `_jac_reraise_pyerror` so host control
flow sees the exact guest exception (`KeyError('k')`, `IndexError('list index
out of range')`, unhashable-key `TypeError`) instead of a resynthesized one.

## Gating choice

Explicit opt-in via the Jac-level dispatcher
`live_container_bridge(value: PyObj) -> any` (ceval.jac, re-exported through
pyc_first). It returns a live view for mutable `PyList`/`PyDict`/`PySet` and
`None` otherwise (frozenset included -- immutable state needs no view).

The default `to_host` arms for plain containers stay MUTABLE_COPY untouched:
existing consumers (json facade, repr paths, stdlib delegation) rely on
snapshot isolation, and silently flipping them to views would change identity
semantics (`x is y` across two crossings) for every caller. Consumers that
need write-through call `live_container_bridge` explicitly; the ContextVar
path is the intended first customer.

## Why collections.abc bases (option a)

Chosen over lighter hand-rolled classes because MutableSequence /
MutableMapping / MutableSet supply the full derived surface (append, pop,
remove, index, count, get, keys/values/items, union/intersection, clear,
`__contains__`, `get`) for free, correctly composed from the five abstract
slots we implement. Hand-rolling would duplicate that composition with no
gain; subclassing the concrete builtins was rejected because storage is the
Jac items table, not a host container (same reasoning as the ns view).

## Documented deltas vs CPython

- Views are NOT dict/list/set instances: `isinstance(view, dict)` is False,
  and `view == [1,2]` falls back to identity for lists/dicts (Sequence defines
  no `__eq__`; Mapping/MutableSet do define value equality, so those compare
  by content).
- repr presents as the equivalent builtin (`[1, 2]`, `{...}`), not the view
  class.
- List `__iter__` walks by index through `mp_subscript`, so appends made
  during iteration are visible (CPython's list iterator also shares the
  backing array; semantics match).
- Dict/set `__iter__` snapshots keys/members at iteration start; there is no
  version-counter RuntimeError ("dict changed size during iteration") at the
  host boundary.
- Set membership uses `PySet.set_contains`, which swallows element-comparison
  errors as False rather than propagating them.
- No `del` gap: unlike the ns view (whose proxy has no delete protocol), all
  three guest types carry delete slots, so `del view[k]` works.

## Un-quarantine path for fp-e87c suites

Suites quarantined under the ContextVar repr cluster can be re-enabled once
their consumer wires `live_container_bridge` into the crossing point:

1. Replace the `to_host(container)` call at the crossing with
   `live_container_bridge(container)` (falling back to `to_host` when it
   returns None).
2. Re-enable the quarantined tests in the suite runner.
3. CI gate: `jac test test_live_view_containers.jac` covers the write-through
   contract (guest-mutation-visible-through-view, view-write-visible-in-guest,
   len/iter/contains for list, dict, set).

## Files

- `jacpython/ceval.jac`: `_jac_make_live_list/_dict/_set` shims,
  `live_container_bridge` dispatcher, pyc_first re-export.
- `jacpython/test_live_view_containers.jac`: vm_exec-pattern conformance pins.
