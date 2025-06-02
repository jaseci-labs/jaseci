# Jac Cloud

## **How To Start**

Just replace `jac run` with `jac serve` and you are now running your jac application as an API server.

```bash
jac serve main.jac
```

Optionally, specify host and port with `--host` and `--port`.

```bash
jac serve main.jac --host 0.0.0.0 --port 8080
```

Once started, navigate to `/docs` in your browser to access the built-in API documentation (e.g., `http://localhost:8000/docs`).

## **Walker Endpoints**

### Automatic Endpoint Generation

By default, each walker declaration is automatically converted to two groups of endpoints:

- **Group 1**: `/walker/{walker's name}` - Endpoint that uses the root node as entry
- **Group 2**: `/walker/{walker's name}/{node}` - Endpoint that uses a specific node as entry

This automatic generation can be disabled by setting the environment variable `DISABLE_AUTO_ENDPOINT=true`.

### Customizing Endpoints

To customize endpoint behavior, you can:

1. Declare an inner `class __specs__ {}` or `obj __specs__ {}`
2. Use the `@specs` decorator from `jac_cloud.plugin.jaseci.specs` (if auto endpoint is disabled)

### HTTP Method Support

Walkers support all standard HTTP methods and FastAPI-supported parameter types:
- Path variables
- Query parameters
- JSON body
- File uploads

## **Supported Specs**

Below is a comprehensive table of all supported configuration options for walker endpoints:

