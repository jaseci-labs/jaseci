"""Destroy must reclaim what deploy created, and only that (#7968)."""
import unittest.mock;
import from types { SimpleNamespace }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes { target as target_mod }
import from jaclang.scale.deploy.target.kubernetes.utils { kubernetes_utils as utils }

glob APP: str = "test01",
     NS: str = "jb-test-ns";


def _pvc_list(names: list) -> object {
    items = [];
    for name in names {
        items.append(SimpleNamespace(metadata=SimpleNamespace(name=name)));
    }
    return SimpleNamespace(items=items);
}


"""Run destroy against fake clients and return the mocks plus the call order."""
def _run_destroy(owned: bool, pvcs: list) -> tuple {
    order: list = [];
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    core_v1.list_namespaced_persistent_volume_claim.return_value = _pvc_list(pvcs);

    monitoring = unittest.mock.MagicMock();

    def _note_monitoring(*args: any, **kwargs: any) {
        order.append("monitoring");
    }

    def _note_namespace(namespace: str) {
        order.append("namespace");
    }

    monitoring.destroy.side_effect = _note_monitoring;
    fake_client = SimpleNamespace(
        AppsV1Api=lambda { apps_v1; },
        CoreV1Api=lambda { core_v1; },
        PolicyV1Api=lambda { unittest.mock.MagicMock(); },
        NetworkingV1Api=lambda { unittest.mock.MagicMock(); },
        RbacAuthorizationV1Api=lambda { unittest.mock.MagicMock(); }
    );

    with unittest.mock.patch.multiple(
        target_mod,
        client=fake_client,
        namespace_is_owned=unittest.mock.MagicMock(return_value=owned),
        delete_namespace=_note_namespace,
        MonitoringDeployer=unittest.mock.MagicMock(return_value=monitoring)
    ) {
        with unittest.mock.patch.multiple(
            target_mod.KubernetesTarget,
            _load_cluster_config=unittest.mock.MagicMock(return_value=None),
            _wait_for_namespace_deletion=unittest.mock.MagicMock(return_value=True)
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
    return (apps_v1, core_v1, order);
}


test "a namespace jac-scale created is reclaimed whole" {
    (apps_v1, core_v1, order) = _run_destroy(True, []);

    assert "namespace" in order , (
        "destroy left the namespace Active, so the postgres StatefulSet, its "
        "PVCs and every unlabelled companion keep running and billing"
    );
    assert order.index("monitoring") < order.index("namespace") , (
        "monitoring owns cluster-scoped ClusterRoles that deleting the "
        "namespace does not collect, so they must go first"
    );
}


test "an adopted namespace keeps its namespace but loses the app" {
    pvcs = [f"{APP}-bundles", f"{APP}-postgres-data-{APP}-postgres-0", "foreign-pvc"];
    (apps_v1, core_v1, order) = _run_destroy(False, pvcs);

    assert "namespace" not in order , (
        "destroy deleted a namespace jac-scale did not create, taking every "
        "foreign workload in it"
    );
    assert apps_v1.delete_namespaced_stateful_set.called , (
        "the postgres StatefulSet outlived destroy in a shared namespace"
    );
    deleted = [
        call.args[0]
        for call in core_v1.delete_namespaced_persistent_volume_claim.call_args_list
    ];
    assert sorted(deleted) == sorted(pvcs[:2]) , (
        f"destroy deleted PVCs {deleted}; it must reclaim the app's two and "
        "leave foreign-pvc alone"
    );
}


test "ownership is only claimed for a namespace jac-scale created" {
    owned_labels = {utils.NAMESPACE_OWNER_LABEL: utils.NAMESPACE_OWNER_VALUE};
    cases = [({"kubernetes.io/metadata.name": NS}, False), (owned_labels, True)];

    for (labels, expected) in cases {
        core_v1 = unittest.mock.MagicMock();
        core_v1.read_namespace.return_value = SimpleNamespace(
            metadata=SimpleNamespace(labels=labels)
        );
        assert utils.namespace_is_owned(core_v1, NS) == expected , (
            f"namespace ownership read wrong for labels {labels}"
        );
    }
}


test "the default namespace is never treated as owned" {
    core_v1 = unittest.mock.MagicMock();

    assert not utils.namespace_is_owned(core_v1, "default") , (
        "treating 'default' as owned would delete the cluster's default namespace"
    );
    assert not core_v1.read_namespace.called , (
        "'default' must be refused without a cluster read"
    );
}
