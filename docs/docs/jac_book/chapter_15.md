### Chapter 15: Design Patterns in Jac

This chapter explores design patterns that leverage Jac's unique features—object-spatial programming, scale-agnostic architecture, and topological computation. These patterns provide reusable solutions to common problems while taking full advantage of Jac's paradigm shift from moving data to computation to moving computation to data.

#### 15.1 Graph Patterns

### Tree Structures

Trees are fundamental in Jac, but unlike traditional implementations, they leverage the natural parent-child relationships through edges:

```jac
// Generic tree node
node TreeNode {
    has value: any;
    has level: int = 0;
}

edge ChildOf {
    has position: int;  // For ordered children
}

// Binary tree specialization
node BinaryNode(TreeNode) {
    has max_children: int = 2;
}

edge LeftChild(ChildOf) {
    has position: int = 0;
}

edge RightChild(ChildOf) {
    has position: int = 1;
}

// Tree operations as walkers
walker TreeBuilder {
    has values: list[any];
    has build_binary: bool = true;

    can build_level_order with entry {
        if not self.values {
            return;
        }

        let queue: list[node] = [here];
        let index = 0;

        while queue and index < len(self.values) {
            let current = queue.pop(0);

            # Add children based on tree type
            if self.build_binary {
                # Left child
                if index < len(self.values) {
                    left = current ++>:LeftChild:++> BinaryNode(
                        value=self.values[index],
                        level=current.level + 1
                    );
                    queue.append(left);
                    index += 1;
                }

                # Right child
                if index < len(self.values) {
                    right = current ++>:RightChild:++> BinaryNode(
                        value=self.values[index],
                        level=current.level + 1
                    );
                    queue.append(right);
                    index += 1;
                }
            } else {
                # N-ary tree: add all available values as children
                let children_count = min(3, len(self.values) - index);
                for i in range(children_count) {
                    child = current ++>:ChildOf(position=i):++> TreeNode(
                        value=self.values[index],
                        level=current.level + 1
                    );
                    queue.append(child);
                    index += 1;
                }
            }
        }
    }
}

// Tree traversal patterns
walker TreeTraverser {
    has order: str = "inorder";  // preorder, inorder, postorder, levelorder
    has result: list = [];

    can traverse with BinaryNode entry {
        match self.order {
            case "preorder":
                self.result.append(here.value);
                self.visit_children();

            case "inorder":
                self.visit_left();
                self.result.append(here.value);
                self.visit_right();

            case "postorder":
                self.visit_children();
                self.result.append(here.value);

            case "levelorder":
                self.level_order_traverse();
        }
    }

    can visit_left {
        let left_edges = [-->:LeftChild:];
        if left_edges {
            visit left_edges[0];
        }
    }

    can visit_right {
        let right_edges = [-->:RightChild:];
        if right_edges {
            visit right_edges[0];
        }
    }

    can visit_children {
        visit [-->:ChildOf:] ordered by edge.position;
    }

    can level_order_traverse {
        let queue: list[node] = [here];

        while queue {
            let current = queue.pop(0);
            self.result.append(current.value);

            # Add children to queue
            let children = [current -->:ChildOf:] ordered by edge.position;
            queue.extend(children);
        }
    }
}

// Advanced tree algorithms
walker TreeAlgorithms {
    can find_height with TreeNode entry -> int {
        let children = [-->:ChildOf:];
        if not children {
            return 0;
        }

        let max_height = 0;
        for child in children {
            let height = spawn TreeAlgorithms().find_height on child;
            max_height = max(max_height, height);
        }

        return max_height + 1;
    }

    can is_balanced with BinaryNode entry -> bool {
        let left_height = 0;
        let right_height = 0;

        let left = [-->:LeftChild:];
        if left {
            left_height = spawn TreeAlgorithms().find_height on left[0];
        }

        let right = [-->:RightChild:];
        if right {
            right_height = spawn TreeAlgorithms().find_height on right[0];
        }

        # Check balance condition
        if abs(left_height - right_height) > 1 {
            return false;
        }

        # Check subtrees
        for child in [-->:ChildOf:] {
            if not spawn TreeAlgorithms().is_balanced on child {
                return false;
            }
        }

        return true;
    }
}
```

