"""`jac scale destroy` used to stop after the label sweep: it deleted the fleet
and the observability stack, then returned, leaving the bundle PVC, the app
secrets, the provisioned postgres and the namespace itself behind - and it
accepted `--component` only to ignore it, so asking for one component tore down
every workload instead. The teardown is now an ordered, fault-isolated run of
phases owned by the base target, with the label sweep contributed by the
fleet-aware subclass through `_destroy_application`.

These drive a real KubernetesTarget against a hand-rolled fake cluster: each API
group is an object that records the calls it receives and otherwise answers like
an empty cluster (reads 404, lists come back empty). The autoscaler arrives
through `AutoscalerFactory.register`, the same seam plugins use, and the only
thing the target itself is asked to substitute is `_api_clients` - the method
whose whole job is handing back a connection. No cluster, no mocks."""

import from types { SimpleNamespace }
import from jaclang.scale._optdeps.kubernetes { ApiException }
import from jaclang.scale.deploy.autoscale.autoscaler { Autoscaler }
import from jaclang.scale.deploy.autoscale.factory { AutoscalerFactory }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target { K8sApis }
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.injector.pvc_injector { bundle_pvc_name }


def _api_error(status: int) -> ApiException {
    err = ApiException(status=status);
    err.status = status;
    return err;
}


obj FakeCall {
    has api: any,
        method: str;

    def __call__(*args: any, **kwargs: any) -> any {
        return self.api.invoke(self.method, args, kwargs);
    }
}


obj FakeApi {
    has group: str,
        log: list,
        answers: dict[str, any] = {};

    def __getattr__(method: str) -> any {
        if method.startswith("__") {
            raise AttributeError(method);
        }
        return FakeCall(api=self, method=method);
    }

    def invoke(method: str, args: tuple, kwargs: dict) -> any {
        self.log.append(
            SimpleNamespace(name=f"{self.group}.{method}", args=args, kwargs=kwargs)
        );
        if method in self.answers {
            answer = self.answers[method];
            if isinstance(answer, Exception) {
                raise answer;
            }
            return answer;
        }
        if method.startswith("read_") {
            raise _api_error(404);
        }
        if method.startswith("list_") {
            return SimpleNamespace(items=[]);
        }
        return None;
    }
}


obj FakeCluster {
    has log: list = [],
        apps: any = None,
        core: any = None,
        policy: any = None,
        networking: any = None,
        rbac: any = None,
        custom: any = None;

    def postinit {
        for group in ["apps", "core", "policy", "networking", "rbac", "custom"] {
            setattr(self, group, FakeApi(group=group, log=self.log));
        }
    }

    def apis -> K8sApis {
        return K8sApis(
            apps=self.apps,
            core=self.core,
            policy=self.policy,
            networking=self.networking,
            rbac=self.rbac,
            custom=self.custom
        );
    }
}


glob AUTOSCALER_CALLS: list = [];


obj RecordingAutoscaler(Autoscaler) {
    def destroy(autoscaler_name: str, namespace: str) {
        AUTOSCALER_CALLS.append(f"destroy:{autoscaler_name}");
    }

    def destroy_collection(namespace: str, label_selector: str) {
        AUTOSCALER_CALLS.append(f"destroy_collection:{label_selector}");
    }

    def resource_name_for(target: str) -> str {
        return f"{target}-hpa";
    }
}


def _recording_autoscaler(config: dict[str, any], logger: any) -> Autoscaler {
    return RecordingAutoscaler();
}


with entry {
    AutoscalerFactory.register("recording", _recording_autoscaler);
}


# The one substitution: `_api_clients` exists to hand back a cluster connection,
# so replacing it swaps the cluster and nothing else about the teardown.
obj FakeClusterTarget(KubernetesTarget) {
    has cluster: any = None;

    def _api_clients -> K8sApis {
        return self.cluster.apis();
    }
}


def _destroy(cluster: FakeCluster, component: str = "", namespace: str = "jac-shop") {
    AUTOSCALER_CALLS.clear();
    FakeClusterTarget(
        config=KubernetesConfig(
            app_name="shop", namespace=namespace, autoscaler_engine="recording"
        ),
        cluster=cluster
    ).destroy(
        "shop", component
    );
}


def _names(cluster: FakeCluster) -> list[str] {
    return [call.name for call in cluster.log];
}


