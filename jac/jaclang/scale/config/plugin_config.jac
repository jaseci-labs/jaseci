def _http_activation_nested_schema -> dict[str, any] {
    """The `nested` fields shared verbatim by [scale.kubernetes.http_activation]
    and [scale.microservices.services.NAME.http_activation] -- factored out so
    the two call sites (top-level default, per-service override) can't drift
    out of sync on a field's type/default the way two independent copies
    would.
    """;
    return {
        "enabled": {
            "type": "bool",
            "default": False,
            "description": "Master switch. Off by default."
        },
        "min_replicas": {
            "type": "int",
            "default": 0,
            "description": "Replica floor while inactive. 0 enables true scale-to-zero."
        },
        "max_replicas": {
            "type": "int",
            "default": 1,
            "description": "Replica ceiling once activated."
        },
        "polling_interval": {
            "type": "int",
            "default": 30,
            "description": "How often KEDA evaluates the HTTP scaling metric, in seconds."
        },
        "cooldown_period": {
            "type": "int",
            "default": 300,
            "description": "Seconds of inactivity before scaling back to min_replicas."
        },
        "target_port": {
            "type": "int",
            "default": None,
            "description": "Container port on the target's own generated Service. Exactly one of target_port/target_port_name must be set when enabled."
        },
        "target_port_name": {
            "type": "string",
            "default": None,
            "description": "Named container port on the target's own generated Service, as an alternative to target_port."
        },
        "concurrency_target": {
            "type": "int",
            "default": None,
            "description": "In-flight-request concurrency target. Exactly one of concurrency_target/request_rate_target must be set when enabled."
        },
        "request_rate_target": {
            "type": "int",
            "default": None,
            "description": "Requests-per-window target, as an alternative to concurrency_target."
        },
        "request_rate_window": {
            "type": "string",
            "default": "1m",
            "description": "Window duration for request_rate_target."
        },
        "request_rate_granularity": {
            "type": "string",
            "default": "1s",
            "description": "Sampling granularity for request_rate_target."
        },
        "cold_start_status_code": {
            "type": "int",
            "default": 503,
            "description": "HTTP status the interceptor returns while the target cold-starts, if a placeholder response is configured."
        },
        "cold_start_body": {
            "type": "string",
            "default": None,
            "description": "Static placeholder response body served while the target cold-starts."
        },
        "cold_start_body_config_map": {
            "type": "dict",
            "default": None,
            "description": "ConfigMap reference to source the placeholder response body from, as an alternative to cold_start_body."
        },
        "cold_start_headers": {
            "type": "dict",
            "default": {},
            "description": "Extra headers on the placeholder response."
        },
        "cold_start_fallback_service": {
            "type": "string",
            "default": None,
            "description": "Service name to forward requests to while the target cold-starts, as an alternative to a static placeholder response."
        },
        "cold_start_fallback_port": {
            "type": "int",
            "default": None,
            "description": "Port on cold_start_fallback_service."
        },
        "timeout_readiness": {
            "type": "string",
            "default": None,
            "description": "Duration (e.g. \"30s\") the interceptor waits for the target to become ready after scaling up."
        },
        "timeout_request": {
            "type": "string",
            "default": None,
            "description": "Duration the interceptor waits for the forwarded request to complete."
        },
        "timeout_response_header": {
            "type": "string",
            "default": None,
            "description": "Duration the interceptor waits for response headers from the target."
        },
        "scale_target_kind": {
            "type": "string",
            "default": "Deployment",
            "description": "Kind of the scale target. Deployment/StatefulSet work directly; other kinds require scale_target_plural."
        },
        "scale_target_api_version": {
            "type": "string",
            "default": "apps/v1",
            "description": "apiVersion of the scale target, used when scale_target_plural is set for a custom-resource target."
        },
        "scale_target_plural": {
            "type": "string",
            "default": None,
            "description": "Plural resource name for a custom-resource scale target (e.g. \"rollouts\"), enabling existence validation before writing anything."
        },
        "rules": {
            "type": "list",
            "default": [],
            "description": "[[...rules]] array-of-tables. Each entry: hosts (list[str]), paths (list[str]), headers (list of {name, value?}). Fields within one rule are AND'd; separate rules are OR'd. At least one rule is required -- leaving this empty raises an error at build time, since no traffic would ever match and the target would never wake. Use hosts = [\"*\"] for an explicit catch-all."
        }
    };
}


class JacScalePluginConfig {
    static def get_plugin_metadata -> dict[str, any] {
        return {
            "name": "scale",
            "version": "0.1.0",
            "description": "Jac Scale - Deploy and scale Jac applications with Kubernetes"
        };
    }

