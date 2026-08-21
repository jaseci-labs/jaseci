"""P2 wave-4 staged vs lifted drift gate."""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p2_staged_manifest_wave4.json"
     ),
     MODULES: str = os.path.join(REPO_ROOT, "jac-py", "Modules");


def _load_manifest() -> dict {
    with open(MANIFEST) as f {
        return json.load(f);
    }
}


def _read(path: str) -> str {
    with open(path) as f {
        return f.read();
    }
}


test "P2 wave-4 staged oracle matches lifted corpus for lift-staged modules" {
    manifest = _load_manifest();
    lifted_dir = os.path.join(REPO_ROOT, manifest["lifted_dir"]);
    for row in manifest["modules"] {
        if row["staging"] != "lift" {
            continue;
        }
        stem = row["stem"];
        staged = os.path.join(MODULES, f"{stem}.jac");
        lifted = os.path.join(lifted_dir, f"{stem}.jac");
        assert os.path.isfile(staged) , f"missing staged {staged}";
        assert os.path.isfile(lifted) , f"missing lifted {lifted}";
        assert _read(staged) == _read(lifted) , (
            f"{stem}: staged oracle drift from lifted corpus"
        );
    }
}
