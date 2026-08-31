import os;
import pathlib;
import from jaclang.cli.console { console }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.config.project_env { load_project_env }
import from jaclang.scale.observability.factory { UtilityFactory }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.runtime.routing {
    ensure_main_service,
    format_route_lines,
    resolve_routes,
    resolve_service_files
}

glob DELEGATED_ENV: str = "JAC_SCALE_PINNED_DEPLOY";


def pinned_deploy_argv(
    jac_bin: str, filename: str, target: str, enable_tls: bool = False
) -> list[str] {
    argv = [jac_bin, "scale", "deploy", filename, "--target", target];
    if enable_tls {
        argv.append("--enable-tls");
    }
    return argv;
}


obj KubernetesRealizer {
    has ms_config: dict[str, any];

    def _deploy_on_pinned_jac(
        filename: str, target: str, enable_tls: bool, dry_run: bool
    ) -> (int | None) {
        import subprocess;
        import from jaclang.scale.injector.binary { host_toolchain_path }
        import from jaclang.scale.injector.bundle { release_binary_env }
        if dry_run or os.environ.get(DELEGATED_ENV) == "1" {
            return None;
        }
        pinned = host_toolchain_path(os.path.dirname(filename) or ".");
        if not pinned {
            return None;
        }
        console.print(
            "Deploying with the jac release this app pins, not the one "
            f"running this deploy ({pinned})."
        );
        env = release_binary_env();
        env[DELEGATED_ENV] = "1";
        return subprocess.run(
            pinned_deploy_argv(pinned, filename, target, enable_tls), env=env
        ).returncode;
    }

    def realize(
        filename: str,
        target: str = "kubernetes",
        enable_tls: bool = False,
        dry_run: bool = False,
        show_yaml: bool = False
    ) -> int {
        import from jaclang.scale.injector.binary { reset_deploy_version_cache }

        reset_deploy_version_cache();

        if target == "kubernetes" {
            routes: dict[str, str] = resolve_routes(self.ms_config);
            if routes {
                service_files = resolve_service_files(self.ms_config, routes);
                ensure_main_service(routes, service_files, os.path.basename(filename));
                raw_cfg = get_scale_config().load();
                raw_ms = raw_cfg.setdefault("microservices", {});
                raw_ms["routes"] = routes;
                raw_ms["service_files"] = service_files;
                self.ms_config["routes"] = routes;
                self.ms_config["service_files"] = service_files;
                plural = "s" if len(routes) != 1 else "";
                console.print(
                    f"Deploying {len(routes)} service{plural} behind a gateway.",
                    style="cyan"
                );
                for line in format_route_lines(routes) {
                    console.print(f"  {line}", style="muted");
                }
            } else {
                console.print(
                    "No [scale.microservices.routes] declared; deploying the app "
                    "as a single service behind a gateway.",
                    style="cyan"
                );
            }
        }
        if not os.path.exists(filename) {
            raise FileNotFoundError(f"File not found: '{filename}'");
        }
        delegated = self._deploy_on_pinned_jac(filename, target, enable_tls, dry_run);
        if delegated is not None {
            return delegated;
        }
        code_folder = os.path.dirname(filename) or '.';
        load_project_env(code_folder);
        scale_config = get_scale_config();
        logger = UtilityFactory.create_logger('standard');

        if target in ('kubernetes', 'kubernetes-microservice') {
            target_config = scale_config.get_kubernetes_config();
        } else {
            target_config = scale_config.get_section(target);
        }
        deployment_target = DeploymentTargetFactory.create(
            target, target_config, logger, dry_run=dry_run
        );
        import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
            KubernetesTargetBase
        }

        if enable_tls and dry_run {
            console.warning(
                "--dry-run ignores --enable-tls: issuing certificates would "
                "modify the cluster. Re-run without --dry-run to enable TLS."
            );
        } elif enable_tls {
            if not target_config.get('domain', '') {
                raise ValueError(
                    "No domain configured. Set 'domain' under [scale.kubernetes] in jac.toml before running --enable-tls."
                );
            }
            if not target_config.get('cert_manager_email', '') {
                raise ValueError(
                    "No cert_manager_email configured. Set 'cert_manager_email' under [scale.kubernetes] in jac.toml before running --enable-tls."
                );
            }
            app_name = target_config.get('app_name', 'jaseci');
            if not isinstance(deployment_target, KubernetesTargetBase) {
                raise ValueError(
                    f"--enable-tls is only supported on kubernetes targets, not '{target}'."
                );
            }
            deployment_target.enable_tls(app_name);
            return 0;
        }

        code_folder = os.path.relpath(code_folder);
        code_folder = pathlib.Path(code_folder).as_posix();
        base_file_path = os.path.basename(filename);
        if isinstance(deployment_target, KubernetesTargetBase) {
            deployment_target.secrets = scale_config.get_secrets_config();
        }

        app_config = AppConfig(code_folder=code_folder, file_name=base_file_path);
        console.warning(
            "Copying local source into the cluster via PVC and installing "
            "jac at pod startup. Keep secrets in [scale.secrets] "
            "(synced as a K8s Secret) or in .env, never inline in source."
        );
        console.print("Preparing deployment...");

        if dry_run {
            try {
                import from jaclang.scale.runtime.cli.plan { print_plan }
                import from jaclang.scale.runtime.cli.diagnostics { has_errors }
                (bundle, diagnostics) = print_plan(
                    deployment_target, app_config, show_yaml=show_yaml
                );
                exit_code = 2 if has_errors(diagnostics) else 0;
            } except Exception as e {
                console.error(f"--dry-run failed: {e}", emoji=False);
                return 1;
            }
            return exit_code;
        }

        try {
            result = deployment_target.deploy(app_config);
        } except Exception as e {
            console.error(f"Deployment failed: {e}", emoji=False);
            return 1;
        }
        if not result.success {
            console.error(
                f"Deployment failed: {result.message or 'unknown error'}", emoji=False
            );
            return 1;
        }
        if result.service_url {
            console.print(
                f"Deployment complete! Service available at: {result.service_url}"
            );
        } elif result.access_hint {
            console.print(f"Deployment complete! {result.access_hint}");
        }
        return 0;
    }
}
