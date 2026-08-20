"""P3 object-core track gate skeleton (PLAN.md §7 P3, TODO.md §3).

Manifest ratchet: ``jac-py/tools/p3_object_core/manifest.json`` holds Layer-0/1
baselines and documents upcoming c2jac Objects/ targets.

Layer-0 corpus replay against those baselines is **P3.1a** work — it must live in
``jac-py/jacpython/layer0_replay.jac`` (or a sibling there), not here: ``jac-py/tests``
cannot ``import layer0_replay`` on collection (``ModuleNotFoundError``).

Layer-0/1 corpus replay ratchets live in ``jac-py/jacpython/layer0_replay_p3_gate.jac``
(``jac run`` via ``tools/p3_object_core/replay_gate.py``); this file validates manifest
shape and that P3.1c Objects/ slots stay ``not_staged``.
"""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST_PATH: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p3_object_core", "manifest.json"
     );


def _load_json(path: str) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}


test "P3 manifest: Layer-0 baseline entries present" {
    manifest = _load_json(MANIFEST_PATH);
    entries = manifest["layer0_files"] as list;
    assert len(entries) == 6;
    for spec in entries {
        baseline = spec["baseline"] as dict;
        assert (baseline["failed"] as int) == 0;
        assert (baseline["errored"] as int) == 0;
        assert (baseline["passed"] as int) > 0;
    }
}


test "P3 manifest: Layer-1 entries gated with honest skip counts (P3.1b)" {
    manifest = _load_json(MANIFEST_PATH);
    entries = manifest["layer1_files"] as list;
    assert len(entries) == 4;
    expected_stems = ["test_set", "test_generators", "test_list", "test_tuple"];
    seen: list[str] = [];
    for spec in entries {
        stem = spec["stem"] as str;
        seen.append(stem);
        assert (spec["status"] as str) == "gated";
        assert (spec["gate"] as str) == "P3.1b";
        baseline = spec["baseline"] as dict;
        assert (baseline["failed"] as int) >= 0;
        assert (baseline["errored"] as int) == 0;
        assert (baseline["passed"] as int) > 0;
        assert (baseline["skipped"] as int) >= 0;
    }
    for stem in expected_stems {
        assert stem in seen;
    }
}


test "P3 manifest: c2jac Objects wave not staged yet (P3.1c)" {
    manifest = _load_json(MANIFEST_PATH);
    wave = manifest["c2jac_objects_wave"] as list;
    assert len(wave) >= 1;
    for spec in wave {
        assert (spec["status"] as str) == "not_staged";
        lift = os.path.join(REPO_ROOT, spec["lift_output"] as str);
        assert not os.path.isfile(lift);
    }
}
