"""Partial Lib/test-style checks for P2 modules with stdlib algorithm mirrors.

Validates bisect/heapq/platform behavior on host CPython. Lifted ``Modules/*.c``
ports remain oracle-gated separately in ``test_p2_module_oracles.jac``.
"""

import shutil;
import subprocess;
import sys;
import from .libtest_snippets { LIBTEST_SNIPPETS, LibtestSnippet }


def host_python() -> str {
    for name in ["python3.14", "python3", "python"] {
        found = shutil.which(name);
        if found {
            return found;
        }
    }
    return sys.executable;
}


def run_host_case(host_case: LibtestSnippet) -> tuple[bool, str, str] {
    proc = subprocess.run(
        [host_python(), "-c", host_case.code],
        capture_output=True,
        text=True,
        timeout=15.0
    );
    stdout = (proc.stdout or "").strip();
    stderr = (proc.stderr or "").strip();
    if proc.returncode != 0 {
        return (False, stdout, stderr or f"exit {proc.returncode}");
    }
    if stdout != host_case.expect_stdout {
        return (False, stdout, f"expected stdout {host_case.expect_stdout!r}, got {stdout!r}");
    }
    return (True, stdout, "");
}


def assert_host_matches_cpython(host_case: LibtestSnippet) -> None {
    (ok, stdout, detail) = run_host_case(host_case);
    assert ok , f"{host_case.module_stem}/{host_case.name}: {detail or stdout}";
}


test "P2 libtest partial: bisect precomputed cases match host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "bisect_precomputed" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: bisect insort matches host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "bisect_insort" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: heapq heappush/heappop matches host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "heapq_push_pop" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: heapq heapify matches host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "heapq_heapify" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}


test "P2 libtest partial: platform basics match host CPython" {
    for host_case in LIBTEST_SNIPPETS {
        if host_case.name != "platform_basic" {
            continue;
        }
        assert_host_matches_cpython(host_case);
    }
}
