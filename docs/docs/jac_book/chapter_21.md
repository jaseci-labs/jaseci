### Chapter 21: Best Practices

#### 21.1 Code Organization

Organizing Jac code effectively is crucial for maintainability and team collaboration. Jac's unique features like implementation separation and object-spatial constructs require thoughtful organization strategies.

### Project Structure Best Practices

#### Standard Project Layout
```
my-jac-project/
│
├── src/
│   ├── main.jac                    # Entry point and root configuration
│   │
│   ├── models/                     # Data models (nodes and objects)
│   │   ├── __init__.jac           # Module exports
│   │   ├── user.jac               # User node definition
│   │   ├── user.impl.jac          # User implementation
│   │   ├── user.test.jac          # User tests
│   │   ├── content.jac            # Content nodes
│   │   └── analytics.jac          # Analytics nodes
│   │
│   ├── edges/                      # Edge definitions
│   │   ├── __init__.jac
│   │   ├── social.jac             # Social relationship edges
│   │   ├── ownership.jac          # Ownership edges
│   │   └── workflow.jac           # Workflow transition edges
│   │
│   ├── walkers/                    # Walker definitions
│   │   ├── __init__.jac
│   │   ├── auth/                  # Authentication walkers
│   │   │   ├── login.jac
│   │   │   ├── register.jac
│   │   │   └── permissions.jac
│   │   ├── analytics/             # Analytics walkers
│   │   │   ├── metrics.jac
│   │   │   └── reports.jac
│   │   └── workflows/             # Business process walkers
│   │       ├── order.jac
│   │       └── approval.jac
│   │
│   ├── abilities/                  # Shared abilities
│   │   ├── validation.jac         # Validation abilities
│   │   ├── transformation.jac     # Data transformation
│   │   └── notification.jac       # Notification handling
│   │
│   ├── lib/                       # Utility libraries
│   │   ├── helpers.jac            # Helper functions
│   │   ├── constants.jac          # Global constants
│   │   └── types.jac              # Custom type definitions
│   │
│   └── api/                       # API entry points
│       ├── rest.jac               # REST API walkers
│       ├── graphql.jac            # GraphQL resolvers
│       └── websocket.jac          # WebSocket handlers
│
├── tests/
│   ├── unit/                      # Unit tests
│   ├── integration/               # Integration tests
│   └── fixtures/                  # Test data and fixtures
│
├── scripts/                       # Utility scripts
│   ├── migrate.jac               # Data migration
│   ├── seed.jac                  # Database seeding
│   └── analyze.jac               # Performance analysis
│
├── docs/                         # Documentation
│   ├── api.md                    # API documentation
│   ├── architecture.md           # Architecture decisions
│   └── deployment.md             # Deployment guide
│
├── config/                       # Configuration files
│   ├── development.toml          # Dev environment config
│   ├── production.toml           # Production config
│   └── test.toml                 # Test environment config
│
├── .jac_db/                      # Local persistence (git-ignored)
├── .gitignore
├── jac.toml                      # Project configuration
└── README.md
```

### Module Organization

#### Clear Module Boundaries
```jac
# models/__init__.jac
# Export public interfaces clearly

# Public exports
export { User, UserProfile } from .user;
export { Post, Comment } from .content;
export { Analytics } from .analytics;

# Internal implementations stay private
# Don't export implementation details
```

#### Cohesive Module Design
```jac
# Good: Cohesive module with related functionality
# walkers/order/processing.jac

node OrderState;
edge OrderTransition;

walker ProcessOrder {
    has order_id: str;
    # Order processing logic
}

walker ValidateOrder {
    has validation_rules: list;
    # Order validation logic
}

walker NotifyOrderStatus {
    has notification_channels: list;
    # Order notification logic
}
```

#### Avoid Circular Dependencies
```jac
# Bad: Circular dependency
# user.jac
import from .post { Post };  # Post imports User!

# Good: Use interfaces or separate common types
# types.jac
obj IUser {
    has id: str;
    has name: str;
}

obj IPost {
    has id: str;
    has author_id: str;
}

# user.jac
import from .types { IUser, IPost };
```

### Implementation Separation Strategy

