"""The mock ratchet: the files that still import unittest.mock, and no more of them.

TESTING.md 2.2 forbids mocks in the scale suites. Removing the existing ones
is phase 3 of #8896; until then this list is the debt, exact in both
directions. A file not listed here that starts importing `unittest.mock` or
`MagicMock` fails the suite: write the test against a real collaborator, or
argue the entry into this list in review. A listed file that stops importing
them also fails, so the list is edited down and never quietly stale.
"""

import from pathlib { Path }

glob TESTS_ROOT: Path = Path(__file__).parents[1],
     SELF: str = str(Path(__file__).relative_to(TESTS_ROOT)),
     ALLOWED: set[str] = {
         "data/test_auth_cutover.jac",
         "data/test_firebase_env.jac",
         "data/test_gcs_storage.jac",
         "data/test_identity_fail_loud.jac",
         "data/test_s3_storage.jac",
         "deploy/http_activation_test_support.jac",
         "deploy/test_cluster_provider.jac",
         "deploy/test_database_intent.jac",
         "deploy/test_deploy_banner.jac",
         "deploy/test_deploy_k8s.jac",
         "deploy/test_deployer.jac",
         "deploy/test_destroy_reclaim.jac",
         "deploy/test_dry_run_purity.jac",
         "deploy/test_factories.jac",
         "deploy/test_http_activation_config.jac",
         "deploy/test_http_activation_microservices.jac",
         "deploy/test_ingress_deployer.jac",
         "deploy/test_ingress_tls_preservation.jac",
         "deploy/test_k8s_utils.jac",
         "deploy/test_memory_trigger_guard.jac",
         "deploy/test_pod_env.jac",
         "deploy/test_superseded_deployment_reap.jac",
         "deploy/test_version_pin.jac",
         "microservices/test_binary_injector.jac",
         "microservices/test_drain.jac",
         "microservices/test_fleet_rollout.jac",
         "microservices/test_plan.jac",
         "microservices/test_stop_signal_scope.jac",
         "misc/test_k8s_ops.jac",
         "misc/test_metrics.jac",
         "misc/test_optional_deps.jac",
         "misc/test_prometheus_client.jac",
         "misc/test_shared_store_failure.jac",
         "server/test_firebase_auth_sso.jac",
         "server/test_sso.jac"
     };


def _imports_mock(path: Path) -> bool {
    text = path.read_text(encoding="utf-8");
    return "unittest.mock" in text or "MagicMock" in text;
}


def _mock_importers -> set[str] {
    found: set[str] = set();
    for path in sorted(TESTS_ROOT.rglob("*.jac")) {
        rel = str(path.relative_to(TESTS_ROOT));
        if rel == SELF or rel.startswith("fixtures/") {
            continue;
        }
        if _imports_mock(path) {
            found.add(rel);
        }
    }
    return found;
}


test "no scale test file outside the allowlist imports unittest.mock" {
    new_importers = sorted(_mock_importers() - ALLOWED);
    assert not new_importers , (
        "these files import unittest.mock or MagicMock and are not on the "
        f"allowlist in {SELF}: {new_importers}. TESTING.md 2.2: stub a boundary "
        "with something real (an in-process server, a temporary Postgres, a "
        "local cluster, a fixture app), not a mock. If this file genuinely "
        "must mock, add it to ALLOWED in review with the reason in the PR."
    );
}


test "every allowlisted file still imports unittest.mock, so the list shrinks with the debt" {
    stale = sorted(ALLOWED - _mock_importers());
    assert not stale , (
        f"these ALLOWED entries no longer import unittest.mock: {stale}. "
        f"Remove them from the list in {SELF}; the ratchet only turns one way."
    );
}
