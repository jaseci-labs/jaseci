"""Deployment intent, not the deployer's ambient environment, picks the deployed app's database."""

import os;
import unittest.mock;

import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTargetBase
}
import from jaclang.scale._optdeps.kubernetes { ApiException }

glob PLATFORM_DB_URL = "postgresql://platform@platform-postgres-service:5432/platform";


# Kubernetes API doubles where every read is a 404, so every create path is taken.
def _mock_apis -> dict {
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    apps_v1.read_namespaced_stateful_set.side_effect = ApiException(status=404);
    core_v1.read_namespaced_secret.side_effect = ApiException(status=404);
    core_v1.read_namespaced_service.side_effect = ApiException(status=404);
    core_v1.read_namespaced_service_account.side_effect = ApiException(status=404);
    core_v1.read_namespaced_persistent_volume_claim.side_effect = ApiException(
        status=404
    );
    return {"apps_v1": apps_v1, "core_v1": core_v1};
}


# Run the database half of a deploy against API doubles and report what it did.
def _run_deploy(cfg: KubernetesConfig, app_name: str) -> dict {
    target = KubernetesTargetBase(config=cfg);
    apis = _mock_apis();
    target._deploy_databases(app_name, cfg.namespace, apis["apps_v1"], apis["core_v1"]);
    apis["env_list"] = list(target.env_list);
    return apis;
}


# Point the deploying process at a database, the way a platform pod is pointed at one.
def _set_ambient_db_url(url: (str | None)) -> (str | None) {
    prior = os.environ.get("JAC_DB_URL");
    if url is None {
        os.environ.pop("JAC_DB_URL", None);
    } else {
        os.environ["JAC_DB_URL"] = url;
    }
    reset_scale_config();
    return prior;
}


test "ambient JAC_DB_URL does not decide the deployed app's database" {
    # A platform service deploying user apps in-process has JAC_DB_URL set to its
    # own fleet database. The app it deploys must still get a database of its own.
    prior = _set_ambient_db_url(PLATFORM_DB_URL);
    try {
        cfg = KubernetesConfig(app_name="tenant-app", namespace="tenant-a");
        apis = _run_deploy(cfg, "tenant-app");

        env_list = apis["env_list"];
        assert len(env_list) == 1 , f"expected one database env var, got {env_list}";
        entry = env_list[0];
        assert entry["name"] == "JAC_DB_URL";
        assert "valueFrom" in entry , f"the deployed app was handed the deployer's own database url verbatim: {entry}";
        assert entry.get("value") != PLATFORM_DB_URL;

        assert apis["apps_v1"].create_namespaced_stateful_set.call_count == 1 , "no per-app postgres StatefulSet was provisioned";
        assert apis["core_v1"].create_namespaced_secret.call_count == 1 , "no per-app postgres Secret was provisioned";
        assert apis["core_v1"].create_namespaced_service.call_count == 1 , "no per-app postgres Service was provisioned";
        assert apis["core_v1"].create_namespaced_service_account.call_count == 1 , "no per-app postgres ServiceAccount was provisioned";
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "the runtime path still honours ambient JAC_DB_URL for this process" {
    # JAC_DB_URL keeps meaning 'the database THIS PROCESS connects to'.
    prior = _set_ambient_db_url(PLATFORM_DB_URL);
    try {
        runtime = get_scale_config().get_database_config();
        assert runtime.get("url") == PLATFORM_DB_URL;
    } finally {
        _set_ambient_db_url(prior);
    }
}
