### Chapter 2: Setting Up Your Jac Environment

#### 2.1 Installation and Setup

Getting started with Jac is straightforward, especially for Python developers. Jac provides multiple installation methods and integrates well with familiar development tools.

#### Installing Jac Compiler and Runtime

##### Method 1: Using pip (Recommended)

```bash
# Install the latest stable version
pip install jaclang

# Verify installation
jac --version
# Output: Jac 0.7.19 (or current version)

# Install with development tools
pip install jaclang[dev]
```

##### Method 2: From Source

```bash
# Clone the repository
git clone https://github.com/Jaseci-Labs/jaclang.git
cd jaclang

# Install in development mode
pip install -e .

# Run tests to verify
python -m pytest
```

##### Method 3: Docker Container

```dockerfile
# Dockerfile for Jac development
FROM python:3.10-slim

RUN pip install jaclang
WORKDIR /app

# Copy your Jac files
COPY . .

CMD ["jac", "run", "main.jac"]
```

```bash
# Build and run
docker build -t my-jac-app .
docker run -it my-jac-app
```

#### System Requirements

- **Python**: 3.10 or higher (Jac compiles to Python)
- **Memory**: 4GB RAM minimum, 8GB recommended
- **OS**: Linux, macOS, Windows (WSL recommended)
- **Storage**: 500MB for Jac + dependencies

#### IDE Support and Extensions

#### Visual Studio Code (Recommended)

Install the official Jac extension for syntax highlighting, auto-completion, and debugging:

```bash
# Install via VS Code marketplace
code --install-extension jaseci.jac-lang
```

**Features:**
- Syntax highlighting for `.jac` files
- IntelliSense for Jac keywords and types
- Integrated debugging support
- Graph visualization for nodes and edges
- Automatic formatting

#### JetBrains IDEs (PyCharm, IntelliJ)

```xml
<!-- Add to your .idea/fileTypes.xml -->
<component name="FileTypeManager">
  <extensionMap>
    <mapping pattern="*.jac" type="Python" />
    <mapping pattern="*.impl.jac" type="Python" />
    <mapping pattern="*.test.jac" type="Python" />
  </extensionMap>
</component>
```

#### Vim/Neovim

```vim
" Add to your .vimrc or init.vim
autocmd BufRead,BufNewFile *.jac set filetype=python
autocmd BufRead,BufNewFile *.jac set syntax=python

" Better: Install jac.vim plugin
Plug 'jaseci-labs/jac.vim'
```

#### Project Structure Conventions

Jac projects follow a structured organization that supports its unique features like implementation separation:

```
my-jac-project/
│
├── src/
│   ├── main.jac                 # Main entry point
│   ├── models/
│   │   ├── user.jac            # User node definition
│   │   ├── user.impl.jac       # User implementation
│   │   └── user.test.jac       # User tests
│   │
│   ├── walkers/
│   │   ├── auth.jac            # Authentication walkers
│   │   └── auth.impl/          # Implementation folder
│   │       ├── login.impl.jac
│   │       └── register.impl.jac
│   │
│   └── edges/
│       └── relationships.jac    # Edge definitions
│
├── tests/
│   ├── integration/
│   └── unit/
│
├── data/                        # Persistent data (auto-generated)
│   └── .jac_db/                # Jac's persistence layer
│
├── jac.toml                     # Project configuration
└── README.md
```

#### jac.toml Configuration

```toml
[project]
name = "my-jac-project"
version = "0.1.0"
description = "A Jac application"

[runtime]
persist_path = "./data/.jac_db"
log_level = "INFO"
enable_distributed = false

[build]
target = "optimized"  # or "debug"
include_tests = false

[dependencies]
# External Jac modules
```

#### Environment Setup

#### Development Environment Variables

```bash
# .env file
JAC_PERSIST_PATH=./data/.jac_db
JAC_LOG_LEVEL=DEBUG
JAC_USER_CONTEXT=development
JAC_ENABLE_METRICS=true
```

#### Python Virtual Environment (Recommended)

```bash
# Create virtual environment
python -m venv jac-env

# Activate it
# On Unix/macOS:
source jac-env/bin/activate
# On Windows:
jac-env\Scripts\activate

# Install Jac in the virtual environment
pip install jaclang
```

#### 2.2 Your First Jac Program

Let's create your first Jac program and understand the key differences from Python.

#### Hello World Comparison: Python vs Jac

#### Python Version

```python
# hello.py
def greet(name):
    return f"Hello, {name}!"

if __name__ == "__main__":
    message = greet("World")
    print(message)
```

#### Jac Version

```jac
# hello.jac
can greet(name: str) -> str {
    return f"Hello, {name}!";
}

with entry {
    message = greet("World");
    print(message);
}
```