### Circular Graphs

Circular graphs require special handling to prevent infinite traversal:

```jac
// Circular linked list pattern
node CircularNode {
    has value: any;
    has is_head: bool = false;
}

edge NextInCircle {
    has traversal_count: int = 0;
}

walker CircularBuilder {
    has values: list[any];

    can build with entry {
        if not self.values {
            return;
        }

        # Mark head
        here.is_head = true;
        here.value = self.values[0];

        # Build chain
        let current = here;
        for i in range(1, len(self.values)) {
            let next_node = current ++>:NextInCircle:++> CircularNode(
                value=self.values[i]
            );
            current = next_node;
        }

        # Close the circle
        current ++>:NextInCircle:++> here;
    }
}

walker CircularTraverser {
    has max_iterations: int = 1;
    has visited_values: list = [];
    has iteration_count: int = 0;

    can traverse with CircularNode entry {
        # Check if we've completed enough iterations
        if here.is_head {
            self.iteration_count += 1;
            if self.iteration_count > self.max_iterations {
                report self.visited_values;
                disengage;
            }
        }

        self.visited_values.append(here.value);

        # Continue to next
        visit [-->:NextInCircle:];
    }
}

// Cycle detection using Floyd's algorithm
walker CycleDetector {
    has slow_ptr: node? = None;
    has fast_ptr: node? = None;
    has cycle_found: bool = false;
    has cycle_start: node? = None;

    can detect_cycle with entry {
        self.slow_ptr = here;
        self.fast_ptr = here;

        # Phase 1: Detect if cycle exists
        while True {
            # Move slow pointer one step
            let slow_next = [self.slow_ptr -->];
            if not slow_next {
                report {"has_cycle": false};
                disengage;
            }
            self.slow_ptr = slow_next[0];

            # Move fast pointer two steps
            let fast_next_1 = [self.fast_ptr -->];
            if not fast_next_1 {
                report {"has_cycle": false};
                disengage;
            }
            self.fast_ptr = fast_next_1[0];

            let fast_next_2 = [self.fast_ptr -->];
            if not fast_next_2 {
                report {"has_cycle": false};
                disengage;
            }
            self.fast_ptr = fast_next_2[0];

            # Check if pointers meet
            if self.slow_ptr == self.fast_ptr {
                self.cycle_found = true;
                break;
            }
        }

        # Phase 2: Find cycle start
        self.slow_ptr = here;
        while self.slow_ptr != self.fast_ptr {
            self.slow_ptr = [self.slow_ptr -->][0];
            self.fast_ptr = [self.fast_ptr -->][0];
        }

        self.cycle_start = self.slow_ptr;

        # Phase 3: Find cycle length
        let cycle_length = 1;
        self.fast_ptr = [self.slow_ptr -->][0];
        while self.fast_ptr != self.slow_ptr {
            self.fast_ptr = [self.fast_ptr -->][0];
            cycle_length += 1;
        }

        report {
            "has_cycle": true,
            "cycle_start": self.cycle_start,
            "cycle_length": cycle_length
        };
    }
}
```

### Hierarchical Organizations

Hierarchical structures are natural in Jac, supporting multiple hierarchy types:

