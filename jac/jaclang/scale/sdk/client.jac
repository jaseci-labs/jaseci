import os;
import pathlib;
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.factory {
    _ensure_deploy_tooling,
    _require_deploy_tooling
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTarget
}
import from jaclang.scale.deploy.target.kubernetes.microservice.target {
    KubernetesMicroserviceTarget
}
import from jaclang.scale.models.deployment_result { DeploymentResult }
import from jaclang.scale.models.resource_status { ResourceStatusInfo }
import from jaclang.scale.models.progress { CallbackSink, EventSink, ProgressEvent }
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.sdk.spec { DeploySpec }
import from jaclang.scale.sdk.events { EventLogger }


obj ScaleClient {
    has kube_context: str = '',
        logger: (Logger | None) = None;

    def deploy(spec: DeploySpec, on_event: any = None) -> DeploymentResult {
        sink = CallbackSink(callback=on_event) if on_event is not None else None;
        target = self._make_target(spec, sink=sink);
        app_config = self._app_config(spec);
        self._emit(sink, 'deploy', 'start', f"Deploying '{spec.app_name}'");

        import from jaclang.scale.injector.binary { reset_deploy_version_cache }
        reset_deploy_version_cache();

        try {
            result = target.deploy(app_config);
        } except Exception as e {
            self._emit(sink, 'deploy', 'error', f"Deployment failed: {e}");
            return DeploymentResult(success=False, message=str(e));
        }

        if result.success and not result.service_url {
            try {
                result.service_url = target.get_service_url(spec.app_name);
            } except Exception {
                result.service_url = None;
            }
        }
        if result.success {
            self._emit(
                sink,
                'deploy',
                'ok',
                f"Deployment of '{spec.app_name}' complete",
                detail={'service_url': result.service_url}
            );
        } else {
            self._emit(
                sink,
                'deploy',
                'error',
                f"Deployment failed: {result.message or 'unknown error'}"
            );
        }
        return result;
    }

    def preview(spec: DeploySpec) -> dict[str, any] {
        if spec.resolved_target() != 'kubernetes-microservice' {
            raise ValueError(
                "preview() is only supported for the kubernetes-microservice "
                "target (the default)."
            );
        }
        target = self._ms_target(spec, dry_run=True);
        return target.generate_manifests(self._app_config(spec));
    }

    def destroy(
        app_name: str, namespace: str, component: str = '', target: str = 'auto'
    ) {
        self._lifecycle_target(app_name, namespace, target).destroy(
            app_name, component
        );
    }

    def status(app_name: str, namespace: str, target: str = 'auto') -> dict[str, any] {
        return self._lifecycle_target(app_name, namespace, target).get_full_status(
            app_name
        );
    }

    def resource_status(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> ResourceStatusInfo {
        return self._lifecycle_target(app_name, namespace, target).get_status(app_name);
    }

    def service_url(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> (str | None) {
        return self._lifecycle_target(app_name, namespace, target).get_service_url(
            app_name
        );
    }

    def scale(app_name: str, namespace: str, replicas: int, target: str = 'auto') {
        self._lifecycle_target(app_name, namespace, target).scale(app_name, replicas);
    }

    def _emit(
        sink: (EventSink | None),
        phase: str,
        status: str,
        message: str,
        detail: dict[str, any] = {}
    ) {
        if sink {
            sink.emit(
                ProgressEvent(
                    phase=phase, status=status, message=message, detail=detail
                )
            );
        }
    }

    def _pick_logger(sink: (EventSink | None)) -> Logger {
        if self.logger is not None {
            return self.logger;
        }
        if sink is not None {
            return EventLogger(sink=sink);
        }
        import from jaclang.scale.observability.factory { UtilityFactory }
        return UtilityFactory.create_logger('standard');
    }

    def _target_config(spec: DeploySpec) -> KubernetesConfig {
        config = spec.to_target_config();
        if not config.get('kube_context') {
            config['kube_context'] = self.kube_context;
        }
        return KubernetesConfig.from_dict(KubernetesConfig, config);
    }

    def _ms_target(
        spec: DeploySpec, sink: (EventSink | None) = None, dry_run: bool = False
    ) -> KubernetesMicroserviceTarget {
        _ensure_deploy_tooling(dry_run);
        _require_deploy_tooling(dry_run);
        return KubernetesMicroserviceTarget(
            config=self._target_config(spec),
            logger=self._pick_logger(sink),
            dry_run=dry_run,
            secrets=dict(spec.secrets),
            env=dict(spec.env),
            events=sink,
            no_image=True,
            microservices_config=spec.to_microservices_config()
        );
    }

    def _plain_target(
        spec: DeploySpec, sink: (EventSink | None) = None, dry_run: bool = False
    ) -> KubernetesTarget {
        _ensure_deploy_tooling(dry_run);
        _require_deploy_tooling(dry_run);
        return KubernetesTarget(
            config=self._target_config(spec),
            logger=self._pick_logger(sink),
            dry_run=dry_run,
            secrets=dict(spec.secrets),
            env=dict(spec.env),
            events=sink
        );
    }

    def _make_target(
        spec: DeploySpec, sink: (EventSink | None) = None, dry_run: bool = False
    ) -> KubernetesTarget {
        if spec.resolved_target() == 'kubernetes-microservice' {
            return self._ms_target(spec, sink=sink, dry_run=dry_run);
        }
        return self._plain_target(spec, sink=sink, dry_run=dry_run);
    }

    def _lifecycle_target(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> KubernetesTarget {
        return self._make_target(
            DeploySpec(app_name=app_name, namespace=namespace, target=target)
        );
    }

    def _app_config(spec: DeploySpec) -> AppConfig {
        (code_folder, file_name) = spec.resolve_entry();
        posix_folder = pathlib.Path(os.path.relpath(code_folder)).as_posix();
        return AppConfig(
            code_folder=posix_folder,
            file_name=file_name,
            no_image=(spec.resolved_target() == 'kubernetes-microservice')
        );
    }
}
