# Quick Start Guide

This guide will help you quickly get up and running with Jac Cloud, with step-by-step instructions designed for beginners.

## Your First Jac Cloud Server in 30 Seconds

Transform any Jac application into a cloud API server with a single command:

```bash
# Basic usage - this is all you need to start!
jac serve main.jac

# With custom host and port (optional)
jac serve main.jac --host 0.0.0.0 --port 8080
```

Once started, your API will be available at:

- **API Endpoint**: `http://localhost:8000`
- **Interactive Documentation**: `http://localhost:8000/docs`

## Understanding Walker Endpoints

### What Happens Automatically

Jac Cloud automatically converts your walker declarations into REST API endpoints. By default, each walker creates two endpoint groups:

| Endpoint Type | URL Pattern | Description |
|--------------|-------------|-------------|
| **Root Entry** | `/walker/{walker_name}` | Executes on the root |
| **Node Entry** | `/walker/{walker_name}/{node_id}` | Executes on a specific node |

### Want to Disable Auto-Generation?

To disable automatic endpoint generation, set the environment variable:
```bash
export DISABLE_AUTO_ENDPOINT=True
```

## Configuring Your Walkers

### Basic Configuration

Control endpoint behavior using the `__specs__` object within your walker:

```jac
walker my_walker {
    has data: str;

    // This is where you configure your endpoint behavior
    obj __specs__ {
        static has methods: list = ["get", "post"];   // Supports both GET and POST
        static has auth: bool = false;                // No authentication required
        static has as_query: list = ["data"];         // "data" will be a query parameter
    }
}
```

## Configuration Reference

### Core Settings (Most Common)

| **Setting** | **Type** | **Description** | **Default** |
|-------------|----------|-----------------|-------------|
| `methods` | `list[str]` | Allowed HTTP methods: `"get"`, `"post"`, `"put"`, `"delete"`, etc. | `["post"]` |
| `as_query` | `str \| list[str]` | Fields to treat as query parameters. Use `"*"` for all fields | `[]` |
| `auth` | `bool` | Whether endpoint requires authentication | `true` |
| `path` | `str` | Additional path after auto-generated path | N/A |
| `private` | `bool` | Skip walker in auto-generation | `false` |

### Advanced Settings

| **Setting** | **Type** | **Description** | **Default** |
|-------------|----------|-----------------|-------------|
| `entry_type` | `str` | `"NODE"`, `"ROOT"`, or `"BOTH"` | `"BOTH"` |
| `webhook` | `dict` | [Webhook configuration](webhook.md) | `None` |
| `schedule` | `dict` | [Scheduler configuration](scheduler.md) | `None` |

### Documentation Settings

| **Setting** | **Type** | **Description** | **Default** |
|-------------|----------|-----------------|-------------|
| `tags` | `list[str]` | API tags for grouping in Swagger UI | `None` |
| `summary` | `str` | Brief endpoint description | `None` |
| `description` | `str` | Detailed endpoint description (supports Markdown) | `None` |
| `status_code` | `int` | Default response status code | `None` |
| `deprecated` | `bool` | Mark endpoint as deprecated | `None` |

## Examples for Beginners

### Basic Endpoint Examples

```jac
// Simple POST endpoint
walker create_user {
    has username: str;
    has email: str;
}

// GET endpoint with query parameters
walker search_users {
    has query: str;
    has limit: int = 10;

    obj __specs__ {
        static has methods: list = ["get"];
        static has as_query: list = ["query", "limit"];
    }
}

// Public endpoint (no authentication)
walker public_info {
    obj __specs__ {
        static has methods: list = ["get"];
        static has auth: bool = false;
    }
}
```

### File Upload Examples

```jac
// Single file upload
walker single_file_upload {
    has file: UploadFile;
    has description: str = "";

    can enter with `root entry {
        print(f"Received file: {self.file.filename}");
        print(f"Description: {self.description}");
    }
}

// Multiple file upload
walker multi_file_upload {
    has files: list[UploadFile];
    has category: str;

    can enter with `root entry {
        for file in self.files {
            print(f"Processing: {file.filename}");
        }
    }
}
```

## Response Format

### What to Expect

All walker endpoints return a standardized JSON response:

```json
{
    "status": 200,
    "reports": [
        "Any reports generated during walker execution"
    ],
    "returns": [
        "Walker return values (optional - requires SHOW_ENDPOINT_RETURNS=true)"
    ]
}
```

### Working with Node and Edge Data

Jac Cloud automatically serializes walker, edge, and node archetypes:

```json
{
    "id": "unique_anchor_reference_id",
    "context": {
        "attribute1": "value1",
        "attribute2": "value2"
    }
}
```

## Helpful Environment Variables

Control Jac Cloud behavior with these environment variables:

- `DISABLE_AUTO_ENDPOINT=True` - Disable automatic endpoint generation
- `SHOW_ENDPOINT_RETURNS=True` - Include walker return values in responses

## Next Steps

Now that you understand the basics, explore these features:

- [Authentication & Permissions](permission.md) - Secure your API
- [Real-time WebSocket Communication](websocket.md) - Add real-time features
- [Task Scheduling](scheduler.md) - Automate recurring tasks
- [Webhook Integration](webhook.md) - Create API integrations
- [Environment Variables](env_vars.md) - Configure your application
- [Logging & Monitoring](logging.md) - Track application performance