"""The admin ops surface: its pure reshape helpers, and that every ops route is registered.

The Kubernetes `.to_dict()` reshaping and the signal self-check chains are
pure functions, so they are fed literal payloads here; the live list calls
behind them run on a real cluster in the deploy e2e. Registration is asserted
because an unregistered /admin/ops/* route falls through to the SPA catch-all
and serves HTML.
"""

import from jaclang.server.serving.endpoint { HTTPMethod }
import from jaclang.scale.server.native_server { NativeJServer }
import from jaclang.scale.admin.deploy_health { JacAPIServerDeployHealth }
import from jaclang.scale.admin.deploy_health { summarize_deployment, summarize_pod }
import from jaclang.scale.admin.ops { JacAPIServerOps }
import from jaclang.scale.admin.ops { short_circuit_chain, _traces_chain }
import from jaclang.scale.admin.network { JacAPIServerNetwork }
import from jaclang.scale.admin.network {
    summarize_service,
    summarize_ingress,
    pvc_claimants,
    summarize_pvc
}


obj DeployHost(JacAPIServerDeployHealth) {
    has server: any = None;
}


obj OpsHost(JacAPIServerOps) {
    has server: any = None;
}


obj NetworkHost(JacAPIServerNetwork) {
    has server: any = None;
}


test "rollout status: complete vs stuck vs progressing" {
    complete = summarize_deployment(
        {
            "metadata": {"name": "gw"},
            "spec": {
                "replicas": 2,
                "template": {"spec": {"containers": [{"image": "app:dev-abc"}]}}
            },
            "status": {
                "ready_replicas": 2,
                "available_replicas": 2,
                "updated_replicas": 2
            }
        }
    );
    assert complete["rollout"]["status"] == "complete";
    assert complete["images"] == ["app:dev-abc"];

    # A deliberate scale-to-zero is complete, not stuck in "progressing".
    zeroed = summarize_deployment(
        {"metadata": {"name": "z"}, "spec": {"replicas": 0}, "status": {}}
    );
    assert zeroed["rollout"]["status"] == "complete" , f"{zeroed['rollout']}";

    stuck = summarize_deployment(
        {
            "metadata": {"name": "gw"},
            "spec": {"replicas": 2},
            "status": {
                "available_replicas": 1,
                "conditions": [
                    {
                        "type": "Progressing",
                        "reason": "ProgressDeadlineExceeded",
                        "message": "stuck"
                    }
                ]
            }
        }
    );
    assert stuck["rollout"]["status"] == "stuck";
}


test "pod summary sums restarts + counts ready containers" {
    pod = summarize_pod(
        {
            "metadata": {"name": "gw-1", "labels": {"app": "gateway"}},
            "spec": {"node_name": "node-a"},
            "status": {
                "phase": "Running",
                "container_statuses": [
                    {
                        "name": "a",
                        "ready": True,
                        "restart_count": 2,
                        "state": {"running": {}}
                    },
                    {
                        "name": "b",
                        "ready": False,
                        "restart_count": 3,
                        "state": {"waiting": {"reason": "CrashLoopBackOff"}}
                    }
                ]
            }
        }
    );
    assert pod["ready"] == 1 and pod["total"] == 2;
    assert pod["restarts"] == 5 , f"restarts={pod['restarts']}";
    assert pod["containers"][1]["reason"] == "CrashLoopBackOff";
}


test "short_circuit_chain: first ok:false is the diagnosis, rest skipped" {
    out = short_circuit_chain(
        [
            {"name": "a", "ok": True, "detail": ""},
            {"name": "b", "ok": False, "detail": "boom"},
            {"name": "c", "ok": True, "detail": ""}
        ]
    );
    assert out["status"] == "fail" , f"status={out['status']}";
    assert out["chain"][1]["ok"] == False and out["chain"][1]["detail"] == "boom";
    assert out["chain"][2]["ok"] == None , "rungs after the first failure are skipped";
}


test "traces chain: all green -> ok; missing tracing extra -> first rung red" {
    p = {
        "has_otel": True,
        "cfg_enabled": True,
        "active": True,
        "endpoint": "http://collector:4318",
        "tempo_ready": True,
        "recent_count": 5
    };
    assert _traces_chain(p)["status"] == "ok";

    p2 = dict(p);
    p2["has_otel"] = False;
    out = _traces_chain(p2);
    assert out["status"] == "fail" and out["chain"][0]["ok"] == False;
}


test "service surfaces 0 ready backends (the no-endpoints 503 cause)" {
    svc = summarize_service(
        {
            "metadata": {"name": "gateway-service"},
            "spec": {
                "type": "ClusterIP",
                "cluster_ip": "10.0.0.1",
                "ports": [{"port": 80, "target_port": 8000, "protocol": "TCP"}]
            }
        },
        {"gateway-service": {"ready": 0, "not_ready": 0}}
    );
    assert svc["ready_backends"] == 0 and svc["ports"][0]["port"] == 80;
}


test "ingress resolves host->service:port + LB; PVC claimants from pods" {
    ing = summarize_ingress(
        {
            "metadata": {"name": "gw-ing"},
            "spec": {
                "rules": [
                    {
                        "host": "app.example.com",
                        "http": {
                            "paths": [
                                {
                                    "path": "/",
                                    "backend": {
                                        "service": {
                                            "name": "gateway-service",
                                            "port": {"number": 80}
                                        }
                                    }
                                }
                            ]
                        }
                    }
                ]
            },
            "status": {
                "load_balancer": {"ingress": [{"hostname": "abc.elb.amazonaws.com"}]}
            }
        }
    );
    assert ing["rules"][0]["service"] == "gateway-service"
        and ing["lb"] == ["abc.elb.amazonaws.com"];

    claims = pvc_claimants(
        [
            {
                "metadata": {"name": "gw-1"},
                "spec": {
                    "volumes": [{"persistent_volume_claim": {"claim_name": "shared"}}]
                }
            },
            {
                "metadata": {"name": "gw-2"},
                "spec": {
                    "volumes": [{"persistent_volume_claim": {"claim_name": "shared"}}]
                }
            }
        ]
    );
    assert claims["shared"] == ["gw-1", "gw-2"];
    pvc = summarize_pvc(
        {
            "metadata": {"name": "shared"},
            "spec": {},
            "status": {"phase": "Bound", "capacity": {"storage": "5Gi"}}
        },
        claims
    );
    assert pvc["phase"] == "Bound" and pvc["claimants"] == ["gw-1", "gw-2"];
}


test "every ops route registers exactly one GET endpoint" {
    for (host, register, path) in [
        (DeployHost(), "register_deploy_health_endpoints", "/admin/ops/deploy"),
        (OpsHost(), "register_ops_endpoints", "/admin/ops/health"),
        (NetworkHost(), "register_network_endpoints", "/admin/ops/network")
    ] {
        host.server = NativeJServer();
        getattr(host, register)();
        eps = [
            e
            for e in host.server._endpoints
            if e.path == path
        ];
        assert len(eps) == 1 and eps[0].method == HTTPMethod.GET , (
            f"{path}: expected one GET endpoint, got {[
                (e.method, e.path) for e in eps
            ]}"
        );
    }
}
