### Chapter 14: Advanced Language Features

This chapter explores Jac's advanced features that enable sophisticated concurrent programming, leverage its powerful type system, and provide robust error handling for production systems. These features build upon the fundamentals to create applications that are both powerful and maintainable.

#### 14.1 Concurrent Programming

### `spawn` for Parallel Walkers

The `spawn` operator not only activates walkers but also enables natural concurrency. Multiple walkers can traverse the graph simultaneously, with Jac handling synchronization automatically:

```jac
// Basic parallel walker spawning
walker DataProcessor {
    has node_id: str;
    has processing_time: float;

    can process with entry {
        let start = time.now();

        // Simulate processing
        sleep(self.processing_time);
        process_node_data(here);

        let duration = time.now() - start;
        report {
            "node": self.node_id,
            "duration": duration,
            "thread": threading.current_thread().name
        };
    }
}

// Spawn multiple walkers concurrently
with entry {
    let nodes = root[-->:DataNode:];

    // These walkers execute in parallel!
    for i, node in enumerate(nodes) {
        spawn DataProcessor(
            node_id=f"node_{i}",
            processing_time=random.uniform(0.1, 0.5)
        ) on node;
    }
}
```

### Advanced Spawning Patterns

```jac
// Parallel map-reduce pattern
walker MapWorker {
    has mapper: callable;
    has data_chunk: list;
    has result_collector: node;

    can map with entry {
        // Process data chunk in parallel
        let results = [self.mapper(item) for item in self.data_chunk];

        // Send results to collector (thread-safe)
        visit self.result_collector {
            :atomic: {  // Atomic operation
                here.results.extend(results);
                here.completed_chunks += 1;
            }
        };
    }
}

walker ReduceWorker {
    has reducer: callable;
    has expected_chunks: int;

    can reduce with ResultCollector entry {
        // Wait for all map workers to complete
        while here.completed_chunks < self.expected_chunks {
            sleep(0.01);  // Busy wait (in practice, use conditions)
        }

        // Reduce results
        final_result = self.reducer(here.results);
        report final_result;
    }
}

// Usage
can parallel_map_reduce(
    data: list,
    mapper: callable,
    reducer: callable,
    chunk_size: int = 100
) -> any {
    // Create result collector
    collector = root ++> ResultCollector(
        results=[],
        completed_chunks=0
    );

    // Split data and spawn mappers
    chunks = [data[i:i+chunk_size] for i in range(0, len(data), chunk_size)];

    for chunk in chunks {
        spawn MapWorker(
            mapper=mapper,
            data_chunk=chunk,
            result_collector=collector
        ) on root;
    }

    // Spawn reducer
    result = spawn ReduceWorker(
        reducer=reducer,
        expected_chunks=len(chunks)
    ) on collector;

    return result;
}
```

### Walker Synchronization

Jac provides several mechanisms for coordinating concurrent walkers:

```jac
// Barrier synchronization
node BarrierNode {
    has required_count: int;
    has arrived_count: int = 0;
    has waiting_walkers: list = [];

    can wait_at_barrier with visitor entry {
        :synchronized: {  // Synchronized block
            self.arrived_count += 1;

            if self.arrived_count < self.required_count {
                // Add walker to waiting list
                self.waiting_walkers.append(visitor);
                visitor.suspend();  // Suspend walker execution
            } else {
                // All walkers arrived, release them
                for walker in self.waiting_walkers {
                    walker.resume();  // Resume suspended walkers
                }
                self.waiting_walkers.clear();
                self.arrived_count = 0;
            }
        }
    }
}

// Pipeline pattern with synchronized stages
walker PipelineStage {
    has stage_num: int;
    has process_func: callable;
    has next_stage: node?;

    can process with WorkItem entry {
        // Process work item
        result = self.process_func(here.data);
        here.data = result;

        // Mark stage completion
        here.completed_stages.add(self.stage_num);

        // Move to next stage if available
        if self.next_stage {
            :synchronized: {
                # Ensure ordering for pipeline
                visit self.next_stage;
            }
        } else {
            report here.data;  // Final result
        }
    }
}
```

