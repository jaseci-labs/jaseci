"""Destroy must reclaim what deploy created, and only that (#7968)."""
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
    rbac_v1 = unittest.mock.MagicMock();

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
        RbacAuthorizationV1Api=lambda { rbac_v1; }
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
    return (apps_v1, core_v1, rbac_v1, order);
}


test "a namespace jac-scale created is reclaimed whole" {
    (apps_v1, core_v1, rbac_v1, order) = _run_destroy(True, []);

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
    (apps_v1, core_v1, rbac_v1, order) = _run_destroy(False, []);

    assert "namespace" not in order , (
        "destroy deleted a namespace jac-scale did not create, taking every "
        "foreign workload in it"
    );
    assert apps_v1.delete_namespaced_stateful_set.called , (
        "the postgres StatefulSet outlived destroy in a shared namespace"
    );
}


test "app PVCs are reclaimed by exact name, never by prefix" {
    (apps_v1, core_v1, rbac_v1, order) = _run_destroy(False, []);

    deleted = [
        call.args[0]
        for call in core_v1.delete_namespaced_persistent_volume_claim.call_args_list
    ];
    expected = [f"{APP}-bundles", f"{APP}-postgres-data-{APP}-postgres-0"];
    assert sorted(deleted) == sorted(expected) , (
        f"destroy deleted {deleted}, expected exactly {expected}. Matching on a "
        f"name prefix would also delete a sibling app such as '{APP}-analytics'"
    );
}


test "shared-volume PVCs are reclaimed by their role label" {
    (apps_v1, core_v1, rbac_v1, order) = _run_destroy(False, []);

    selectors = [
        call.kwargs.get("label_selector")
        for call in
            core_v1.delete_collection_namespaced_persistent_volume_claim
                .call_args_list
    ];
    assert "managed=jac-scale,jac-scale.role=shared-volume" in selectors , (
        "a shared volume is named from user config with no app prefix, so "
        "without its role label it survives destroy and keeps billing"
    );
}


test "ops RBAC teardown is scoped to this app" {
    (apps_v1, core_v1, rbac_v1, order) = _run_destroy(False, []);

    for name in ["delete_collection_namespaced_role", "delete_collection_namespaced_role_binding"] {
        for call in getattr(rbac_v1, name).call_args_list {
            selector = call.kwargs.get("label_selector", "");
            assert f"app={APP}" in selector , (
                f"{name} used selector '{selector}', which also deletes a "
                "co-tenant app's ops Role and RoleBinding"
            );
        }
    }
}


test "a namespace is only owned by the app that created it" {
    cases = [
        ({"kubernetes.io/metadata.name": NS}, False),
        ({utils.NAMESPACE_OWNER_LABEL: "other-app"}, False),
        ({utils.NAMESPACE_OWNER_LABEL: APP}, True)
    ];

    for (labels, expected) in cases {
        core_v1 = unittest.mock.MagicMock();
        core_v1.read_namespace.return_value = SimpleNamespace(
            metadata=SimpleNamespace(labels=labels)
        );
        assert utils.namespace_is_owned(core_v1, NS, APP) == expected , (
            f"a namespace labelled {labels} must not be reclaimable by '{APP}': "
            "deleting it would take a co-tenant app's database with it"
        );
    }
}


test "creating a namespace stamps the owning app on it" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespace.side_effect = ApiException(status=404);

    with unittest.mock.patch.object(utils.client, "CoreV1Api", lambda { core_v1; }) {
        utils.ensure_namespace_exists(NS, APP);
    }

    body = core_v1.create_namespace.call_args.kwargs["body"];
    assert body["metadata"]["labels"].get(utils.NAMESPACE_OWNER_LABEL) == APP , (
        "the created namespace carries no owner label, so destroy reads it as "
        "adopted and the #7968 leak returns"
    );
}


test "an adopted namespace is never stamped as owned" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespace.return_value = SimpleNamespace(
        metadata=SimpleNamespace(labels={})
    );

    with unittest.mock.patch.object(utils.client, "CoreV1Api", lambda { core_v1; }) {
        utils.ensure_namespace_exists(NS, APP);
    }

    assert not core_v1.create_namespace.called , "an existing namespace must not be recreated";
    for call in core_v1.patch_namespace.call_args_list {
        patched = call.kwargs["body"]["metadata"]["labels"];
        assert utils.NAMESPACE_OWNER_LABEL not in patched , (
            "patching ownership onto an adopted namespace would let destroy "
            "delete a namespace jac-scale did not create"
        );
    }
}


test "the default namespace is never treated as owned" {
    core_v1 = unittest.mock.MagicMock();

    assert not utils.namespace_is_owned(core_v1, "default", APP) , (
        "treating 'default' as owned would delete the cluster's default namespace"
    );
    assert not core_v1.read_namespace.called , (
        "'default' must be refused without a cluster read"
    );
}