#### When to Separate Implementations
```jac
# api/user.jac - Interface definitions
walker GetUser {
    has user_id: str;
    has include_posts: bool = false;

    can retrieve with entry;
    can format_response -> dict;
}

walker UpdateUser {
    has user_id: str;
    has updates: dict;

    can validate -> bool;
    can update with entry;
}

# api/user.impl.jac - Implementations
impl GetUser {
    can retrieve with entry {
        user = find_user_by_id(self.user_id);
        if not user {
            report {"error": "User not found"};
            disengage;
        }

        visit user;
    }

    can format_response -> dict {
        # Complex formatting logic
        return {
            "id": self.user_data.id,
            "name": self.user_data.name,
            # ... more formatting
        };
    }
}
```

#### Implementation File Organization
```
walkers/
├── analytics.jac              # Interfaces
├── analytics.impl/            # Implementation directory
│   ├── metrics.impl.jac      # Metrics implementations
│   ├── reports.impl.jac      # Report implementations
│   └── visualization.impl.jac # Visualization implementations
└── analytics.test/            # Test directory
    ├── metrics.test.jac
    └── reports.test.jac
```

### Graph Structure Organization

#### Logical Node Grouping
```jac
# models/social_graph.jac
# Group related node types together

# User-related nodes
node User {
    has username: str;
    has email: str;
}

node UserProfile {
    has bio: str;
    has avatar_url: str;
}

node UserSettings {
    has notifications_enabled: bool;
    has privacy_level: str;
}

# Relationship edges
edge Follows(User, User);
edge ProfileOf(UserProfile, User);
edge SettingsOf(UserSettings, User);
```

#### Hierarchical Graph Organization
```jac
# Create a clear graph hierarchy
with entry {
    # Root level - major categories
    root ++> users_root = UsersRoot();
    root ++> content_root = ContentRoot();
    root ++> analytics_root = AnalyticsRoot();

    # Users subtree
    users_root ++> active_users = ActiveUsers();
    users_root ++> inactive_users = InactiveUsers();

    # Content subtree
    content_root ++> posts = Posts();
    content_root ++> comments = Comments();
    content_root ++> media = Media();
}
```

#### 21.2 Naming Conventions

Consistent naming conventions make Jac code more readable and maintainable. Follow these guidelines adapted from Python's PEP 8 with Jac-specific additions.

### General Naming Rules

| Element | Convention | Example |
|---------|------------|---------|
| Files | `snake_case.jac` | `user_management.jac` |
| Modules | `snake_case` | `import from auth_helpers` |
| Objects/Nodes/Edges | `PascalCase` | `UserProfile`, `FriendshipEdge` |
| Walkers | `PascalCase` + verb | `ProcessOrder`, `ValidateUser` |
| Functions/Abilities | `snake_case` | `calculate_total`, `validate_input` |
| Variables | `snake_case` | `user_count`, `is_active` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| Type aliases | `PascalCase` | `UserId`, `Timestamp` |

### Archetype-Specific Conventions

#### Node Naming
```jac
# Nodes represent entities - use nouns
node User { }              # Good
node ProcessUser { }       # Bad - sounds like an action

node OrderItem { }         # Good
node ItemInOrder { }       # Awkward - avoid

# For state nodes, include "State" suffix
node PendingState { }      # Clear it's a state
node Pending { }           # Ambiguous
```

#### Edge Naming
```jac
# Edges represent relationships - use descriptive names
edge Follows(User, User);        # Good - clear relationship
edge UserUser(User, User);       # Bad - unclear relationship

edge AuthoredBy(Post, User);     # Good - directional clarity
edge PostUser(Post, User);       # Bad - ambiguous

# For typed relationships, be specific
edge Manages(Employee, Employee);     # Good if clear
edge DirectlyManages(Employee, Employee);  # Better - more specific
```

#### Walker Naming
```jac
# Walkers perform actions - use verb phrases
walker ValidateOrder { }      # Good - clear action
walker OrderValidator { }     # Acceptable alternative
walker Order { }             # Bad - sounds like a node

# Be specific about the action
walker CalculateMonthlyRevenue { }  # Good - specific
walker Calculate { }                # Bad - too vague

# For multi-step processes, use descriptive names
walker ProcessAndShipOrder { }      # Clear workflow
walker OrderWorkflow { }            # Acceptable but less clear
```

