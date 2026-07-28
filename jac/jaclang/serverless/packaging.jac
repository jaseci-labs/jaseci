import json;
import logging;
import os;
import shutil;
import subprocess;
import sys;
import zipfile;

glob logger = logging.getLogger(__name__),
     STAGING_DIR_NAME = "serverless-build",
     BASE_REQUIREMENTS = [
         "sqlalchemy>=2.0",
         "psycopg2-binary>=2.9",
         "bcrypt>=4.0",
         "PyJWT>=2.8",
         "fastapi>=0.110",
         "python-multipart>=0.0.9",
         "httpx>=0.27"
     ],
     JACLANG_EXCLUDES = [
         "__pycache__",
         ".zig-cache",
         "zig-out",
         "node_modules",
         "llvm",
         "examples",
         "tests",
         "test",
         ".git"
     ],
     APP_EXCLUDES = ["__pycache__", ".jac", "dist", "node_modules", ".git", ".venv"];


def _ignore_names(excludes: list) -> any {
    def ignore(src: str, names: list) -> set {
        skipped: set = set();
        for n in names {
            if n in excludes or n.endswith(".pyc") {
                skipped.add(n);
            }
        }
        return skipped;
    }
    return ignore;
}


def app_dependencies(app_dir: str) -> list {
    import tomllib;
    toml_path = os.path.join(app_dir, "jac.toml");
    if not os.path.isfile(toml_path) {
        return [];
    }
    try {
        with open(toml_path, "rb") as f {
            parsed = tomllib.load(f);
        }
    } except Exception as e {
        logger.warning(f"jac-serverless: unreadable {toml_path}: {e}");
        return [];
    }
    deps = parsed.get("dependencies") or {};
    out: list = [];
    for (pkg, spec) in deps.items() {
        if pkg == "npm" or isinstance(spec, dict) {
            continue;
        }
        marker = str(spec).strip();
        if marker in ("*", "") {
            out.append(pkg);
        } else {
            out.append(f"{pkg}{marker}");
        }
    }
    return out;
}


def write_handler_shim(staging: str, entry_rel: str) {
    lines = [
        "import os",
        "import sys",
        "",
        "_BASE = os.path.dirname(os.path.abspath(__file__))",
        "sys.path.insert(0, os.path.join(_BASE, 'deps'))",
        "sys.path.insert(0, _BASE)",
        "os.environ.setdefault('HOME', '/tmp')",
        "os.environ.setdefault('XDG_CACHE_HOME', '/tmp/.cache')",
        "os.environ.setdefault('JAC_DATA_PATH', '/tmp')",
        "os.environ.setdefault('JAC_SERVERLESS_ENTRY', "
        f"os.path.join(_BASE, {json.dumps(entry_rel)}))",
        "",
        "from jaclang.serverless.functions import lambda_handler as _lambda_handler",
        "",
        "",
        "def handler(event, context=None):",
        "    return _lambda_handler(event, context)",
        ""
    ];
    with open(os.path.join(staging, "handler.py"), "w") as f {
        f.write("\n".join(lines));
    }
}


def build_package(entry_file: str, out_zip: str = "") -> str {
    entry_abs = os.path.abspath(entry_file);
    app_dir = os.path.dirname(entry_abs);
    dist_dir = os.path.join(app_dir, "dist");
    staging = os.path.join(dist_dir, STAGING_DIR_NAME);
    if os.path.isdir(staging) and staging.endswith(STAGING_DIR_NAME) {
        shutil.rmtree(staging);
    }
    os.makedirs(staging, exist_ok=True);

    shutil.copytree(
        app_dir, os.path.join(staging, "app"), ignore=_ignore_names(APP_EXCLUDES)
    );

    import jaclang;
    jaclang_src = os.path.dirname(os.path.abspath(jaclang.__file__));
    shutil.copytree(
        jaclang_src,
        os.path.join(staging, "jaclang"),
        ignore=_ignore_names(JACLANG_EXCLUDES)
    );

    requirements = BASE_REQUIREMENTS + app_dependencies(app_dir);
    deps_dir = os.path.join(staging, "deps");
    os.makedirs(deps_dir, exist_ok=True);
    cmd = [
        sys.executable,
        "-m",
        "pip",
        "install",
        "--quiet",
        "--target",
        deps_dir
    ] + requirements;
    logger.info(f"jac-serverless: installing {len(requirements)} deps into package");
    result = subprocess.run(cmd, capture_output=True, text=True);
    if result.returncode != 0 {
        raise RuntimeError(f"pip install for package failed: {result.stderr[-2000:]}");
    }

    entry_rel = os.path.join("app", os.path.basename(entry_abs));
    write_handler_shim(staging, entry_rel);

    zip_path = os.path.abspath(out_zip or os.path.join(dist_dir, "function.zip"));
    if os.path.exists(zip_path) {
        os.remove(zip_path);
    }
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf {
        for (dirpath, dirnames, filenames) in os.walk(staging) {
            for fname in filenames {
                full = os.path.join(dirpath, fname);
                zf.write(full, os.path.relpath(full, staging));
            }
        }
    }
    size_mb = os.path.getsize(zip_path) / (1024 * 1024);
    logger.info(f"jac-serverless: built {zip_path} ({size_mb:.1f} MB)");
    return zip_path;
}


def deploy_package(
    zip_path: str,
    fn_name: str,
    region: str = "",
    role_arn: str = "",
    memory: int = 1024,
    timeout: int = 120,
    env_vars: (dict | None) = None
) -> dict {
    try {
        import boto3;
    } except ImportError {
        raise RuntimeError(
            "jac-serverless deploy needs boto3 (pip install boto3) and AWS credentials"
        );
    }
    resolved_region = region or os.environ.get("AWS_REGION") or "us-east-1";
    client = boto3.client("lambda", region_name=resolved_region);
    with open(zip_path, "rb") as f {
        zip_bytes = f.read();
    }
    env = {"Variables": dict(env_vars or {})};
    exists = True;
    try {
        client.get_function(FunctionName=fn_name);
    } except Exception {
        exists = False;
    }
    if exists {
        client.update_function_code(FunctionName=fn_name, ZipFile=zip_bytes);
        waiter = client.get_waiter("function_updated_v2");
        waiter.wait(FunctionName=fn_name);
        if env["Variables"] {
            client.update_function_configuration(
                FunctionName=fn_name,
                MemorySize=memory,
                Timeout=timeout,
                Environment=env
            );
            waiter.wait(FunctionName=fn_name);
        }
    } else {
        if not role_arn {
            raise RuntimeError("deploy of a new function needs --role_arn");
        }
        client.create_function(
            FunctionName=fn_name,
            Runtime="python3.13",
            Role=role_arn,
            Handler="handler.handler",
            Code={"ZipFile": zip_bytes},
            MemorySize=memory,
            Timeout=timeout,
            Environment=env
        );
        waiter = client.get_waiter("function_active_v2");
        waiter.wait(FunctionName=fn_name);
    }
    url = "";
    try {
        url_cfg = client.get_function_url_config(FunctionName=fn_name);
        url = url_cfg["FunctionUrl"];
    } except Exception {
        url_cfg = client.create_function_url_config(
            FunctionName=fn_name, AuthType="NONE"
        );
        url = url_cfg["FunctionUrl"];
        try {
            client.add_permission(
                FunctionName=fn_name,
                StatementId="FunctionURLAllowPublicAccess",
                Action="lambda:InvokeFunctionUrl",
                Principal="*",
                FunctionUrlAuthType="NONE"
            );
        } except Exception { }
    }
    return {"function_name": fn_name, "region": resolved_region, "function_url": url};
}
