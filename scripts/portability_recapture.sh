#!/usr/bin/env bash
# Second-machine portability re-capture for JacInteropBench.
#
# Purpose: demonstrate that the PAPER'S RATIOS port across machines while the
# ABSOLUTE nanosecond figures are clock-specific -- the single-machine
# generalizability objection. Run this on a DIFFERENT box (ideally arm64) from
# the canonical Ultra 7 255H, then compare the printed ratios against the
# canonical values below.
#
# Canonical (Ultra 7 255H, performance governor, turbo off):
#   placement slope ratio  sv/na  ~= 42x        (iop_cb.free 212 / na_local 5.0)
#   payload serialization  rpc/direct ~= 2.6x   (890 / 342 ns/element)
#   callback twin-gap intercept        ~= 2.0us
#   cross-runtime floors   svc_split 374x, feed 241x, wasm 6.8x
# The RATIOS should reproduce within a few percent on any machine; the ns
# ABSOLUTES will differ with clock/uarch. That contrast IS the result.
#
# Requirements: a working `jac` (0.34.x), `node` on PATH, pinned governor.
# Usage:
#   scripts/portability_recapture.sh <machine-label>
# writes results/portability/<machine-label>/{env,sweep,payload,xruntime}.json
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:?usage: portability_recapture.sh <machine-label> (e.g. arm64-m2)}"
OUT="results/portability/${LABEL}"
mkdir -p "$OUT"

# --- guardrail: refuse unless governor is pinned (matches sweep_controlled) ---
GOV="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
if [[ "$GOV" != "performance" && "$GOV" != "unknown" ]]; then
  echo "ABORT: governor is '$GOV', not 'performance'. Pin it first:" >&2
  echo "  echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor" >&2
  exit 2
fi
TURBO="$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo NA)"
[[ "$TURBO" == "1" || "$TURBO" == "NA" ]] || \
  echo "WARNING: turbo not disabled (no_turbo=$TURBO); absolutes will drift." >&2

echo "== 1/4 environment provenance =="
python3 scripts/capture_env.py -o "$OUT/env.json"

echo "== 2/4 family-1 work sweep (iop_call/iop_cb/iop_symmetric), reps=20 =="
python3 scripts/sweep_controlled.py --reps 20 --out "$OUT/sweep.json"

echo "== 3/4 payload sweep (xop_feed_payload N=1..100k), n=20 =="
python3 scripts/payload_sweep_controlled.py --invocations 20 --reps 1 \
  --out "$OUT/payload.json"

echo "== 4/4 cross-runtime small (svc_split/feed/wasm), n=20 =="
( cd jac/examples/interopbench && \
  jac run harness/xbench.jac --experimental \
    --kernels xop_svc_split,xop_feed,xop_wasm_call --sizes small \
    --invocations 20 --out "$(pwd)/../../../$OUT/xruntime.json" )

echo
echo "== portability summary for '$LABEL' (compare RATIOS to canonical above) =="
python3 - "$OUT" <<'PY'
import json, sys, statistics as st
out = sys.argv[1]

def fit(pw):
    xs = sorted(int(w) for w in pw)
    X = [(w, pw[str(w)]["median_per_call_ns"]) for w in xs]
    n=len(X); sx=sum(w for w,_ in X); sy=sum(y for _,y in X)
    sxx=sum(w*w for w,_ in X); sxy=sum(w*y for w,y in X)
    b=(n*sxy-sx*sy)/(n*sxx-sx*sx); a=(sy-b*sx)/n
    return a,b

sw = json.load(open(f"{out}/sweep.json"))["cells"]
cb = fit(sw["iop_cb"]["variants"]["free"]["per_work"])[1]
na = fit(sw["iop_symmetric"]["variants"]["na_local"]["per_work"])[1]
print(f"  placement slope ratio sv/na = {cb/na:5.1f}x   (canonical ~42x)")

ps = json.load(open(f"{out}/payload.json"))["cells"]["xop_feed_payload"]["per_size"]
def pfit(key):
    pts=sorted((s["N"], s[key]["per_call_ns"]) for s in ps.values())
    n=len(pts); sx=sum(x for x,_ in pts); sy=sum(y for _,y in pts)
    sxx=sum(x*x for x,_ in pts); sxy=sum(x*y for x,y in pts)
    return (n*sxy-sx*sy)/(n*sxx-sx*sx)
ds, rs = pfit("direct"), pfit("rpc")
print(f"  payload serialization rpc/direct = {rs/ds:4.2f}x   (canonical ~2.6x)")
print(f"    direct {ds:.0f} ns/el,  rpc {rs:.0f} ns/el  (absolutes are machine-specific)")

xr = json.load(open(f"{out}/xruntime.json"))["cells"]
for cell in ("xop_svc_split","xop_feed","xop_wasm_call"):
    v=xr[cell]["variants"]; ref="direct" if "direct" in v else "native"
    oth=[k for k in v if k!=ref][0]
    print(f"  {cell:16s} {oth}/{ref} = {v[oth]['median_ns']/v[ref]['median_ns']:6.1f}x")
PY
echo "done -> $OUT/"