#### Ability Naming
```jac
# Entry/exit abilities describe triggers
can validate_data with entry { }     # Good - what happens
can on_entry with entry { }         # Bad - redundant

can cleanup with exit { }           # Good - clear purpose
can exit_handler with exit { }     # Redundant

# Action abilities use verb phrases
can calculate_total -> float { }    # Good
can get_total -> float { }         # Good - getter pattern
can total -> float { }             # Ambiguous
```

### Variable Naming Patterns

#### Boolean Variables
```jac
# Use is_, has_, can_, should_ prefixes
has is_active: bool = true;
has has_permission: bool = false;
has can_edit: bool = true;
has should_notify: bool = false;

# Avoid negative names
has is_enabled: bool = true;     # Good
has is_not_disabled: bool = true; # Bad - double negative
```

#### Collection Variables
```jac
# Use plural forms
has users: list[User] = [];
has active_user_ids: set[str] = {};
has user_by_email: dict[str, User] = {};

# For single items, use singular
has current_user: User;
has selected_item: Item;
```

#### Counter and Index Variables
```jac
# Use descriptive names for loop variables
for user in users { }           # Good
for u in users { }             # Avoid single letters

# Exceptions: i, j, k for numeric indices
for i = 0 to i < len(items) by i += 1 { }  # Acceptable

# Use descriptive counters
has retry_count: int = 0;      # Good
has count: int = 0;           # Too vague
```

### Special Naming Cases

#### Private Members
```jac
# Use leading underscore for internal use
obj DatabaseConnection {
    has :priv _connection: any;
    has :priv _is_connected: bool = false;

    can connect {
        self._connection = establish_connection();
        self._is_connected = true;
    }
}
```

#### Test Naming
```jac
# Test names should describe what they test
test "user can follow another user" { }          # Good
test "test_follow" { }                          # Less descriptive

test "order total calculates correctly with tax" { }  # Good
test "test_calculation" { }                          # Vague
```

#### Entry Point Naming
```jac
# Use descriptive entry point names
with entry:web_server { }     # Clear purpose
with entry:cli { }           # Clear purpose
with entry:main { }          # Generic but acceptable
with entry:entry1 { }        # Bad - meaningless
```

#### 21.3 Documentation Standards

Well-documented Jac code is essential for maintainability and team collaboration. Follow these standards for comprehensive documentation.

### Module-Level Documentation

```jac
"""
User Management Module

This module provides core functionality for user creation, authentication,
and profile management in the application.

Key Components:
- User node: Represents a user account
- UserProfile node: Extended user information
- Authentication walkers: Handle login/logout flows
- Profile management walkers: Update user information

Usage Example:
    spawn CreateUser(
        email="user@example.com",
        username="johndoe"
    ) on root;

Dependencies:
- auth_lib: For password hashing
- email_service: For sending notifications
"""

import from auth_lib { hash_password, verify_password };
import from email_service { send_email };
```

### Archetype Documentation

#### Node Documentation
```jac
"""
Represents a user in the system.

The User node is the central entity for authentication and identification.
It connects to UserProfile for extended information and to various content
nodes for user-generated content.

Attributes:
    id (str): Unique identifier (auto-generated)
    username (str): Unique username for login
    email (str): User's email address
    created_at (str): ISO timestamp of account creation
    is_active (bool): Whether the account is active
    last_login (str): ISO timestamp of last successful login

Relationships:
    - ProfileOf: One-to-one with UserProfile
    - Authored: One-to-many with Post nodes
    - Follows: Many-to-many with other User nodes

Example:
    user = User(
        username="johndoe",
        email="john@example.com"
    );
    root ++> user;
"""
node User {
    has id: str by postinit;
    has username: str;
    has email: str;
    has created_at: str by postinit;
    has is_active: bool = true;
    has last_login: str = "";

    can postinit {
        import:py uuid;
        import:py from datetime { datetime };
        self.id = str(uuid.uuid4());
        self.created_at = datetime.now().isoformat();
    }
}
```

