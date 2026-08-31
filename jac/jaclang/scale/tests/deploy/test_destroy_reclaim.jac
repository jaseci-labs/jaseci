"""Destroy branches a real cluster cannot reach (#7968).

What destroy reclaims and what it spares is decided by an API server, so those
properties are asserted in destroy_reclaim_real_e2e.sh against real objects.
Only the branches that need a cluster to misbehave live here.
"""
import unittest.mock;
import from types { SimpleNamespace }
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes { target as target_mod }
import from jaclang.scale.deploy.target.kubernetes.utils { kubernetes_utils as utils }

glob APP: str = "test01",
     NS: str = "jb-test-ns";


test "the default namespace is never treated as owned" {
    core_v1 = unittest.mock.MagicMock();

    assert not utils.namespace_is_owned(core_v1, "default", APP) , (
        "treating 'default' as owned would delete the cluster's default namespace"
    );
    assert not core_v1.read_namespace.called , (
        "'default' must be refused without a cluster read"
    );
}


test "a namespace with no readable labels is never owned" {
    for labels in [None, {}] {
        core_v1 = unittest.mock.MagicMock();
        core_v1.read_namespace.return_value = SimpleNamespace(
            metadata=SimpleNamespace(labels=labels)
        );
        assert not utils.namespace_is_owned(core_v1, NS, APP) , (
            f"a namespace whose labels read as {labels} was treated as owned, "
            "so destroy would delete a namespace it cannot prove it created"
        );
    }
}


test "an unreachable cluster fails loudly instead of reading as adopted" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespace.side_effect = ApiException(status=503);
    raised = False;

    try {
        utils.namespace_is_owned(core_v1, NS, APP);
    } except ApiException {
        raised = True;
    }

    assert raised , (
        "answering 'not owned' when the cluster is unreachable silently skips "
        "the reclaim and brings the #7968 leak back"
    );
}


test "a missing namespace is not owned" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespace.side_effect = ApiException(status=404);

    assert not utils.namespace_is_owned(core_v1, NS, APP) , (
        "a namespace that is already gone has nothing left to reclaim"
    );
}


test "a failed monitoring teardown keeps the namespace" {
    order: list = [];
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    monitoring = unittest.mock.MagicMock();
    monitoring.destroy.side_effect = RuntimeError("prometheus ClusterRole stuck");

    def _note_namespace(namespace: str) {
        order.append("namespace");
    }

    fake_client = SimpleNamespace(
        AppsV1Api=lambda { unittest.mock.MagicMock(); },
        CoreV1Api=lambda { core_v1; },
        PolicyV1Api=lambda { unittest.mock.MagicMock(); },
        NetworkingV1Api=lambda { unittest.mock.MagicMock(); },
        RbacAuthorizationV1Api=lambda { unittest.mock.MagicMock(); }
    );

    with unittest.mock.patch.multiple(
        target_mod,
        client=fake_client,
        namespace_is_owned=unittest.mock.MagicMock(return_value=True),
        delete_namespace=_note_namespace,
        KEDAAutoscaler=unittest.mock.MagicMock(),
        MonitoringDeployer=unittest.mock.MagicMock(return_value=monitoring)
    ) {
        with unittest.mock.patch.object(
            target_mod.KubernetesTarget,
            "_load_cluster_config",
            unittest.mock.MagicMock(return_value=None)
        ) {
            with unittest.mock.patch.object(
                target_mod.AutoscalerFactory,
                "create",
                return_value=unittest.mock.MagicMock()
            ) {
                target = target_mod.KubernetesTarget(
                    config=KubernetesConfig(app_name=APP, namespace=NS),
                    microservices_config={}
                );
                target.destroy(APP);
            }
        }
    }

    assert "namespace" not in order , (
        "the namespace was deleted after monitoring teardown failed, orphaning "
        "cluster-scoped roles named after a namespace that no longer exists"
    );
}
