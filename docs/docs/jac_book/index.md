# Jac Programming Language Book

Welcome to the comprehensive guide to the Jac programming language. This book will take you from a complete beginner to an advanced Jac developer, covering everything from basic syntax to building scalable, cloud-native applications.

## About This Book

Jac is a revolutionary programming language that introduces **Object-Spatial Programming (OSP)**, a paradigm that inverts the traditional relationship between data and computation. Instead of moving data to computation, Jac moves computation to data through spatially-aware constructs like nodes, edges, and walkers.

This book is structured to provide both theoretical understanding and practical experience, with extensive code examples and real-world applications throughout.

# Jac Programming Language Book - Table of Contents

## Part I: Getting Started

### Chapter 1: Introduction to Jac
- What is Jac and why it exists
- Object-Spatial Programming paradigm overview
- Scale-agnostic programming concept
- Comparison with Python and traditional languages
- **Code Example Ideas**: Simple friend network with 3 people connected by friendship edges

### Chapter 2: Environment Setup and First Program
- Installation and IDE setup
- Project structure conventions
- Hello World in Jac
- Entry blocks and basic execution
- **Code Example Ideas**: Hello World and basic calculator program

## Part II: Core Language Features

### Chapter 3: Variables, Types, and Basic Syntax
- Variable declarations with mandatory typing
- Basic data types and type inference
- Lists, dicts, sets, tuples with type safety
- Collection comprehensions
- Control flow (if/else, loops with curly braces)
- Pattern matching
- Exception Handling
- Walrus Operation
- **Code Example Ideas**: Simple grade book system with student scores and basic operations

### Chapter 4: Functions and Decorators
- Function definitions
- Parameter types and return annotations
- Decorators in Jac context
- Lambda functions and functional programming
- Async functions
- **Code Example Ideas**: Math functions library with timing decorator

### Chapter 5: Imports System and File Operations
- Import statements and module organization
- Implementation separation (.impl.jac files)
- Package structure and well-typed codebases
- File operations
- **Code Example Ideas**: Simple config file reader across multiple modules

## Part III: New Features

### Chapter 6: Pipe Operations and AI Integration
- Pipe operator chains
- Built-in AI function calls
- Model declaration and configuration
- MTLLM variations and basic usage
- **Code Example Ideas**: Text summarizer using pipe operations

### Chapter 7: Advanced AI Operations
- Semantic strings and prompt engineering
- Multimodality support (vision, audio)
- Custom model integration
- Embedding and vector operations
- Performance considerations
- **Code Example Ideas**: Simple image captioning tool

## Part IV: Object Spatial Programming (OSP)

### Chapter 8: Enhanced OOP - Objects and Classes
- python `class` to jac `obj`
- Automatic constructors with `has`
- Access control (:pub, :priv, :protect)
- Inheritance and composition
- **Code Example Ideas**: Simple pet shop with different animal types

### Chapter 9: OSP Introduction and Paradigm Shift
- From "data to computation" to "computation to data"
- Data Spatial Programming foundation
- Graph thinking vs object thinking
- **Code Example Ideas**: Family tree with 3 generations

### Chapter 10: Nodes and Edges
- Node creation and properties
- Edge types and relationships
- Graph creation syntax
- Filtering
- **Code Example Ideas**: Simple classroom with students and teacher connections

### Chapter 11: Walkers and Abilities
- Walker creation
- Ability definitions and triggers
- Entry/exit behaviors
- Walker spawn and visit
- **Code Example Ideas**: Message delivery walker in the classroom graph

### Chapter 12: Advanced Object Spatial Operations
- Visit patterns
- Advanced Filtering
- Complex traversal patterns
- **Code Example Ideas**: Find all friends of friends in a social network

## Part V: Scale-Agnostic Features

### Chapter 13: Persistence and the Root Node
- Automatic persistence
- Root node concept
- State consistency
- **Code Example Ideas**: Simple counter that remembers its value between runs

### Chapter 14: Jac Cloud Introduction
- What is Jac Cloud and benefits
- Quick setup and deployment
- Walker endpoints as APIs
- Local to Cloud
- **Code Example Ideas**: Simple weather API endpoint

### Chapter 15: Multi-User Architecture and Permissions
- User isolation and permission systems
- Shared data patterns
- Security considerations
- Access control strategies
- **Code Example Ideas**: Simple shared notebook with user permissions

## Part VI: Advanced Scale-Agnostic Features

### Chapter 16: Advanced Jac Cloud Features
- Environment variables and configuration
- Webhook integration
- WebSocket communication
- Logging and monitoring
- Task scheduling and cron jobs
- **Code Example Ideas**: Simple chat room with WebSocket connections

<!-- disabled for now
### Chapter 17: Concurrency and Parallelism
- Async walkers and scheduling
- Walker spawning for parallelism
- Async/await patterns
- Synchronization primitives
- Distributed coordination
- **Code Example Ideas**: Parallel data processing, concurrent user handling -->

## Part VII: Advanced Topics

### Chapter 17: Type System Deep Dive
- Advanced generics
- Type constraints
- Graph type checking
- Runtime type validation
- **Code Example Ideas**: Generic list operations with type safety

### Chapter 18: Testing and Debugging
- Test block syntax
- Walker behavior testing
- Distributed debugging
- **Code Example Ideas**: Tests for the classroom graph system

## Part VIII: Deployment and Production

### Chapter 19: Deployment Strategies
- Local vs cloud deployment
- Kubernetes deployment
- Configuration management
- Monitoring and observability
- CI/CD patterns
- **Code Example Ideas**: Deploy the weather API to production

### Chapter 20: Performance Optimization
- Graph structure optimization
- Traversal efficiency
- Memory management
- Distributed performance
- **Code Example Ideas**: Optimize the friend-finding algorithm

## Part IX: Real-World Applications

### Chapter 21: Complete Application: LittleX Social Platform
- Architecture design using data spatial concepts
- User profile creation and management
- Creating posts and content sharing
- Following users and social connections
- Viewing personalized feeds
- Real-time features with WebSockets
- **Code Example Ideas**: Full social media platform (based on LittleX tutorial)

### Chapter 22: Complete Application: RAG Chatbot
- Building intelligent chatbots
- Retrieval-augmented generation patterns
- Knowledge base integration
- Context management
- **Code Example Ideas**: Simple FAQ chatbot for a school

### Chapter 23: Complete Application: Workflow Engine
- Business process modeling
- State machine implementation
- Task assignment and tracking
- Integration patterns
- **Code Example Ideas**: Simple homework assignment workflow

## Part X: Migration and Best Practices

### Chapter 24: Python to Jac Migration
- Migration strategies
- Incremental adoption
- Python integration patterns
- Common pitfalls
- **Code Example Ideas**: Convert a simple Python class to Jac objects

### Chapter 25: Best Practices and Patterns
- Code organization
- Naming conventions
- Documentation standards
- Team collaboration
- **Code Example Ideas**: Clean code examples and project structure

### Chapter 26: Big Features and Future of Jac
- Roadmap and evolution
- Upcoming features in development
- Research directions
- Community resources
- Contributing guidelines
- **Code Example Ideas**: Simple community contribution example