    static def get_config_schema -> dict[str, any] {
        return {
            "section": "scale",
            "options": {
                "jwt": {
                    "type": "dict",
                    "default": {},
                    "description": "JWT authentication configuration",
                    "nested": {
                        "secret": {
                            "type": "string",
                            "default": "supersecretkey_for_testing_only!",
                            "description": "Secret key for JWT signing"
                        },
                        "algorithm": {
                            "type": "string",
                            "default": "HS256",
                            "description": "JWT encoding algorithm"
                        },
                        "exp_delta_days": {
                            "type": "int",
                            "default": 7,
                            "description": "JWT token expiration in days"
                        }
                    }
                },
                "sso": {
                    "type": "dict",
                    "default": {},
                    "description": "SSO authentication configuration",
                    "nested": {
                        "host": {
                            "type": "string",
                            "default": "http://localhost:8000/sso",
                            "description": "SSO callback host URL"
                        },
                        "google": {
                            "type": "dict",
                            "default": {},
                            "description": "Google OAuth configuration",
                            "nested": {
                                "client_id": {
                                    "type": "string",
                                    "default": "",
                                    "description": "Google OAuth client ID"
                                },
                                "client_secret": {
                                    "type": "string",
                                    "default": "",
                                    "description": "Google OAuth client secret"
                                }
                            }
                        }
                    }
                },
                "database": {
                    "type": "dict",
                    "default": {},
                    "description": "Database connection configuration",
                    "nested": {
                        "type": {
                            "type": "string",
                            "default": None,
                            "description": "Optional default database backend metadata (e.g. mongodb, redis, firestore)"
                        },
                        "mongodb_uri": {
                            "type": "string",
                            "default": None,
                            "description": "MongoDB connection URI"
                        },
                        "redis_url": {
                            "type": "string",
                            "default": None,
                            "description": "Redis connection URL"
                        },
                        "project_id": {
                            "type": "string",
                            "default": None,
                            "description": "Firestore project ID (or set FIRESTORE_PROJECT_ID / FIREBASE_PROJECT_ID)"
                        },
                        "shelf_db_path": {
                            "type": "string",
                            "default": ".jac/data/anchor_store.db",
                            "description": "File-based storage path for ShelfDB fallback"
                        },
                        "redis_cpu_request": {
                            "type": "string",
                            "default": "100m",
                            "description": "K8s CPU request for the jac-scale provisioned Redis pod. Used verbatim in the Deployment, so it must be a valid Kubernetes quantity, e.g. 100m or 1."
                        },
                        "redis_cpu_limit": {
                            "type": "string",
                            "default": "500m",
                            "description": "K8s CPU limit for the jac-scale provisioned Redis pod. Used verbatim in the Deployment, so it must be a valid Kubernetes quantity, e.g. 500m or 1."
                        },
                        "redis_memory_request": {
                            "type": "string",
                            "default": "128Mi",
                            "description": "K8s memory request (scheduling reservation) for the jac-scale provisioned Redis pod. Used verbatim in the Deployment, so it must be a valid Kubernetes quantity, e.g. 128Mi or 512Mi (not 128mb). Raise it alongside redis_memory_limit for a cache whose working set is large enough that eviction under node memory pressure would hurt."
                        },
                        "redis_memory_limit": {
                            "type": "string",
                            "default": "1Gi",
                            "description": "K8s memory limit (cgroup) for the jac-scale provisioned Redis pod. Used verbatim in the Deployment, so it must be a valid Kubernetes quantity, e.g. 1Gi or 512Mi (not 1gb, which the API server rejects at apply time). Must exceed redis_max_memory with headroom for BGSAVE fork copy-on-write, fragmentation, and buffers, or the pod is OOMKilled."
                        }
                    }
                },
                "kubernetes": {
                    "type": "dict",
                    "default": {},
                    "description": "Kubernetes deployment configuration",
                    "nested": {
                        "app_name": {
                            "type": "string",
                            "default": None,
                            "description": "Application name for Kubernetes resources. Defaults to a k8s-safe slug of [project].name when unset, or 'jaseci' if no project name is usable"
                        },
                        "namespace": {
                            "type": "string",
                            "default": "default",
                            "description": "Kubernetes namespace for deployment"
                        },
                        "container_port": {
                            "type": "int",
                            "default": 8000,
                            "description": "Container port for the application"
                        },
                        "mongodb_enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Enable MongoDB deployment in Kubernetes"
                        },
                        "redis_enabled": {
                            "type": "bool",
                            "default": True,
                            "description": "Enable Redis deployment in Kubernetes"
                        },
                        "plugin_versions": {
                            "type": "dict",
                            "default": {},
                            "description": "Package versions for PyPI installation (default mode). Use 'latest' or specific version.",
                            "nested": {
                                "jaclang": {
                                    "type": "string",
                                    "default": "latest",
                                    "description": "jaclang package version (scale ships inside it)"
                                },
                                "jac_byllm": {
                                    "type": "string",
                                    "default": "latest",
                                    "description": "jac-byllm package version (use 'none' to skip)"
                                }
                            }
                        },
                        "autoscaler_engine": {
                            "type": "string",
                            "default": "hpa",
                            "description": "Autoscaler engine to use. Built-in: 'hpa' (default, CPU/memory only) or 'keda' (event-driven, supports scale-to-zero). External plugins can register additional engines via AutoscalerFactory.register()."
                        },
                        "min_replicas": {
                            "type": "int",
                            "default": 1,
                            "description": "Minimum pod replicas for the autoscaler."
                        },
                        "max_replicas": {
                            "type": "int",
                            "default": 3,
                            "description": "Maximum pod replicas for the autoscaler."
                        },
                        "revision_history_limit": {
                            "type": "int",
                            "default": 10,
                            "description": "How many superseded ReplicaSets Kubernetes keeps per Deployment, which is how far back a rollback can reach. 0 keeps no history and makes a rollback impossible."
                        },
                        "cpu_utilization_target": {
                            "type": "int",
                            "default": 50,
                            "description": "CPU utilization percentage for the HPA cpu trigger (engine='hpa') or the KEDA cpu trigger when no explicit cpu trigger is listed. Ignored when engine='keda' and at least one non-cpu trigger is configured without a cpu trigger."
                        },
                        "memory_utilization_target": {
                            "type": "int",
                            "default": 80,
                            "description": "Memory utilization percentage (of the container memory request) for the default memory trigger, so pods scale out before hitting their memory limit instead of getting OOM-killed. Applied alongside cpu_utilization_target when no explicit triggers are configured."
                        },
                        "autoscaler_scale_up_stabilization": {
                            "type": "int",
                            "default": 60,
                            "description": "HPA scale-up stabilization window in seconds. Prevents the Kubernetes default (double the fleet every 15s) from bursting pods faster than nodes can absorb their memory."
                        },
                        "autoscaler_scale_up_max_pods": {
                            "type": "int",
                            "default": 2,
                            "description": "Maximum pods the autoscaler may add per minute. Rate-limits scale-up so a traffic spike cannot OOM the node with a burst of booting pods."
                        },
                        "idle_replicas": {
                            "type": "int",
                            "default": None,
                            "description": "(KEDA only) Replica count when all triggers go inactive. Set to 0 for scale-to-zero. Omit (null) to fall back to min_replicas."
                        },
                        "autoscaler_polling_interval": {
                            "type": "int",
                            "default": 30,
                            "description": "(KEDA only) How often KEDA evaluates triggers, in seconds."
                        },
                        "autoscaler_cooldown": {
                            "type": "int",
                            "default": 300,
                            "description": "Seconds of continuous inactivity before scaling down to idle_replicas (KEDA); also used as the HPA scale-down stabilization window on both engines."
                        },
                        "autoscaler_initial_cooldown": {
                            "type": "int",
                            "default": 0,
                            "description": "(KEDA only) Delay after a fresh deploy before scale-to-zero becomes eligible. Prevents cold-start thrash on slow-booting apps."
                        },
                        "extra_triggers": {
                            "type": "list",
                            "default": [],
                            "description": "(KEDA only) Additional KEDA trigger dicts applied to every service. Each entry: `type` (str), `metadata` (dict[str,str]), optional `name` (str), optional `auth.secret_refs` (dict). For per-service triggers use [[scale.microservices.services.NAME.triggers]] instead."
                        },
                        "postgres_storage_size": {
                            "type": "string",
                            "default": "2Gi",
                            "description": "PVC size for the provisioned Postgres StatefulSet (k8s target)"
                        },
                        "cpu_request": {
                            "type": "string",
                            "default": None,
                            "description": "Container CPU request for the app pod (e.g. '100m')"
                        },
                        "cpu_limit": {
                            "type": "string",
                            "default": None,
                            "description": "Container CPU limit for the app pod (e.g. '1000m')"
                        },
                        "memory_request": {
                            "type": "string",
                            "default": None,
                            "description": "Container memory request for the app pod (e.g. '128Mi')"
                        },
                        "memory_limit": {
                            "type": "string",
                            "default": None,
                            "description": "Container memory limit for the app pod (e.g. '1Gi')"
                        },
                        "readiness_initial_delay": {
                            "type": "int",
                            "default": 10,
                            "description": "Readiness probe initialDelaySeconds"
                        },
                        "readiness_period": {
                            "type": "int",
                            "default": 20,
                            "description": "Readiness probe periodSeconds"
                        },
                        "readiness_period_scale_to_zero": {
                            "type": "int",
                            "default": 2,
                            "description": "Readiness probe periodSeconds for a service whose replica floor is 0 (hpa.min == 0), overriding readiness_period so a woken pod isn't left waiting on a stale poll interval"
                        },
                        "liveness_initial_delay": {
                            "type": "int",
                            "default": 10,
                            "description": "Liveness probe initialDelaySeconds"
                        },
                        "liveness_period": {
                            "type": "int",
                            "default": 20,
                            "description": "Liveness probe periodSeconds"
                        },
                        "liveness_failure_threshold": {
                            "type": "int",
                            "default": 80,
                            "description": "Liveness probe failureThreshold"
                        },
                        "startup_probe_period": {
                            "type": "int",
                            "default": 2,
                            "description": "Startup probe periodSeconds for no-image pods; failureThreshold scales automatically to preserve the ~900s total startup budget"
                        },
                        "health_check_path": {
                            "type": "string",
                            "default": "/docs",
                            "description": "HTTP path used for readiness/liveness probes"
                        },
                        "python_image": {
                            "type": "string",
                            "default": "",
                            "description": "Base container image for app pods; empty resolves the default jac image"
                        },
                        "wait_image": {
                            "type": "string",
                            "default": "busybox",
                            "description": "Image used by init/wait containers"
                        },
                        "bundle_storage_class": {
                            "type": "string",
                            "default": "",
                            "description": "StorageClass for the code-bundle PVC; empty uses the cluster default"
                        },
                        "bundle_access_mode": {
                            "type": "string",
                            "default": "ReadWriteMany",
                            "description": "Access mode for the code-bundle PVC"
                        },
                        "resource_deletion_wait": {
                            "type": "int",
                            "default": 5,
                            "description": "Seconds to wait between resource deletions on destroy"
                        },
                        "aws_nlb_wait": {
                            "type": "int",
                            "default": 60,
                            "description": "Seconds to wait for an AWS NLB to become reachable"
                        },
                        "app_mount_path": {
                            "type": "string",
                            "default": "/app",
                            "description": "Mount path for the application volume inside pods"
                        },
                        "code_mount_path": {
                            "type": "string",
                            "default": "/code",
                            "description": "Mount path for the code bundle volume inside pods"
                        },
                        "workspace_path": {
                            "type": "string",
                            "default": "/code/workspace",
                            "description": "Working directory for the app inside pods"
                        },
                        "additional_packages": {
                            "type": "list",
                            "default": [],
                            "description": "Extra pip packages installed into app pods at startup"
                        },
                        "loki_enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Deploy the Loki + Alloy log pipeline (see [scale.microservices.logs])"
                        },
                        "tracing_enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Deploy the tracing stack (see [scale.microservices.tracing])"
                        },
                        "ingress_node_port": {
                            "type": "int",
                            "default": 30080,
                            "description": "NodePort used when exposing the app without a LoadBalancer"
                        },
                        "shared_ingress": {
                            "type": "bool",
                            "default": False,
                            "description": "Join a cluster-shared ingress instead of provisioning a dedicated one"
                        },
                        "shared_ingress_class": {
                            "type": "string",
                            "default": "nginx",
                            "description": "IngressClass used when shared_ingress is enabled"
                        },
                        "shared_ingress_annotations": {
                            "type": "dict",
                            "default": {},
                            "description": "Extra annotations applied to the shared ingress"
                        },
                        "shared_ingress_tls": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable TLS on the shared ingress"
                        },
                        "shared_ingress_skip_reachability": {
                            "type": "bool",
                            "default": False,
                            "description": "Skip the post-deploy reachability probe for the shared ingress"
                        },
                        "ingress_limit_rps": {
                            "type": "int",
                            "default": 20,
                            "description": "Ingress rate limit: requests per second per client"
                        },
                        "ingress_limit_burst_multiplier": {
                            "type": "int",
                            "default": 5,
                            "description": "Ingress rate limit burst multiplier"
                        },
                        "ingress_limit_connections": {
                            "type": "int",
                            "default": 20,
                            "description": "Ingress concurrent connection limit per client"
                        },
                        "ingress_session_affinity": {
                            "type": "bool",
                            "default": True,
                            "description": "Enable cookie-based session affinity on the ingress"
                        },
                        "domain": {
                            "type": "string",
                            "default": "",
                            "description": "Public domain for the deployment (enables host-based ingress rules)"
                        },
                        "cert_manager_email": {
                            "type": "string",
                            "default": "",
                            "description": "Email used for cert-manager ACME registration when TLS is enabled"
                        },
                        "service_account_name": {
                            "type": "string",
                            "default": "",
                            "description": "ServiceAccount assigned to app pods; empty uses the namespace default"
                        },
                        "ops_console": {
                            "type": "bool",
                            "default": False,
                            "description": "Deploy the experimental ops console"
                        },
                        "ops_console_mutations": {
                            "type": "bool",
                            "default": False,
                            "description": "Allow mutating operations from the ops console"
                        },
                        "kube_context": {
                            "type": "string",
                            "default": "",
                            "description": "kubectl context to deploy with; empty uses the active context"
                        },
                        "kubeconfig": {
                            "type": "string",
                            "default": "",
                            "description": "Path to an explicit kubeconfig file; empty uses the default resolution"
                        },
                        "labels": {
                            "type": "dict",
                            "default": {},
                            "description": "Extra labels applied to every generated Kubernetes resource"
                        },
                        "http_activation": {
                            "type": "dict",
                            "default": {},
                            "description": "KEDA HTTP Add-on scale-to-zero activation for the monolith app (or shared defaults inherited by microservices unless overridden per-service). Requires the KEDA HTTP Add-on installed separately from core KEDA. For per-service activation use [scale.microservices.services.NAME.http_activation] instead.",
                            "nested": _http_activation_nested_schema()
                        }
                    }
                },
                "secrets": {
                    "type": "dict",
                    "default": {},
                    "description": "Environment variable secrets for K8s deployment. Values use ${ENV_VAR} syntax, resolved at deploy time and created as a K8s Secret with envFrom.secretRef."
                },
                "server": {
                    "type": "dict",
                    "default": {},
                    "description": "Server configuration",
                    "nested": {
                        "port": {
                            "type": "int",
                            "default": 8000,
                            "description": "Server port"
                        },
                        "host": {
                            "type": "string",
                            "default": "0.0.0.0",
                            "description": "Server host"
                        },
                        "suppress_health_check_logs": {
                            "type": "bool",
                            "default": False,
                            "description": "Suppress health-check endpoint access log entries (/docs, /, /openapi.json, /health, /healthz, /healthz/ready, /healthz/live) from CLI output and Kubernetes pod logs. Off by default."
                        }
                    }
                },
                "microservices": {
                    "type": "dict",
                    "default": {},
                    "description": "Microservice mode - run declared Jac files as independent service processes behind an API gateway",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Deprecated - sv imports are auto-discovered, so microservice mode turns on without this key; set false to opt out and run single-process. Ignored inside deployed fleet pods (the deploy already realized the topology). A future release removes this key."
                        },
                        "gateway_port": {
                            "type": "int",
                            "default": 8000,
                            "description": "Gateway port (external-facing)"
                        },
                        "gateway_host": {
                            "type": "string",
                            "default": "0.0.0.0",
                            "description": "Gateway host"
                        },
                        "drain_timeout_seconds": {
                            "type": "float",
                            "default": 10.0,
                            "description": "Graceful shutdown window (seconds). On SIGTERM, gateway + services flip a drain flag (503s on new requests) and wait up to this many seconds for in-flight requests to finish before the server force-closes; the serving core mirrors K8s `terminationGracePeriodSeconds`."
                        },
                        "http_forward_timeout": {
                            "type": "float",
                            "default": 30.0,
                            "description": "Gateway-to-service forward timeout (seconds). Applies to `raw_forward` (built-in passthrough fan-out) and `stream_forward` (path-routed proxy). Distinct from `services.NAME.rpc_timeout`, which controls inter-service `sv import` calls. Override per-service with `[scale.microservices.services.NAME].http_forward_timeout`."
                        },
                        "ingress": {
                            "type": "dict",
                            "default": {},
                            "description": "Optional K8s Ingress for the gateway. Default off (no Ingress emitted) so existing deployments don't grow one unexpectedly. Subkeys: `enabled` (bool, opt-in), `host` (str, omitted means match-any-host), `ingress_class_name` (str, e.g. \"nginx\", \"alb\", \"gce\"), `annotations` (dict[str,str], controller-specific knobs like nginx.ingress.kubernetes.io/proxy-body-size). HTTP only - TLS via cert-manager / ACM is deployment-specific. Routes all external traffic to gateway-service:container_port; the gateway dispatches /<svc>/* internally (member-subpath; the /api prefix was dropped)."
                        },
                        "routes": {
                            "type": "dict",
                            "default": {},
                            "description": "Module-name -> gateway-prefix map. Services are discovered via `sv import`; this only controls client-facing URL routing."
                        },
                        "services": {
                            "type": "dict",
                            "default": {},
                            "description": "Per-service overrides keyed by module name. Subkeys (all optional): `file` (str, the service's entry file relative to the project root; default `<name>.jac`), `rpc_timeout` (float, default 10s, inter-service RPC calls), `http_forward_timeout` (float, default 30s, gateway-to-service forward), `replicas` (int, default 1, K8s Deployment.spec.replicas), `cpu_request` / `cpu_limit` (str, e.g. \"100m\", K8s container resources), `memory_request` / `memory_limit` (str, e.g. \"128Mi\"), `env` (dict[str,str], extra container env vars merged with auto-set JAC_SV_NAME), and nested `hpa` / `pdb` sub-tables. `hpa` keys: `enabled` (bool, default true), `min` (int, default 1), `max` (int, default 3), `cpu_target` (int percent, default 50), `memory_target` (int percent of memory request, default 80), `behavior` (table, default `{}`): a raw HPA `behavior` fragment (`scaleUp`/`scaleDown`, each with `stabilizationWindowSeconds`/`policies`/`selectPolicy`) deep-merged over the generated scale-rate defaults - same merge semantics as `deployment_overlay` (maps merge recursively, the `policies` list has no `name` key so it replaces wholesale rather than merging by entry); applies to both \"hpa\" and \"keda\" engines since both route through the same `Autoscaler._build_behavior` (for keda it only governs scaling above zero replicas - the drop to zero remains controlled by `autoscaler_cooldown`, the ScaledObject's cooldownPeriod). Use it to slow scale-down for connection-heavy services (e.g. `[services.NAME.hpa.behavior.scaleDown] stabilizationWindowSeconds = 600, selectPolicy = 'Min', policies = [{ type = 'Pods', value = 2, periodSeconds = 300 }]`) without imposing the same rate limit on every service via the app-global `autoscaler_cooldown`. `pdb` keys: `enabled` (bool, default true), `max_unavailable` (int, default 1; no PDB is emitted when it is at or above the service's replica floor, since such a budget permits evicting every replica), `min_available` (int, default unset; wins over `max_unavailable` and is the only way to ask for a budget that holds at one replica). `deployment_overlay` (table): a raw Deployment-manifest fragment merged into the generated manifest at build time - maps merge recursively, lists whose members all carry `name` (containers, volumes, env, initContainers, volumeMounts) merge by that name, anything else replaces; identity fields (metadata.name/namespace, selector, the app/managed template labels) are reasserted after the merge. The main container's `name` is the k8s-safe service name (e.g. `builder-sv`; gateway is `gateway`). Use it for nodeSelector, probe tuning, extra volumes/env/init containers - anything the schema has no first-class key for - so pods are right on the FIRST rollout instead of being kubectl-patched into a second one. Overlays add and override only: there is no delete directive (setting a key to null stores null rather than removing the generated field). Gateway uses the `__gateway__` key. `[[services.NAME.triggers]]` array (KEDA only): per-service event-driven triggers; each entry has `type` (str), `metadata` (dict[str,str]), optional `name` (str), optional `auth.secret_refs` (dict). Requires `autoscaler_engine = \"keda\"` in [scale.kubernetes]. `http_activation` sub-table (KEDA HTTP Add-on only): per-service HTTP scale-to-zero activation, same keys as [scale.kubernetes.http_activation] (`enabled`, `min_replicas`, `max_replicas`, `target_port`/`target_port_name`, `concurrency_target`/`request_rate_target`, `[[rules]]`, cold-start and timeout keys, `scale_target_kind`/`scale_target_api_version`/`scale_target_plural`); the target Service is always the service's own generated Service, never user-set. Falls back to [scale.kubernetes.http_activation]'s values for any key left unset. Example: [scale.microservices.services.llm_app] rpc_timeout = 120.0, replicas = 2, cpu_limit = \"2000m\", memory_limit = \"4Gi\", env = { LOG_LEVEL = \"DEBUG\" }, [scale.microservices.services.llm_app.hpa] max = 20, cpu_target = 60",
                            "nested_each": {
                                "file": {
                                    "type": "string",
                                    "default": None,
                                    "description": "Service entry file relative to the project root; default <name>.jac"
                                },
                                "rpc_timeout": {
                                    "type": "float",
                                    "default": 10.0,
                                    "description": "Inter-service RPC call timeout in seconds"
                                },
                                "http_forward_timeout": {
                                    "type": "float",
                                    "default": 30.0,
                                    "description": "Gateway-to-service forward timeout in seconds"
                                },
                                "replicas": {
                                    "type": "int",
                                    "default": 1,
                                    "description": "K8s Deployment.spec.replicas"
                                },
                                "cpu_request": {
                                    "type": "string",
                                    "default": None,
                                    "description": "K8s container CPU request, e.g. '100m'"
                                },
                                "cpu_limit": {
                                    "type": "string",
                                    "default": None,
                                    "description": "K8s container CPU limit, e.g. '2000m'"
                                },
                                "memory_request": {
                                    "type": "string",
                                    "default": None,
                                    "description": "K8s container memory request, e.g. '128Mi'"
                                },
                                "memory_limit": {
                                    "type": "string",
                                    "default": None,
                                    "description": "K8s container memory limit, e.g. '4Gi'"
                                },
                                "env": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Extra container env vars merged with auto-set JAC_SV_NAME"
                                },
                                "hpa": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Per-service autoscaler settings",
                                    "nested": {
                                        "enabled": {
                                            "type": "bool",
                                            "default": True,
                                            "description": "Emit an HPA/ScaledObject for this service"
                                        },
                                        "min": {
                                            "type": "int",
                                            "default": 1,
                                            "description": "Minimum replicas"
                                        },
                                        "max": {
                                            "type": "int",
                                            "default": 3,
                                            "description": "Maximum replicas"
                                        },
                                        "cpu_target": {
                                            "type": "int",
                                            "default": 50,
                                            "description": "CPU utilization target percent"
                                        },
                                        "memory_target": {
                                            "type": "int",
                                            "default": 80,
                                            "description": "Memory utilization target percent (of the memory request)"
                                        },
                                        "behavior": {
                                            "type": "dict",
                                            "default": {},
                                            "description": "Raw HPA behavior fragment deep-merged over generated defaults"
                                        }
                                    }
                                },
                                "pdb": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Per-service PodDisruptionBudget settings",
                                    "nested": {
                                        "enabled": {
                                            "type": "bool",
                                            "default": True,
                                            "description": "Emit a PDB for this service"
                                        },
                                        "max_unavailable": {
                                            "type": "int",
                                            "default": 1,
                                            "description": "PDB maxUnavailable. A budget that permits evicting every replica protects nothing, so no PDB is emitted when this is at or above the service's replica floor (hpa.min, or replicas when the HPA is off)."
                                        },
                                        "min_available": {
                                            "type": "int",
                                            "default": None,
                                            "description": "PDB minAvailable. Set it to keep a floor of healthy pods through voluntary disruption; it wins over max_unavailable. min_available = 1 on a single-replica service refuses node drains until the service is scaled up, which is the trade for never going to zero."
                                        }
                                    }
                                },
                                "deployment_overlay": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "Raw Deployment-manifest fragment merged into the generated manifest"
                                },
                                "triggers": {
                                    "type": "list",
                                    "default": [],
                                    "description": "(KEDA only) Per-service event-driven trigger dicts"
                                },
                                "http_activation": {
                                    "type": "dict",
                                    "default": {},
                                    "description": "(KEDA HTTP Add-on only) Per-service HTTP scale-to-zero activation. Same keys as [scale.kubernetes.http_activation]; the target Service is always this service's own generated Service, never user-set. Falls back to [scale.kubernetes.http_activation]'s values for any key left unset.",
                                    "nested": _http_activation_nested_schema()
                                }
                            }
                        },
                        "rate_limit": {
                            "type": "dict",
                            "default": {},
                            "description": "Gateway rate limiting (token bucket). Disabled unless `enabled = true`.",
                            "nested": {
                                "enabled": {
                                    "type": "bool",
                                    "default": False,
                                    "description": "Master switch."
                                },
                                "per_ip_rpm": {
                                    "type": "int",
                                    "default": 60,
                                    "description": "Requests per minute per client IP. 0 disables per-IP limit."
                                },
                                "per_user_rpm": {
                                    "type": "int",
                                    "default": 0,
                                    "description": "Additional requests per minute per authenticated user (keyed by Authorization header hash). 0 disables per-user limit."
                                },
                                "burst_multiplier": {
                                    "type": "float",
                                    "default": 2.0,
                                    "description": "Bucket capacity = rpm * burst_multiplier / 60 (allows short bursts above the steady rate)."
                                },
                                "exempt_paths": {
                                    "type": "list",
                                    "default": ["/health", "/healthz", "/metrics"],
                                    "description": "Paths that bypass rate limiting entirely (monitoring + probes)."
                                }
                            }
                        },
                        "cors": {
                            "type": "dict",
                            "default": {},
                            "description": "CORS middleware on the gateway. Open by default (any origin). Set `allow_origins = []` to disable, or provide a concrete list to restrict.",
                            "nested": {
                                "allow_origins": {
                                    "type": "list",
                                    "default": ["*"],
                                    "description": "Origins that may access the gateway. Default [\"*\"] allows any. Empty list disables CORS."
                                },
                                "allow_methods": {
                                    "type": "list",
                                    "default": ["*"],
                                    "description": "HTTP methods allowed on cross-origin requests."
                                },
                                "allow_headers": {
                                    "type": "list",
                                    "default": ["*"],
                                    "description": "Request headers allowed on cross-origin requests."
                                },
                                "allow_credentials": {
                                    "type": "bool",
                                    "default": False,
                                    "description": "Allow cookies / Authorization on cross-origin requests. Incompatible with allow_origins = [\"*\"] per spec."
                                },
                                "expose_headers": {
                                    "type": "list",
                                    "default": [],
                                    "description": "Response headers the browser is allowed to read across origins."
                                },
                                "max_age": {
                                    "type": "int",
                                    "default": 600,
                                    "description": "How long (seconds) the browser may cache a preflight response."
                                }
                            }
                        },
                        "client": {
                            "type": "dict",
                            "default": {},
                            "description": "Client UI build settings (optional)",
                            "nested": {
                                "entry": {
                                    "type": "string",
                                    "default": "",
                                    "description": "jac-client entry point (e.g., client/main.jac)"
                                },
                                "dist_dir": {
                                    "type": "string",
                                    "default": ".jac/client/dist",
                                    "description": "Build output directory for static assets"
                                },
                                "base_route": {
                                    "type": "string",
                                    "default": "/",
                                    "description": "SPA base route"
                                }
                            }
                        },
                        "logs": {
                            "type": "dict",
                            "default": {},
                            "description": "Centralised log aggregation via Loki + Grafana Alloy (M-14). Off by default. When enabled, deploys the full monitoring stack (Prometheus + Grafana + Loki + Alloy) into the app namespace; Alloy tails every pod's stdout/stderr from `/var/log/pods` and ships to Loki, queried via Grafana's `Pod Logs` dashboard. v0 uses ephemeral `emptyDir` for Loki storage (suitable for dev/staging); persistent backends land in M-14.c. **Multi-tenant note**: Alloy's ClusterRole reads pods cluster-wide and the dashboard query is `{namespace=~\".+\"}`, so anyone with Grafana access sees logs from every namespace - change the default Grafana password and only enable on clusters where this exposure is acceptable.",
                            "nested": {
                                "enabled": {
                                    "type": "bool",
                                    "default": False,
                                    "description": "Enable the Loki + Alloy logging pipeline. Implies the full monitoring stack (Prometheus + Grafana) because the Pod Logs dashboard view lives in Grafana."
                                }
                            }
                        }
                    }
                },
                "events": {
                    "type": "dict",
                    "default": {},
                    "description": "Event-streaming broker configuration. Off by default. When enabled, jac-scale exposes publish() / @subscribe via the active broker (RedisBroker if a redis URL resolves, otherwise LocalBroker in-memory).",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable the event-streaming broker. When false, all publish() calls become no-ops."
                        },
                        "url": {
                            "type": "string",
                            "default": None,
                            "description": "Redis connection URL. If unset, falls back to [scale.database].redis_url. If neither is set or `redis` extra is missing, LocalBroker (in-memory) is used."
                        },
                        "consumer_group": {
                            "type": "string",
                            "default": "jac-scale",
                            "description": "Default consumer group name used when @subscribe does not specify one."
                        },
                        "serializer": {
                            "type": "string",
                            "default": "json",
                            "description": "Payload serializer: 'json' (default) or 'msgpack' (requires extra)."
                        },
                        "retry": {
                            "type": "dict",
                            "default": {},
                            "description": "Default retry policy applied when a subscription does not provide its own.",
                            "nested": {
                                "max_attempts": {
                                    "type": "int",
                                    "default": 3,
                                    "description": "Number of delivery attempts before the message is sent to the dead-letter topic."
                                },
                                "backoff_seconds": {
                                    "type": "list",
                                    "default": [1.0, 5.0, 30.0],
                                    "description": "Backoff delays per attempt index, clamped to the last value."
                                },
                                "dead_letter_suffix": {
                                    "type": "string",
                                    "default": ".dlq",
                                    "description": "Suffix appended to the topic name to form its dead-letter topic."
                                }
                            }
                        }
                    }
                },
                "monitoring": {
                    "type": "dict",
                    "default": {},
                    "description": "Monitoring configuration for the HTTP /metrics endpoint and Kubernetes Prometheus + Grafana stack",
                    "nested": {
                        "enabled": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable Prometheus metrics collection, /metrics endpoint, and Kubernetes monitoring stack"
                        },
                        "endpoint": {
                            "type": "string",
                            "default": "/metrics",
                            "description": "Path for the Prometheus metrics endpoint"
                        },
                        "namespace": {
                            "type": "string",
                            "default": "jaclang_scale",
                            "description": "Metrics namespace prefix (e.g., myapp_http_requests_total)"
                        },
                        "walker_metrics": {
                            "type": "bool",
                            "default": False,
                            "description": "Enable walker execution timing metrics"
                        },
                        "histogram_buckets": {
                            "type": "list",
                            "default": [
                                0.005,
                                0.01,
                                0.025,
                                0.05,
                                0.075,
                                0.1,
                                0.25,
                                0.5,
                                0.75,
                                1.0,
                                2.5,
                                5.0,
                                10.0
                            ],
                            "description": "Histogram bucket boundaries in seconds for latency metrics"
                        },
                        "prometheus_admin_password": {
                            "type": "string",
                            "default": "Adminpassword123",
                            "description": "Admin password for Grafana when deploying the monitoring stack"
                        }
                    }
                }
            }
        };
    }
}
