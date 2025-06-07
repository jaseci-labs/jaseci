### Chapter 16: Testing and Debugging

Testing and debugging in Jac requires unique approaches due to its object-spatial nature, graph-based architecture, and scale-agnostic features. This chapter explores comprehensive strategies for ensuring your Jac applications work correctly from development through production.

#### 16.1 Testing Framework

### Built-in `test` Blocks

Jac provides first-class support for testing through the `test` keyword, making tests an integral part of the language:

```jac
// Basic test structure
test "basic arithmetic operations" {
    assert 2 + 2 == 4;
    assert 10 - 5 == 5;
    assert 3 * 4 == 12;
    assert 15 / 3 == 5.0;
}

// Testing with setup and teardown
test "user creation and validation" {
    // Setup
    let user = User(name="Alice", email="alice@example.com");

    // Test assertions
    assert user.name == "Alice";
    assert user.email == "alice@example.com";
    assert user.is_valid();

    // Cleanup happens automatically when test block ends
}

// Parameterized testing
test "edge cases for division" {
    let test_cases = [
        (10, 2, 5.0),
        (7, 2, 3.5),
        (0, 5, 0.0),
        (-10, 2, -5.0)
    ];

    for (a, b, expected) in test_cases {
        assert divide(a, b) == expected;
    }

    // Test error cases
    assert_raises(ZeroDivisionError) {
        divide(10, 0);
    };
}

// Test utilities
can assert_raises(exception_type: type) -> callable {
    can wrapper(code_block: callable) {
        try {
            code_block();
            assert False, f"Expected {exception_type.__name__} but no exception raised";
        } except exception_type {
            // Expected exception was raised
            pass;
        } except Exception as e {
            assert False, f"Expected {exception_type.__name__} but got {type(e).__name__}";
        }
    }
    return wrapper;
}

can assert_almost_equal(a: float, b: float, tolerance: float = 0.0001) {
    assert abs(a - b) < tolerance, f"{a} != {b} within tolerance {tolerance}";
}
```

### Testing Graph Structures

Testing nodes, edges, and their relationships requires specialized approaches:

```jac
// Graph structure test utilities
obj GraphTestCase {
    has root_node: node;

    can setup {
        self.root_node = create_test_root();
    }

    can teardown {
        // Clean up test graph
        clean_graph(self.root_node);
    }

    can assert_connected(source: node, target: node, edge_type: type? = None) {
        let edges = [source --> target];
        assert len(edges) > 0, f"No connection from {source} to {target}";

        if edge_type {
            let typed_edges = [e for e in edges if isinstance(e, edge_type)];
            assert len(typed_edges) > 0,
                f"No {edge_type.__name__} edge from {source} to {target}";
        }
    }

    can assert_not_connected(source: node, target: node) {
        let edges = [source --> target];
        assert len(edges) == 0, f"Unexpected connection from {source} to {target}";
    }

    can assert_node_count(expected: int, node_type: type? = None) {
        if node_type {
            let nodes = find_all_nodes(self.root_node, node_type);
            assert len(nodes) == expected,
                f"Expected {expected} {node_type.__name__} nodes, found {len(nodes)}";
        } else {
            let nodes = find_all_nodes(self.root_node);
            assert len(nodes) == expected,
                f"Expected {expected} total nodes, found {len(nodes)}";
        }
    }
}

// Example graph structure test
test "social network graph structure" {
    let tc = GraphTestCase();
    tc.setup();

    // Create test graph
    let alice = tc.root_node ++> User(name="Alice");
    let bob = tc.root_node ++> User(name="Bob");
    let charlie = tc.root_node ++> User(name="Charlie");

    alice ++>:Follows:++> bob;
    bob ++>:Follows:++> charlie;
    charlie ++>:Follows:++> alice;  // Circular

    // Test structure
    tc.assert_connected(alice, bob, Follows);
    tc.assert_connected(bob, charlie, Follows);
    tc.assert_connected(charlie, alice, Follows);
    tc.assert_not_connected(alice, charlie);  // No direct connection

    tc.assert_node_count(4);  // root + 3 users
    tc.assert_node_count(3, User);

    tc.teardown();
}

// Testing graph algorithms
test "shortest path algorithm" {
    // Create test graph
    let start = create_node("Start");
    let a = create_node("A");
    let b = create_node("B");
    let c = create_node("C");
    let end = create_node("End");

    // Create paths with weights
    start ++>:WeightedEdge(weight=1):++> a;
    start ++>:WeightedEdge(weight=4):++> b;
    a ++>:WeightedEdge(weight=2):++> c;
    b ++>:WeightedEdge(weight=1):++> c;
    c ++>:WeightedEdge(weight=1):++> end;

    // Test shortest path
    let path = find_shortest_path(start, end);

    assert path == [start, a, c, end];
    assert calculate_path_weight(path) == 4;

    // Test alternate path
    let all_paths = find_all_paths(start, end);
    assert len(all_paths) == 2;
}
```

