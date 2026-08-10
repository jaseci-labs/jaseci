import os;
import tempfile;
import unittest.mock;
import from pathlib { Path }
import from types { SimpleNamespace }

import from jaclang.scale.config.config_loader { JacScaleConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTargetBase
}
import from jaclang.scale.deploy.target.kubernetes.database_provisioner {
    DatabaseProvisioner
}
import from jaclang.scale.deploy.target.kubernetes { database_provisioner as dp_module }
import from jaclang.scale.deploy.database { kubernetes_postgres as pg_provider_module }
import from jaclang.scale.persistence.pg { scale_db_url }
import from jaclang.scale._optdeps.kubernetes { ApiException }


glob PROJECT_HEADER: str = (
         '[project]\nname = "dbapp"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n'
     );


def _k8s_config_from_toml(toml_text: str) -> dict[str, any] {
    tmp = tempfile.mkdtemp();
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(toml_text);
    }
    return JacScaleConfig(project_dir=Path(tmp)).get_kubernetes_config();
}


test "default config provisions postgres" {
    os.environ.pop("JAC_DB_URL", None);
    cfg = _k8s_config_from_toml(PROJECT_HEADER);
    assert cfg["postgres_enabled"] is True;
    assert cfg["database_external_url"] == "";
}


test "database enabled=false turns postgres off even when a url is set" {
    os.environ.pop("JAC_DB_URL", None);
    cfg = _k8s_config_from_toml(
        PROJECT_HEADER
            + '[scale.database]\nenabled = false\nurl = "postgresql://h:5432/app"\n'
    );
    assert cfg["postgres_enabled"] is False;
    assert cfg["database_external_url"] == "";
}


test "a database url switches the deploy to external mode" {
    os.environ.pop("JAC_DB_URL", None);
    cfg = _k8s_config_from_toml(
        PROJECT_HEADER + '[scale.database]\nurl = "postgresql://ext.host:5432/app"\n'
    );
    assert cfg["postgres_enabled"] is False;
    assert cfg["database_external_url"] == "postgresql://ext.host:5432/app";
}


test "the JAC_DB_URL env var also switches to external mode" {
    os.environ["JAC_DB_URL"] = "postgresql://env.host:5432/app";
    try {
        cfg = _k8s_config_from_toml(PROJECT_HEADER);
        assert cfg["postgres_enabled"] is False;
        assert cfg["database_external_url"] == "postgresql://env.host:5432/app";
    } finally {
        del os.environ["JAC_DB_URL"];
    }
}


test "legacy kubernetes postgres_enabled=false still disables provisioning" {
    os.environ.pop("JAC_DB_URL", None);
    cfg = _k8s_config_from_toml(
        PROJECT_HEADER + '[scale.kubernetes]\npostgres_enabled = false\n'
    );
    assert cfg["postgres_enabled"] is False;
    assert cfg["database_external_url"] == "";
}


def _target(postgres_enabled: bool, external_url: str) -> KubernetesTargetBase {
    return KubernetesTargetBase(
        config=KubernetesConfig(
            app_name="dbapp",
            namespace="db-ns",
            postgres_enabled=postgres_enabled,
            database_external_url=external_url
        )
    );
}


test "external mode ships the url via a secret, provisions nothing" {
    target = _target(False, "postgresql://user:pw@ext.host:5432/app");
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    target._deploy_databases("dbapp", "db-ns", apps_v1, core_v1);

    core_v1.create_namespaced_secret.assert_called_once();
    secret_body = core_v1.create_namespaced_secret.call_args.kwargs["body"];
    assert secret_body["metadata"]["name"] == "dbapp-postgres-secret";
    assert secret_body["stringData"]
        == {"connection-string": "postgresql://user:pw@ext.host:5432/app"};
    assert target.env_list
        == [
            {
                "name": "JAC_DB_URL",
                "valueFrom": {
                    "secretKeyRef": {
                        "name": "dbapp-postgres-secret",
                        "key": "connection-string"
                    }
                }
            }
        ];
    apps_v1.create_namespaced_stateful_set.assert_not_called();
    assert target._get_database_init_containers("dbapp") == [];
}


test "disabled database deploys nothing and removes the stale secret" {
    target = _target(False, "");
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    target._deploy_databases("dbapp", "db-ns", apps_v1, core_v1);

    assert target.env_list == [];
    apps_v1.create_namespaced_stateful_set.assert_not_called();
    core_v1.create_namespaced_secret.assert_not_called();
    core_v1.delete_namespaced_secret.assert_called_once_with(
        name="dbapp-postgres-secret", namespace="db-ns"
    );
    assert target._get_database_init_containers("dbapp") == [];
}


def _not_found(*args: any, **kwargs: any) {
    raise ApiException(status=404);
}


test "a forbidden secret cleanup does not fail a disabled-database deploy" {
    target = _target(False, "");
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    def _forbidden(*args: any, **kwargs: any) {
        raise ApiException(status=403);
    }
    core_v1.delete_namespaced_secret.side_effect = _forbidden;

    target._deploy_databases("dbapp", "db-ns", apps_v1, core_v1);

    assert target.env_list == [];
    apps_v1.create_namespaced_stateful_set.assert_not_called();
}


