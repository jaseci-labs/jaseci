# Fresh differential-fuzz findings - 2026-08-22 (fuzz corpus expansion lane)

New RED divergences discovered while expanding `fuzz_corpus_pinned.json` from
39 to 169 cases with the checked-in generator (`tools/fuzz_gen.py`, seed
20260822). All reproduced minimally through the Layer-1 harness
(`_fuzz_smoke.jac` dual-execution: jacpython vs host CPython). Recorded as
pins + entries in `tools/fuzz_known_reds.json`; NOT fixed here (runtime-lane
scope). For the runtime lane.

## F1 - `bytes.__eq__` raises on any comparison (10 cases: gen-bytes-000..009)

Minimal repro:

```python
self.assertEqual(b'a' == b'a', True)   # jacpython RAISES; CPython -> True
```

- Any `bytes == bytes` expression errors during eval-mode replay
  (`B[1:3] == bytes([208, 141])`, `B + B[-1:] == ...`,
  `b'abc'.translate(...) == b'XY'`). Note two-arg assertEqual on identical
  sub-expressions passes because the harness compares pairs host-side - the
  bug is in bytes richcompare itself, not slicing/concat/translate.
- Related: `bytearray(b'ab') == b'ab'` does not raise but returns a wrong
  value under jacpython.

## F2 - user-defined exception subclass catch loses function return value

Minimal repro:

```python
class MyErr(Exception): pass
class SubErr(MyErr): pass
def pick():
    try:
        raise SubErr('sub')
    except (SubErr, MyErr):
        pass
    return 'ok'
self.assertEqual(pick(), 'ok')   # jacpython returns non-'ok'; CPython 'ok'
```

- With builtin exceptions (`ValueError`) the same shape passes, so the defect
  is specific to raising/catching user-defined exception classes.
- Affects gen-exc-003 / gen-exc-008. `issubclass(SubErr, MyErr)` itself is
  correct and except-tuple dispatch picks the right branch (side effects land),
  so suspicion is post-except block state/return handling in ceval.

## F3 - implicit exception context chain broken (gen-exc-009)

```python
def ctx_probe():
    try:
        try:
            1 / 0
        except ZeroDivisionError:
            raise KeyError('ctx')
    except KeyError as e2:
        return type(e2.__context__).__name__
self.assertEqual(ctx_probe(), 'ZeroDivisionError')   # jacpython differs
```

- Explicit `raise X from e` chains are covered by existing pins and pass;
  this is the IMPLICIT `__context__` path. Likely same root as known-red pin
  `pin-ok-exc-chaining-nesteddef`.

## F4 - multiple lambda-returning comprehensions corrupt closure cells

Minimal repro:

```python
fs = [lambda x=x: x + 2 for x in range(3)]
gs = [lambda: x for x in range(3)]
self.assertEqual([fn() for fn in fs], [2, 3, 4])   # fails on jacpython
```

- Single comprehension alone passes; adding a second one in the same scope
  breaks the first's results (order-independent: defining `gs` first also
  fails). Suspect comprehension-function cell/free-variable wiring in codegen.
- Affects gen-closure-002 / 005 / 008 and, in variant form, gen-exc-004
  (finally-on-return log ordering check fails only when a second nested def
  shares the setup).

## Gate status after expansion

`python3 tools/fuzz_run.py --known-reds tools/fuzz_known_reds.json`
→ 169 cases: GREEN 143, EXPECTED-RED 26 (9 pre-mapped walker pins + 17 fresh
above), NEW-RED 0 → GATE PASS.