Key differences:
1. **Function declaration**: `can` instead of `def`
2. **Type annotations**: Required in Jac (`name: str`)
3. **Semicolons**: Required for statements
4. **Entry point**: `with entry` instead of `if __name__ == "__main__"`
5. **Curly braces**: Instead of indentation

#### Understanding Entry Blocks

Entry blocks are Jac's way of organizing executable code at the module level:

```jac
# module_demo.jac

# Imports (similar to Python)
import:py from datetime { datetime }
import:py random;

# Global variables must be declared
glob start_time: str = datetime.now().isoformat();
let config: dict = {"debug": true};

# Function definitions
can setup_application() -> bool {
    print(f"Application started at {start_time}");
    return true;
}

# Classes (called objects in Jac)
obj Application {
    has name: str;
    has version: str = "1.0.0";

    can display_info {
        print(f"{self.name} v{self.version}");
    }
}

# Entry block - code that runs when module executes
with entry {
    print("=== Jac Module Demo ===");

    if setup_application() {
        app = Application(name="MyApp");
        app.display_info();
    }
}

# Named entry block - alternative entry point
with entry:cli {
    print("Running from CLI entry point");
    # Different initialization for CLI mode
}
```

#### Your First Object-Spatial Program

Let's create a simple but complete object-spatial program:

```jac
# social_hello.jac

# Define a Person node
node Person {
    has name: str;
    has joined: str;
}

# Define a Knows edge
edge Knows {
    has since: str;
}

# Define a Greeter walker
walker Greeter {
    has greeting_count: int = 0;

    # Ability triggered when entering a Person node
    can greet with Person entry {
        print(f"Hello, {here.name}! You joined on {here.joined}");
        self.greeting_count += 1;

        # Visit all people this person knows
        visit [-->:Knows:];
    }

    # Ability triggered when walker finishes
    can summarize with `root exit {
        print(f"\nGreeted {self.greeting_count} people total!");
    }
}

# Main program
with entry {
    # Create a small social network
    person1 = Person(name="Alice", joined="2024-01-15");
    person2 = Person(name="Bob", joined="2024-02-20");
    person3 = Person(name="Charlie", joined="2024-03-10");

    # Connect to root for persistence
    root ++> person1;

    # Create relationships
    person1 ++>:Knows(since="2024-02-01"):++> person2;
    person2 ++>:Knows(since="2024-03-01"):++> person3;

    # Spawn walker to greet everyone
    greeter = Greeter();
    root spawn greeter;
}
```

#### Running and Testing Jac Programs

#### Basic Execution

```bash
# Run a Jac file
jac run hello.jac

# Run with specific entry point
jac run module_demo.jac:cli

# Run with debugging
jac run --debug social_hello.jac
```

#### Interactive Mode (REPL)

```bash
# Start Jac REPL
jac shell

# In the REPL:
> let x = 42;
> print(x * 2);
84
> node TestNode { has value: int; }
> n = TestNode(value=100);
> print(n.value);
100
```

#### Testing Your Programs

```jac
# test_hello.jac

import:jac from hello { greet }

test "greet function works correctly" {
    assert greet("Jac") == "Hello, Jac!";
    assert greet("") == "Hello, !";
}

test "greet with special characters" {
    assert greet("世界") == "Hello, 世界!";
    assert greet("O'Brien") == "Hello, O'Brien!";
}

# Run tests
# Command: jac test test_hello.jac
```

#### Debugging Techniques

```jac
# debug_example.jac

walker DebugWalker {
    has visited_nodes: list = [];

    can walk with entry {
        # Debug print statements
        print(f"[DEBUG] Entering node: {here}");
        print(f"[DEBUG] Node type: {type(here)}");

        # Inspect node properties
        ::py::
        import pprint
        print("[DEBUG] Node properties:")
        pprint.pprint(here.__dict__)
        ::py::

        self.visited_nodes.append(here);

        # Conditional debugging
        if len(self.visited_nodes) > 10 {
            print("[WARNING] Visited more than 10 nodes!");
            disengage;  # Stop walker
        }

        visit [-->];
    }
}

# Enable verbose logging
with entry {
    import:py logging;
    logging.basicConfig(level=logging.DEBUG);

    # Your code here
}
```

#### Building a Complete Example

Let's build a simple todo list application that showcases basic Jac features:

```jac
# todo_app.jac

import:py from datetime { datetime }
import:py json;

# Define our data structures
node TodoList {
    has name: str;
    has created_at: str;
}

node TodoItem {
    has title: str;
    has completed: bool = false;
    has created_at: str;
    has due_date: str = "";
}

