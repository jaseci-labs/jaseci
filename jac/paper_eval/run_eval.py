"""GraphMend paper reproduction harness (break-elimination + output correctness).

For each registered model, runs the forward pass through a counting backend in
two isolated subprocesses (GraphMend off, then on), and reports:
  - breaks before / after  (reproduces Table 2 break counts + fix rate)
  - output fingerprint match (reproduces the bit-identical FP32 claim)

CPU-reproducible; GPU is only needed for the latency/throughput numbers, which
are out of scope here. Run with the repo jaclang on PYTHONPATH:

    PYTHONPATH=$PWD python -m paper_eval.run_eval [model_key ...]
"""
import sys, os, json, subprocess

from paper_eval.registry import MODELS, NETWORK_MODELS


def _run(key: str, mode: str) -> dict:
    env = dict(os.environ, PYTHONPATH=os.getcwd())
    p = subprocess.run([sys.executable, "-m", "paper_eval._runner", key, mode],
                       capture_output=True, text=True, env=env)
    for line in reversed(p.stdout.strip().splitlines()):
        try:
            return json.loads(line)
        except Exception:
            continue
    return {"key": key, "mode": mode, "graphs": None, "breaks": None,
            "out_hash": None, "error": (p.stderr.strip()[-160:] or "no output")}


def main(keys):
    rows = []
    tot_before = tot_after = 0
    for key in keys:
        off = _run(key, "off")
        on = _run(key, "on")
        err = off["error"] or on["error"]
        if err:
            rows.append((key, "-", "-", "-", "ERR")); print(f"  {key}: {err}", file=sys.stderr); continue
        b0, b1 = off["breaks"], on["breaks"]
        fixed = b0 - b1
        pct = f"{100*fixed//b0 if b0 else 100}%"
        correct = "yes" if off["out_hash"] == on["out_hash"] else "NO"
        # The off/on runs must use identical inputs for the comparison to mean
        # anything; show the shape and flag a mismatch rather than trusting it.
        s0, s1 = off.get("in_shape"), on.get("in_shape")
        shape = "x".join(str(d) for d in (s0 or [])) or "-"
        if s0 != s1:
            shape += " MISMATCH"
        tot_before += b0; tot_after += b1
        rows.append((key, b0, b1, pct, correct, shape))

    print(f"\n{'model':28} {'breaks_before':>13} {'breaks_after':>12} "
          f"{'fixed':>6} {'output_ok':>9} {'input':>12}")
    print("-" * 85)
    for r in rows:
        print(f"{r[0]:28} {str(r[1]):>13} {str(r[2]):>12} "
              f"{str(r[3]):>6} {str(r[4]):>9} {str(r[5] if len(r) > 5 else '-'):>12}")
    print("-" * 85)
    if tot_before:
        print(f"{'TOTAL':28} {tot_before:>13} {tot_after:>12} "
              f"{100*(tot_before-tot_after)//tot_before:>5}% (eliminated {tot_before-tot_after}/{tot_before})")


if __name__ == "__main__":
    # Named models run as asked; a bare run skips the ones needing network so the
    # default stays offline and download-free.
    args = sys.argv[1:]
    if not args:
        args = [k for k in MODELS if k not in NETWORK_MODELS]
        skipped = sorted(NETWORK_MODELS)
        if skipped:
            print(f"(skipping network models: {', '.join(skipped)} -- "
                  f"run by name to include)", file=sys.stderr)
    main(args)
