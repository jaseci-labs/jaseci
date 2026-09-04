"""IngressDeployer: per-app and shared ingress rendering, and what a redeploy preserves.

Per-app rules render a host-bound rule plus a catch-all so TLS bindings
survive redeploys (#7707); shared controllers stay host-scoped; patch, never
replace, so spec.tls set by enable_tls is kept; cert-manager annotations on a
shared ingress add the tls block and nothing else does.
"""
import unittest.mock;
import from types { SimpleNamespace }
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes { ingress as ingress_module }
import from jaclang.scale.deploy.target.kubernetes.ingress { IngressDeployer }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}

def _make_deployer(domain: str = '', cert_email: str = '') -> IngressDeployer {
    cfg = KubernetesConfig(domain=domain, cert_manager_email=cert_email);
    return IngressDeployer(k8s_config=cfg);
}

def _make_shared_deployer(annotations: dict) -> IngressDeployer {
    cfg = KubernetesConfig(
        domain='app.example.com',
        shared_ingress=True,
        shared_ingress_tls=True,
        shared_ingress_class='jb-custom',
        shared_ingress_annotations=annotations
    );
    return IngressDeployer(k8s_config=cfg);
}

def _call_deploy(deployer: IngressDeployer, networking_v1: any, core_v1: any) {
    deployer._deploy_ingress_resource(
        'myapp', 'test-ns', 'test-ns-myapp-nginx', 8000, False, networking_v1, core_v1
    );
}

test "deploy uses patch not replace for main ingress" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    assert networking_v1.patch_namespaced_ingress.called , "patch_namespaced_ingress must be called on redeployment";
    assert not networking_v1.replace_namespaced_ingress.called , "replace_namespaced_ingress must never be called";
}

test "patch body keeps spec.tls untouched and renders host plus catch-all rules" {
    # spec.tls is map-merged by patch, so omitting it preserves what
    # enable_tls set. Rules are a REPLACED list: omitting the host does
    # not preserve it, it wipes the binding the certificate is served
    # from (#7707). A domain app must therefore re-render the host rule
    # itself, alongside a catch-all for raw load-balancer access.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert 'tls' not in body.get('spec', {}) , "spec.tls must not appear in the patch body";
    rules = body.get('spec', {}).get('rules', []);
    assert len(rules) == 2 , "domain app must render a host rule plus a catch-all";
    assert rules[0].get('host') == 'example.com' , "first rule must bind the domain host";
    assert 'host' not in rules[1] , "second rule must stay a catch-all";
    assert rules[0]['http'] == rules[1]['http'] , "both rules must serve the same paths";
}

test "patch body contains jac-scale-owned annotations" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    ann = body['metadata']['annotations'];
    assert 'nginx.ingress.kubernetes.io/proxy-body-size' in ann , "proxy-body-size annotation must be present";
    assert 'nginx.ingress.kubernetes.io/limit-rps' in ann , "limit-rps annotation must be present";
    assert ann.get('jac-scale/domain') == 'example.com' , "jac-scale/domain annotation must match config";

    assert 'cert-manager.io/issuer' not in ann , "cert-manager.io/issuer must not be set by _deploy_ingress_resource";
    assert 'nginx.ingress.kubernetes.io/ssl-redirect' not in ann , "ssl-redirect must not be set by _deploy_ingress_resource";
    assert 'nginx.ingress.kubernetes.io/force-ssl-redirect' not in ann , "force-ssl-redirect must not be set by _deploy_ingress_resource";
}

test "first deploy creates ingress when patch returns 404" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);

    deployer = _make_deployer();
    _call_deploy(deployer, networking_v1, core_v1);

    assert networking_v1.create_namespaced_ingress.called , "create_namespaced_ingress must be called when patch returns 404";

    create_body = networking_v1.create_namespaced_ingress.call_args[1]['body'];
    assert 'tls' not in create_body.get('spec', {}) , "spec.tls must not appear in create body";
    assert 'host' not in create_body.get('spec', {}).get('rules', [{}])[0] , "host must not appear in create body";
}

