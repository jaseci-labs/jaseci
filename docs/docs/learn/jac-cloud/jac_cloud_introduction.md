# Introduction to Jac Cloud

## What is Jac Cloud?

Jac Cloud is a powerful extension of the Jac programming language that allows you to easily deploy and run your Jac applications as API servers. With minimal configuration, you can transform your Jac code into a full-featured web service with support for:

- RESTful API endpoints
- WebSockets for real-time communication
- Scheduled tasks
- Webhooks for integration with external services
- Authentication and authorization

## Why Use Jac Cloud?

Jac Cloud streamlines the deployment process by eliminating the need for separate web frameworks or complex server configurations. Benefits include:

- **Simplified Deployment**: Turn any Jac application into an API server with a single command
- **Built-in Documentation**: Access auto-generated API documentation at `/docs`
- **Developer-Friendly**: Focus on building your application logic without worrying about server infrastructure
- **Production-Ready**: Includes authentication, scheduling, and other features needed for production applications
- **Highly Extensible**: Easy integration with external services through webhooks and WebSockets

## Key Features

### RESTful API Generation
Automatically converts walker declarations into REST API endpoints with support for different HTTP methods, query parameters, path variables, and request bodies.

### WebSocket Support
Enables real-time bidirectional communication between clients and your Jac application for applications requiring instant updates.

### Task Scheduling
Schedule walkers to run at specific times or intervals using cron expressions, date triggers, or interval-based execution.

### Webhook Integration
Configure walkers to be triggered by external events or services through webhook callbacks.

### Authentication
Built-in authentication system to secure your API endpoints and control access to your application.

## Getting Started

To get started with Jac Cloud, head over to the [How To Start](./jac_cloud.md#how-to-start) section to learn how to run your first Jac Cloud application.

```python
# A simple Jac Cloud application example
walker hello_world {
    has name: str = "World";

    can enter with `root entry {
        report "Hello, " + self.name + "!";
    }

    obj __specs__ {
        static has methods: list = ["get", "post"],
        as_query: list = ["name"],
        auth: bool = false;
    }
}
```

The above example creates both GET and POST endpoints at `/walker/hello_world` that accept a `name` query parameter and return a greeting.
