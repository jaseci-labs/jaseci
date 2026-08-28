# AutoscalerObserverRegistry is the structural enforcement of "no code path
# opens its own watch": every test here injects a lightweight test double
# via observer_factory so these stay pure registry-semantics tests (identity,
# keying, shutdown, publish atomicity, release refcounting) with no
# Kubernetes mechanics involved -- those are already covered by
# test_kubernetes_autoscaler_observer.jac.
import unittest.mock;
import time;
import from threading { Thread, Lock }
import from jaclang.scale.deploy.autoscale.observer_registry {
    AutoscalerObserverRegistry
}
import from jaclang.scale.deploy.autoscale.observer {
    AutoscalerObserver,
    AutoscalerSubscription
}
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    default_cluster_key
}


obj FakeObserver(AutoscalerObserver) {
    has watch_calls: list = [],
        stop_calls: list = [],
        started: bool = False,
        watch_called: bool = False;

    def start {
        self.started = True;
    }

    def stop(drain: bool = True) {
        self.stop_calls.append(drain);
    }

    def watch_namespace(namespace: str) {
        # A small delay makes the publish-before-watching race in
        # get_or_create observable if it regresses: without the fix, a
        # concurrent caller could see this instance in the registry before
        # this method -- and therefore this flag -- has run.
        time.sleep(0.02);
        self.watch_calls.append(namespace);
        self.watch_called = True;
    }

    def subscribe(
        autoscaler_name: (str | None) = None,
        scale_target_name: (str | None) = None,
        max_queue: int = 100,
        backpressure: str = "drop_oldest"
    ) -> AutoscalerSubscription {
        return AutoscalerSubscription();
    }
}


def fake(obs: AutoscalerObserver) -> FakeObserver {
    # get_or_create is declared to return the abstract AutoscalerObserver;
    # these tests always inject FakeObserver via observer_factory, so this
    # narrows the type to reach its test-only fields.
    assert isinstance(obs, FakeObserver);
    return obs;
}


obj FailingObserver(AutoscalerObserver) {
    # Exercises get_or_create's error path: watch_namespace raises after
    # start() has already succeeded, so a started-but-unpublished observer
    # must be stopped rather than leaked.
    has stop_calls: list = [];

    def start { }
    def watch_namespace(namespace: str) {
        raise RuntimeError("watch_namespace failed");
    }

    def stop(drain: bool = True) {
        self.stop_calls.append(drain);
    }

    def subscribe(
        autoscaler_name: (str | None) = None,
        scale_target_name: (str | None) = None,
        max_queue: int = 100,
        backpressure: str = "drop_oldest"
    ) -> AutoscalerSubscription {
        return AutoscalerSubscription();
    }
}


obj SlowStoppingObserver(AutoscalerObserver) {
    # Exercises the release()/get_or_create() eviction race: stop() sleeps
    # long enough that a concurrent get_or_create for the same key would
    # observe the overlap (a second observer created and watching before
    # this one has finished stopping) if the "stopping" gate regressed.
    has watch_calls: list = [],
        stop_calls: list = [],
        stop_finished_at: (float | None) = None,
        watch_started_at: (float | None) = None;

    def start { }
    def stop(drain: bool = True) {
        time.sleep(0.05);
        self.stop_calls.append(drain);
        self.stop_finished_at = time.monotonic();
    }

    def watch_namespace(namespace: str) {
        self.watch_started_at = time.monotonic();
        self.watch_calls.append(namespace);
    }

    def subscribe(
        autoscaler_name: (str | None) = None,
        scale_target_name: (str | None) = None,
        max_queue: int = 100,
        backpressure: str = "drop_oldest"
    ) -> AutoscalerSubscription {
        return AutoscalerSubscription();
    }
}


def slow(obs: AutoscalerObserver) -> SlowStoppingObserver {
    assert isinstance(obs, SlowStoppingObserver);
    return obs;
}


test "get_or_create returns the identical instance for the same namespace and cluster" {
    AutoscalerObserverRegistry._instances = {};

    first = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    second = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );

    assert first is second;
    assert first.started is True;
    # watch_namespace only runs on the first, actually-creating call.
    assert first.watch_calls == ["ns-a"];
}

