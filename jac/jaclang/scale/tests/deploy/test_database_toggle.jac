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
import from jaclang.scale.deploy.database {
    kubernetes_postgres as pg_provider_module
}
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


test "external mode injects JAC_DB_URL and touches no cluster resources" {
    target = _target(False, "postgresql://ext.host:5432/app");
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    target._deploy_databases("dbapp", "db-ns", apps_v1, core_v1);

    assert target.env_list == [
        {"name": "JAC_DB_URL", "value": "postgresql://ext.host:5432/app"}
    ];
    apps_v1.create_namespaced_stateful_set.assert_not_called();
    core_v1.create_namespaced_secret.assert_not_called();
    assert target._get_database_init_containers("dbapp") == [];
}


test "disabled database deploys nothing and injects nothing" {
    target = _target(False, "");
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    target._deploy_databases("dbapp", "db-ns", apps_v1, core_v1);

    assert target.env_list == [];
    apps_v1.create_namespaced_stateful_set.assert_not_called();
    core_v1.create_namespaced_secret.assert_not_called();
    assert target._get_database_init_containers("dbapp") == [];
}


def _not_found(*args: any, **kwargs: any) -> None {
    raise ApiException(status=404);
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


test "provisioner skips the cluster entirely when the database is off" {
    mock_target = unittest.mock.MagicMock();
    mock_target.env_list = [];
    mock_target.k8s_config = SimpleNamespace(
        postgres_enabled=False, database_external_url="", namespace="db-ns"
    );

    ctx = DatabaseProvisioner(k8s_target=mock_target).provision("dbapp");

    assert ctx.env_list == [];
    assert ctx.init_containers == [];
    mock_target._load_cluster_config.assert_not_called();
    mock_target._deploy_databases.assert_not_called();
}


test "scale_db_url honors the enabled switch at runtime" {
    fake_cfg = unittest.mock.MagicMock();
    fake_cfg.get_database_config.return_value = {"enabled": False, "url": None};
    os.environ["JAC_DB_URL"] = "postgresql://env.host:5432/app";
    try {
        with unittest.mock.patch(
            "jaclang.scale.config.config_loader.get_scale_config",
            return_value=fake_cfg
        ) {
            assert scale_db_url() is None;
            fake_cfg.get_database_config.return_value = {
                "enabled": True,
                "url": None
            };
            assert scale_db_url() == "postgresql://env.host:5432/app";
        }
    } finally {
        del os.environ["JAC_DB_URL"];
    }
}