test "default mode provisions the postgres statefulset and wires its secret" {
    target = _target(True, "");
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    apps_v1.read_namespaced_stateful_set.side_effect = _not_found;
    core_v1.read_namespaced_secret.side_effect = _not_found;
    core_v1.read_namespaced_service.side_effect = _not_found;
    core_v1.read_namespaced_service_account.side_effect = _not_found;
    core_v1.read_namespaced_persistent_volume_claim.side_effect = _not_found;

    fake_cfg = unittest.mock.MagicMock();
    fake_cfg.get_database_config.return_value = {
        "enabled": True,
        "url": None,
        "deploy_mode": "image",
        "postgres_image": "postgres:18",
        "postgres_storage": "2Gi"
    };
    with unittest.mock.patch.object(
        pg_provider_module, "get_scale_config", lambda { fake_cfg; }
    ) {
        target._deploy_databases("dbapp", "db-ns", apps_v1, core_v1);
        init_containers = target._get_database_init_containers("dbapp");
    }

    apps_v1.create_namespaced_stateful_set.assert_called_once();
    core_v1.create_namespaced_secret.assert_called_once();
    assert target.env_list[0]["name"] == "JAC_DB_URL";
    assert target.env_list[0]["valueFrom"]["secretKeyRef"]["key"]
        == "connection-string";
    assert [c["name"] for c in init_containers] == ["wait-for-postgres"];
}


test "provisioner still reconciles the database secret when disabled" {
    mock_target = unittest.mock.MagicMock();
    mock_target.env_list = [];
    mock_target.k8s_config = SimpleNamespace(
        postgres_enabled=False, database_external_url="", namespace="db-ns"
    );
    mock_target._get_database_init_containers.return_value = [];

    with unittest.mock.patch.object(
        dp_module.client, "AppsV1Api", lambda { unittest.mock.MagicMock(); }
    ), unittest.mock.patch.object(
        dp_module.client, "CoreV1Api", lambda { unittest.mock.MagicMock(); }
    ), unittest.mock.patch.object(dp_module, "ensure_namespace_exists") {
        ctx = DatabaseProvisioner(k8s_target=mock_target).provision("dbapp");
    }

    assert ctx.env_list == [];
    assert ctx.init_containers == [];
    mock_target._deploy_databases.assert_called_once();
}


test "switching from external back to provisioned replaces the stale secret" {
    target = _target(True, "");
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    apps_v1.read_namespaced_stateful_set.side_effect = _not_found;
    core_v1.read_namespaced_service.side_effect = _not_found;
    core_v1.read_namespaced_service_account.side_effect = _not_found;
    core_v1.read_namespaced_persistent_volume_claim.side_effect = _not_found;
    core_v1.read_namespaced_secret.return_value = SimpleNamespace(
        data={"connection-string": "b64-old-external-url"}
    );

    fake_cfg = unittest.mock.MagicMock();
    fake_cfg.get_database_config.return_value = {
        "enabled": True,
        "url": None,
        "deploy_mode": "image",
        "postgres_image": "postgres:18",
        "postgres_storage": "2Gi"
    };
    with unittest.mock.patch.object(
        pg_provider_module, "get_scale_config", lambda { fake_cfg; }
    ) {
        target._deploy_databases("dbapp", "db-ns", apps_v1, core_v1);
    }

    core_v1.replace_namespaced_secret.assert_called_once();
    replaced = core_v1.replace_namespaced_secret.call_args.kwargs["body"];
    assert "username" in replaced["stringData"];
    core_v1.create_namespaced_secret.assert_not_called();
}


test "a provisioned-shaped secret is left alone on redeploy" {
    target = _target(True, "");
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespaced_persistent_volume_claim.side_effect = _not_found;
    core_v1.read_namespaced_secret.return_value = SimpleNamespace(
        data={"username": "amFj", "password": "b2xk", "connection-string": "b64-url"}
    );

    fake_cfg = unittest.mock.MagicMock();
    fake_cfg.get_database_config.return_value = {
        "enabled": True,
        "url": None,
        "deploy_mode": "image",
        "postgres_image": "postgres:18",
        "postgres_storage": "2Gi"
    };
    with unittest.mock.patch.object(
        pg_provider_module, "get_scale_config", lambda { fake_cfg; }
    ) {
        target._deploy_databases("dbapp", "db-ns", apps_v1, core_v1);
    }

    core_v1.replace_namespaced_secret.assert_not_called();
    core_v1.create_namespaced_secret.assert_not_called();
}


test "scale_db_url honors the enabled switch at runtime" {
    fake_cfg = unittest.mock.MagicMock();
    fake_cfg.get_database_config.return_value = {"enabled": False, "url": None};
    os.environ["JAC_DB_URL"] = "postgresql://env.host:5432/app";
    try {
        with unittest.mock.patch(
            "jaclang.scale.config.config_loader.get_scale_config", return_value=fake_cfg
        ) {
            assert scale_db_url() is None;
            fake_cfg.get_database_config.return_value = {"enabled": True, "url": None};
            assert scale_db_url() == "postgresql://env.host:5432/app";
        }
    } finally {
        del os.environ["JAC_DB_URL"];
    }
}
