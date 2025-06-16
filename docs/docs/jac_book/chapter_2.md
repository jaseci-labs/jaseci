# Chapter 2: Environment Setup and First Program

<h2 style="color: orange; font-weight: bold;">Getting Your Development Environment Ready</h2>

In this chapter, we'll set up your Jac development environment and write your first programs. By the end, you'll have everything you need to start building with Jac.

## Installation Requirements

Before installing Jac, ensure you have:

- **Python 3.12 or higher** installed in your environment
- **pip** package manager (comes with Python)
- **Memory:** 4GB RAM minimum, 8GB recommended
- **OS:** Linux, macOS, Windows (WSL recommended)
- **Storage:** 500MB for Jac + dependencies

### Installing Jac

Installing Jac is straightforward with pip:

```bash
python -m pip install -U jaclang
```

The `-U` flag ensures you get the latest version with all recent improvements and bug fixes.

### Verifying Installation

Once installed, verify everything works correctly:

```bash
# Check Jac version
jac --version

# This should output something like: Jac 0.x.x
```

If you see the version number, congratulations! Jac is successfully installed.

### Python Virtual Environment Installation (Optional)
```bash
# Create virtual environment
python -m venv jac-env

# Activate it
source jac-env/bin/activate

# Install Jac in the virtual environment
pip install jaclang
```

## IDE Setup: VS Code Extension

While you can write Jac in any text editor, the VS Code extension provides the best development experience with:

- **Syntax highlighting** for Jac-specific constructs
- **Graph visualization** for nodes and edges
- **Autocomplete** for language features
- **Error detection** and type checking
- **Debugging** with Jac Debugger
- **Code formatting** and snippets

### Installing the VS Code Extension

1. Open Visual Studio Code
2. Go to Extensions (Ctrl+Shift+X / Cmd+Shift+X)
3. Search for "Jac"
4. Install the **Jac** extension by jaseci-labs

Alternatively, visit the [VS Code marketplace](https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jaclang-extension) directly.

## Your First Jac Program: Hello World

Let's start with the traditional "Hello World" program in Jac:

### Creating Your First File

Create a new file called `hello.jac`:

=== "Hello World!"
    <div class="code-block">

    ```jac
    # hello.jac
    with entry {
        print("Hello, World!");
    }
    ```
    </div>

=== "Python"
    ```python
    # hello.py
    print("Hello, World!")
    ```

### Running Your Program

Execute your program from the command line:

```bash
jac run hello.jac
```

**Expected Output:**
```
Hello, World!
```

### Understanding the Entry Block

The `with entry { ... }` block is Jac's equivalent to Python's `if __name__ == "__main__":` section. It defines the entry point where program execution begins.

## Quick Test: Confirming Everything Works (Optional)

Let's do a quick test to ensure your environment is properly configured:

```bash
# Create a test file
echo "with entry { print('hello world'); }" > test.jac

# Run the test
jac run test.jac

# Clean up
rm test.jac
```

If this prints `hello world`, you're ready to proceed!

## Jac CLI Commands Overview

The Jac CLI provides several useful commands:

```bash
# Run a Jac file
jac run <file_name>.jac

# Check version
jac --version

# Get help
jac --help

# Serve a Jac application (for cloud features)
jac serve <file_name>.jac
```

## Project Structure Conventions

As your Jac projects grow, following these conventions will help maintain organized code:

```
my_jac_project/
├── main.jac              # main file
├── main.impl.jac         # main implementations
├── main.test.jac         # Test main functionalities
├── users/
│   ├── user.jac          # Object definitions
│   ├── user.impl.jac     # Object implementations
│   └── user.test.jac     # Test user functionalities
└── features/
    ├── feature.jac       # Feature definitions
    ├── feature.impl.jac  # Feature Implementations
    └── feature.test.jac  # Test features
```

### Separation of Declaration and Implementation

Jac encourages separating **declarations** from **implementations**:

=== "**Try it out**"

    <div class="code-block">

    ```jac
    --8<-- "docs/examples/user.jac:1:20"
    ```
    </div>

=== "**user.jac** (declarations)"

    ```jac
    --8<-- "docs/examples/user.jac:1:6"
    ```

=== "**user.impl.jac** (implementations)"

    ```jac
    --8<-- "docs/examples/user.jac:8:15"
    ```

This pattern keeps your code organized and interfaces clean.


## Example 1: Basic Graph Creation

Here's a simple example showing Jac's graph capabilities:

=== "Sample Graph"
    ```mermaid
    graph TD
    style Person1 fill:#de8129,stroke:#333,stroke-width:2px
    style Person2 fill:#de8129,stroke:#333,stroke-width:2px
    style Person3 fill:#de8129,stroke:#333,stroke-width:2px

    Person1["Alice Joined: 2024-01-15"] -->|Knows Since: 2024-02-01| Person2["Bob Joined: 2024-02-20"]
    Person2 -->|Knows Since: 2024-03-01| Person3["Charlie Joined: 2024-03-10"]
    ```

=== "**Try it out**"

    <div class="code-block">

    ```jac
    --8<-- "docs/examples/graph.jac:1:48"
    ```
    </div>

=== "**graph.jac**"

    ```jac
    --8<-- "docs/examples/graph.jac:1:24"
    ```

=== "**graph.impl.jac**"

    ```jac
    --8<-- "docs/examples/graph.jac:26:32"
    ```

This introduces:

- **Nodes** with properties using `has`
- **Edge creation** with the `++>` operator
- **Graph thinking** instead of just object thinking

## Example 2: Todo List Application

Let's build a simple todo list to demonstrate basic Jac concepts:

=== "Try Todo List Program"
    <div class="code-block">

    ```jac
    --8<-- "docs/examples/todo.jac:1:112"
    ```
    </div>

=== "todo.jac"
    ```jac
    --8<-- "docs/examples/todo.jac:1:46"
    ```

=== "todo.impl.jac"
    ```jac
    --8<-- "docs/examples/todo.jac:47:96"
    ```
---

Run this example:
```bash
jac run todo.jac
```

**Expected Output:**
```
=== Todo List ===
1. ○ Learn Jac basics (due: 2024-12-31)
2. ○ Build first Jac app
3. ○ Master object-spatial programming
Total: 3 items
```

## Interactive Mode (REPL)

Jac also supports interactive exploration through Python's REPL integration:

```bash
# Start Jac REPL
jac

# In the REPL:
> x = 42;
> print(x * 2);
84
> node TestNode { has value: int; }
> n = TestNode(value=100);
> print(n.value);
100
```

## Common Beginner Tips
1. **Type annotations are required** - Jac enforces type safety
2. **Statements end with semicolons** - Unlike Python, Jac uses `;`
3. **Curly braces for blocks** - Use `{ }` instead of indentation
4. **Entry blocks are mandatory** - Always use `with entry { ... }` for executables

## Troubleshooting Common Issues

| Issue | Solution |
|-------|----------|
| `ModuleNotFoundError` | Ensure Jac is installed: `pip install jaclang` |
| `SyntaxError: Missing semicolon` | Add `;` at end of statements |
| `TypeError: Missing type annotation` | Add type hints to all function parameters |
| `RuntimeError: No entry point` | Add `with entry { ... }` block |

## What's Next?

You now have:

- Jac installed and working
- VS Code extension set up
- Your first programs running
- Understanding of basic project structure

In the next chapter, we'll take a rapid tour through Jac's syntax and core features with examples.

---

- **Next**: [Chapter 3: Jac in a Flash](chapter_3.md)
- **Previous**: [Chapter 1: Introduction to Jac](chapter_1.md)