```jac
// Organizational hierarchy
node Person {
    has name: str;
    has title: str;
    has department: str;
    has level: int = 0;
}

edge ReportsTo {
    has direct: bool = true;
}

edge BelongsTo {
    has role: str;
}

node Department {
    has name: str;
    has budget: float;
    has parent_dept: Department? = None;
}

edge SubdepartmentOf;

// Build organizational chart
walker OrgBuilder {
    has org_data: dict;

    can build with entry {
        # Create departments first
        let depts = {};
        for dept_name, dept_info in self.org_data["departments"].items() {
            let dept = root ++> Department(
                name=dept_name,
                budget=dept_info["budget"]
            );
            depts[dept_name] = dept;

            # Link to parent department
            if "parent" in dept_info {
                let parent = depts[dept_info["parent"]];
                dept ++>:SubdepartmentOf:++> parent;
                dept.parent_dept = parent;
            }
        }

        # Create people and relationships
        let people = {};
        for person_data in self.org_data["people"] {
            let person = root ++> Person(
                name=person_data["name"],
                title=person_data["title"],
                department=person_data["department"]
            );
            people[person_data["name"]] = person;

            # Link to department
            person ++>:BelongsTo(role=person_data["title"]):++>
                depts[person_data["department"]];

            # Link to manager
            if "manager" in person_data {
                person ++>:ReportsTo:++> people[person_data["manager"]];
            }
        }
    }
}

// Hierarchical queries
walker OrgAnalyzer {
    can find_all_reports with Person entry -> list[Person] {
        let direct_reports = [<--:ReportsTo(direct=true):];
        let all_reports = list(direct_reports);

        # Recursively find indirect reports
        for report in direct_reports {
            let indirect = spawn OrgAnalyzer().find_all_reports on report;
            all_reports.extend(indirect);
        }

        return all_reports;
    }

    can calculate_dept_headcount with Department entry -> dict {
        let stats = {
            "department": here.name,
            "direct_employees": 0,
            "total_employees": 0,
            "subdepartments": {}
        };

        # Count direct employees
        let direct = [<--:BelongsTo:];
        stats["direct_employees"] = len(direct);
        stats["total_employees"] = len(direct);

        # Include subdepartment counts
        let subdepts = [<--:SubdepartmentOf:];
        for subdept in subdepts {
            let subdept_stats = spawn OrgAnalyzer()
                .calculate_dept_headcount on subdept;
            stats["subdepartments"][subdept.name] = subdept_stats;
            stats["total_employees"] += subdept_stats["total_employees"];
        }

        return stats;
    }
}

// Matrix organization support
edge CollaboratesWith {
    has project: str;
    has role: str;
}

walker MatrixAnalyzer {
    has project_name: str;

    can find_project_team with entry {
        let team = [];
        let to_visit = [root];
        let visited = set();

        while to_visit {
            let current = to_visit.pop();
            if current in visited {
                continue;
            }
            visited.add(current);

            # Check if person is on project
            let collabs = [current <-->:CollaboratesWith:];
            for collab in collabs {
                if collab.project == self.project_name {
                    team.append({
                        "person": current,
                        "role": collab.role
                    });
                }
            }

            # Add connections to visit
            to_visit.extend([current <-->:CollaboratesWith:-->]);
        }

        report team;
    }
}
```

#### 15.2 Walker Patterns

### Visitor Pattern Reimagined

The classic Visitor pattern becomes natural in Jac, with walkers as visitors:

```jac
// Abstract syntax tree nodes
node ASTNode {
    has node_type: str;
}

node BinaryOp(ASTNode) {
    has operator: str;
}

node UnaryOp(ASTNode) {
    has operator: str;
}

node Literal(ASTNode) {
    has value: any;
}

edge LeftOperand;
edge RightOperand;
edge Operand;

// Different visitor walkers for different operations
walker Evaluator {
    has variables: dict[str, any] = {};

    can evaluate with Literal entry -> any {
        return here.value;
    }

    can evaluate with BinaryOp entry -> any {
        let left_val = spawn Evaluator(variables=self.variables)
            .evaluate on [-->:LeftOperand:][0];
        let right_val = spawn Evaluator(variables=self.variables)
            .evaluate on [-->:RightOperand:][0];

        match here.operator {
            case "+": return left_val + right_val;
            case "-": return left_val - right_val;
            case "*": return left_val * right_val;
            case "/": return left_val / right_val;
            case _: raise ValueError(f"Unknown operator: {here.operator}");
        }
    }

    can evaluate with UnaryOp entry -> any {
        let operand_val = spawn Evaluator(variables=self.variables)
            .evaluate on [-->:Operand:][0];

        match here.operator {
            case "-": return -operand_val;
            case "!": return not operand_val;
            case _: raise ValueError(f"Unknown operator: {here.operator}");
        }
    }
}

walker PrettyPrinter {
    has indent_level: int = 0;
    has indent_str: str = "  ";

    can print_ast with ASTNode entry -> str {
        let indent = self.indent_str * self.indent_level;

        match here {
            case Literal:
                return f"{indent}Literal({here.value})";

            case BinaryOp:
                let result = f"{indent}BinaryOp({here.operator})\n";

                # Print children with increased indent
                let printer = PrettyPrinter(
                    indent_level=self.indent_level + 1,
                    indent_str=self.indent_str
                );

                result += spawn printer.print_ast on [-->:LeftOperand:][0];
                result += "\n";
                result += spawn printer.print_ast on [-->:RightOperand:][0];

                return result;

            case UnaryOp:
                let result = f"{indent}UnaryOp({here.operator})\n";

                let printer = PrettyPrinter(
                    indent_level=self.indent_level + 1,
                    indent_str=self.indent_str
                );

                result += spawn printer.print_ast on [-->:Operand:][0];

                return result;
        }
    }
}

// Type checker visitor
walker TypeChecker {
    has type_env: dict[str, str] = {};
    has errors: list[str] = [];

    can check with ASTNode entry -> str? {
        match here {
            case Literal:
                return type(here.value).__name__;

            case BinaryOp:
                let left_type = spawn TypeChecker(type_env=self.type_env)
                    .check on [-->:LeftOperand:][0];
                let right_type = spawn TypeChecker(type_env=self.type_env)
                    .check on [-->:RightOperand:][0];

                if left_type != right_type {
                    self.errors.append(
                        f"Type mismatch in {here.operator}: {left_type} vs {right_type}"
                    );
                }

                # Determine result type
                match here.operator {
                    case "+" | "-" | "*" | "/":
                        return left_type;  # Assuming numeric
                    case "<" | ">" | "==" | "!=":
                        return "bool";
                }

            case UnaryOp:
                let operand_type = spawn TypeChecker(type_env=self.type_env)
                    .check on [-->:Operand:][0];

                match here.operator {
                    case "-": return operand_type;
                    case "!": return "bool";
                }
        }
    }
}
```

### Map-Reduce with Walkers

Map-reduce patterns become intuitive with walker-based distribution:

```jac
// Generic map-reduce framework
node DataPartition {
    has data: list[any];
    has partition_id: int;
}

node ResultCollector {
    has results: dict = {};
    has expected_partitions: int;
    has reducer: callable;
}

walker MapWorker {
    has mapper: callable;
    has collector: ResultCollector;

    can map_partition with DataPartition entry {
        # Apply mapper to each item
        let mapped = [self.mapper(item) for item in here.data];

        # Send to collector
        visit self.collector {
            :synchronized: {
                here.results[here.partition_id] = mapped;

                # Check if all partitions complete
                if len(here.results) == here.expected_partitions {
                    # Trigger reduction
                    spawn ReduceWorker() on here;
                }
            }
        };
    }
}

walker ReduceWorker {
    can reduce with ResultCollector entry {
        # Flatten all mapped results
        let all_results = [];
        for partition_results in here.results.values() {
            all_results.extend(partition_results);
        }

        # Apply reducer
        let final_result = here.reducer(all_results);

        report final_result;
    }
}

// Word count example
walker WordCounter {
    can count_words(text: str) -> dict[str, int] {
        # Partition text
        let lines = text.split('\n');
        let chunk_size = max(1, len(lines) // 4);  # 4 partitions

        # Create partitions
        let partitions = [];
        for i in range(0, len(lines), chunk_size) {
            let partition = root ++> DataPartition(
                data=lines[i:i+chunk_size],
                partition_id=len(partitions)
            );
            partitions.append(partition);
        }

        # Create collector with reducer
        let collector = root ++> ResultCollector(
            expected_partitions=len(partitions),
            reducer=lambda results: self.merge_word_counts(results)
        );

        # Spawn mappers
        for partition in partitions {
            spawn MapWorker(
                mapper=lambda line: self.count_line_words(line),
                collector=collector
            ) on partition;
        }

        # Wait for result
        return wait_for_result(collector);
    }

    can count_line_words(line: str) -> dict[str, int] {
        let counts = {};
        for word in line.split() {
            word = word.lower().strip('.,!?";');
            counts[word] = counts.get(word, 0) + 1;
        }
        return counts;
    }

    can merge_word_counts(count_dicts: list[dict]) -> dict[str, int] {
        let total = {};
        for counts in count_dicts {
            for word, count in counts.items() {
                total[word] = total.get(word, 0) + count;
            }
        }
        return total;
    }
}
```

### Pipeline Processing

Pipeline patterns for streaming data through transformation stages:

```jac
// Pipeline stage definition
node PipelineStage {
    has name: str;
    has transform: callable;
    has error_handler: callable? = None;
}

edge NextStage {
    has condition: callable? = None;  // Optional routing condition
}

// Data packet flowing through pipeline
walker DataPacket {
    has data: any;
    has metadata: dict = {};
    has trace: list[str] = [];

    can flow with PipelineStage entry {
        self.trace.append(here.name);

        try {
            # Transform data
            self.data = here.transform(self.data);
            self.metadata[f"{here.name}_processed"] = now();

            # Find next stage(s)
            let next_stages = [-->:NextStage:];

            if not next_stages {
                # End of pipeline
                report {
                    "data": self.data,
                    "metadata": self.metadata,
                    "trace": self.trace
                };
                disengage;
            }

            # Route to appropriate next stage
            for edge in next_stages {
                if edge.condition is None or edge.condition(self.data) {
                    visit edge.target;
                    break;  # Take first matching route
                }
            }

        } except Exception as e {
            if here.error_handler {
                self.data = here.error_handler(self.data, e);
                self.metadata[f"{here.name}_error"] = str(e);
                # Continue to next stage
                visit [-->:NextStage:];
            } else {
                # Propagate error
                report {
                    "error": str(e),
                    "stage": here.name,
                    "trace": self.trace
                };
                disengage;
            }
        }
    }
}

// Pipeline builder
walker PipelineBuilder {
    has stages: list[dict];

    can build with entry -> PipelineStage {
        let previous: PipelineStage? = None;
        let first_stage: PipelineStage? = None;

        for stage_def in self.stages {
            let stage = here ++> PipelineStage(
                name=stage_def["name"],
                transform=stage_def["transform"],
                error_handler=stage_def.get("error_handler")
            );

            if previous {
                # Connect stages
                if "condition" in stage_def {
                    previous ++>:NextStage(condition=stage_def["condition"]):++> stage;
                } else {
                    previous ++>:NextStage:++> stage;
                }
            } else {
                first_stage = stage;
            }

            previous = stage;
        }

        return first_stage;
    }
}

// Example: Data processing pipeline
with entry {
    # Define pipeline stages
    let pipeline_def = [
        {
            "name": "validation",
            "transform": lambda d: validate_data(d),
            "error_handler": lambda d, e: {"data": d, "validation_error": str(e)}
        },
        {
            "name": "normalization",
            "transform": lambda d: normalize_data(d)
        },
        {
            "name": "enrichment",
            "transform": lambda d: enrich_with_metadata(d)
        },
        {
            "name": "classification",
            "transform": lambda d: classify_data(d)
        },
        {
            "name": "storage_router",
            "transform": lambda d: d,  # Pass through
            "condition": lambda d: d.get("priority") == "high"
        }
    ];

    # Build pipeline
    let pipeline_start = spawn PipelineBuilder(stages=pipeline_def).build on root;

    # Process data through pipeline
    let data_items = load_data_items();
    for item in data_items {
        spawn DataPacket(data=item) on pipeline_start;
    }
}
```