| **NAME**             | **TYPE**                                             | **DESCRIPTION**                                                                                                                                                                                                                                                                                                                                                                                | **DEFAULT**           |
| -------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| path                 | str                                                  | additional path after default auto generated path **[root]:**`walker/{walker's name}`**/{your path}** or **[node]:**`walker/{walker's name}/{node id}`**/{your path}**                                                                                                                                                                                                                         | N/A                   |
| methods              | list[str]                                            | list of allowed http methods lowercase                                                                                                                                                                                                                                                                                                                                                         | ["post"]              |
| as_query             | str or list[str]                                     | list of declared fields that's intended to be query params. Setting it to `"*"` will set all fields to be query params                                                                                                                                                                                                                                                                         | []                    |
| auth                 | bool                                                 | if endpoint requires authentication or not                                                                                                                                                                                                                                                                                                                                                     | true                  |
| private              | bool                                                 | only applicable if auto endpoint is enabled. This will skip the walker in auto generation.                                                                                                                                                                                                                                                                                                     | false                 |
| webhook              | dict or None                                         | [Webhook Configuration](./jac_cloud_webhook.md)                                                                                                                                                                                                                                                                                                                                                | None                  |
| entry_type           | str or StrEnum (jac_cloud.plugin.EntryType)          | "NODE" for generating api with node entry input. "ROOT" for generating api without node entry input (always current root entry). "BOTH" will support both.                                                                                                                                                                                                                                     | `"BOTH"`              |
| schedule             | dict [Jac-Cloud Scheduler](./jac_cloud_scheduler.md) | Allow walker to be scheduled via cron, interval or one datetime trigger                                                                                                                                                                                                                                                                                                                        | `"BOTH"`              |
|                      |                                                      |                                                                                                                                                                                                                                                                                                                                                                                                |                       |
|                      |                                                      | **`Following fields is for configuring FastAPI's OpenAPI Specs / Swagger`**                                                                                                                                                                                                                                                                                                                    |                       |
|                      |                                                      |                                                                                                                                                                                                                                                                                                                                                                                                |                       |
| tags                 | list[str] or None                                    | A list of tags to be applied to the _path operation_. It will be added to the generated OpenAPI (e.g. visible at `/docs`). Read more about it in the [FastAPI docs for Path Operation Configuration](https://fastapi.tiangolo.com/tutorial/path-operation-configuration/#tags).                                                                                                                | None                  |
| status_code          | int or None                                          | The default status code to be used for the response. You could override the status code by returning a response directly. Read more about it in the [FastAPI docs for Response Status Code](https://fastapi.tiangolo.com/tutorial/response-status-code/).                                                                                                                                      | None                  |
| summary              | str or None                                          | A summary for the _path operation_. It will be added to the generated OpenAPI (e.g. visible at `/docs`). Read more about it in the [FastAPI docs for Path Operation Configuration](https://fastapi.tiangolo.com/tutorial/path-operation-configuration/).                                                                                                                                       | None                  |
| description          | str or None                                          | A description for the _path operation_. If not provided, it will be extracted automatically from the docstring of the _path operation function_. It can contain Markdown. It will be added to the generated OpenAPI (e.g. visible at `/docs`). Read more about it in the [FastAPI docs for Path Operation Configuration](https://fastapi.tiangolo.com/tutorial/path-operation-configuration/). | None                  |
| response_description | str                                                  | The description for the default response. It will be added to the generated OpenAPI (e.g. visible at `/docs`).                                                                                                                                                                                                                                                                                 | "Successful Response" |
| responses            | dict[int or str, dict[str, Any]] or None             | Additional responses that could be returned by this _path operation_. It will be added to the generated OpenAPI (e.g. visible at `/docs`).                                                                                                                                                                                                                                                     | None                  |
| deprecated           | bool or None                                         | Mark this _path operation_ as deprecated. It will be added to the generated OpenAPI (e.g. visible at `/docs`).                                                                                                                                                                                                                                                                                 | None                  |
| name                 | str or None                                          | Name for this _path operation_. Only used internally.                                                                                                                                                                                                                                                                                                                                          | None                  |
| openapi_extra        | dict[str, Any] or None                               | Extra metadata to be included in the OpenAPI schema for this _path operation_. Read more about it in the [FastAPI docs for Path Operation Advanced Configuration](https://fastapi.tiangolo.com/advanced/path-operation-advanced-configuration/#custom-openapi-path-operation-schema).                                                                                                          | None                  |

## **Examples**

Below are examples of different walker configurations for various API endpoint types:

```python
import from jac_cloud {FastAPI}

# Basic POST endpoint with no parameters
walker post_no_body {}

# POST endpoint with a body parameter
walker post_with_body {
    has a: str;
}

# GET endpoint with no parameters
walker get_no_body {
    obj __specs__ {
        static has methods: list = ["get"];
    }
}

# GET endpoint with a query parameter
walker get_with_query {
    has a: str;

    obj __specs__ {
        static has methods: list = ["get"], as_query: list = ["a"];
    }
}

# GET endpoint with all parameters as query parameters
walker get_all_query {
    has a: str;
    has b: str;

    obj __specs__ {
        static has methods: list = ["get"], as_query: list = "*", auth: bool = False;
    }
}

# Endpoint with a path variable
walker post_path_var {
    has a: str;

    obj __specs__ {
        static has path: str = "/{a}", methods: list = ["post", "get"];
    }
}

# Endpoint with a combination of body and query parameters
walker combination1 {
    has a: str;
    has b: str;
    has c: str;

    obj __specs__ {
        static has methods: list = ["post", "get"], as_query: list = ["a", "b"];
    }
}

# Endpoint with all HTTP methods and a path variable
walker combination2 {
    has a: str;
    has b: str;
    has c: str;

    obj __specs__ {
        static has path: str = "/{a}", methods: list = ["post", "get", "put", "patch", "delete", "head", "trace", "options"], as_query: list = ["b"];
    }
}

# Endpoint that accepts file uploads
walker post_with_file {
    has single: UploadFile;
    has multiple: list[UploadFile];
    has singleOptional: UploadFile | None = None;


    can enter with `root entry {
        print(self.single);
        print(self.multiple);
        print(self.singleOptional);
    }

    obj __specs__ {}
}

# Endpoint that accepts both body parameters and file uploads
walker post_with_body_and_file {
    has val: int;
    has single: UploadFile;
    has multiple: list[UploadFile];
    has optional_val: int = 0;

    can enter with `root entry {
        print(self.val);
        print(self.optional_val);
        print(self.single);
        print(self.multiple);
    }

    obj __specs__ {
        static has auth: bool = False;
    }
}
```

## **Walker Response Structure**

Responses from walker endpoints are automatically serialized with the following structure:

```python
{
    "status": {{ int : http status code }},
    "reports": {{ list : jac reports }},

    # optional via SHOW_ENDPOINT_RETURNS=true environment variable
    "returns" {{ list : jac per visit return }}
}
```

## **Walker/Edge/Node Serialization**

Objects are serialized with the following structure:

```python
{
    "id": {{ str : anchor ref_id }},
    "context": {{ dict : anchor archetype data }}
}
```
