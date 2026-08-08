"""A deploy's client bundle is built once, on the host, and shipped to the
gateway pod. A failed build must fail the deploy right there, with the real
build error - not ship a broken bundle and leave the gateway pod to retry the
build at boot, where the failure surfaces minutes later as crash-loop noise
that reads like a client-build problem regardless of the real cause.

These drive the real ManifestBuilder against real project folders (the broken
build runs the actual `jac build` subprocess); no mocks."""

import os;
import shutil;
import tempfile;
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }


def _builder(project_dir: str) -> ManifestBuilder {
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="landing", namespace="jb-landing"),
        microservices_config={"client": {"entry": "main.jac"}}
    );
    mb.project_dir = project_dir;
    return mb;
}


def _project(entry_source: str) -> str {
    tmp = tempfile.mkdtemp(prefix="client-fail-fast-");
    with open(os.path.join(tmp, "jac.toml"), "w", encoding="utf-8") as f {
        f.write('[project]\nname = "landing"\nentry-point = "main.jac"\n');
    }
    with open(os.path.join(tmp, "main.jac"), "w", encoding="utf-8") as f {
        f.write(entry_source);
    }
    return tmp;
}


test "a failing client build aborts the deploy with the build error" {
    project_dir = _project("with entry { this does not parse ((( }\n");
    raised = None;
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
    } except Exception as e {
        raised = e;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert raised is not None , (
        "a failed client build must abort the deploy, not fall through to a "
        "pod-boot rebuild"
    );
    assert "client" in str(raised).lower() , f"error names no cause: {raised}";
}


test "the gateway pod command carries no client rebuild fallback" {
    project_dir = _project("with entry {}\n");
    try {
        entrypoint = _builder(project_dir)._pod_entrypoint();
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    args = "".join(entrypoint.get("args", []));
    assert "exec jac scale gateway" in args;
    assert "jac build" not in args , (
        f"the pod still rebuilds the client at boot: {args}"
    );
    assert "building client bundle" not in args;
}


test "an app without a client entry skips the build untouched" {
    project_dir = _project("with entry {}\n");
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="api", namespace="jb-api"),
        microservices_config={"client": {"entry": False}}
    );
    mb.project_dir = project_dir;
    try {
        mb._build_client_bundle(project_dir);
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}