### `async`/`await` Patterns

Jac fully supports asynchronous programming for I/O-bound operations:

```jac
import:py asyncio;
import:py aiohttp;
import:py from asyncio { gather, create_task }

// Async walker abilities
walker AsyncWebCrawler {
    has urls: list[str];
    has max_concurrent: int = 10;
    has results: dict = {};

    async can crawl with entry {
        // Create semaphore for rate limiting
        semaphore = asyncio.Semaphore(self.max_concurrent);

        // Create tasks for all URLs
        tasks = [
            create_task(self.fetch_url(url, semaphore))
            for url in self.urls
        ];

        // Wait for all to complete
        await gather(*tasks);

        report self.results;
    }

    async can fetch_url(url: str, semaphore: asyncio.Semaphore) -> None {
        async with semaphore {  // Limit concurrent requests
            try {
                async with aiohttp.ClientSession() as session {
                    async with session.get(url) as response {
                        content = await response.text();
                        self.results[url] = {
                            "status": response.status,
                            "length": len(content),
                            "title": extract_title(content)
                        };
                    }
                }
            } except Exception as e {
                self.results[url] = {"error": str(e)};
            }
        }
    }
}

// Async node abilities
node AsyncDataSource {
    has api_endpoint: str;
    has cache: dict = {};
    has cache_ttl: int = 300;  // seconds

    async can fetch_data with AsyncClient entry {
        cache_key = visitor.query_params;

        // Check cache
        if cache_key in self.cache {
            cached_data, timestamp = self.cache[cache_key];
            if time.now() - timestamp < self.cache_ttl {
                visitor.receive_data(cached_data);
                return;
            }
        }

        // Fetch fresh data
        try {
            data = await fetch_from_api(
                self.api_endpoint,
                visitor.query_params
            );

            // Update cache
            self.cache[cache_key] = (data, time.now());
            visitor.receive_data(data);

        } except APIError as e {
            visitor.receive_error(e);
        }
    }
}

// Async entry point
async with entry:main {
    // Spawn async walker
    crawler = AsyncWebCrawler(urls=[
        "https://example.com",
        "https://example.org",
        "https://example.net"
    ]);

    results = await spawn crawler on root;
    print(f"Crawled {len(results)} URLs");
}
```

### Thread-Safe Graph Operations

When multiple walkers operate on the same graph regions, Jac provides thread-safety guarantees:

```jac
// Thread-safe node with fine-grained locking
node ConcurrentCounter {
    has count: int = 0;
    has :lock: lock = threading.Lock();  // Node-level lock

    can increment with visitor entry {
        with self.lock {
            old_value = self.count;
            self.count += 1;

            // Log the change atomically
            self ++> CounterLog(
                timestamp=now(),
                old_value=old_value,
                new_value=self.count,
                walker_id=visitor.id
            );
        }
    }

    can get_value -> int {
        with self.lock {
            return self.count;
        }
    }
}

// Read-write lock pattern
node SharedResource {
    has data: dict = {};
    has :rwlock: rwlock = threading.RWLock();

    can read_data(key: str) -> any? {
        with self.rwlock.read() {  // Multiple readers allowed
            return self.data.get(key);
        }
    }

    can write_data(key: str, value: any) {
        with self.rwlock.write() {  // Exclusive write access
            self.data[key] = value;
        }
    }
}

// Atomic operations on edges
edge ConcurrentEdge {
    has weight: float;
    has access_count: int = 0;

    :atomic: ["weight", "access_count"];  // Declare atomic fields

    can traverse with visitor entry {
        # These operations are atomic
        self.access_count += 1;
        self.weight *= 0.99;  # Decay weight

        if self.weight < 0.1 {
            # Mark for deletion (thread-safe)
            self.mark_for_deletion();
        }
    }
}
```

