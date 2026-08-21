"""P2 wave-4 staged vs lifted drift gate."""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p2_staged_manifest_wave4.json"
     );


def _load_manifest -> dict {
    with open(MANIFEST) as f {
        return json.load(f);
    }
}


def _read(path: str) -> str {
    with open(path) as f {
        return f.read();
    }
}


test "P2 wave-4 staged manifest lists four modules" {
    manifest = _load_manifest();
    modules = manifest["modules"] as list;
    assert len(modules) == 4 , len(modules);
    stems = sorted([row["stem"] for row in modules]);
    expected = sorted(
        ["math_factorial_small", "pyctype_alpha", "pyctype_space", "pystricmp"]
    );
    assert stems == expected , stems;
}


test "P2 wave-4 lift-staged modules match committed _lifted corpus" {
    manifest = _load_manifest();
    staged_dir = os.path.join(REPO_ROOT, manifest["staged_dir"]);
    lifted_dir = os.path.join(REPO_ROOT, manifest["lifted_dir"]);
    mismatches: list = [];

    for row in (manifest["modules"] as list) {
        stem = row["stem"] as str;
        staging = row["staging"] as str;
        staged_path = os.path.join(staged_dir, f"{stem}.jac");
        lifted_path = os.path.join(lifted_dir, f"{stem}.jac");
        assert os.path.isfile(staged_path) , staged_path;
        assert os.path.isfile(lifted_path) , lifted_path;

        if staging == "lift" {
            staged_text = _read(staged_path);
            lifted_text = _read(lifted_path);
            if staged_text != lifted_text {
                mismatches.append(
                    f"{stem}: staged != lifted (re-lift or copy staged oracle)"
                );
            }
        } elif staging == "hand" {
            note = row.get("note");
            assert note , f"hand module {stem} needs manifest note";
        } else {
            assert False , f"unknown staging {staging!r} for {stem}";
        }
    }

    assert not mismatches , "\n".join(mismatches);
}
