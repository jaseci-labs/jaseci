# Walkers - Computation in Motion



## What are Walkers?

Walkers are the beating heart of Object-Spatial Programming. They embody the paradigm shift from static functions to mobile computational entities that traverse your data graph, processing information where it lives. In this chapter, we'll master the art of creating and controlling walkers to build powerful, scalable algorithms.

```jac
walker SimpleVisitor {
    ...
}
```


### Walker State
State variables are declared using the `has` keyword and are used to store information about the walker's current status and context. They can include things like the current node, the path taken, and any other relevant data.

```jac
walker SimpleVisitor {
    has current_node: node = null;  # Current node being visited
    ...  # Other state variables
}
```

### Walker Abilities
Abilities are the methods that define what a walker can do. They are declared using the `can` keyword and can be triggered by events such as entering or exiting a node. Abilities can access both the walker's state and the current node's properties.


```jac
node SimpleNode {
    has name: str;
}

walker SimpleVisitor {
    has visited_nodes: list = [];  # List of nodes visited

    # Ability triggered when entering a node
    can visit with entry {
        self.visited_nodes.append(here);  # Add current node to visited list

        # Continue traversal to connected nodes
        visit [-->];
    }
}
```


## Traversal Patterns

The `visit` statement is how walkers move through the graph. It can be used to traverse all connected nodes, filter nodes by type, or even apply complex conditions.

```jac
node Node {
    has name: str;
    has priority: int = 0;  # Optional attribute for filtering
}

edge ImportantEdge {}

walker Explorer {
    has max_depth: int = 3;
    has current_depth: int = 0;

    can explore with entry {
        print(f"At depth {self.current_depth}: {here.name}");

        if self.current_depth < self.max_depth {
            # Visit all connected nodes
            visit [-->];

            # Filter nodes based on priority
            important_nodes = [-->](`?Node:priority > 5);
            visit important_nodes;

            # Or visit with type filtering
            visit [->:ImportantEdge:->];
        }
    }
}

with entry{
    print("Explorer example");

    # Create some nodes with a priority attribute
    n1 = Node(name="Node 1", priority=3);
    n2 = Node(name="Node 2", priority=7);
    n3 = Node(name="Node 3", priority=5);

    # Connect them
    n1 +>:ImportantEdge:+> n2;
    n2 +>:ImportantEdge:+> n3;

    # Start exploring
    explorer = Explorer(max_depth=2) spawn n1;
}
```

Use `disengage` to stop traversal immediately. This is useful for search algorithms or when a condition is met:

```jac
node SimpleNode {
    has name: str;
}

walker SearchWalker {
    has target_name: str;
    has found: bool = false;


    can search with entry {
        if here.name == self.target_name {
            print(f"Found target: {here.name}!");
            self.found = True;
            disengage;    # Stop searching
        }

        # Continue search if not found
        visit [-->];
    }
}
```

The `skip` statement ends processing at the current node but continues traversal:

```jac
walker ConditionalProcessor {
    has process_count: int = 0;
    has skip_count: int = 0;

    can process with entry {
        # Skip nodes that don't meet criteria
        if here.active == True {
            self.skip_count += 1;
            print(f"Skipping inactive node");
            skip;  # Move to next node without further processing
        }

        # do extra processing here
        ...
}
```

## Walker Abilities

### Entry and Exit Abilities

Abilities are event-driven methods that execute automatically, triggered by the walker entering or exiting a node. They allow walkers to react to their environment dynamically.

```jac
node Store {
    has name: str;
    has inventory: dict = {};
    has revenue: float = 0.0;
}

walker InventoryChecker {
    has low_stock_items: list = [];
    has total_value: float = 0.0;
    has stores_checked: int = 0;

    # Entry ability - main processing
    can check_inventory with Store entry {
        # execute all commands when entering a store
        ...
    }

    # Exit ability - cleanup or summary
    can summarize with Store exit {
        # Execute commands after visiting all stores
        ...
    }
}
```

## Summary

In this chapter, we've mastered walkers—the mobile computational entities that make Object-Spatial Programming unique:

- **Walker Basics**: Creating, spawning, and managing walker lifecycle
- **Traversal Control**: Using `visit`, `disengage`, and `skip` effectively
- **Walker Abilities**: Writing entry/exit abilities with proper context usage


Walkers transform static data structures into dynamic, reactive systems. They enable algorithms that naturally adapt to the shape and content of your data, scaling from simple traversals to complex distributed computations.

Next, we'll explore abilities in depth—the event-driven computation model that makes the interaction between walkers and nodes so powerful.