import from threading { Lock }
import from jaclang.scale._optdeps.optional_deps { require_optional }
import from jaclang.scale.deploy.autoscale.observer { AutoscalerObserver }
import from jaclang.scale.deploy.autoscale.kubernetes_observer {
    KubernetesAutoscalerObserver
}
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    default_cluster_key
}

type ObserverFactoryFn = Callable[[], AutoscalerObserver];

class AutoscalerObserverRegistry {
    static has _instances: dict[str, AutoscalerObserver] = {},
        _refcounts: dict[str, int] = {},
        _lock: Lock = Lock();

    static def get_or_create(
        namespace: str,
        cluster_key: (str | None) = None,
        observer_factory: (ObserverFactoryFn | None) = None
    ) -> AutoscalerObserver {
        key = f"{cluster_key or default_cluster_key()}::{namespace}";
        with AutoscalerObserverRegistry._lock {
            existing = AutoscalerObserverRegistry._instances.get(key);
            if existing is not None {
                AutoscalerObserverRegistry._refcounts[key] = (
                    AutoscalerObserverRegistry._refcounts.get(key, 0) + 1
                );
                return existing;
            }
            if observer_factory {
                created = observer_factory();
            } else {
                require_optional("kubernetes", "deploy.k8s");
                created = KubernetesAutoscalerObserver();
            }
            created.start();
            created.watch_namespace(namespace);
            AutoscalerObserverRegistry._instances[key] = created;
            AutoscalerObserverRegistry._refcounts[key] = 1;
        }
        return created;
    }

    static def release(
        namespace: str, cluster_key: (str | None) = None, drain: bool = True
    ) -> None {
        key = f"{cluster_key or default_cluster_key()}::{namespace}";
        to_stop: (AutoscalerObserver | None) = None;
        with AutoscalerObserverRegistry._lock {
            count = AutoscalerObserverRegistry._refcounts.get(key);
            if count is None {
                return;
            }
            count -= 1;
            if count <= 0 {
                AutoscalerObserverRegistry._refcounts.pop(key, None);
                to_stop = AutoscalerObserverRegistry._instances.pop(key, None);
            } else {
                AutoscalerObserverRegistry._refcounts[key] = count;
            }
        }
        if to_stop is not None {
            to_stop.stop(drain=drain);
        }
    }

    static def shutdown_all(drain: bool = True) {
        with AutoscalerObserverRegistry._lock {
            instances = list(AutoscalerObserverRegistry._instances.values());
            AutoscalerObserverRegistry._instances = {};
            AutoscalerObserverRegistry._refcounts = {};
        }
        for observer in instances {
            observer.stop(drain=drain);
        }
    }
}