#### 15.3 Persistence Patterns

### Event Sourcing with Graphs

Event sourcing becomes natural when events are nodes in a temporal graph:

```jac
// Event base node
node Event {
    has event_id: str;
    has event_type: str;
    has timestamp: str;
    has data: dict;
    has aggregate_id: str;
}

edge NextEvent {
    has causal: bool = true;
}

edge AppliesTo;

// Aggregate root
node Aggregate {
    has aggregate_id: str;
    has aggregate_type: str;
    has version: int = 0;
    has current_state: dict = {};
}

// Event store
walker EventStore {
    has events_to_append: list[dict] = [];

    can append_events with Aggregate entry {
        let last_event: Event? = None;

        # Find the last event for this aggregate
        let existing_events = [<--:AppliesTo:];
        if existing_events {
            # Get the most recent event
            last_event = existing_events
                .sort(key=lambda e: e.timestamp)
                .last();
        }

        # Append new events
        for event_data in self.events_to_append {
            let event = here ++> Event(
                event_id=generate_id(),
                event_type=event_data["type"],
                timestamp=now(),
                data=event_data["data"],
                aggregate_id=here.aggregate_id
            );

            # Link to aggregate
            event ++>:AppliesTo:++> here;

            # Link to previous event
            if last_event {
                last_event ++>:NextEvent:++> event;
            }

            last_event = event;
            here.version += 1;
        }
    }
}

// Event replay
walker EventReplayer {
    has from_version: int = 0;
    has to_version: int? = None;
    has state: dict = {};

    can replay with Aggregate entry {
        # Get all events
        let events = [<--:AppliesTo:]
            .filter(lambda e: e.version >= self.from_version)
            .sort(key=lambda e: e.timestamp);

        if self.to_version {
            events = events.filter(lambda e: e.version <= self.to_version);
        }

        # Replay events to rebuild state
        for event in events {
            self.apply_event(event);
        }

        report self.state;
    }

    can apply_event(event: Event) {
        match event.event_type {
            case "UserCreated":
                self.state["user_id"] = event.data["user_id"];
                self.state["email"] = event.data["email"];

            case "EmailChanged":
                self.state["email"] = event.data["new_email"];

            case "UserDeactivated":
                self.state["active"] = false;

            # Add more event handlers
        }
    }
}

// Snapshot pattern
node Snapshot {
    has aggregate_id: str;
    has version: int;
    has state: dict;
    has timestamp: str;
}

edge SnapshotOf;

walker SnapshotManager {
    has snapshot_interval: int = 100;

    can create_snapshot with Aggregate entry {
        if here.version % self.snapshot_interval == 0 {
            # Replay events to get current state
            let state = spawn EventReplayer().replay on here;

            # Create snapshot
            let snapshot = here ++> Snapshot(
                aggregate_id=here.aggregate_id,
                version=here.version,
                state=state,
                timestamp=now()
            );

            snapshot ++>:SnapshotOf:++> here;
        }
    }

    can load_from_snapshot with Aggregate entry -> dict {
        # Find latest snapshot
        let snapshots = [<--:SnapshotOf:]
            .sort(key=lambda s: s.version);

        if snapshots {
            let latest_snapshot = snapshots.last();

            # Replay only events after snapshot
            return spawn EventReplayer(
                from_version=latest_snapshot.version + 1,
                state=latest_snapshot.state.copy()
            ).replay on here;
        } else {
            # No snapshot, replay all
            return spawn EventReplayer().replay on here;
        }
    }
}
```

