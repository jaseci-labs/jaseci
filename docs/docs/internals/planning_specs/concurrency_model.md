# Go-Style Concurrency Model for Jac

## 1. Introduction

This document outlines the design and implementation of a Go-inspired concurrency model for the Jac programming language. The goal is to create a complete Python-based runtime that simulates Go's M:N concurrency system, providing lightweight goroutines, efficient scheduling, and channel-based communication.

### 1.1 Objectives

- **Educational Understanding**: Gain deep insights into Go's runtime internals from a compiler and systems design perspective
- **Performance**: Achieve efficient concurrent execution with minimal overhead
- **Scalability**: Support thousands of concurrent goroutines on limited OS threads
- **Compatibility**: Provide familiar Go-like concurrency primitives for Jac developers
- **Integration**: Seamlessly integrate with Jac's compiler and type system

### 1.2 Key Components

The concurrency model consists of several core components that work together:

```mermaid
graph TD
    subgraph "Runtime System"
        E[GMP Scheduler]
        F[Goroutines G]
        G[Machines M]
        H[Processors P]
        I[Channels]
        J[Preemption System]
        K[Memory Management]
    end

    E --> F
    E --> G
    E --> H
    F <--> I
    J --> F
    K --> F
```

## 2. Architecture Overview

### 2.1 The GMP Model

Our implementation follows Go's GMP (Goroutines, Machines, Processors) model:

```mermaid
classDiagram
    class Goroutine {
        +id: int
        +state: GoroutineState
        +stack: Stack
        +function: callable
        +args: tuple
        +local_storage: dict
        +chan_wait_queue: list
        +preempt_flag: bool
        +run()
        +yield_to_scheduler()
        +park()
        +ready()
    }

    class Machine {
        +id: int
        +thread: Thread
        +current_g: Goroutine
        +current_p: Processor
        +spinning: bool
        +park_note: Event
        +start()
        +stop()
        +schedule()
        +execute(g: Goroutine)
    }

    class Processor {
        +id: int
        +status: ProcessorStatus
        +run_queue: deque
        +run_queue_head: int
        +run_queue_tail: int
        +machine: Machine
        +run_next() Goroutine
        +put_runnable(g: Goroutine)
        +steal_work() Goroutine
    }

    class Scheduler {
        +global_run_queue: Queue
        +processors: list[Processor]
        +machines: list[Machine]
        +idle_machines: Queue
        +stop_flag: bool
        +schedule_goroutine(g: Goroutine)
        +find_runnable_goroutine() Goroutine
        +work_steal() Goroutine
        +start_runtime()
        +shutdown()
    }

    Scheduler --> Processor
    Scheduler --> Machine
    Machine --> Goroutine
    Machine --> Processor
    Processor --> Goroutine
```

### 2.2 Concurrency Primitives

The system provides Go-like concurrency primitives:

```mermaid
classDiagram
    class Channel {
        +buffer: deque
        +capacity: int
        +closed: bool
        +send_queue: WaitQueue
        +recv_queue: WaitQueue
        +send(value) bool
        +receive() Any
        +close()
        +select_case_ready() bool
    }

    class WaitQueue {
        +waiters: deque
        +enqueue(g: Goroutine)
        +dequeue() Goroutine
        +remove(g: Goroutine)
    }

    class SelectCase {
        +channel: Channel
        +operation: SelectOp
        +value: Any
        +ready: bool
        +execute()
    }

    class Mutex {
        +locked: bool
        +wait_queue: WaitQueue
        +lock()
        +unlock()
        +try_lock() bool
    }

    Channel --> WaitQueue
    SelectCase --> Channel
```