test "get_or_create returns different instances for different namespaces" {
    AutoscalerObserverRegistry._instances = {};

    ns_a = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    ns_b = AutoscalerObserverRegistry.get_or_create(
        "ns-b", observer_factory=FakeObserver
    );

    assert ns_a is not ns_b;
}

test "get_or_create returns different instances for the same namespace under different clusters" {
    AutoscalerObserverRegistry._instances = {};

    cluster_1 = AutoscalerObserverRegistry.get_or_create(
        "ns-a", cluster_key="cluster-1", observer_factory=FakeObserver
    );
    cluster_2 = AutoscalerObserverRegistry.get_or_create(
        "ns-a", cluster_key="cluster-2", observer_factory=FakeObserver
    );

    assert cluster_1 is not cluster_2;
}

test "get_or_create always watches the shared, jac-scale-managed selector" {
    # There is no per-caller label_selector: the observer is one shared
    # watch per (cluster, namespace), so its selector is a fixed constant
    # (see MANAGED_SELECTOR), not something individual callers can set --
    # scoping to a single scale target happens client-side via
    # AutoscalerSubscription instead.
    AutoscalerObserverRegistry._instances = {};

    obs = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    assert obs.watch_calls == ["ns-a"];

    AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver);
    assert obs.watch_calls == ["ns-a"];
}

test "get_or_create never returns an observer before its watch has started, under concurrent callers" {
    AutoscalerObserverRegistry._instances = {};

    violations: list = [];
    violations_lock = Lock();

    def worker {
        obs = fake(
            AutoscalerObserverRegistry.get_or_create(
                "ns-race", observer_factory=FakeObserver
            )
        );
        if not obs.watch_called {
            with violations_lock {
                violations.append(obs);
            }
        }
    }

    workers = [Thread(target=worker) for _ in range(16)];
    for w in workers {
        w.start();
    }
    for w in workers {
        w.join();
    }

    assert violations == [];
}

test "release does not stop the observer while other references remain" {
    AutoscalerObserverRegistry._instances = {};

    first = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver);

    AutoscalerObserverRegistry.release("ns-a");

    assert first.stop_calls == [];
    second = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    assert second is first;
}

test "release stops and evicts the observer once its refcount reaches zero" {
    AutoscalerObserverRegistry._instances = {};

    obs = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    AutoscalerObserverRegistry.release("ns-a");

    assert obs.stop_calls == [True];

    # A fresh get_or_create for the same namespace must build a brand new
    # instance, not the one release() just evicted.
    fresh = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    assert fresh is not obs;
}

test "release passes drain through to stop" {
    AutoscalerObserverRegistry._instances = {};

    obs = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    AutoscalerObserverRegistry.release("ns-a", drain=False);

    assert obs.stop_calls == [False];
}

test "release is a no-op for a namespace with no outstanding references" {
    AutoscalerObserverRegistry._instances = {};

    AutoscalerObserverRegistry.release("ns-never-created");

    obs = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    AutoscalerObserverRegistry.release("ns-a");
    AutoscalerObserverRegistry.release("ns-a");

    assert obs.stop_calls == [True];
}

test "release only affects the released cluster's namespace" {
    AutoscalerObserverRegistry._instances = {};

    cluster_1 = fake(
        AutoscalerObserverRegistry.get_or_create(
            "ns-a", cluster_key="cluster-1", observer_factory=FakeObserver
        )
    );
    cluster_2 = fake(
        AutoscalerObserverRegistry.get_or_create(
            "ns-a", cluster_key="cluster-2", observer_factory=FakeObserver
        )
    );

    AutoscalerObserverRegistry.release("ns-a", cluster_key="cluster-1");

    assert cluster_1.stop_calls == [True];
    assert cluster_2.stop_calls == [];
}

test "concurrent releases stop the observer exactly once, however the refcount races down to zero" {
    AutoscalerObserverRegistry._instances = {};

    obs = fake(
        AutoscalerObserverRegistry.get_or_create(
            "ns-race", observer_factory=FakeObserver
        )
    );
    for _ in range(15) {
        AutoscalerObserverRegistry.get_or_create(
            "ns-race", observer_factory=FakeObserver
        );
    }
    assert AutoscalerObserverRegistry._refcounts.get(
        f"{default_cluster_key()}::ns-race"
    )
        == 16;

    def worker {
        AutoscalerObserverRegistry.release("ns-race");
    }

    workers = [Thread(target=worker) for _ in range(16)];
    for w in workers {
        w.start();
    }
    for w in workers {
        w.join();
    }

    assert obs.stop_calls == [True];
    fresh = AutoscalerObserverRegistry.get_or_create(
        "ns-race", observer_factory=FakeObserver
    );
    assert fresh is not obs;
}