### Testing Walker Behavior

Walker testing requires simulating graph traversal and verifying behavior:

```jac
// Walker test framework
obj WalkerTestCase {
    has test_graph: node;
    has walker_results: list = [];

    can setup_graph -> node abs;  // Abstract, must implement

    can spawn_and_collect[W: walker](
        walker_type: type[W],
        spawn_node: node,
        **kwargs: dict
    ) -> list {
        // Create walker with test parameters
        let w = walker_type(**kwargs);

        // Capture results
        self.walker_results = spawn w on spawn_node;

        return self.walker_results;
    }

    can assert_visited_sequence(walker: walker, expected_nodes: list[node]) {
        assert walker.visited_nodes == expected_nodes,
            f"Expected visit sequence {expected_nodes}, got {walker.visited_nodes}";
    }

    can assert_walker_state(walker: walker, **expected_state: dict) {
        for key, expected_value in expected_state.items() {
            actual_value = getattr(walker, key);
            assert actual_value == expected_value,
                f"Expected {key}={expected_value}, got {actual_value}";
        }
    }
}

// Walker behavior test
test "data aggregator walker" {
    obj AggregatorTest(WalkerTestCase) {
        can setup_graph -> node {
            self.test_graph = create_test_root();

            // Create data nodes
            let n1 = self.test_graph ++> DataNode(value=10);
            let n2 = self.test_graph ++> DataNode(value=20);
            let n3 = self.test_graph ++> DataNode(value=30);

            n1 ++> n2 ++> n3;  // Linear chain

            return self.test_graph;
        }
    }

    let tc = AggregatorTest();
    let start_node = tc.setup_graph();

    // Test walker
    walker DataAggregator {
        has sum: float = 0;
        has count: int = 0;
        has visited_nodes: list = [];

        can aggregate with DataNode entry {
            self.sum += here.value;
            self.count += 1;
            self.visited_nodes.append(here);

            visit [-->];
        }

        can finalize with `root exit {
            report {
                "sum": self.sum,
                "count": self.count,
                "average": self.sum / self.count if self.count > 0 else 0
            };
        }
    }

    let results = tc.spawn_and_collect(DataAggregator, start_node);

    assert len(results) == 1;
    assert results[0]["sum"] == 60;
    assert results[0]["count"] == 3;
    assert results[0]["average"] == 20;
}