#### Walker Documentation
```jac
"""
Authenticates a user with email and password.

This walker handles the complete authentication flow including:
- Input validation
- Password verification
- Session creation
- Login tracking

The walker reports authentication results and creates a session
edge if successful.

Attributes:
    email (str): User's email address
    password (str): Plain text password to verify
    create_session (bool): Whether to create a session (default: true)

Reports:
    On success:
        {
            "success": true,
            "user_id": str,
            "session_id": str,
            "message": "Login successful"
        }

    On failure:
        {
            "success": false,
            "error": str,
            "message": str
        }

Example:
    result = spawn LoginUser(
        email="user@example.com",
        password="secure123"
    ) on root;
"""
walker LoginUser {
    has email: str;
    has password: str;
    has create_session: bool = true;

    can validate_input -> bool {
        """Validates email format and password presence."""
        # Implementation
    }

    can authenticate with entry {
        """Main authentication logic."""
        # Implementation
    }
}
```

### Ability Documentation

```jac
can calculate_compound_interest(
    principal: float,
    rate: float,
    time: float,
    compounds_per_year: int = 12
) -> float {
    """
    Calculate compound interest.

    Uses the formula: A = P(1 + r/n)^(nt)

    Args:
        principal: Initial amount
        rate: Annual interest rate (as decimal, e.g., 0.05 for 5%)
        time: Time period in years
        compounds_per_year: Number of times interest compounds per year

    Returns:
        float: Final amount after compound interest

    Example:
        >>> calculate_compound_interest(1000, 0.05, 2)
        1104.94
    """
    return principal * (1 + rate/compounds_per_year) ** (compounds_per_year * time);
}
```

### Inline Documentation

```jac
walker ComplexProcessor {
    has threshold: float = 0.8;
    has max_iterations: int = 100;

    can process with entry {
        # Initialize processing metrics
        metrics = {
            "processed": 0,
            "skipped": 0,
            "errors": 0
        };

        # Phase 1: Validate all nodes
        # This ensures data integrity before processing
        validation_results = self.validate_all_nodes();

        if not validation_results["valid"] {
            # Early exit if validation fails
            # Log details for debugging
            log_validation_errors(validation_results["errors"]);
            report {"error": "Validation failed", "details": validation_results};
            disengage;
        }

        # Phase 2: Process nodes in priority order
        # High-priority nodes are processed first to ensure
        # critical data is handled even if we hit limits
        priority_queue = self.build_priority_queue();

        # ... more processing
    }
}
```

### API Documentation

```jac
"""
REST API Endpoints for User Management

All endpoints require authentication unless otherwise noted.
Authentication is done via Bearer token in the Authorization header.

Endpoints:
    POST   /users           - Create new user (no auth required)
    GET    /users/:id       - Get user details
    PUT    /users/:id       - Update user
    DELETE /users/:id       - Delete user
    GET    /users/:id/posts - Get user's posts

Error Responses:
    All endpoints may return these error codes:
    - 400: Bad Request - Invalid input data
    - 401: Unauthorized - Missing or invalid auth token
    - 403: Forbidden - Insufficient permissions
    - 404: Not Found - Resource doesn't exist
    - 500: Internal Server Error
"""

walker CreateUserAPI {
    """
    POST /users

    Create a new user account.

    Request Body:
        {
            "email": "user@example.com",    // required, valid email
            "username": "johndoe",          // required, 3-20 chars
            "password": "secure123",        // required, min 8 chars
            "full_name": "John Doe"         // optional
        }

    Response:
        201 Created
        {
            "id": "uuid",
            "email": "user@example.com",
            "username": "johndoe",
            "created_at": "2024-01-01T00:00:00Z"
        }

    Errors:
        400: Invalid input data
        409: Email or username already exists
    """
    has email: str;
    has username: str;
    has password: str;
    has full_name: str = "";
}
```

### Documentation Generation

```jac
# Use docstring extraction tools
walker DocumentationGenerator {
    has output_format: str = "markdown";

    can generate with entry {
        # Extract all docstrings from nodes
        for node_type in get_all_node_types() {
            doc = extract_docstring(node_type);
            if doc {
                self.format_and_save(node_type.__name__, doc);
            }
        }

        # Extract walker documentation
        for walker_type in get_all_walker_types() {
            doc = extract_docstring(walker_type);
            if doc {
                self.format_and_save(walker_type.__name__, doc);
            }
        }
    }
}
```

### Best Practices Summary

1. **Consistency is Key**
   - Stick to chosen conventions throughout the project
   - Document conventions in a CONTRIBUTING.md file
   - Use linters and formatters to enforce standards

2. **Clear Module Boundaries**
   - Each module should have a single, clear purpose
   - Minimize inter-module dependencies
   - Use explicit exports to control module interfaces