#### 14.2 Type System Deep Dive

### Type Inference vs Explicit Typing

While Jac requires type annotations, it provides sophisticated type inference in many contexts:

```jac
// Explicit typing (required for declarations)
let numbers: list[int] = [1, 2, 3, 4, 5];
let processor: DataProcessor = DataProcessor();

// Type inference in expressions
let doubled = numbers.map(lambda x: int -> int : x * 2);  // Inferred: list[int]
let filtered = doubled.filter(lambda x: int -> bool : x > 5);  // Inferred: list[int]

// Generic type inference
can identity[T](value: T) -> T {
    return value;
}

let x = identity(42);  // T inferred as int
let y = identity("hello");  // T inferred as str

// Complex type inference
can process_data[T, R](
    data: list[T],
    transformer: callable[[T], R]
) -> list[R] {
    return [transformer(item) for item in data];
}

// Usage with inference
let strings = ["1", "2", "3"];
let integers = process_data(strings, int);  // Inferred: list[int]
```

### Generic Types and Constraints

Jac supports sophisticated generic programming with type constraints:

```jac
// Basic generics
obj Container[T] {
    has items: list[T] = [];

    can add(item: T) {
        self.items.append(item);
    }

    can get(index: int) -> T? {
        if 0 <= index < len(self.items) {
            return self.items[index];
        }
        return None;
    }
}

// Generic constraints
can sort_comparable[T: Comparable](items: list[T]) -> list[T] {
    return sorted(items);
}

// Multiple type parameters with constraints
obj Cache[K: Hashable, V] {
    has store: dict[K, tuple[V, float]] = {};
    has ttl: float;

    can set(key: K, value: V) {
        self.store[key] = (value, time.now());
    }

    can get(key: K) -> V? {
        if key in self.store {
            value, timestamp = self.store[key];
            if time.now() - timestamp < self.ttl {
                return value;
            }
            del self.store[key];
        }
        return None;
    }
}

// Bounded generics
walker TypedTraverser[N: node, E: edge] {
    has node_filter: callable[[N], bool];
    has edge_filter: callable[[E], bool];

    can traverse with N entry {
        if self.node_filter(here) {
            // Process node
            process_typed_node(here);

            // Traverse filtered edges
            let valid_edges = [e for e in [<-->]
                              if isinstance(e, E) and self.edge_filter(e)];

            for edge in valid_edges {
                visit edge.target;
            }
        }
    }
}
```

### Type-Safe Graph Operations

Jac's type system extends to graph operations, ensuring type safety in topological programming:

```jac
// Typed node references
node TypedNode {
    has data: str;
}

node SpecialNode(TypedNode) {
    has special_data: int;
}

// Type-safe traversal
walker StrictTraverser {
    can process with entry {
        // Type-checked at compile time
        let typed_nodes: list[TypedNode] = [-->(`TypedNode)];
        let special_nodes: list[SpecialNode] = [-->(`SpecialNode)];

        // This would be a compile error:
        // let wrong: list[SpecialNode] = [-->(`TypedNode)];
    }
}

