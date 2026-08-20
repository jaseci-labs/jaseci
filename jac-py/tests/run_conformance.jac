"""T6 P2 conformance harness skeleton (PLAN.md §6.6).

Runs embedded pure-Python Lib/test-style snippets on the host CPython interpreter,
records pass/fail, and writes ``conformance_manifest.json``. Lifted C module ports
without a stdlib equivalent are documented as oracle- or deferred-gated only.

Oracle differential tests live in ``test_p2_module_oracles.jac`` and
``test_rotatingtree_oracle.jac``; this harness covers the libtest leg and the
manifest ratchet.
"""

import json;
import os;
import shutil;
import subprocess;
import sys;
import from tests.support { JAC_ROOT }
import from .libtest_snippets { LIBTEST_SNIPPETS, LibtestSnippet }


glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MANIFEST_PATH: str = os.path.join(
         REPO_ROOT, "jac-py", "tests", "conformance_manifest.json"
     ),
     P2_CORPUS_MANIFEST: str = os.path.join(
         REPO_ROOT, "jac-py", "tools", "p2_corpus", "manifest.json"
     ),
     P2_MODULE_COUNT: int = 10;


obj P2ModuleGate {
    has stem: str;
    has gate_type: str;
    has status: str;
    has oracle_tests: list[str];
    has libtest_snippets: list[str];
    has notes: str;
}


glob P2_MODULE_GATES: list[P2ModuleGate] = [
    P2ModuleGate(
        stem="mysnprintf",
        gate_type="oracle",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=[],
        notes="No Python stdlib equivalent; cc vs staged jac oracle (PyOS_vsnprintf)."
    ),
    P2ModuleGate(
        stem="pystrcmp",
        gate_type="oracle",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=[],
        notes="No Python stdlib equivalent; cc vs lifted jac oracle."
    ),
    P2ModuleGate(
        stem="rotatingtree",
        gate_type="oracle",
        status="gated",
        oracle_tests=["test_rotatingtree_oracle.jac"],
        libtest_snippets=[],
        notes="No Python stdlib equivalent; cc vs lifted jac oracle."
    ),
    P2ModuleGate(
        stem="getbuildinfo",
        gate_type="oracle",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=[],
        notes="Build-info internals; cc vs staged jac oracle (hand-edited empty-string semantics)."
    ),
    P2ModuleGate(
        stem="_bisectmodule",
        gate_type="libtest",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=["bisect_precomputed", "bisect_insort"],
        notes="Algorithm parity via bisect stdlib; C port oracle-gated separately."
    ),
    P2ModuleGate(
        stem="_heapqmodule",
        gate_type="libtest",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=["heapq_push_pop", "heapq_heapify"],
        notes="Algorithm parity via heapq stdlib; C port oracle-gated separately."
    ),
    P2ModuleGate(
        stem="getplatform",
        gate_type="libtest",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=["platform_basic"],
        notes="Partial Lib/test via platform module; Py_GetPlatform oracle-gated separately."
    ),
    P2ModuleGate(
        stem="getcompiler",
        gate_type="oracle",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=[],
        notes="No Python stdlib equivalent; cc vs lifted jac oracle."
    ),
    P2ModuleGate(
        stem="getcopyright",
        gate_type="oracle",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=[],
        notes="No Python stdlib equivalent; cc vs lifted jac oracle."
    ),
    P2ModuleGate(
        stem="pyfpe",
        gate_type="oracle",
        status="gated",
        oracle_tests=["test_p2_module_oracles.jac"],
        libtest_snippets=[],
        notes="Legacy FPE hook; cc vs lifted jac oracle."
    ),
];


def host_python() -> str {
    for name in ["python3.14", "python3", "python"] {
        found = shutil.which(name);
        if found {
            return found;
        }
    }
    return sys.executable;
}


def run_host_snippet(code: str, timeout: float = 15.0) -> tuple[bool, str] {
    proc = subprocess.run(
        [host_python(), "-c", code],
        capture_output=True,
        text=True,
        timeout=timeout
    );
    if proc.returncode != 0 {
        detail = (proc.stderr or proc.stdout or "").strip();
        return (False, detail or f"exit {proc.returncode}");
    }
    return (True, (proc.stdout or "").strip());
}