test "non-404 patch error propagates" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=500);

    deployer = _make_deployer();
    raised = False;
    try {
        _call_deploy(deployer, networking_v1, core_v1);
    } except ApiException as e {
        raised = e.status == 500;
    }
    assert raised , "Non-404 ApiException from patch_namespaced_ingress must propagate";
}

test "shared ingress with a cert-manager issuer annotation adds spec.tls" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_shared_deployer(
        {'cert-manager.io/cluster-issuer': 'letsencrypt-prod'}
    );
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    tls = body.get('spec', {}).get('tls');
    assert tls , "shared ingress + cert-manager annotation must add spec.tls";
    assert tls[0]['hosts'] == ['app.example.com'] , "tls host must be the domain";
    assert tls[0]['secretName'] == 'myapp-tls' , "tls secretName must be {app}-tls";
}

test "shared ingress without a cert-manager annotation adds no cert tls block" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_shared_deployer({});
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert body.get('spec', {}).get('tls') is None , "no issuer annotation must not add a cert tls block";
}


def _render_rules(domain: str) -> list {
    config = KubernetesConfig(app_name="myapp", namespace="test-ns", domain=domain);
    deployer = IngressDeployer(k8s_config=config, logger=None);
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    deployer._deploy_ingress_resource(
        app_name="myapp",
        namespace="test-ns",
        ingress_class="test-ns-myapp-nginx",
        service_port=8000,
        grafana_enabled=False,
        networking_v1=networking_v1,
        core_v1=core_v1
    );
    call_args = networking_v1.patch_namespaced_ingress.call_args;
    assert call_args is not None;
    return call_args.kwargs["body"]["spec"]["rules"];
}


test "per-app ingress without a domain renders a single catch-all rule" {
    rules = _render_rules("");
    assert len(rules) == 1 , f"expected one catch-all rule, got {rules}";
    assert "host" not in rules[0];
}

def _run_enable_tls(shared: bool) -> list {
    cfg = KubernetesConfig(
        app_name="myapp",
        namespace="test-ns",
        domain="example.com",
        cert_manager_email="a@b.com",
        shared_ingress=shared,
        shared_ingress_class=("nginx" if shared else "")
    );
    deployer = IngressDeployer(k8s_config=cfg, logger=None);
    ing = SimpleNamespace(
        metadata=SimpleNamespace(
            annotations={
                "jac-scale/domain": "example.com",
                "jac-scale/cert-email": "a@b.com"
            }
        )
    );
    networking_v1 = unittest.mock.MagicMock();
    networking_v1.read_namespaced_ingress.side_effect = [
        ing,
        ing,
        ApiException(status=404)
    ];
    custom_api = unittest.mock.MagicMock();
    custom_api.get_namespaced_custom_object.return_value = {
        "status": {"conditions": [{"type": "Ready", "status": "True"}]}
    };
    fake_api_client = unittest.mock.MagicMock();
    fake_api_client.sanitize_for_serialization.return_value = {
        "spec": {"rules": [{"http": {"paths": [{"path": "/"}]}}]}
    };
    with unittest.mock.patch.object(
        IngressDeployer, "_install_cert_manager", unittest.mock.MagicMock()
    ) {
        with unittest.mock.patch.object(
            ingress_module.client, "ApiClient", lambda { fake_api_client; }
        ) {
            deployer.enable_tls(
                "myapp",
                "test-ns",
                networking_v1,
                custom_api,
                unittest.mock.MagicMock(),
                unittest.mock.MagicMock()
            );
        }
    }
    body = networking_v1.patch_namespaced_ingress.call_args_list[0][1]["body"];
    return body["spec"]["rules"];
}

test "enable_tls on a per-app ingress renders host plus catch-all rules" {
    rules = _run_enable_tls(False);
    assert len(rules) == 2 , f"expected host rule + catch-all, got {rules}";
    assert rules[0].get("host") == "example.com";
    assert "host" not in rules[1];
}

test "enable_tls on a shared ingress stays host-scoped with no catch-all" {
    # A catch-all rule on a SHARED controller would swallow other apps'
    # unmatched traffic, so the shared path must keep exactly one
    # host-bound rule.
    rules = _run_enable_tls(True);
    assert len(rules) == 1 , f"expected a single host-bound rule, got {rules}";
    assert rules[0].get("host") == "example.com";
}