3. **Meaningful Names**
   - Names should convey purpose without needing comments
   - Avoid abbreviations except well-known ones
   - Update names when functionality changes

4. **Comprehensive Documentation**
   - Document "why" not just "what"
   - Include examples in docstrings
   - Keep documentation up-to-date with code changes

5. **Thoughtful Organization**
   - Group related functionality together
   - Separate concerns clearly
   - Make the codebase navigable for newcomers

Following these best practices will make your Jac code more maintainable, understandable, and enjoyable to work with for your entire team.

# Learning Path Recommendations

### For Quick Start (Chapters 1-3, 6-8)

If you need to get productive with Jac quickly, this accelerated path covers the essentials in about 1-2 weeks of focused learning.

##### Week 1: Foundations and Setup

**Day 1-2: Understanding Jac (Chapter 1)**
- Read about the paradigm shift from "data to computation" to "computation to data"
- Understand why graph structures matter
- Learn about scale-agnostic programming benefits
- **Exercise**: Write a comparison of how you'd model a social network in Python vs Jac

**Day 3-4: Environment Setup (Chapter 2)**
- Install Jac and set up your development environment
- Create your first "Hello World" program
- Build the todo list application
- **Exercise**: Modify the todo app to add priority levels to tasks

**Day 5-7: Core Syntax (Chapter 3)**
- Master the syntax differences from Python
- Learn about mandatory type annotations
- Understand entry blocks and control flow
- Practice with pipe operators
- **Exercise**: Convert a simple Python script to Jac

##### Week 2: Object-Spatial Basics

**Day 8-9: Object-Spatial Concepts (Chapter 6)**
- Understand nodes, edges, and walkers
- Learn the difference between objects and nodes
- Grasp the concept of computation moving to data
- **Exercise**: Design a graph structure for a problem you're familiar with

**Day 10-11: Building Graphs (Chapter 7)**
- Create nodes and connect them with edges
- Learn edge reference syntax
- Master graph navigation patterns
- **Exercise**: Build a simple family tree graph

**Day 12-14: Walkers in Action (Chapter 8)**
- Create your first walker
- Understand spawn and visit operations
- Learn about walker abilities
- Master traversal patterns
- **Exercise**: Build a walker that finds all descendants in your family tree

### Quick Start Project

Build a simple contact management system:
```jac
node Contact {
    has name: str;
    has email: str;
    has phone: str;
}

edge Knows {
    has context: str;  # "work", "family", "friend"
}

walker FindConnections {
    has context_filter: str;
    has max_depth: int = 2;
    has connections: list = [];

    can search with Contact entry {
        # Find all connections of a specific type
        for edge in [-->:Knows:] {
            if edge.context == self.context_filter {
                self.connections.append(edge.target);
            }
        }
        report self.connections;
    }
}
```

### Success Criteria
You should be able to:
- ✓ Set up a Jac development environment
- ✓ Understand the basic object-spatial concepts
- ✓ Create simple graphs with nodes and edges
- ✓ Write walkers that traverse graphs
- ✓ Convert simple Python logic to Jac

#### Next Steps
- Continue to Chapter 4-5 for advanced language features
- Jump to Chapter 10 if you need persistence immediately
- Explore Chapter 17 for real-world examples

---

### For Full Migration (All chapters)

This comprehensive path is designed for teams or individuals planning to fully migrate from Python to Jac. Expect 2-3 months for complete mastery.

##### Month 1: Language Mastery

**Week 1-2: Foundations (Chapters 1-5)**
- Complete the Quick Start path
- Deep dive into Jac's type system
- Master object-oriented features
- Learn implementation separation
- **Project**: Convert a small Python application to Jac

**Week 3-4: Object-Spatial Programming (Chapters 6-9)**
- Master all archetype types
- Understand abilities vs methods
- Learn advanced traversal patterns
- Study bidirectional computation
- **Project**: Build a workflow engine using state machines

##### Month 2: Scale and Distribution

**Week 5-6: Scale-Agnostic Features (Chapters 10-13)**
- Understand the root node and persistence
- Master multi-user patterns
- Learn walker-as-API patterns
- Study distribution concepts
- **Project**: Convert single-user app to multi-user