// Generic graph algorithms
can find_path[N: node](
    start: N,
    end: N,
    filter_func: callable[[N], bool] = lambda n: N -> bool : True
) -> list[N]? {

    walker PathFinder[N] {
        has target: N;
        has filter_func: callable[[N], bool];
        has path: list[N] = [];
        has found: bool = False;

        can search with N entry {
            self.path.append(here);

            if here == self.target {
                self.found = True;
                report self.path;
                disengage;
            }

            let next_nodes: list[N] = [-->(`N)]
                .filter(self.filter_func)
                .filter(lambda n: N -> bool : n not in self.path);

            for next in next_nodes {
                visit next;
                if self.found {
                    disengage;
                }
            }

            self.path.pop();
        }
    }

    let finder = PathFinder[N](
        target=end,
        filter_func=filter_func
    );

    return spawn finder on start;
}
```

### Advanced Type Features

```jac
// Union types
type StringOrInt = str | int;
type MaybeNode = node | None;

can process_mixed(value: StringOrInt) -> str {
    match value {
        case str as s: return s;
        case int as i: return str(i);
    }
}

// Type aliases for complex types
type UserGraph = dict[str, list[tuple[User, Relationship]]];
type AsyncCallback = callable[[any], Awaitable[None]];

// Literal types
type Direction = "north" | "south" | "east" | "west";
type Priority = 1 | 2 | 3 | 4 | 5;

can move(direction: Direction, steps: int) -> Position {
    match direction {
        case "north": return Position(0, steps);
        case "south": return Position(0, -steps);
        case "east": return Position(steps, 0);
        case "west": return Position(-steps, 0);
    }
}

// Protocol types (structural typing)
protocol Serializable {
    can to_json() -> str;
    can from_json(data: str) -> Self;
}

can save_object[T: Serializable](obj: T, filename: str) {
    with open(filename, "w") as f {
        f.write(obj.to_json());
    }
}

// Variadic generics
can combine[*Ts](values: tuple[*Ts]) -> tuple[*Ts] {
    return values;
}

let combined = combine((1, "hello", 3.14, True));  // tuple[int, str, float, bool]
```

#### 14.3 Error Handling

### Exception Handling in Traversals

Error handling in graph traversal requires special consideration:

```jac
// Traversal-aware exception handling
walker ResilientTraverser {
    has errors: list[dict] = [];
    has continue_on_error: bool = True;

    can traverse with entry {
        try {
            // Process current node
            result = process_node(here);

            // Continue traversal
            visit [-->];

        } except NodeProcessingError as e {
            self.errors.append({
                "node": here,
                "error": str(e),
                "traceback": get_traceback()
            });

            if not self.continue_on_error {
                disengage;  // Stop traversal
            }

        } except NetworkError as e {
            // Handle cross-machine traversal errors
            print(f"Network error visiting remote node: {e}");

            // Try alternate path
            visit [-->:LocalEdge:];  // Only local edges
        }
    }

    can summarize with `root exit {
        if self.errors {
            report {
                "status": "completed_with_errors",
                "error_count": len(self.errors),
                "errors": self.errors
            };
        } else {
            report {"status": "success"};
        }
    }
}
```

### Ability-Specific Error Patterns

Different ability types require different error handling strategies:

```jac
// Node ability error handling
node DataNode {
    has data: dict;
    has error_count: int = 0;
    has max_errors: int = 3;

    can process_visitor with DataWalker entry {
        try {
            # Validate visitor
            if not visitor.is_authorized() {
                raise UnauthorizedError("Visitor not authorized");
            }

            # Process data
            result = transform_data(self.data, visitor.transform_spec);
            visitor.receive_result(result);

        } except UnauthorizedError as e {
            # Specific handling for auth errors
            log_security_event(visitor, e);
            visitor.reject(reason=str(e));

        } except DataTransformError as e {
            # Handle processing errors
            self.error_count += 1;

            if self.error_count >= self.max_errors {
                self.mark_as_failed();
                raise NodeFailureError(f"Node failed after {self.error_count} errors");
            }

            visitor.receive_error(e);

        } finally {
            # Always log visit
            self ++> VisitLog(
                visitor_type=type(visitor).__name__,
                timestamp=now(),
                success=not visitor.has_error()
            );
        }
    }
}

// Walker ability error handling
walker DataMigrator {
    has source_version: int;
    has target_version: int;
    has rollback_on_error: bool = True;
    has migrated_nodes: list[node] = [];

    can migrate with entry {
        # Create savepoint for rollback
        savepoint = create_graph_savepoint();

        try {
            # Check version compatibility
            if here.version != self.source_version {
                raise VersionMismatchError(
                    f"Expected v{self.source_version}, found v{here.version}"
                );
            }

            # Perform migration
            migrate_node_data(here, self.target_version);
            here.version = self.target_version;
            self.migrated_nodes.append(here);

            # Continue to connected nodes
            visit [-->];

        } except MigrationError as e {
            print(f"Migration failed at {here}: {e}");

            if self.rollback_on_error {
                # Rollback all migrated nodes
                restore_graph_savepoint(savepoint);

                # Report failure
                report {
                    "status": "failed",
                    "error": str(e),
                    "rolled_back": True,
                    "attempted_nodes": len(self.migrated_nodes)
                };

                disengage;
            } else {
                # Continue despite error
                self.errors.append({
                    "node": here,
                    "error": e
                });
            }
        }
    }
}
```

### Distributed Error Propagation

Handling errors across machine boundaries requires special consideration:

```jac
// Cross-machine error handling
walker DistributedProcessor {
    has timeout: float = 30.0;
    has retry_attempts: int = 3;

    can process with entry {
        for attempt in range(self.retry_attempts) {
            try {
                # Set timeout for cross-machine operations
                with timeout_context(self.timeout) {
                    # This might cross machine boundaries
                    remote_result = visit_and_get_result(
                        [-->:RemoteEdge:][0]
                    );

                    process_remote_result(remote_result);
                    break;  # Success, exit retry loop
                }

            } except TimeoutError as e {
                if attempt < self.retry_attempts - 1 {
                    # Exponential backoff
                    wait_time = 2 ** attempt;
                    print(f"Timeout, retrying in {wait_time}s...");
                    sleep(wait_time);
                } else {
                    # Final attempt failed
                    raise DistributedOperationError(
                        f"Operation timed out after {self.retry_attempts} attempts"
                    );

            } except RemoteMachineError as e {
                # Remote machine failure
                handle_machine_failure(e.machine_id);

                # Try alternate route
                alternate = find_alternate_route(here, e.failed_node);
                if alternate {
                    visit alternate;
                } else {
                    raise NoAlternateRouteError();
            }
        }
    }
}

// Circuit breaker pattern for distributed calls
obj CircuitBreaker {
    has failure_threshold: int = 5;
    has recovery_timeout: float = 60.0;
    has failure_count: int = 0;
    has last_failure_time: float = 0.0;
    has state: str = "closed";  # closed, open, half-open

    can call[T](func: callable[[], T]) -> T {
        if self.state == "open" {
            if time.now() - self.last_failure_time > self.recovery_timeout {
                self.state = "half-open";
            } else {
                raise CircuitOpenError("Circuit breaker is open");
            }
        }

        try {
            result = func();

            if self.state == "half-open" {
                # Success in half-open state, close circuit
                self.state = "closed";
                self.failure_count = 0;
            }

            return result;

        } except Exception as e {
            self.failure_count += 1;
            self.last_failure_time = time.now();

            if self.failure_count >= self.failure_threshold {
                self.state = "open";
                print(f"Circuit breaker opened after {self.failure_count} failures");
            }

            raise e;
        }
    }
}

// Using circuit breaker in distributed operations
walker ResilientDistributedWalker {
    has circuit_breakers: dict[str, CircuitBreaker] = {};

    can get_breaker(machine_id: str) -> CircuitBreaker {
        if machine_id not in self.circuit_breakers {
            self.circuit_breakers[machine_id] = CircuitBreaker();
        }
        return self.circuit_breakers[machine_id];
    }

    can visit_remote with entry {
        for remote_node in [-->:RemoteEdge:-->] {
            machine_id = remote_node.__machine_id__;
            breaker = self.get_breaker(machine_id);

            try {
                result = breaker.call(lambda: visit_and_process(remote_node));
                handle_result(result);

            } except CircuitOpenError {
                print(f"Skipping {machine_id} - circuit open");
                continue;

            } except Exception as e {
                print(f"Error processing remote node: {e}");
                continue;
            }
        }
    }
}
```

### Error Recovery Patterns

```jac
// Compensation pattern for distributed transactions
walker CompensatingTransaction {
    has operations: list[dict] = [];
    has compensations: list[callable] = [];

    can execute_with_compensation(
        operation: callable,
        compensation: callable
    ) -> any {
        try {
            result = operation();

            # Record successful operation and its compensation
            self.operations.append({
                "operation": operation.__name__,
                "result": result,
                "timestamp": now()
            });
            self.compensations.append(compensation);

            return result;

        } except Exception as e {
            # Operation failed, run compensations in reverse order
            print(f"Operation failed: {e}, running compensations...");

            for comp in reversed(self.compensations) {
                try {
                    comp();
                } except Exception as comp_error {
                    print(f"Compensation failed: {comp_error}");
                }
            }

            raise TransactionFailedError(
                f"Transaction rolled back due to: {e}"
            );
        }
    }
}

// Saga pattern for long-running transactions
walker SagaOrchestrator {
    has saga_id: str;
    has steps: list[SagaStep];
    has completed_steps: list[str] = [];

    can execute_saga with entry {
        for step in self.steps {
            try {
                # Execute step
                result = spawn step.walker on step.target_node;

                self.completed_steps.append(step.id);

                # Persist saga state
                persist_saga_state(self.saga_id, self.completed_steps);

            } except SagaStepError as e {
                # Step failed, initiate compensation
                print(f"Saga step {step.id} failed: {e}");

                spawn CompensatingSaga(
                    saga_id=self.saga_id,
                    failed_step=step.id,
                    completed_steps=self.completed_steps
                ) on root;

                disengage;
            }
        }

        report {
            "saga_id": self.saga_id,
            "status": "completed",
            "steps": self.completed_steps
        };
    }
}

// Bulkhead pattern for isolation
node ResourcePool {
    has name: str;
    has max_concurrent: int;
    has active_count: int = 0;
    has queue: list[walker] = [];

    can acquire_resource with visitor entry {
        :synchronized: {
            if self.active_count < self.max_concurrent {
                self.active_count += 1;
                visitor.resource_acquired = True;
            } else {
                # Add to queue
                self.queue.append(visitor);
                visitor.suspend();
            }
        }
    }

    can release_resource with visitor exit {
        :synchronized: {
            self.active_count -= 1;

            # Process queued walkers
            if self.queue {
                next_walker = self.queue.pop(0);
                self.active_count += 1;
                next_walker.resource_acquired = True;
                next_walker.resume();
            }
        }
    }
}
```

### Summary

This chapter covered Jac's advanced features that enable production-ready applications:

### Concurrent Programming
- **Parallel Walkers**: Natural concurrency through `spawn`
- **Async/Await**: Full support for asynchronous operations
- **Synchronization**: Thread-safe graph operations and coordination
- **Patterns**: Pipeline, map-reduce, and barrier synchronization

### Type System
- **Inference**: Smart type inference reduces boilerplate
- **Generics**: Powerful generic programming with constraints
- **Graph Types**: Type-safe topological operations
- **Advanced Features**: Union types, protocols, and variadic generics

### Error Handling
- **Traversal Errors**: Graceful handling of graph navigation failures
- **Distributed Errors**: Cross-machine error propagation
- **Recovery Patterns**: Compensation, sagas, and circuit breakers
- **Resilience**: Building fault-tolerant distributed systems

These advanced features, combined with Jac's scale-agnostic programming model, provide all the tools needed to build sophisticated, production-ready applications that can scale from single-user prototypes to global distributed systems.

In the next chapter, we'll explore design patterns specific to Jac that leverage these advanced features to solve common architectural challenges.