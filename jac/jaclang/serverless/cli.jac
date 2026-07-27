"""jac serverless CLI: dev, invoke, package, deploy."""
import json;
import os;
import sys;
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.console { console }

glob registry = get_registry();


def _invoke_local(
    file: str, method: str, path: str, data: str, token: str
) -> int {
    import from jaclang.serverless.functions { get_function }
    fn = get_function(os.path.abspath(file));
    body = None;
    if data {
        try {
            body = json.loads(data);
        } except json.JSONDecodeError as e {
            console.error(f"--data is not valid JSON: {e}", emoji=False);
            return 1;
        }
    }
    headers = {"content-type": "application/json"};
    if token {
        headers["authorization"] = f"Bearer {token}";
    }
    response = fn.invoke(method, path, headers=headers, body=body);
    console.print(f"{method.upper()} {path} -> {response.status_code}");
    try {
        pretty = json.dumps(json.loads(response.text), indent=2);
    } except Exception {
        pretty = response.text;
    }
    print(pretty);
    return 0 if response.status_code < 500 else 1;
}


def _dev(file: str) -> int {
    console.print(
        "jac-serverless dev: serving locally with the same runtime as jac start",
        style="cyan"
    );
    os.execv(
        sys.executable, [sys.executable, "-m", "jaclang", "start", file]
    );
    return 0;
}


def _package(file: str, out: str) -> int {
    import from jaclang.serverless.packaging { build_package }
    zip_path = build_package(os.path.abspath(file), out);
    size_mb = os.path.getsize(zip_path) / (1024 * 1024);
    console.success(f"Built {zip_path} ({size_mb:.1f} MB)", emoji=False);
    if size_mb > 250 {
        console.print(
            "Warning: unzipped size may exceed the AWS Lambda 250 MB limit; "
            "consider a container image deploy.",
            style="yellow"
        );
    }
    return 0;
}


def _deploy(
    file: str,
    out: str,
    fn_name: str,
    region: str,
    role_arn: str,
    memory: int,
    timeout: int
) -> int {
    import from jaclang.serverless.packaging { build_package, deploy_package }
    import from jaclang.serverless.config { resolve_database_url }
    app_dir = os.path.dirname(os.path.abspath(file));
    resolved_name = fn_name or (
        "jac-" + os.path.basename(app_dir).lower().replace("_", "-")
    );
    zip_path = build_package(os.path.abspath(file), out);
    env_vars: dict = {};
    db_url = resolve_database_url(app_dir);
    if db_url {
        env_vars["DATABASE_URL"] = db_url;
    } else {
        console.print(
            "Warning: no SUPABASE_DB_URL / DATABASE_URL / [serverless].database_url "
            "found; the function will fall back to ephemeral storage.",
            style="yellow"
        );
    }
    result = deploy_package(
        zip_path,
        resolved_name,
        region=region,
        role_arn=role_arn,
        memory=memory,
        timeout=timeout,
        env_vars=env_vars
    );
    console.success(
        f"Deployed {result['function_name']} ({result['region']})", emoji=False
    );
    if result.get("function_url") {
        console.print(f"Function URL: {result['function_url']}", style="bold");
    }
    return 0;
}


@registry.command(
    name="serverless",
    help="Run and deploy Jac apps as serverless functions with Supabase/Postgres state",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            help="Action: dev, invoke, package, deploy"
        ),
        Arg.create("file", typ=str, default="main.jac", help="App entry .jac file"),
        Arg.create("method", short="X", typ=str, default="POST", help="invoke: HTTP method"),
        Arg.create("path", typ=str, default="/healthz", help="invoke: request path"),
        Arg.create("data", typ=str, default="", help="invoke: JSON request body"),
        Arg.create("token", typ=str, default="", help="invoke: bearer token"),
        Arg.create("out", typ=str, default="", help="package/deploy: output zip path"),
        Arg.create(
            "fn_name", short="n", typ=str, default="", help="deploy: Lambda function name"
        ),
        Arg.create("region", typ=str, default="", help="deploy: AWS region"),
        Arg.create(
            "role_arn", short="A", typ=str, default="", help="deploy: Lambda execution role ARN"
        ),
        Arg.create("memory", short="M", typ=int, default=1024, help="deploy: memory (MB)"),
        Arg.create("timeout", short="T", typ=int, default=120, help="deploy: timeout (seconds)")
    ],
    examples=[
        ("jac serverless dev", "Run the app locally (same runtime as jac start)"),
        (
            "jac serverless invoke --path /walker/load_feed --token T",
            "Invoke a walker as a function locally"
        ),
        ("jac serverless package", "Build dist/function.zip for AWS Lambda"),
        (
            "jac serverless deploy --role_arn arn:aws:iam::...:role/lambda",
            "Package and deploy to AWS Lambda with a public function URL"
        )
    ],
    group="serverless"
)
def serverless_cmd(
    action: str,
    file: str = "main.jac",
    method: str = "POST",
    path: str = "/healthz",
    data: str = "",
    token: str = "",
    out: str = "",
    fn_name: str = "",
    region: str = "",
    role_arn: str = "",
    memory: int = 1024,
    timeout: int = 120
) -> int {
    if action == "invoke" {
        return _invoke_local(file, method, path, data, token);
    }
    if action == "dev" {
        return _dev(file);
    }
    if action == "package" {
        return _package(file, out);
    }
    if action == "deploy" {
        return _deploy(file, out, fn_name, region, role_arn, memory, timeout);
    }
    console.error(
        f"Unknown action '{action}'. Use: dev, invoke, package, deploy", emoji=False
    );
    return 1;
}