// Testing walker interactions
test "walker communication" {
    // Create communicating walkers
    walker Sender {
        has message: str;
        has recipient: node;

        can send with entry {
            visit self.recipient {
                here.received_messages.append(self.message);
            };
        }
    }

    walker Receiver {
        has received_messages: list = [];
        has response: str = "ACK";

        can respond with entry {
            if self.received_messages {
                report {
                    "messages": self.received_messages,
                    "response": self.response
                };
            }
        }
    }

    // Test communication
    let sender_node = create_node();
    let receiver_node = create_node() with {
        has received_messages: list = [];
    };

    sender_node ++> receiver_node;

    // Send message
    spawn Sender(
        message="Hello",
        recipient=receiver_node
    ) on sender_node;

    // Check reception
    assert len(receiver_node.received_messages) == 1;
    assert receiver_node.received_messages[0] == "Hello";

    // Get response
    let response = spawn Receiver() on receiver_node;
    assert response[0]["response"] == "ACK";
}
```

### Testing with Mocks and Stubs

```jac
// Mock framework for Jac
obj Mock {
    has name: str;
    has return_values: dict = {};
    has call_history: list = [];
    has side_effects: dict = {};

    can __getattr__(attr: str) -> callable {
        can mock_method(*args: list, **kwargs: dict) -> any {
            // Record call
            self.call_history.append({
                "method": attr,
                "args": args,
                "kwargs": kwargs,
                "timestamp": now()
            });

            // Execute side effects
            if attr in self.side_effects {
                self.side_effects[attr](*args, **kwargs);
            }

            // Return configured value
            if attr in self.return_values {
                return self.return_values[attr];
            }

            return None;
        }

        return mock_method;
    }

    can assert_called(method: str, times: int? = None) {
        let calls = [c for c in self.call_history if c["method"] == method];

        if times is not None {
            assert len(calls) == times,
                f"{method} called {len(calls)} times, expected {times}";
        } else {
            assert len(calls) > 0,
                f"{method} was not called";
        }
    }

    can assert_called_with(method: str, *args: list, **kwargs: dict) {
        let calls = [c for c in self.call_history if c["method"] == method];

        for call in calls {
            if call["args"] == args and call["kwargs"] == kwargs {
                return;  // Found matching call
            }
        }

        assert False, f"{method} not called with args={args}, kwargs={kwargs}";
    }
}

