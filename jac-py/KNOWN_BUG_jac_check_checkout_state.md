# KNOWN ISSUE: `jac check` phantom type errors bound to THIS checkout's history

**Status:** investigated 2026-08-22 (QuickRaven session); filed upstream as
jaseci-labs/jac#8543 with correction comment. NOT a jac-py code problem - do
not chase the "errors" and do not re-debug from scratch; read this first.
Cost ~4 agent-hours of false positives before root-cause hunt.

## Symptom

In THIS checkout (`/home/jac/repos/jac-python`), `jac check` on
`jac-py/jacpython/compiler_emit.jac` (and other files) reports ~27
deterministic type errors:

```
error[E1032]: Type is Unknown, cannot access attribute "arg"
error[E1053]: Cannot assign <Unknown> to parameter 'val' of type str
error[E1099]: Cannot access attribute "defaults" for type "arguments | NoneType"
error[E1053]: Cannot assign cmpop to parameter 'op' of type PyObj
```

The same bytes pass clean when copied into a fresh clone directory, or from a
detached worktree. A **fresh clone of the same branch passes everywhere** -
so this binds to THIS checkout's accumulated state, not to committed content.

## What we ruled out (each tested by transplant/isolation)

| Suspect | Verdict |
|---|---|
| Dirty WIP files / untracked stray `.jac` probes | exonerated |
| Project caches `.jac/`, `jac/.jac`, `jac-py/.jac`, nested `data/*.db` | exonerated (transplanted both directions) |
| Global `~/.cache/jac/jir/modules` + `kernel_units` | exonerated (moved aside, cold rebuild) |
| `_precompiled/cpython-314` sealed image, `__pycache__`, native artifacts | exonerated |
| Root-level extra files, environment variables (`env -i`) | exonerated |
| Compiler source version (jac/ identical across test trees at time of test) | exonerated |

strace: failing runs re-read dependency `.jac` sources from disk every run;
passing runs are fully served from compiled caches. Failure is stable across
repeat runs, cold/warm global cache, and cwd changes.

Leading theory: incremental state keyed on per-file mtime/inode/history that
constant concurrent agent edits keep invalidating; transplants cannot
reproduce it because copies get fresh mtimes/inodes.

## Practical rules for agents

1. Phantom errors from THIS checkout: verify your work via transplant into a
   fresh clone/worktree, or trust CI. NEVER revert good work over them and do
   not "fix" code to silence them.
2. Do not run heavy experiments against `/tmp` on this box without checking
   `df -h /tmp` first - it is a 7.5G tmpfs shared by all agents and fills fast
   (it hit 100% twice on 2026-08-22).
3. `_precompiled/` was removed from `jac/jaclang/` during debugging; it is an
   optional acceleration artifact (regenerable via the `jac build` seal flow).
   Absence only costs first-run compile time.

## Upstream

- Issue: https://github.com/jaseci-labs/jac/issues/8543 (includes correction
  comment narrowing the claim after fresh-clone testing)