def _first(cluster: FakeCluster, name: str) -> any {
    for call in cluster.log {
        if call.name == name {
            return call;
        }
    }
    return None;
}


test "destroy completes the teardown the fleet sweep leaves behind" {
    cluster = FakeCluster();

    _destroy(cluster);

    names = _names(cluster);
    assert "apps.delete_collection_namespaced_deployment" in names , (
        f"the fleet was never swept: {names}"
    );
    assert "apps.delete_namespaced_stateful_set" in names , (
        f"the provisioned postgres survived destroy: {names}"
    );
    assert "core.delete_namespaced_secret" in names , (
        f"the app secrets survived destroy: {names}"
    );
    assert "core.list_namespaced_persistent_volume_claim" in names , (
        f"the volume sweep never ran: {names}"
    );
    assert "core.delete_namespace" in names , (f"the namespace leaked: {names}");
    assert _first(cluster, "core.delete_namespace").kwargs["name"] == "jac-shop";
}


test "the fleet is deleted before the bundle PVC it pins" {
    cluster = FakeCluster();

    _destroy(cluster);

    names = _names(cluster);
    fleet = names.index("apps.delete_collection_namespaced_deployment");
    pvc = names.index("core.delete_namespaced_persistent_volume_claim");
    assert fleet < pvc , (
        "the bundle PVC was deleted before the pods holding its finalizer, "
        f"which is what wedges teardown: {names}"
    );
    assert _first(cluster, "core.delete_namespaced_persistent_volume_claim").args[0]
        == bundle_pvc_name("shop");
}


test "the sweep selects exactly the resources jac-scale manages" {
    cluster = FakeCluster();

    _destroy(cluster);

    workloads = _first(cluster, "apps.delete_collection_namespaced_deployment");
    assert workloads.kwargs["label_selector"]
        == "managed=jac-scale,jac-scale.role in (microservice,gateway)" , (
        f"fleet selector drifted: {workloads.kwargs}"
    );
    assert workloads.kwargs["namespace"] == "jac-shop";
    source = _first(cluster, "core.delete_collection_namespaced_config_map");
    assert source.kwargs["label_selector"]
        == "managed=jac-scale,jac-scale.role=source" , (
        f"source configmap selector drifted: {source.kwargs}"
    );
    assert "destroy_collection:managed=jac-scale" in AUTOSCALER_CALLS , (
        f"the autoscalers were not swept: {AUTOSCALER_CALLS}"
    );
}


test "a component destroy touches only that component" {
    cluster = FakeCluster();

    _destroy(cluster, component="database");

    names = _names(cluster);
    assert "apps.delete_namespaced_stateful_set" in names , (
        f"the requested component was not destroyed: {names}"
    );
    assert "apps.delete_collection_namespaced_deployment" not in names , (
        f"a --component destroy tore down the whole fleet: {names}"
    );
    assert "core.delete_namespace" not in names , (
        f"a --component destroy deleted the namespace: {names}"
    );
}


test "a failing phase does not strand the namespace behind it" {
    cluster = FakeCluster();
    cluster.apps.answers["delete_namespaced_stateful_set"] = _api_error(403);

    _destroy(cluster);

    names = _names(cluster);
    assert "core.list_namespaced_persistent_volume_claim" in names , (
        f"a failed phase skipped the phase behind it: {names}"
    );
    assert "core.delete_namespace" in names , (
        f"a failed phase stranded the namespace: {names}"
    );
}


test "a forbidden ClusterRole delete never fails the destroy" {
    cluster = FakeCluster();
    cluster.rbac.answers["delete_cluster_role"] = _api_error(403);

    _destroy(cluster);

    assert "core.delete_namespace" in _names(cluster) , (
        "observability RBAC the caller may not own must stay non-fatal: "
        f"{_names(cluster)}"
    );
}


test "a failed phase is fatal once the namespace survives too" {
    cluster = FakeCluster();
    cluster.apps.answers["delete_namespaced_stateful_set"] = _api_error(403);
    cluster.core.answers["delete_namespace"] = _api_error(403);

    raised = "";
    try {
        _destroy(cluster);
    } except Exception as e {
        raised = str(e);
    }

    assert "databases" in raised , f"the failing phase went unreported: {raised}";
    assert "jac-shop" in raised , f"the surviving namespace went unreported: {raised}";
}
