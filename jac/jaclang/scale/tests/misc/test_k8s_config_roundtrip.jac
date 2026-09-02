"""Every key the loader emits must survive the KubernetesConfig round-trip.

get_kubernetes_config hands its dict through KubernetesConfig.from_dict and
back through to_dict, and from_dict enumerates its kwargs by hand, so a field
missing from that enumeration is silently reset to its default on the way
through. admin_username travelled exactly that path: emitted by the loader,
declared on the config object, read by the monitoring scrape config, and
dropped in between, so Prometheus scraped /metrics as 'admin' whenever a
different admin username was configured. The first test pins the real
toml-to-loader hop; the second walks every to_dict key through the round-trip
so the next hand-enumeration gap cannot land silently."""

import tempfile;
import from pathlib { Path }
import from jaclang.scale.config.config_loader { JacScaleConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "a configured admin username reaches the kubernetes config" {
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\n'
            'name = "roundtrip-app"\n'
            'version = "0.0.1"\n'
            '\n'
            '[scale.admin]\n'
            'username = "metrics-admin"\n'
        );
        cfg = JacScaleConfig(project_dir=Path(project));
        k8s = cfg.get_kubernetes_config();
        assert k8s["admin_username"] == "metrics-admin";
    }
}


test "every to_dict key survives a from_dict round-trip" {
    base = KubernetesConfig().to_dict();
    for (key, value) in base.items() {
        if key == "database_mode" {
            continue;
        }
        mutated: any = None;
        if isinstance(value, bool) {
            mutated = not value;
        } elif isinstance(value, int) {
            mutated = value + 1;
        } elif isinstance(value, str) {
            mutated = value + "x";
        } elif isinstance(value, dict) {
            mutated = {"probe": "probe"};
        } elif isinstance(value, list) {
            mutated = ["probe"];
        } else {
            continue;
        }
        src = dict(base);
        src[key] = mutated;
        out = KubernetesConfig.from_dict(KubernetesConfig, src).to_dict();
        assert out[key] == mutated , f"from_dict drops '{key}'";
    }
}