### Temporal Data Modeling

Model time-varying data with temporal edges:

```jac
// Temporal node
node TemporalEntity {
    has entity_id: str;
    has entity_type: str;
}

// Temporal property edge
edge HadProperty {
    has property_name: str;
    has property_value: any;
    has valid_from: str;
    has valid_to: str? = None;  // None means currently valid
}

// Temporal relationship edge
edge WasRelatedTo {
    has relationship_type: str;
    has valid_from: str;
    has valid_to: str? = None;
}

// Temporal queries
walker TemporalQuery {
    has as_of_date: str;
    has property_name: str? = None;

    can get_properties_at_time with TemporalEntity entry -> dict {
        let properties = {};

        # Find all property edges valid at the given time
        let prop_edges = [<-->:HadProperty:];

        for edge in prop_edges {
            if edge.valid_from <= self.as_of_date {
                if edge.valid_to is None or edge.valid_to > self.as_of_date {
                    # Property was valid at the query time
                    if self.property_name is None or
                       edge.property_name == self.property_name {
                        properties[edge.property_name] = edge.property_value;
                    }
                }
            }
        }

        return properties;
    }

    can get_relationships_at_time with TemporalEntity entry -> list[dict] {
        let relationships = [];

        # Find all relationships valid at the given time
        let rel_edges = [<-->:WasRelatedTo:];

        for edge in rel_edges {
            if edge.valid_from <= self.as_of_date {
                if edge.valid_to is None or edge.valid_to > self.as_of_date {
                    relationships.append({
                        "type": edge.relationship_type,
                        "entity": edge.target if edge.source == here else edge.source,
                        "valid_from": edge.valid_from,
                        "valid_to": edge.valid_to
                    });
                }
            }
        }

        return relationships;
    }
}

// Temporal updates
walker TemporalUpdater {
    has property_name: str;
    has new_value: any;
    has effective_date: str;

    can update_property with TemporalEntity entry {
        # Find current property edge
        let current_edges = [<-->:HadProperty:]
            .filter(lambda e: e.property_name == self.property_name
                    and e.valid_to is None);

        # End current validity
        for edge in current_edges {
            edge.valid_to = self.effective_date;
        }

        # Create new property edge
        here ++>:HadProperty(
            property_name=self.property_name,
            property_value=self.new_value,
            valid_from=self.effective_date
        ):++> here;  # Self-edge for properties
    }
}

// Bi-temporal modeling (system time + valid time)
edge HadPropertyBitemporal {
    has property_name: str;
    has property_value: any;
    has valid_from: str;
    has valid_to: str? = None;
    has system_from: str = now();
    has system_to: str? = None;
}

walker BitemporalQuery {
    has valid_time: str;
    has system_time: str = now();

    can query with TemporalEntity entry -> dict {
        let properties = {};

        let edges = [<-->:HadPropertyBitemporal:];

        for edge in edges {
            # Check both temporal dimensions
            let valid_in_business_time = (
                edge.valid_from <= self.valid_time and
                (edge.valid_to is None or edge.valid_to > self.valid_time)
            );

            let valid_in_system_time = (
                edge.system_from <= self.system_time and
                (edge.system_to is None or edge.system_to > self.system_time)
            );

            if valid_in_business_time and valid_in_system_time {
                properties[edge.property_name] = edge.property_value;
            }
        }

        return properties;
    }
}
```

### Migration Strategies

Patterns for evolving graph schemas over time:

```jac
// Schema version tracking
node SchemaVersion {
    has version: int;
    has applied_at: str;
    has description: str;
}

edge MigratedFrom;

// Migration definition
node Migration {
    has from_version: int;
    has to_version: int;
    has up_script: callable;
    has down_script: callable;
}

// Migration runner
walker MigrationRunner {
    has target_version: int;
    has dry_run: bool = false;

    can run_migrations with entry {
        # Find current version
        let versions = [root -->:SchemaVersion:]
            .sort(key=lambda v: v.version);

        let current_version = 0;
        if versions {
            current_version = versions.last().version;
        }

        if current_version == self.target_version {
            report {"status": "already_at_target_version"};
            disengage;
        }

        # Find migrations to run
        let direction = "up" if self.target_version > current_version else "down";
        let migrations = self.find_migration_path(
            current_version,
            self.target_version,
            direction
        );

        # Run migrations
        for migration in migrations {
            if self.dry_run {
                print(f"Would run migration from v{migration.from_version} "
                      f"to v{migration.to_version}");
            } else {
                self.run_migration(migration, direction);
            }
        }
    }

    can run_migration(migration: Migration, direction: str) {
        print(f"Running {direction} migration: "
              f"v{migration.from_version} -> v{migration.to_version}");

        if direction == "up" {
            migration.up_script();

            # Record new version
            let new_version = root ++> SchemaVersion(
                version=migration.to_version,
                applied_at=now(),
                description=f"Migrated from v{migration.from_version}"
            );

            # Link versions
            let old_version = [root -->:SchemaVersion:]
                .filter(lambda v: v.version == migration.from_version)
                .first();

            if old_version {
                new_version ++>:MigratedFrom:++> old_version;
            }
        } else {
            migration.down_script();
            # Remove version record
            let version_node = [root -->:SchemaVersion:]
                .filter(lambda v: v.version == migration.from_version)
                .first();
            if version_node {
                del version_node;
            }
        }
    }
}

// Example migrations
can create_user_email_index_v1_to_v2() {
    # Add email index to all users
    walker AddEmailIndex {
        can add_index with User entry {
            if not hasattr(here, "email_index") {
                here.email_index = here.email.lower();
            }
            visit [-->];  # Process all users
        }
    }

    spawn AddEmailIndex() on root;
}

can add_user_roles_v2_to_v3() {
    # Add default role to all users
    walker AddDefaultRole {
        can add_role with User entry {
            if not hasattr(here, "roles") {
                here.roles = ["user"];
            }
            visit [-->];
        }
    }

    spawn AddDefaultRole() on root;
}

# Migration registry
with entry {
    # Register migrations
    let migrations = [
        Migration(
            from_version=1,
            to_version=2,
            up_script=create_user_email_index_v1_to_v2,
            down_script=lambda: remove_property_from_all(User, "email_index")
        ),
        Migration(
            from_version=2,
            to_version=3,
            up_script=add_user_roles_v2_to_v3,
            down_script=lambda: remove_property_from_all(User, "roles")
        )
    ];

    for mig in migrations {
        root ++> mig;
    }
}
```

### Summary

This chapter explored essential design patterns that leverage Jac's unique features:

### Graph Patterns
- **Tree Structures**: Natural parent-child relationships through edges
- **Circular Graphs**: Cycle detection and controlled traversal
- **Hierarchical Organizations**: Multi-dimensional hierarchies with matrix support

### Walker Patterns
- **Visitor Pattern**: Walkers as natural visitors with type-specific behaviors
- **Map-Reduce**: Distributed computation through walker parallelism
- **Pipeline Processing**: Stage-based transformation with error handling

### Persistence Patterns
- **Event Sourcing**: Events as nodes in temporal graphs
- **Temporal Data**: Time-varying properties and relationships
- **Migration Strategies**: Schema evolution with version tracking

These patterns demonstrate how Jac's paradigm shift—from moving data to computation to moving computation to data—creates elegant solutions to complex architectural challenges. The combination of topological thinking, scale-agnostic design, and walker-based computation enables patterns that would be cumbersome or impossible in traditional programming paradigms.

In the next chapter, we'll explore comprehensive testing and debugging techniques that ensure these patterns work correctly in production environments.