// Using mocks in tests
test "payment processor with mocks" {
    // Create mock payment gateway
    let mock_gateway = Mock(name="PaymentGateway");
    mock_gateway.return_values["charge"] = {"status": "success", "id": "12345"};
    mock_gateway.side_effects["log"] = lambda msg: print(f"Mock log: {msg}");

    // Test payment processing
    walker PaymentProcessor {
        has gateway: any;
        has amount: float;

        can process with Order entry {
            let result = self.gateway.charge(
                amount=self.amount,
                currency="USD",
                order_id=here.id
            );

            if result["status"] == "success" {
                here.payment_id = result["id"];
                here.status = "paid";
                self.gateway.log(f"Payment successful for order {here.id}");
            }

            report result;
        }
    }

    // Create test order
    let order = create_node() with {
        has id: str = "ORDER-001";
        has status: str = "pending";
        has payment_id: str? = None;
    };

    // Process payment
    let result = spawn PaymentProcessor(
        gateway=mock_gateway,
        amount=99.99
    ) on order;

    // Verify mock interactions
    mock_gateway.assert_called("charge", times=1);
    mock_gateway.assert_called_with(
        "charge",
        amount=99.99,
        currency="USD",
        order_id="ORDER-001"
    );
    mock_gateway.assert_called("log");

    // Verify order state
    assert order.status == "paid";
    assert order.payment_id == "12345";
}
```

#### 16.2 Debugging Techniques

### Traversal Visualization

Understanding walker paths through complex graphs is crucial for debugging:

```jac
// Traversal tracer
walker TraversalTracer {
    has trace: list = [];
    has show_properties: list[str] = [];
    has max_depth: int = 10;
    has current_depth: int = 0;

    can trace_traversal with entry {
        // Record current position
        let trace_entry = {
            "depth": self.current_depth,
            "node_type": type(here).__name__,
            "node_id": here.__id__ if hasattr(here, "__id__") else id(here),
            "timestamp": now()
        };

        // Add requested properties
        for prop in self.show_properties {
            if hasattr(here, prop) {
                trace_entry[prop] = getattr(here, prop);
            }
        }

        self.trace.append(trace_entry);

        // Continue traversal with depth limit
        if self.current_depth < self.max_depth {
            self.current_depth += 1;
            visit [-->];
            self.current_depth -= 1;
        }
    }

    can visualize with `root exit {
        print("\n=== Traversal Trace ===");
        for entry in self.trace {
            indent = "  " * entry["depth"];
            print(f"{indent}→ {entry['node_type']} (id: {entry['node_id']})");

            for key, value in entry.items() {
                if key not in ["depth", "node_type", "node_id", "timestamp"] {
                    print(f"{indent}  {key}: {value}");
            }
        }

        print(f"\nTotal nodes visited: {len(self.trace)}");
        print("===================\n");
    }
}

// Visual graph representation
walker GraphVisualizer {
    has format: str = "mermaid";  // or "dot", "ascii"
    has visited: set = set();
    has edges: list = [];
    has nodes: dict = {};

    can visualize with entry {
        if here in self.visited {
            return;
        }
        self.visited.add(here);

        // Record node
        self.nodes[id(here)] = {
            "type": type(here).__name__,
            "label": self.get_node_label(here)
        };

        // Record edges
        for edge in [<-->] {
            self.edges.append({
                "from": id(here),
                "to": id(edge.target),
                "type": type(edge).__name__,
                "label": self.get_edge_label(edge)
            });
        }

        // Continue traversal
        visit [-->];
    }

    can get_node_label(n: node) -> str {
        if hasattr(n, "name") {
            return f"{n.name}";
        } elif hasattr(n, "id") {
            return f"#{n.id}";
        }
        return "";
    }

    can get_edge_label(e: edge) -> str {
        if hasattr(e, "label") {
            return e.label;
        }
        return "";
    }

    can render with `root exit -> str {
        if self.format == "mermaid" {
            return self.render_mermaid();
        } elif self.format == "dot" {
            return self.render_dot();
        } else {
            return self.render_ascii();
        }
    }

    can render_mermaid -> str {
        let output = ["graph TD"];

        // Add nodes
        for node_id, info in self.nodes.items() {
            let label = f"{info['type']}";
            if info['label'] {
                label += f": {info['label']}";
            }
            output.append(f"    N{node_id}[{label}]");
        }

        // Add edges
        for edge in self.edges {
            let arrow = "-->";
            if edge['type'] != "Edge" {
                arrow = f"-->|{edge['type']}|";
            }
            output.append(f"    N{edge['from']} {arrow} N{edge['to']}");
        }

        return "\n".join(output);
    }
}

// Usage in debugging
with entry:debug {
    // Trace a specific walker's path
    let tracer = TraversalTracer(
        show_properties=["name", "value", "status"],
        max_depth=5
    );
    spawn tracer on problematic_node;

    // Visualize graph structure
    let viz = GraphVisualizer(format="mermaid");
    let graph_diagram = spawn viz on root;
    print(graph_diagram);
}
```

### State Inspection

Tools for inspecting walker and node state during execution:

```jac
// State inspector
obj StateInspector {
    has breakpoints: dict[str, callable] = {};
    has watch_list: list[str] = [];
    has history: list[dict] = [];

    can add_breakpoint(location: str, condition: callable) {
        self.breakpoints[location] = condition;
    }

    can add_watch(expression: str) {
        self.watch_list.append(expression);
    }

    can checkpoint(location: str, context: dict) {
        // Check if we should break
        if location in self.breakpoints {
            if self.breakpoints[location](context) {
                self.interactive_debug(location, context);
            }
        }

        // Record state
        let state_snapshot = {
            "location": location,
            "timestamp": now(),
            "context": context.copy(),
            "watches": {}
        };

        // Evaluate watch expressions
        for expr in self.watch_list {
            try {
                state_snapshot["watches"][expr] = eval(expr, context);
            } except Exception as e {
                state_snapshot["watches"][expr] = f"Error: {e}";
            }
        }

        self.history.append(state_snapshot);
    }

    can interactive_debug(location: str, context: dict) {
        print(f"\n🔴 Breakpoint hit at {location}");
        print("Context variables:");
        for key, value in context.items() {
            print(f"  {key}: {value}");
        }

        // Simple REPL for inspection
        while True {
            let cmd = input("debug> ");
            if cmd == "continue" or cmd == "c" {
                break;
            } elif cmd == "quit" or cmd == "q" {
                raise DebuggerExit();
            } elif cmd.startswith("print ") {
                let expr = cmd[6:];
                try {
                    let result = eval(expr, context);
                    print(result);
                } except Exception as e {
                    print(f"Error: {e}");
                }
            } elif cmd == "help" {
                print("Commands: continue (c), quit (q), print <expr>");
            }
        }
    }
}