def _snippet_by_name(name: str) -> LibtestSnippet | None {
    for snip in LIBTEST_SNIPPETS {
        if snip.name == name {
            return snip;
        }
    }
    return None;
}


def run_libtest_snippets() -> dict {
    results: dict = {};
    for gate in P2_MODULE_GATES {
        if gate.gate_type != "libtest" {
            continue;
        }
        passed = 0;
        failed = 0;
        cases: list = [];
        for snip_name in gate.libtest_snippets {
            snip = _snippet_by_name(snip_name);
            assert snip is not None , f"missing libtest snippet {snip_name}";
            (ok, detail) = run_host_snippet(snip.code);
            cases.append(
                {
                    "name": snip.name,
                    "passed": ok,
                    "detail": detail if not ok else "ok",
                }
            );
            if ok {
                passed += 1;
            } else {
                failed += 1;
            }
        }
        results[gate.stem] = {
            "passed": passed,
            "failed": failed,
            "total": passed + failed,
            "cases": cases,
        };
    }
    return results;
}


def build_manifest(libtest_results: dict) -> dict {
    modules: list = [];
    for gate in P2_MODULE_GATES {
        row = {
            "stem": gate.stem,
            "gate_type": gate.gate_type,
            "status": gate.status,
            "oracle_tests": gate.oracle_tests,
            "libtest_snippets": gate.libtest_snippets,
            "notes": gate.notes,
        };
        if gate.stem in libtest_results {
            row["libtest"] = libtest_results[gate.stem];
        }
        modules.append(row);
    }
    return {
        "version": 1,
        "wave": "p2_wave1",
        "description": "P2 proving wave conformance manifest (T6 skeleton)",
        "module_count": P2_MODULE_COUNT,
        "modules": modules,
        "libtest_results": libtest_results,
    };
}


def write_manifest(path: str = MANIFEST_PATH) -> dict {
    libtest_results = run_libtest_snippets();
    manifest = build_manifest(libtest_results);
    with open(path, "w") as f {
        json.dump(manifest, f, indent=2);
        f.write("\n");
    }
    return manifest;
}


def load_manifest(path: str = MANIFEST_PATH) -> dict {
    with open(path) as f {
        return json.load(f);
    }
}


def assert_all_modules_gated(manifest: dict) -> None {
    modules = manifest["modules"] as list;
    assert len(modules) == P2_MODULE_COUNT , len(modules);
    for row in modules {
        entry = row as dict;
        assert entry["status"] == "gated" , entry;
    }
}


def assert_libtest_zero_failures(manifest: dict) -> None {
    libtest_results = manifest["libtest_results"] as dict;
    for (stem, row) in libtest_results.items() {
        detail = row as dict;
        assert (detail["failed"] as int) == 0 , f"{stem}: {detail}";
    }
}


with entry {
    manifest = write_manifest();
    assert_all_modules_gated(manifest);
    assert_libtest_zero_failures(manifest);
    print(f"wrote {MANIFEST_PATH} ({P2_MODULE_COUNT} modules gated)");
}


test "P2 conformance: corpus manifest lists ten modules" {
    corpus = json.load(open(P2_CORPUS_MANIFEST));
    assert len(corpus["files"] as list) == P2_MODULE_COUNT;
}


test "P2 conformance: host libtest snippets pass on CPython" {
    results = run_libtest_snippets();
    for (stem, row) in results.items() {
        detail = row as dict;
        assert (detail["failed"] as int) == 0 , f"{stem}: {detail}";
    }
}


test "P2 conformance: manifest ratchet — all modules gated" {
    manifest = write_manifest();
    assert_all_modules_gated(manifest);
    assert_libtest_zero_failures(manifest);
    on_disk = load_manifest();
    assert_all_modules_gated(on_disk);
    assert_libtest_zero_failures(on_disk);
}
