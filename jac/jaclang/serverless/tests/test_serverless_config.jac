"""Unit tests for jac-serverless configuration and event parsing."""
import base64;
import json;
import os;
import tempfile;
import from jaclang.serverless.config {
    ENV_URL_KEYS,
    clear_config_cache,
    normalize_postgres_url,
    resolve_database_url,
    serverless_enabled
}
import from jaclang.serverless.functions { parse_event }


def _clear_env -> dict {
    saved: dict = {};
    for key in ENV_URL_KEYS {
        saved[key] = os.environ.pop(key, None);
    }
    clear_config_cache();
    return saved;
}


def _restore_env(saved: dict) -> None {
    for key in ENV_URL_KEYS {
        os.environ.pop(key, None);
    }
    for (key, val) in saved.items() {
        if val is not None {
            os.environ[key] = val;
        }
    }
    clear_config_cache();
}


test "normalize rewrites the postgres scheme and picks a driver" {
    normalized = normalize_postgres_url("postgres://u:p@h:5432/db");
    assert normalized.startswith("postgresql");
    assert "://u:p@h:5432/db" in normalized;
}


test "normalize keeps an explicit driver suffix" {
    url = "postgresql+psycopg://u:p@h/db";
    assert normalize_postgres_url(url) == url;
}


test "normalize passes non-postgres urls through" {
    assert normalize_postgres_url("sqlite:///x.db") == "sqlite:///x.db";
}


test "serverless is off without any configuration" {
    saved = _clear_env();
    try {
        assert not serverless_enabled("/nonexistent-dir-for-jac-serverless");
        assert resolve_database_url("/nonexistent-dir-for-jac-serverless") is None;
    } finally {
        _restore_env(saved);
    }
}


test "an environment url activates serverless" {
    saved = _clear_env();
    os.environ["SUPABASE_DB_URL"] = "postgres://u:p@h/db";
    clear_config_cache();
    try {
        assert serverless_enabled("/nonexistent-dir-for-jac-serverless");
        assert (
            resolve_database_url("/nonexistent-dir-for-jac-serverless")
            == "postgres://u:p@h/db"
        );
    } finally {
        _restore_env(saved);
    }
}


test "a [serverless] database_url in jac.toml activates serverless" {
    saved = _clear_env();
    try {
        with tempfile.TemporaryDirectory() as tmp {
            with open(os.path.join(tmp, "jac.toml"), "w") as f {
                f.write(
                    "[serverless]\n"
                    "database_url = \"postgres://toml:pw@h/db\"\n"
                );
            }
            clear_config_cache();
            assert serverless_enabled(tmp);
            assert resolve_database_url(tmp) == "postgres://toml:pw@h/db";
        }
    } finally {
        _restore_env(saved);
    }
}


test "enabled = false wins over an environment url" {
    saved = _clear_env();
    os.environ["DATABASE_URL"] = "postgres://u:p@h/db";
    clear_config_cache();
    try {
        with tempfile.TemporaryDirectory() as tmp {
            with open(os.path.join(tmp, "jac.toml"), "w") as f {
                f.write("[serverless]\nenabled = false\n");
            }
            clear_config_cache();
            assert not serverless_enabled(tmp);
        }
    } finally {
        _restore_env(saved);
    }
}


test "lambda function url events parse into requests" {
    body = {"content": "hi"};
    event = {
        "version": "2.0",
        "rawPath": "/walker/create_tweet",
        "rawQueryString": "a=1",
        "headers": {"Authorization": "Bearer tok", "content-type": "application/json"},
        "requestContext": {"http": {"method": "POST", "path": "/walker/create_tweet"}},
        "body": json.dumps(body),
        "isBase64Encoded": False
    };
    req = parse_event(event);
    assert req["method"] == "POST";
    assert req["path"] == "/walker/create_tweet?a=1";
    assert req["body"] == body;
    assert req["headers"]["Authorization"] == "Bearer tok";
}


test "base64 bodies and v1 events are handled" {
    payload = json.dumps({"x": 1}).encode();
    event = {
        "httpMethod": "POST",
        "path": "/walker/x",
        "headers": {},
        "body": base64.b64encode(payload).decode(),
        "isBase64Encoded": True
    };
    req = parse_event(event);
    assert req["method"] == "POST";
    assert req["path"] == "/walker/x";
    assert req["body"] == {"x": 1};
}
