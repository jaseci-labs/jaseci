"""Configuration for jac-serverless.

Reads the [serverless] section of the project's jac.toml and environment
overrides. Serverless mode turns on when a Postgres-compatible database URL
(e.g. a Supabase connection string) is available and [serverless].enabled is
not explicitly false. All lookups are cheap and cached per project root.
"""
import logging;
import os;
import tomllib;
import from importlib.util { find_spec }
import from pathlib { Path }

glob logger = logging.getLogger(__name__),
     ENV_URL_KEYS = ["SUPABASE_DB_URL", "DATABASE_URL", "SERVERLESS_DATABASE_URL"],
     _toml_cache: dict[str, dict] = {};


def find_project_root(start: (str | None) = None) -> (Path | None) {
    cur = Path(start or os.getcwd()).resolve();
    if cur.is_file() {
        cur = cur.parent;
    }
    for candidate in [cur] + list(cur.parents) {
        if (candidate / "jac.toml").is_file() {
            return candidate;
        }
    }
    return None;
}


def load_serverless_config(base_path: (str | None) = None) -> dict {
    project_root = find_project_root(base_path);
    if project_root is None {
        return {};
    }
    key = str(project_root);
    if key in _toml_cache {
        return _toml_cache[key];
    }
    section: dict = {};
    toml_path = project_root / "jac.toml";
    try {
        with open(toml_path, "rb") as f {
            section = tomllib.load(f).get("serverless") or {};
        }
    } except Exception as e {
        logger.warning(f"jac-serverless: could not read {toml_path}: {e}");
    }
    _toml_cache[key] = section;
    return section;
}


def clear_config_cache -> None {
    _toml_cache.clear();
}


def resolve_database_url(base_path: (str | None) = None) -> (str | None) {
    for env_key in ENV_URL_KEYS {
        val = os.environ.get(env_key);
        if val {
            return val;
        }
    }
    return load_serverless_config(base_path).get("database_url") or None;
}


def serverless_enabled(base_path: (str | None) = None) -> bool {
    if load_serverless_config(base_path).get("enabled") is False {
        return False;
    }
    return resolve_database_url(base_path) is not None;
}


def pick_postgres_driver -> (str | None) {
    for driver in ["psycopg2", "psycopg"] {
        try {
            if find_spec(driver) is not None {
                return driver;
            }
        } except (ImportError, ValueError) {
            continue;
        }
    }
    return None;
}


def normalize_postgres_url(url: str) -> str {
    u = url.strip();
    if u.startswith("postgres://") {
        u = "postgresql://" + u[len("postgres://"):];
    }
    if u.startswith("postgresql://") {
        driver = pick_postgres_driver();
        if driver {
            u = f"postgresql+{driver}://" + u[len("postgresql://"):];
        }
    }
    return u;
}


def missing_driver_hint -> str {
    return (
        "jac-serverless needs a Postgres driver to reach the database. "
        "Add 'psycopg2-binary = \">=2.9\"' to [dependencies] in jac.toml "
        "(or pip install psycopg2-binary) and retry."
    );
}