// Instrumented walker for debugging
walker DebuggedWalker {
    has inspector: StateInspector;
    has _original_process: callable;

    can __init__ {
        self.inspector = StateInspector();
        self._original_process = self.process;
        self.process = self._debug_process;
    }

    can _debug_process with entry {
        // Pre-process checkpoint
        self.inspector.checkpoint("pre_process", {
            "walker": self,
            "here": here,
            "here_type": type(here).__name__
        });

        // Call original process
        self._original_process();

        // Post-process checkpoint
        self.inspector.checkpoint("post_process", {
            "walker": self,
            "here": here,
            "here_type": type(here).__name__
        });
    }
}

// Property change tracking
node DebugNode {
    has _properties: dict = {};
    has _change_log: list = [];

    can __setattr__(name: str, value: any) {
        let old_value = self._properties.get(name, "<unset>");
        self._properties[name] = value;

        self._change_log.append({
            "property": name,
            "old_value": old_value,
            "new_value": value,
            "timestamp": now(),
            "stack_trace": get_stack_trace()
        });

        super.__setattr__(name, value);
    }

    can get_change_history(property_name: str? = None) -> list {
        if property_name {
            return [c for c in self._change_log if c["property"] == property_name];
        }
        return self._change_log;
    }
}
```

### Distributed Debugging

Debugging across multiple machines requires special tools:

```jac
// Distributed debugger
walker DistributedDebugger {
    has trace_id: str = generate_trace_id();
    has machine_traces: dict[str, list] = {};
    has correlation_id: str;

    can trace_cross_machine with entry {
        let machine_id = here.__machine_id__;

        # Initialize trace for this machine
        if machine_id not in self.machine_traces {
            self.machine_traces[machine_id] = [];
        }

        # Record entry
        self.machine_traces[machine_id].append({
            "event": "walker_arrival",
            "node": type(here).__name__,
            "timestamp": now(),
            "machine": machine_id,
            "correlation_id": self.correlation_id
        });

        # Check for cross-machine edges
        for edge in [<-->] {
            if edge.__is_cross_machine__ {
                self.machine_traces[machine_id].append({
                    "event": "cross_machine_edge",
                    "from_machine": machine_id,
                    "to_machine": edge.target.__machine_id__,
                    "edge_type": type(edge).__name__,
                    "timestamp": now()
                });
            }
        }

        # Continue traversal
        visit [-->];
    }

    can generate_distributed_timeline with `root exit {
        // Merge all machine traces
        let all_events = [];
        for machine_id, events in self.machine_traces.items() {
            for event in events {
                event["machine_id"] = machine_id;
                all_events.append(event);
            }
        }

        // Sort by timestamp
        all_events.sort(key=lambda e: e["timestamp"]);

        // Generate timeline
        print(f"\n=== Distributed Execution Timeline (Trace: {self.trace_id}) ===");
        for event in all_events {
            let time_str = event["timestamp"];
            let machine = event["machine_id"];

            match event["event"] {
                case "walker_arrival":
                    print(f"{time_str} [{machine}] Walker arrived at {event['node']}");

                case "cross_machine_edge":
                    print(f"{time_str} [{machine}] Cross-machine edge to "
                          f"[{event['to_machine']}] via {event['edge_type']}");
            }
        }
        print("=====================================\n");
    }
}

// Remote debugging session
obj RemoteDebugSession {
    has session_id: str;
    has target_machines: list[str];
    has debug_port: int = 5678;

    can attach_to_walker(walker_id: str, machine_id: str) {
        // Establish remote debug connection
        let connection = establish_debug_connection(machine_id, self.debug_port);

        // Set remote breakpoints
        connection.set_breakpoint(
            walker_type="*",
            condition=f"self.id == '{walker_id}'"
        );

        // Start monitoring
        self.monitor_walker(connection, walker_id);
    }

    can monitor_walker(connection: any, walker_id: str) {
        while True {
            let event = connection.get_next_event();

            match event.type {
                case "breakpoint_hit":
                    print(f"Walker {walker_id} hit breakpoint on "
                          f"{event.machine_id} at {event.location}");
                    self.remote_inspect(connection, event);

                case "state_change":
                    print(f"Walker {walker_id} state changed: "
                          f"{event.property} = {event.new_value}");

                case "exception":
                    print(f"Walker {walker_id} raised {event.exception_type}: "
                          f"{event.message}");
                    self.analyze_remote_exception(connection, event);
            }
        }
    }
}

// Distributed assertion framework
walker DistributedAssertion {
    has assertions: list[callable] = [];
    has machine_results: dict = {};

    can add_assertion(name: str, check: callable) {
        self.assertions.append({"name": name, "check": check});
    }

    can verify_distributed_state with entry {
        let machine_id = here.__machine_id__;
        let results = [];

        for assertion in self.assertions {
            try {
                assertion["check"](here);
                results.append({
                    "name": assertion["name"],
                    "status": "passed",
                    "machine": machine_id
                });
            } except AssertionError as e {
                results.append({
                    "name": assertion["name"],
                    "status": "failed",
                    "machine": machine_id,
                    "error": str(e)
                });
            }
        }

        self.machine_results[machine_id] = results;

        // Continue to other machines
        visit [-->];
    }

    can report_results with `root exit {
        let total_passed = 0;
        let total_failed = 0;

        print("\n=== Distributed Assertion Results ===");
        for machine_id, results in self.machine_results.items() {
            print(f"\nMachine: {machine_id}");
            for result in results {
                if result["status"] == "passed" {
                    print(f"  ✓ {result['name']}");
                    total_passed += 1;
                } else {
                    print(f"  ✗ {result['name']}: {result['error']}");
                    total_failed += 1;
                }
            }
        }

        print(f"\nTotal: {total_passed} passed, {total_failed} failed");
        print("===================================\n");
    }
}
```

### Performance Profiling

```jac
// Performance profiler for walkers
walker PerformanceProfiler {
    has profile_data: dict = {};
    has _start_times: dict = {};

    can start_timer(operation: str) {
        self._start_times[operation] = time.perf_counter();
    }

    can stop_timer(operation: str) {
        if operation in self._start_times {
            elapsed = time.perf_counter() - self._start_times[operation];

            if operation not in self.profile_data {
                self.profile_data[operation] = {
                    "count": 0,
                    "total_time": 0.0,
                    "min_time": float('inf'),
                    "max_time": 0.0
                };
            }

            let stats = self.profile_data[operation];
            stats["count"] += 1;
            stats["total_time"] += elapsed;
            stats["min_time"] = min(stats["min_time"], elapsed);
            stats["max_time"] = max(stats["max_time"], elapsed);

            del self._start_times[operation];
        }
    }

    can profile_ability(ability_name: str) -> callable {
        can profiled_ability(original_ability: callable) -> callable {
            can wrapper(*args, **kwargs) {
                self.start_timer(ability_name);
                try {
                    result = original_ability(*args, **kwargs);
                    return result;
                } finally {
                    self.stop_timer(ability_name);
                }
            }
            return wrapper;
        }
        return profiled_ability;
    }

    can generate_report with `root exit {
        print("\n=== Performance Profile ===");
        print(f"{'Operation':<30} {'Count':<10} {'Total(s)':<10} "
              f"{'Avg(ms)':<10} {'Min(ms)':<10} {'Max(ms)':<10}");
        print("-" * 80);

        for op, stats in self.profile_data.items() {
            avg_ms = (stats["total_time"] / stats["count"]) * 1000;
            print(f"{op:<30} {stats['count']:<10} "
                  f"{stats['total_time']:<10.3f} {avg_ms:<10.2f} "
                  f"{stats['min_time']*1000:<10.2f} "
                  f"{stats['max_time']*1000:<10.2f}");
        }
        print("========================\n");
    }
}

// Memory profiler
walker MemoryProfiler {
    has snapshots: list = [];
    has track_types: list[type] = [node, edge, walker];

    can take_snapshot(label: str) {
        import:py gc;
        import:py sys;

        gc.collect();  // Force garbage collection

        let snapshot = {
            "label": label,
            "timestamp": now(),
            "total_objects": 0,
            "by_type": {},
            "memory_usage": self.get_memory_usage()
        };

        for obj in gc.get_objects() {
            obj_type = type(obj);
            if any(isinstance(obj, t) for t in self.track_types) {
                type_name = obj_type.__name__;
                if type_name not in snapshot["by_type"] {
                    snapshot["by_type"][type_name] = {
                        "count": 0,
                        "size": 0
                    };
                }
                snapshot["by_type"][type_name]["count"] += 1;
                snapshot["by_type"][type_name]["size"] += sys.getsizeof(obj);
                snapshot["total_objects"] += 1;
            }
        }

        self.snapshots.append(snapshot);
    }

    can get_memory_usage -> dict {
        import:py psutil;
        import:py os;

        process = psutil.Process(os.getpid());
        mem_info = process.memory_info();

        return {
            "rss": mem_info.rss,  // Resident Set Size
            "vms": mem_info.vms,  // Virtual Memory Size
            "percent": process.memory_percent()
        };
    }

    can compare_snapshots(label1: str, label2: str) {
        let snap1 = [s for s in self.snapshots if s["label"] == label1][0];
        let snap2 = [s for s in self.snapshots if s["label"] == label2][0];

        print(f"\n=== Memory Comparison: {label1} → {label2} ===");

        // Overall memory change
        let mem_diff = snap2["memory_usage"]["rss"] - snap1["memory_usage"]["rss"];
        print(f"Memory change: {mem_diff / 1024 / 1024:.2f} MB");

        // Object count changes
        print("\nObject count changes:");
        let all_types = set(snap1["by_type"].keys()) | set(snap2["by_type"].keys());

        for type_name in sorted(all_types) {
            let count1 = snap1["by_type"].get(type_name, {}).get("count", 0);
            let count2 = snap2["by_type"].get(type_name, {}).get("count", 0);
            let diff = count2 - count1;

            if diff != 0 {
                print(f"  {type_name}: {count1} → {count2} ({diff:+})");
            }
        }
        print("================================\n");
    }
}
```

### Error Diagnostics

```jac
// Enhanced error reporting
obj ErrorDiagnostics {
    has error_handlers: dict[type, callable] = {};
    has context_collectors: list[callable] = [];

    can register_handler(error_type: type, handler: callable) {
        self.error_handlers[error_type] = handler;
    }

    can add_context_collector(collector: callable) {
        self.context_collectors.append(collector);
    }

    can diagnose(error: Exception, context: dict = {}) -> dict {
        let diagnosis = {
            "error_type": type(error).__name__,
            "message": str(error),
            "timestamp": now(),
            "context": context,
            "stack_trace": get_detailed_stack_trace(),
            "suggestions": []
        };

        // Collect additional context
        for collector in self.context_collectors {
            try {
                additional_context = collector(error, context);
                diagnosis["context"].update(additional_context);
            } except Exception as e {
                diagnosis["context"][f"collector_error_{collector.__name__}"] = str(e);
            }
        }

        // Run specific handler if available
        error_type = type(error);
        if error_type in self.error_handlers {
            let handler_result = self.error_handlers[error_type](error, diagnosis);
            diagnosis["suggestions"].extend(handler_result.get("suggestions", []));
            diagnosis["probable_cause"] = handler_result.get("probable_cause");
        }

        return diagnosis;
    }
}

// Graph-specific error diagnostics
can diagnose_graph_errors(error: Exception, context: dict) -> dict {
    let result = {"suggestions": []};

    match type(error) {
        case NodeNotFoundError:
            result["probable_cause"] = "Attempting to access non-existent node";
            result["suggestions"] = [
                "Check if node was deleted",
                "Verify node creation completed",
                "Check for race conditions in concurrent access"
            ];

        case CircularDependencyError:
            result["probable_cause"] = "Circular reference detected in graph";
            result["suggestions"] = [
                "Use cycle detection before traversal",
                "Implement maximum depth limit",
                "Consider using visited set"
            ];

        case CrossMachineError:
            result["probable_cause"] = "Failed cross-machine operation";
            result["suggestions"] = [
                "Check network connectivity",
                "Verify remote machine availability",
                "Check for version mismatches",
                "Enable distributed tracing"
            ];
    }

    return result;
}

// Automatic error reporting
walker ErrorReporter {
    has diagnostics: ErrorDiagnostics;
    has report_endpoint: str?;

    can __init__ {
        self.diagnostics = ErrorDiagnostics();
        self.diagnostics.register_handler(GraphError, diagnose_graph_errors);
    }

    can safe_traverse with entry {
        try {
            // Normal traversal
            self.process_node();
            visit [-->];

        } except Exception as e {
            // Diagnose error
            let diagnosis = self.diagnostics.diagnose(e, {
                "walker_type": type(self).__name__,
                "node_type": type(here).__name__,
                "node_id": here.__id__ if hasattr(here, "__id__") else None,
                "machine_id": here.__machine_id__ if hasattr(here, "__machine_id__") else None
            });

            // Report error
            self.report_error(diagnosis);

            // Decide whether to continue
            if self.should_continue_after_error(e) {
                visit [-->] else {
                    report {"error": diagnosis};
                    disengage;
                };
            } else {
                disengage;
            }
        }
    }

    can report_error(diagnosis: dict) {
        // Log locally
        print(f"\n🔴 Error Diagnostic Report");
        print(f"Type: {diagnosis['error_type']}");
        print(f"Message: {diagnosis['message']}");

        if diagnosis.get("probable_cause") {
            print(f"Probable Cause: {diagnosis['probable_cause']}");
        }

        if diagnosis["suggestions"] {
            print("Suggestions:");
            for suggestion in diagnosis["suggestions"] {
                print(f"  • {suggestion}");
            }
        }

        // Send to monitoring service if configured
        if self.report_endpoint {
            send_error_report(self.report_endpoint, diagnosis);
        }
    }
}
```

### Summary

This chapter covered comprehensive testing and debugging strategies for Jac applications:

### Testing Framework
- **Built-in Tests**: First-class `test` blocks with assertions
- **Graph Testing**: Specialized utilities for structure verification
- **Walker Testing**: Simulating traversals and verifying behavior
- **Mock Framework**: Isolating components for unit testing

### Debugging Techniques
- **Traversal Visualization**: Understanding walker paths
- **State Inspection**: Interactive debugging and property tracking
- **Distributed Debugging**: Cross-machine tracing and correlation
- **Performance Profiling**: Identifying bottlenecks and optimization opportunities

### Best Practices
1. **Test at Multiple Levels**: Unit, integration, and system tests
2. **Use Visualization**: Graph structure and traversal paths
3. **Profile Early**: Identify performance issues before scaling
4. **Embrace Distributed Debugging**: Essential for production systems
5. **Automate Error Reporting**: Comprehensive diagnostics for rapid fixes

These tools and techniques ensure that Jac applications are robust, performant, and maintainable at any scale, from development to global deployment.