"""Consolidated staged-vs-lifted drift gates for P2 waves 2-11."""

import json;
import os;
import from tests.support { JAC_ROOT }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     TESTS: str = os.path.join(REPO_ROOT, "jac-py", "tests");


def _wave_number(path: str) -> int {
    name = os.path.basename(path);
    return int(name.split("wave")[1].split(".")[0]);
}


def _manifest_paths() -> list {
    paths: list = [];
    for name in os.listdir(TESTS) {
        if name.startswith("conformance_manifest_wave") and name.endswith(".json") {
            paths.append(os.path.join(TESTS, name));
        }
    }
    for i in range(len(paths)) {
        min_i = i;
        for j in range(i + 1, len(paths)) {
            if _wave_number(paths[j]) < _wave_number(paths[min_i]) {
                min_i = j;
            }
        }
        if min_i != i {
            tmp = paths[i];
            paths[i] = paths[min_i];
            paths[min_i] = tmp;
        }
    }
    return paths;
}


def _load_json(path: str) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}


def _corpus_manifest_path(wave: int) -> str {
    return os.path.join(
        REPO_ROOT, "jac-py", "tools", f"p2_corpus_wave{wave}", "manifest.json"
    );
}


# Expected stems come straight from the wave's corpus lift manifest, so a new
# wave needs no inventory edits here.
def _expected_stems(wave: int) -> list {
    manifest = _load_json(_corpus_manifest_path(wave));
    return sorted([row["stem"] for row in (manifest["files"] as list)]);
}


def _staged_manifest_path(wave: int) -> str {
    return os.path.join(
        REPO_ROOT, "jac-py", "tools", f"p2_staged_manifest_wave{wave}.json"
    );
}


def _check_manifest(wave: int) -> str {
    try {
        manifest = _load_json(_staged_manifest_path(wave));
        modules = manifest["modules"] as list;
        expected = _expected_stems(wave);
        actual = sorted([row["stem"] for row in modules]);
        assert len(modules) == len(expected), len(modules);
        assert actual == expected, actual;
        return "";
    } except Exception as e {
        return f"wave {wave}: staged manifest module check failed: {e}";
    }
}


def _read_text(path: str) -> str {
    with open(path) as f {
        return f.read();
    }
}


def _check_staged_matches(wave: int) -> str {
    try {
        manifest = _load_json(_staged_manifest_path(wave));
        staged_dir = os.path.join(REPO_ROOT, manifest["staged_dir"]);
        lifted_dir = os.path.join(REPO_ROOT, manifest["lifted_dir"]);
        mismatches: list = [];
        for row in (manifest["modules"] as list) {
            stem = row["stem"] as str;
            staging = row["staging"] as str;
            staged_path = os.path.join(staged_dir, f"{stem}.jac");
            lifted_path = os.path.join(lifted_dir, f"{stem}.jac");
            assert os.path.isfile(staged_path), staged_path;
            assert os.path.isfile(lifted_path), lifted_path;
            if staging == "lift" {
                if _read_text(staged_path) != _read_text(lifted_path) {
                    mismatches.append(
                        f"{stem}: staged != lifted (re-lift or copy staged oracle)"
                    );
                }
            } elif staging == "hand" {
                note = row.get("note");
                assert note, f"hand module {stem} needs manifest note";
            } else {
                assert False, f"unknown staging {staging!r} for {stem}";
            }
        }
        assert not mismatches, "\n".join(mismatches);
        return "";
    } except Exception as e {
        return f"wave {wave}: staged/lifted corpus check failed: {e}";
    }
}


test "P2 waves 2-11 staged vs lifted drift gates" {
    failures: list = [];
    paths = _manifest_paths();
    assert len(paths) > 0, "no conformance wave manifests found";
    for path in paths {
        wave = _wave_number(path);
        checks = [_check_manifest(wave), _check_staged_matches(wave)];
        wave_failures = [item for item in checks if item];
        if len(wave_failures) > 0 {
            print(f"wave {wave}: FAIL");
            failures.extend(wave_failures);
        } else {
            print(f"wave {wave}: PASS (2 staged checks)");
        }
    }
    assert not failures, "\n".join(failures);
}
