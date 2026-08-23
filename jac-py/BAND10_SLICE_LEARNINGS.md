# Band 10 slice learnings (JacPython native compiler)

**Call-site `*args` / `**kwargs` via `CALL_FUNCTION_EX`.** Lands after Band 9
dict-merge displays (`DICT_UPDATE`) and reuses VM `CALL_FUNCTION_EX` /
`DICT_MERGE` already proven on host-compiled bytecode.

UPDATE 2026-08-22: call-site unpacking actually landed in Band 11 (commit
8bfdf5f8b, compiler_emit.jac) -- this doc's earlier implication that it shipped
with Band 10 was wrong; only the display-side DICT_UPDATE/LIST_EXTEND forms
were Band 10. See BAND11_SLICE_LEARNINGS.md for the authoritative notes.

Last updated: 2026-08-22.

---

## 1. Scope

| Slice | Status |
|-------|--------|
| `f(*a)` | done - sole star leaves iterable as-is + `PUSH_NULL` kwargs |
| `f(**d)` | done - `LOAD_CONST ()` + `BUILD_MAP 0` + `DICT_MERGE` |
| `f(x, *a)` / `f(*a, *b)` | done - `BUILD_LIST` + `LIST_EXTEND*` + `LIST_TO_TUPLE` |
| `f(x, **d)` / named + `**` | done - `BUILD_TUPLE` or named `BUILD_MAP` + `DICT_MERGE` |
| `f(x, *a, **d)` | done - list path + kwargs path |
| `f(**d, a=1)` | done - `**` then named |
| `f(a=1, **d)` | **blocked** - native parser drops trailing `**` after named kw |
| Chained-compare cleanup inside EX call | deferred (`NotImplementedError`) |

**Parser bug (parked):** [jaseci-labs/jac#8473](https://github.com/jaseci-labs/jac/issues/8473).
Band 10 does **not** wait on it - use `g(**d, a=1)` until a separate parser PR lands.

---

## 2. Stack model (CPython 3.14)

```text
  <callable>
  PUSH_NULL                 # self_or_null (Name / non-method)
  <callargs iterable/tuple>
  <kwargs mapping | PUSH_NULL>
  CALL_FUNCTION_EX 0        # oparg unused in 3.14
```

`ceval` pops kwargs (NULL/`PUSH_NULL` ⇒ no kwargs), then callargs, then
callable+null, and dispatches through `py_invoke`.

---

## 3. Args materialization

| Shape | Emission |
|-------|----------|
| sole `*a` | `visit(a)` only (no tuple coerce) |
| plains, no stars (kwargs-only EX) | `BUILD_TUPLE n` or `LOAD_CONST ()` |
| plains + stars / multi-star | leading plains → `BUILD_LIST n`; each `*` → `LIST_EXTEND 1`; `CALL_INTRINSIC_1 6` |

Positional args after `*` are a `SyntaxError` (CPython).

**Const ordering (oracle-critical):** before emitting callargs, pre-register named
keyword string consts. For empty callargs with no named kwargs, seed `None` first
so `()` lands at index 1 (`(None, ())`), matching CPython.

---

## 4. Kwargs materialization

Same left-to-right walk as dict-merge displays, but flush/merge with
**`DICT_MERGE`** (duplicate-key error) not `DICT_UPDATE`:

- no keywords → `PUSH_NULL`
- `**` first → `BUILD_MAP 0` then `DICT_MERGE`
- named pairs then `**` → `BUILD_MAP n` then `DICT_MERGE`
- named after `**` → `BUILD_MAP n` + `DICT_MERGE` onto existing

**Parser gap:** `g(a=1, **d)` and `g(*a, b=1, **d)` drop the trailing `**`
unpack in the native parser (named/`**` order). Codegen is fine once the AST
is correct; use `g(**d, a=1)` until the parser is fixed on a separate branch.

---

## 5. Key functions

```text
compiler_codegen.jac
  call_needs_ex
  emit_call_args_ex
  emit_call_kwargs_ex
  emit_call_function_ex
```

Wired from `visit_expr` Call and `visit_comp_elt` Call. Ordinary `CALL` /
`CALL_KW` paths unchanged when no star / `**`.

---

## 6. Gates

- `compiler_slice` / `layer9` band10 fixtures (oracle `co_code` + ceval)
- `vm_opcode_fixtures.py`: `CALL_FUNCTION_EX`, `DICT_MERGE`, `LIST_EXTEND`
- `layer_vm_conformance.jac` matching `# vm-opcode:` tags
