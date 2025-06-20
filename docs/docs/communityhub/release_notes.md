# Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of Jac and Jaseci. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](./breaking_changes.md) page.

## jaclang 0.8.4 / jac-cloud 0.2.4 / mtllm 0.3.9 (Unreleased)

## jaclang 0.8.3 / jac-cloud 0.2.3 / mtllm 0.3.8

*   **Semantic Strings**: Introduced `sem` strings to attach natural language descriptions to code elements like functions, classes, and parameters. These semantic annotations can be used by Large Language Models (LLMs) to enable intelligent, AI-powered code generation and execution. (mtllm)
*   **LLM Function Overriding**: Introduced the ability to override any regular function with an LLM-powered implementation at runtime using the `function_call() by llm()` syntax. This allows for dynamic, on-the-fly replacement of function behavior with generative models. (mtllm)
*   **JacMachine Interface Reorganization**: The machine and interface have been refactored to maintain a shared global state—similar to Python's `sys.modules`—removing the need to explicitly pass execution context and dramatically improving performance.
*   **Async Walker Support**: Introduced comprehensive async walker functionality that brings Python's async/await paradigm to object-spatial programming. Async walkers enable non-blocking spawns during graph traversal, allowing for concurrent execution of multiple walkers and efficient handling of I/O-bound operations.
*   **Native Jac Imports**: Native import statements can now be used to import Jac modules seamlessly into python code, eliminating the need to use `_.jac_import()`.
*   **Unicode String Literal Support**: Fixed unicode character handling in string literals. Unicode characters like "✓", "○", emojis, and other international characters are now properly preserved during compilation instead of being corrupted into byte sequences.
*   **Removed Ignore Statements**: The `ignore` keyword and ignore statements have been removed as this functionality can be achieved more elegantly by modifying path collection expressions directly in visit statements.

## jaclang 0.8.1 / jac-cloud 0.2.1 / mtllm 0.3.6

*   **Function Renaming**: The `dotgen` built-in function has been renamed to `printgraph`. This change aims to make the function's purpose clearer, as `printgraph` more accurately reflects its action of outputting graph data. It can output in DOT format and also supports JSON output via the `as_json=True` parameter. Future enhancements may include support for other formats like Mermaid.
*   **Queue Insertion Index for Visit Statements**: Visit statements now support queue insertion indices (e.g., `visit:0: [-->]` for depth-first, `visit:-1: [-->]` for breadth-first) that control where new destinations are inserted in the walker's traversal queue. Any positive or negative index can be used, enabling fine-grained control over traversal patterns and supporting complex graph algorithms beyond simple depth-first or breadth-first strategies.
*   **Edge Ability Execution Semantics**: Enhanced edge traversal behavior with explicit edge references. By default, `[-->]` returns connected nodes, while `[edge -->]` returns edge objects. When walkers visit edges explicitly using `visit [edge -->]`, abilities are executed on both the edge and its connected node. Additionally, spawning a walker on an edge automatically queues both the edge and its target node for processing, ensuring complete traversal of the topological structure.
*   **Jac Imports Execution**: Jac imports (`Jac.jac_import`) now run in a Python-like interpreter mode by default. Full compilation with dependency inclusion can only occur when explicitly calling `compile` from the `JacProgram` object.
*   **Concurrent Execution with `flow` and `wait`**: Introduced `flow` and `wait` keywords for concurrent expressions. `flow` initiates parallel execution of expressions, and `wait` synchronizes these parallel operations. This enables efficient parallel processing and asynchronous operations directly within Jac with separate (and better) semantics than python's async/await.

## Version 0.8.0

*   **`impl` Keyword for Implementation**: Introduced the `impl` keyword for a simpler, more explicit way to implement abilities and methods for objects, nodes, edges, and other types, replacing the previous colon-based syntax.
*   **Updated Inheritance Syntax**: Changed the syntax for specifying inheritance from colons to parentheses (e.g., `obj Car(Vehicle)`) for better alignment with common object-oriented programming languages.
*   **`def` Keyword for Functions**: The `def` keyword is now used for traditional Python-like functions and methods, while `can` is reserved for object-spatial abilities.
*   **`visitor` Keyword**: Introduced the `visitor` keyword to reference the walker context within nodes/edges, replacing the ambiguous use of `here` in such contexts. `here` is now used only in walker abilities to reference the current node/edge.
*   **Lambda Syntax Update**: The lambda syntax has been updated from `with x: int can x;` to `lambda x: int: x * x;`, aligning it more closely with Python's lambda syntax.
*   **Object-Spatial Arrow Notation Update**: Typed arrow notations `-:MyEdge:->` and `+:MyEdge:+>` are now `->:MyEdge:->` and `+>:MyEdge:+>` respectively, to avoid conflicts with Python-style list slicing.
*   **Import `from` Syntax Update**: The syntax for importing specific modules from a package now uses curly braces (e.g., `import from utils { helper, math_utils }`) for improved clarity.
*   **Auto-Resolved Imports**: Removed the need for explicit language annotations (`:py`, `:jac`) in import statements; the compiler now automatically resolves imports.
*   **Permission API Renaming**: The `Jac.restrict` and `Jac.unrestrict` interfaces have been renamed to `Jac.perm_revoke` and `Jac.perm_grant` respectively, for better clarity on their actions.