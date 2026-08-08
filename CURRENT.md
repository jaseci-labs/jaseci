# CPython reference pin

`reference/cpython` is the upstream source jacpython ports against. It is a vendored git
checkout of https://github.com/python/cpython (gitignored in this repo, ~194MB), not a
registered submodule, so the pin lives here as policy + the checked-out commit.

## Pin (set 2026-07-14)

- **Version:** CPython **3.14.6** (chosen over the prior 3.16.0a0 moving-alpha checkout).
- **Commit:** `c63aec69bd59c55314c06c23f4c22c03de76fe45`
- **Tag:** `v3.14.6`
- **Baseline survey (3.14.6):** 469 `.c` files / 634,080 C LOC; 620 headers / 301,104 header LOC; 2138 `.py` files (Lib + Modules).

## Policy

jacpython is a **living implementation** that tracks CPython releases. 3.14.6 is the *anchor*
tag: all calibration (Tier-B density, LOC buckets, grammar/bytecode/DSL assumptions) is measured
against it. To move the anchor forward, `git -C reference/cpython checkout v3.1x.y` to the new
release tag and update the baseline survey + this file; keep the delta small and re-run the
differential harness on the ported corpus after each bump.

## Re-pin recipe

```
git -C reference/cpython fetch origin --tags
git -C reference/cpython checkout v3.14.6      # or a newer 3.14.x / chosen release
# re-derive the baseline survey, update jac-py/PLAN.md §3 + this file
```
