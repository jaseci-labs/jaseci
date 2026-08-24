# File-I/O census regression probes

Four probe scripts (73 behaviors total) diffing guest file-I/O behavior against
host CPython: open modes/reads/seeks, fd-level ops/stat/dir entries, encodings/
buffering/update modes, and high-frequency real-code combos (json.dump/load,
JSON-lines). Round 1-4 found ZERO guest-wrong results as of origin/jac-python
@ a673dbb17; W-I/O is verified complete at probed depth, so this directory
exists to keep the probes from dying with /var/tmp and to catch regressions.

Re-run: for each censusN.py, run it under host python3 and under the guest
(`jac tool py2jac` then `jac run` on the converted module), each with a fresh
scratch root -- override the default via IO_CENSUS_ROOT / IO_CENSUS_ROOT2..4
env vars per side -- then byte-diff the structured OK/FAIL output. One jac
process at a time, hard timeout.