**Week 7-8: Advanced Patterns (Chapters 14-16)**
- Master concurrent programming with walkers
- Learn advanced type system features
- Study design patterns in Jac
- Understand testing strategies
- **Project**: Build a distributed task processing system

##### Month 3: Real-World Application

**Week 9-10: Case Studies (Chapter 17)**
- Study the social network implementation
- Understand the workflow engine patterns
- Learn microservices in Jac
- **Project**: Design your own case study

**Week 11-12: Migration and Optimization (Chapters 18-19)**
- Plan migration strategy for existing Python codebase
- Learn incremental adoption techniques
- Master performance optimization
- Study monitoring and profiling
- **Project**: Create migration plan for your Python application

### Comprehensive Learning Project

Build a complete e-commerce platform:

1. **User Management** (Week 2)
   ```jac
   node Customer {
       has email: str;
       has verified: bool = false;
   }

   node Merchant {
       has business_name: str;
       has rating: float = 0.0;
   }
   ```

2. **Product Catalog** (Week 3)
   ```jac
   node Product {
       has name: str;
       has price: float;
       has inventory: int;
   }

   edge Sells(Merchant, Product) {
       has since: str;
       has commission_rate: float;
   }
   ```

3. **Order Processing** (Week 4)
   ```jac
   walker ProcessOrder {
       has items: list[dict];

       can validate with entry {
           # Check inventory
           # Verify payment
           # Create order
       }
   }
   ```

4. **Multi-User Scaling** (Week 6)
   ```jac
   walker CustomerDashboard {
       # Automatically scoped to current user's root
       can get_orders with entry {
           orders = root[-->:Order:];
           report orders;
       }
   }
   ```

5. **API Layer** (Week 7)
   ```jac
   walker:api CreateProduct {
       has name: str;
       has price: float;
       has description: str;

       can create with entry {
           # REST API endpoint
           # Automatic parameter validation
           # Returns JSON response
       }
   }
   ```

### Success Criteria
You should be able to:
- ✓ Architect complete applications in Jac
- ✓ Migrate Python applications incrementally
- ✓ Build scalable, multi-user systems
- ✓ Optimize performance for large graphs
- ✓ Deploy distributed Jac applications

### Certification Path
Consider building and open-sourcing:
1. A Jac library/framework
2. A migration tool for Python→Jac
3. A complete application case study

---

### For Specific Use Cases

### Web Services Focus (Chapters 10-12)

**2-Week Intensive Path**

**Week 1: Multi-User Foundations**
- Day 1-2: Understanding root nodes and persistence (Ch 10)
- Day 3-4: Multi-user patterns and isolation (Ch 11)
- Day 5-7: Walkers as API endpoints (Ch 12)

**Week 2: Building Services**
- Day 8-9: REST API patterns
- Day 10-11: WebSocket integration
- Day 12-14: Complete service project

**Sample Web Service Project**
```jac
# Real-time chat service
node ChatRoom {
    has name: str;
    has created_at: str;
}

node Message {
    has content: str;
    has timestamp: str;
}

edge InRoom(User, ChatRoom);
edge Posted(User, Message);
edge Contains(ChatRoom, Message);

walker:api SendMessage {
    has room_id: str;
    has content: str;

    can send with entry {
        # Find room and user
        room = find_room(self.room_id);

        # Create message
        msg = Message(
            content=self.content,
            timestamp=timestamp_now()
        );

        # Connect relationships
        root ++>:Posted:++> msg;
        room ++>:Contains:++> msg;

        # Notify room members
        spawn NotifyRoomMembers(message=msg) on room;

        report {"success": true, "message_id": msg.id};
    }
}

walker:websocket MessageStream {
    has room_id: str;

    can stream with ChatRoom entry {
        # Send existing messages
        for msg in [-->:Contains:-->][-20:] {
            yield msg.to_json();
        }

        # Wait for new messages
        while true {
            new_msg = wait_for_new_message(here);
            yield new_msg.to_json();
        }
    }
}
```

### Distributed Systems Focus (Chapters 13, 19)

**3-Week Advanced Path**

**Week 1: Distribution Concepts**
- Understanding topology-aware distribution
- Cross-machine edge traversal
- Distributed walker patterns

**Week 2: Implementation**
- Partitioning strategies
- Consistency patterns
- Fault tolerance

**Week 3: Optimization**
- Minimizing network traversals
- Caching strategies
- Monitoring distributed performance

