# PACKET: Residual file-I/O edges (W-I/O)

Status header for the executor: read this whole file before touching anything.
Executor role: mechanical. Do not invent new probe behaviors beyond the recipe.

## 0. Outcome of this packet

The Aug 25 QuickRaven census found ZERO guest-wrong file I/O behaviors across
73 probes. There is no fix list. This packet therefore has two deliverables:

1. Preserve the census probe suite inside the repo as a regression asset
   (it currently lives only in `/var/tmp/qr-probe/`, which is ephemeral).
2. Record the verified-complete disposition so no future session re-opens
   W-I/O by accident.

## 1. Prerequisites

- Working `.venv` with jac (`uv venv && uv pip install -e jac` if missing).
- Host CPython 3.14 available as `python3` (oracle side).
- Census probes present at `/var/tmp/qr-probe/` (census.py, census2.py,
  census3.py, census4.py). If missing, STOP (see conditions below).

## 2. Exact steps

### Step 1: copy probes into the repo

```bash
mkdir -p jac-py/tools/io_census
cp /var/tmp/qr-probe/census.py  jac-py/tools/io_census/census1.py
cp /var/tmp/qr-probe/census2.py jac-py/tools/io_census/census2.py
cp /var/tmp/qr-probe/census3.py jac-py/tools/io_census/census3.py
cp /var/tmp/qr-probe/census4.py jac-py/tools/io_census/census4.py
```

Add `jac-py/tools/io_census/README.md` with three sentences: what the probes
are, that round 1-4 cover 73 behaviors with zero guest-wrong results as of
origin/jac-python @ a673dbb17, and how to re-run (Step 2 commands).

### Step 2: verify the suite still passes today (re-census)

Run host and guest sides and diff. Use a fresh scratch root each time:

```bash
cd /home/jac/repos/jac-python
for n in 1 2 3 4; do
  sed "s#/var/tmp/qr-census#/var/tmp/io-regr/host$n#" \
    jac-py/tools/io_census/census$n.py > /tmp/rehost$n.py
  mkdir -p /var/tmp/io-regr/host$n
  python3 /tmp/rehost$n.py > /var/tmp/io-regr/host$n.txt 2>&1
done
# guest side: convert then run, one process per round
for n in 1 2 3 4; do
  .venv/bin/jac tool py2jac /tmp/rehost$n.py -o /tmp/rehost$n.jac
  .venv/bin/jac run /tmp/rehost$n.jac > /var/tmp/io-regr/guest$n.txt 2>&1
  diff /var/tmp/io-regr/host$n.txt /var/tmp/io-regr/guest$n.txt
done
```

Expected: zero diffs except the three known probe artifacts already
dispositioned in `~/notes/io-census-quickraven.md`
(round-1 x_mode ordering, round-3 wrapper-over-rb). If any NEW diff appears:
do NOT fix anything. Record it verbatim in a new file
`jac-py/tools/io_census/REGRESSIONS.md` (behavior name, both outputs) and
STOP at Step 2.

### Step 3: record the disposition

Append a short section to `docs/packets/PACKET-io-edges.md` (this file)
titled `## Re-run log` with: date, git SHA of HEAD, per-round OK counts,
and either "no new diffs" or pointer to REGRESSIONS.md.

Commit everything on the current workstream branch:

```bash
git add jac-py/tools/io_census docs/packets/PACKET-io-edges.md
git commit -m "test(jac-py): preserve io-census probe suite as regression asset"
```

## 3. Explicit non-goals

- Do NOT implement fcntl/flock/mmap/sendfile/O_NONBLOCK. These belong to
  PACKET-subprocess.md and PACKET-networking.md territories and are ordered
  AFTER those workstreams by the revised plan sequencing.
- Do NOT touch `_io`, os.path, or pathlib runtime code. Nothing is broken.
- Do NOT delete or edit the original probes while copying (copy verbatim;
  only the hardcoded `/var/tmp/qr-census` root may be parameterized via sed
  at run time, never edited in the committed copies).

## 4. Acceptance criteria

- `jac-py/tools/io_census/census{1,2,3,4}.py` + README.md exist in repo.
- Re-run shows zero unexplained diffs (known artifacts documented).
- REGRESSIONS.md absent, or present with entries and a STOP report filed.

## 5. Verification commands

```bash
ls jac-py/tools/io_census/
git log --oneline -1        # shows your commit
grep -c "^OK" /var/tmp/io-regr/guest*.txt   # 26/22/19/5 style counts
```

## 6. Effort estimate

Half a day including one full re-run cycle.

## 7. STOP conditions (escalate to stronger model)

- Probes are gone from `/var/tmp/qr-probe/` AND not recoverable: escalate
  instead of rewriting probes from memory.
- Any new host-vs-guest diff in Step 2: stop after recording it.
- `jac run` of any converted census file stalls past 240s: stop and report
  which round, do not tune timeouts.
