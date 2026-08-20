"""Drift gate for P2 wave-3 staged vs lifted corpus."""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST_PATH: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p2_staged_manifest_wave3.json"
     );


def _load_json(path: str) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}

def _read_text(path: str) -> str {
    with open(path) as f {
        return f.read();
    }
}


test "P2 wave-3 staged manifest lists four modules" {
    manifest = _load_json(MANIFEST_PATH);
    modules = manifest["modules"] as list;
    assert len(modules) == 4 , len(modules);
    stems = sorted([row["stem"] for row in modules]);
    expected = sorted(
        ["math_count_bits", "math_lcm_long", "pyctype_digit", "strhex_byte"]
    );
    assert stems == expected , stems;
}

test "P2 wave-3 lift-staged modules match committed _lifted corpus" {
    manifest = _load_json(MANIFEST_PATH);
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
            staged_text = _read_text(staged_path);
            lifted_text = _read_text(lifted_path);
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