**Distributed System Project**
```jac
# Distributed task processing
node TaskQueue {
    has name: str;
    has priority: int;
}

node Task {
    has id: str;
    has payload: dict;
    has status: str = "pending";
    has assigned_worker: str = "";
}

edge Queued(TaskQueue, Task) {
    has queued_at: str;
}

walker:distributed TaskWorker {
    has worker_id: str;
    has capabilities: list[str];

    can claim_task with TaskQueue entry {
        # Find unclaimed task matching capabilities
        for task in [-->:Queued:-->] {
            if task.status == "pending" and
               task.matches_capabilities(self.capabilities) {
                # Atomic claim operation
                if atomic_claim(task, self.worker_id) {
                    spawn ProcessTask(task=task) on task;
                    return;
                }
            }
        }
    }
}

walker ProcessTask {
    has task: Task;

    can process with Task entry {
        try {
            # Process task
            result = execute_task(here.payload);
            here.status = "completed";
            here.result = result;

            # Notify completion
            spawn TaskCompleted(task_id=here.id) on root;
        } except as e {
            here.status = "failed";
            here.error = str(e);

            # Retry logic
            spawn RetryTask(task=here) on root;
        }
    }
}
```

### Data Processing Focus (Chapters 8-9, 15)

**2-Week Specialized Path**

**Week 1: Graph Algorithms**
- Graph traversal patterns
- Data aggregation with walkers
- Stream processing patterns

**Week 2: Advanced Processing**
- Map-reduce with walkers
- Pipeline architectures
- Real-time analytics

**Data Processing Project**
```jac
# Real-time analytics pipeline
node DataSource {
    has source_type: str;
    has config: dict;
}

node DataPoint {
    has timestamp: str;
    has metrics: dict;
    has processed: bool = false;
}

walker StreamProcessor {
    has buffer: list = [];
    has buffer_size: int = 100;

    can process with DataPoint entry {
        if here.processed {
            return;
        }

        # Add to buffer
        self.buffer.append(here);
        here.processed = true;

        # Process when buffer full
        if len(self.buffer) >= self.buffer_size {
            self.flush_buffer();
        }

        # Continue to next data point
        visit [-->];
    }

    can flush_buffer {
        # Aggregate metrics
        aggregated = aggregate_metrics(self.buffer);

        # Store results
        result_node = root ++> AggregatedMetrics(
            timestamp=timestamp_now(),
            data=aggregated,
            point_count=len(self.buffer)
        );

        # Clear buffer
        self.buffer = [];

        # Trigger downstream processing
        spawn DownstreamAnalytics() on result_node;
    }
}

walker RealTimeAlerting {
    has alert_rules: list[dict];

    can check with AggregatedMetrics entry {
        for rule in self.alert_rules {
            if evaluate_rule(rule, here.data) {
                spawn SendAlert(
                    rule=rule,
                    metrics=here.data
                ) on root;
            }
        }
    }
}
```

### Learning Resources by Path

**Quick Start Resources**
- Official Jac tutorials
- Interactive playground
- Quick reference card
- Community Discord

**Full Migration Resources**
- Migration guide and tools
- Architecture patterns book
- Performance tuning guide
- Case study repository

**Web Services Resources**
- REST API templates
- GraphQL integration guide
- WebSocket examples
- Authentication patterns

**Distributed Systems Resources**
- Distribution patterns guide
- Consistency models in Jac
- Monitoring and observability
- Fault tolerance patterns

**Data Processing Resources**
- Graph algorithms library
- Streaming patterns guide
- Analytics templates
- Visualization integration

### Assessment Checkpoints

**Week 2 Check**: Can you build a basic graph application?
**Week 4 Check**: Can you implement complex traversal patterns?
**Week 8 Check**: Can you build a multi-user application?
**Week 12 Check**: Can you optimize and scale your application?

### Community Learning

Join the Jac community for accelerated learning:
- **Discord**: Real-time help and discussions
- **GitHub**: Contribute to open source projects
- **Forums**: Share your learning journey
- **Meetups**: Local and virtual events

Remember: The best learning path is the one that matches your goals and timeline. Start with Quick Start if you need immediate productivity, or commit to Full Migration if you're planning a significant transition. Either way, the Jac community is here to support your journey from Python to the future of programming!