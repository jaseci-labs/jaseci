"""P2 wave-8 corpus Tier-B density ratchet."""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p2_corpus_wave8", "manifest.json"
     ),
     BASELINE: str = os.path.join(
         REPO_ROOT,
         "jac-py",
         "tools",
         "p2_corpus_wave8",
         "baseline",
         "project.c2jac.report.json"
     ),
     LIFTED: str = os.path.join(
         REPO_ROOT,
         "jac-py",
         "Modules",
         "_lifted",
         "p2_corpus_wave8",
         "project.c2jac.report.json"
     );


test "P2 wave-8 lifted corpus tier_b_total does not regress baseline" {
    with open(MANIFEST) as f {
        manifest = json.load(f);
    }
    with open(BASELINE) as f {
        baseline = json.load(f);
    }
    with open(LIFTED) as f {
        current = json.load(f);
    }
    assert len(manifest["files"]) == 4;
    baseline_total = baseline["tier_b_total"] as int;
    current_total = current["tier_b_total"] as int;
    assert current_total <= baseline_total , (
        f"Tier-B regressed: {current_total} > baseline {baseline_total}"
    );
}
