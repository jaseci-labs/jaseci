# KNOWN BUG: `jac check` errors are project-root-dependent (phantom type errors)

**Status:** upstream toolchain bug (jaclang), NOT a jac-py code problem. Do not
chase the "errors" it reports, and do not re-debug from scratch - read this first.
First documented 2026-08-22 (QuickRaven session); cost ~3 agent-hours of false positives.

## Symptom

`jac check jac-py/jacpython/compiler_emit.jac` (and other files) reports ~27
deterministic type errors from the shared checkout:

```
error[E1032]: Type is Unknown, cannot access attribute "arg"
error[E1053]: Cannot assign <Unknown> to parameter 'val' of type str
error[E1099]: Cannot access attribute "defaults" for type "arguments | NoneType"
error[E1053]: Cannot assign cmpop to parameter 'op' of type PyObj
```

The same bytes pass clean when checked from a `git worktree` of the same commit.

## 2-command repro (deterministic)

```bash
git worktree add /tmp/wt HEAD                      # any detached worktree
cd /home/jac/repos/jac-python && .venv/bin/jac check jac-py/jacpython/compiler_emit.jac   # FAILS (~27 errors)
cd /tmp/wt && /home/jac/repos/jac-python/.venv/bin/jac check jac-py/jacpython/compiler_emit.jac  # PASSES
```

Outcome follows **which project root the compiler resolves**, not file content:
checking the *shared tree's* file from the worktree cwd PASSES; checking the
*worktree's* file from the shared cwd FAILS. From a cwd with no jac.toml (/tmp)
it fails too.

## What it is NOT (all tested by transplant/isolation)

| Suspect | Verdict |
|---|---|
| Dirty WIP files (codegen/objects/literals/ceval) | exonerated - transplanted individually into pristine worktree, still pass |
| Untracked stray `.jac` probe files | exonerated |
| Project caches `.jac/`, `jac/.jac`, `jac-py/.jac` (+ nested `data/*.db`) | exonerated - transplanted both directions |
| Global `~/.cache/jac/jir/modules` (2650 entries) + `kernel_units` | exonerated - moved aside, cold rebuild, still fails |
| `_precompiled/cpython-314` sealed image (was 7 weeks stale) | exonerated - removed from shared / injected into worktree, no flip |
| `__pycache__`, `libjacllvm.so`, root-level extras | exonerated |
| Environment variables | exonerated - `env -i` run fails identically |

## Shrunk repro

Copying just `jac.toml` + `jac-py/` into an empty directory (no caches, no
tests/tools/Modules) reproduces the identical error signature - so no state,
artifact, or cache is required. Deterministic across repeated runs and after
global-cache wipes.

## What strace shows

- FAILING config: dependency modules (e.g. `ast_nodes.jac`) are re-read from
  source on every run; AST node types (`arg`, `arguments`) resolve to Unknown.
- PASSING config: nothing re-read; all deps served from compiled cache.

Working theory: dependency-module resolution/cache-keying depends on the
resolved project root; in the canonical checkout some imports resolve to
Unknown (fresh recompile path), while from another root the same graph is
served consistent facts. Compiler-team territory.

## Workaround until fixed

Verify your files via a detached worktree transplant:

```bash
git worktree add /tmp/wt-$(date +%s) HEAD
cp <your-edited-files> /tmp/wt-*/jac-py/jacpython/   # matching paths
cd /tmp/wt-* && /home/jac/repos/jac-python/.venv/bin/jac check <file>
```

Or trust CI. **Never** "fix" your code to silence these phantom errors, and
don't let the shared-tree error count alarm you into reverting good work
(it burned two agents on 2026-08-22).