test "shutdown_all stops every created instance and clears the registry" {
    AutoscalerObserverRegistry._instances = {};

    ns_a = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    ns_b = fake(
        AutoscalerObserverRegistry.get_or_create("ns-b", observer_factory=FakeObserver)
    );

    AutoscalerObserverRegistry.shutdown_all(drain=True);

    assert ns_a.stop_calls == [True];
    assert ns_b.stop_calls == [True];
    assert AutoscalerObserverRegistry._instances == {};
    assert AutoscalerObserverRegistry._refcounts == {};
}

test "get_or_create after shutdown_all returns a fresh instance, not the stopped one" {
    AutoscalerObserverRegistry._instances = {};

    original = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    AutoscalerObserverRegistry.shutdown_all();

    fresh = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    assert fresh is not original;
    assert fresh.stop_calls == [];
}

test "shutdown_all defaults to draining" {
    AutoscalerObserverRegistry._instances = {};

    obs = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    AutoscalerObserverRegistry.shutdown_all();

    assert obs.stop_calls == [True];
}

test "shutdown_all with drain=False passes it through to every instance" {
    AutoscalerObserverRegistry._instances = {};

    obs = fake(
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver)
    );
    AutoscalerObserverRegistry.shutdown_all(drain=False);

    assert obs.stop_calls == [False];
}

test "the default construction path (no observer_factory) builds a real KubernetesAutoscalerObserver" {
    AutoscalerObserverRegistry._instances = {};
    import from jaclang.scale.deploy.autoscale.kubernetes_observer {
        KubernetesAutoscalerObserver
    }

    obs = AutoscalerObserverRegistry.get_or_create("ns-default-path");
    assert isinstance(obs, KubernetesAutoscalerObserver);

    AutoscalerObserverRegistry.shutdown_all();
}

test "get_or_create stops and does not leak an observer whose watch_namespace fails" {
    AutoscalerObserverRegistry._instances = {};
    AutoscalerObserverRegistry._refcounts = {};
    AutoscalerObserverRegistry._stopping = {};

    created_instances: list = [];

    def failing_factory -> AutoscalerObserver {
        obs = FailingObserver();
        created_instances.append(obs);
        return obs;
    }

    threw = False;
    try {
        AutoscalerObserverRegistry.get_or_create(
            "ns-fail", observer_factory=failing_factory
        );
    } except RuntimeError {
        threw = True;
    }
    assert threw;

    assert len(created_instances) == 1;
    assert created_instances[0].stop_calls == [False];

    key = f"{default_cluster_key()}::ns-fail";
    assert key not in AutoscalerObserverRegistry._instances;
    assert key not in AutoscalerObserverRegistry._refcounts;

    # The failed key must not block subsequent creation.
    fresh = fake(
        AutoscalerObserverRegistry.get_or_create(
            "ns-fail", observer_factory=FakeObserver
        )
    );
    assert fresh.watch_calls == ["ns-fail"];
}

test "get_or_create waits for an in-flight release before creating a new observer for the same key" {
    AutoscalerObserverRegistry._instances = {};
    AutoscalerObserverRegistry._refcounts = {};
    AutoscalerObserverRegistry._stopping = {};

    first = slow(
        AutoscalerObserverRegistry.get_or_create(
            "ns-evict-race", observer_factory=SlowStoppingObserver
        )
    );

    def releaser {
        AutoscalerObserverRegistry.release("ns-evict-race");
    }

    release_thread = Thread(target=releaser);
    release_thread.start();
    # Give release() time to pop the instance, mark it stopping, and enter
    # its (slow) stop() call before this thread races in behind it.
    time.sleep(0.01);

    second = slow(
        AutoscalerObserverRegistry.get_or_create(
            "ns-evict-race", observer_factory=SlowStoppingObserver
        )
    );
    release_thread.join();

    assert second is not first;
    assert first.stop_finished_at is not None;
    assert second.watch_started_at is not None;
    assert first.stop_finished_at <= second.watch_started_at;
}