edge Contains;
edge NextItem;

# Walker to add new todos
walker AddTodo {
    has title: str;
    has due_date: str = "";

    can add with TodoList entry {
        new_item = here ++>:Contains:++> TodoItem(
            title=self.title,
            created_at=datetime.now().isoformat(),
            due_date=self.due_date
        );

        # Link to previous items
        last_item = [-->:Contains:-->:TodoItem:][-2:];
        if last_item {
            last_item[0] ++>:NextItem:++> new_item;
        }

        report f"Added: {self.title}";
    }
}

# Walker to list todos
walker ListTodos {
    has show_completed: bool = false;
    has items: list = [];

    can collect with TodoList entry {
        for item in [-->:Contains:-->:TodoItem:] {
            if not item.completed or self.show_completed {
                self.items.append({
                    "title": item.title,
                    "completed": item.completed,
                    "created": item.created_at,
                    "due": item.due_date
                });
            }
        }
    }

    can display with `root exit {
        print("\n=== Todo List ===");
        for i, item in enumerate(self.items) {
            status = "✓" if item["completed"] else "○";
            due = f" (due: {item['due']})" if item["due"] else "";
            print(f"{i+1}. {status} {item['title']}{due}");
        }
        print(f"\nTotal: {len(self.items)} items\n");
    }
}

# Walker to complete todos
walker CompleteTodo {
    has item_index: int;

    can complete with TodoList entry {
        items = [-->:Contains:-->:TodoItem:];
        if 0 <= self.item_index < len(items) {
            items[self.item_index].completed = true;
            report f"Completed: {items[self.item_index].title}";
        } else {
            report "Invalid item index!";
        }
    }
}

# Main program
with entry {
    # Create or get existing todo list
    lists = root[-->:TodoList:];

    if not lists {
        print("Creating new todo list...");
        my_list = root ++> TodoList(
            name="My Tasks",
            created_at=datetime.now().isoformat()
        );
    } else {
        my_list = lists[0];
        print("Loading existing todo list...");
    }

    # Example: Add some todos
    spawn AddTodo(title="Learn Jac basics", due_date="2024-12-31") on my_list;
    spawn AddTodo(title="Build first Jac app") on my_list;
    spawn AddTodo(title="Master object-spatial programming") on my_list;

    # List all todos
    spawn ListTodos(show_completed=true) on my_list;
}

# CLI entry point
with entry:add {
    import:py sys;
    if len(sys.argv) < 3 {
        print("Usage: jac run todo_app.jac:add 'Task title' [due_date]");
        exit(1);
    }

    title = sys.argv[2];
    due_date = sys.argv[3] if len(sys.argv) > 3 else "";

    lists = root[-->:TodoList:];
    if lists {
        spawn AddTodo(title=title, due_date=due_date) on lists[0];
        spawn ListTodos() on lists[0];
    }
}
```

### Running the Todo App

```bash
# First run - creates the list
jac run todo_app.jac

# Add a new todo via CLI
jac run todo_app.jac:add "Buy groceries" "2024-12-25"

# Run again - todos persist!
jac run todo_app.jac
```

#### Development Workflow

```mermaid
graph TD
    A[Write Jac Code] --> B{Syntax Valid?}
    B -->|No| C[Fix Syntax Errors]
    C --> A
    B -->|Yes| D[Run Tests]
    D --> E{Tests Pass?}
    E -->|No| F[Debug & Fix]
    F --> A
    E -->|Yes| G[Run Program]
    G --> H{Works as Expected?}
    H -->|No| I[Debug with Logging]
    I --> A
    H -->|Yes| J[Deploy/Share]

    style A fill:#e3f2fd
    style D fill:#e8f5e9
    style G fill:#fff9c4
    style J fill:#c8e6c9
```

#### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| `ModuleNotFoundError` | Ensure Jac is installed: `pip install jaclang` |
| `SyntaxError: Missing semicolon` | Add `;` at end of statements |
| `TypeError: Missing type annotation` | Add type hints to all function parameters |
| `RuntimeError: No entry point` | Add `with entry { ... }` block |
| `PersistenceError` | Check write permissions for `JAC_PERSIST_PATH` |

#### Next Steps

Now that you have Jac installed and have written your first programs, you're ready to dive deeper into the language. In the next chapter, we'll explore how Jac's syntax relates to Python and learn about the enhanced features that make Jac powerful for modern application development.

Try modifying the todo app to add new features:
- Add priority levels to todos
- Implement due date notifications
- Create categories for todos
- Add a search walker to find specific items

Remember: every Jac program you write is automatically persistent and ready for multi-user scenarios. The same todo app could serve thousands of users without any code changes - that's the power of scale-agnostic programming!