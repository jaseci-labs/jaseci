"""Guards #8000 (Part 4): identity storage is Postgres-only. When no store
resolves, the user manager must fail loudly instead of silently degrading to
a second credential store with divergent semantics (the old sqlite fallback).

Also guards the two ways the scale server could reach a request while its
identity is wrong: an in-process runtime built for a project that pins the
core store, and a signing secret that cannot be kept.
"""

import os;
import unittest.mock;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.scale.identity.user_manager { JacScaleUserManager }
import from jaclang.scale.server.inprocess { prepare_inprocess_runtime }


"""Apply `values` over the environment, returning what was there before."""
def _set_env(values: dict[str, str | None]) -> dict[str, str | None] {
    previous: dict[str, str | None] = {};
    for (key, value) in values.items() {
        previous[key] = os.environ.get(key);
        if value is None {
            os.environ.pop(key, None);
        } else {
            os.environ[key] = value;
        }
    }
    return previous;
}


"""A project pinning `[serve] identity` with one trivial module in it."""
def _pinned_project(project_dir: str, owner: str) -> str {
    (Path(project_dir) / "jac.toml").write_text(
        f'[project]\nname = "pinned"\n\n[serve]\nidentity = "{owner}"\n',
        encoding="utf-8"
    );
    entry_file = os.path.join(project_dir, "app.jac");
    Path(entry_file).write_text("with entry {}\n", encoding="utf-8");
    return entry_file;
}


test "user manager refuses to start without a reachable database" {
    with unittest.mock.patch(
        "jaclang.scale.persistence.pg.shared_store", return_value=None
    ) {
        with testraises(RuntimeError) as exc {
            JacScaleUserManager(base_path=".");
        }
        assert "Postgres" in str(exc.value);
        assert "credential store" in str(exc.value);
    }
}


test "sqlite identity fallback is gone" {
    import jaclang.scale.identity.identity_storage as storage_mod;
    assert not hasattr(storage_mod, "SqliteIdentityStorage");
}


test "the in-process runtime refuses a project that pins the core identity" {
    with TemporaryDirectory() as tmpdir {
        entry_file = _pinned_project(tmpdir, "core");
        previous = _set_env({"JAC_IDENTITY_BACKEND": None});
        try {
            with testraises(RuntimeError) as exc {
                prepare_inprocess_runtime(entry_file, tmpdir);
            }
            message = str(exc.value);
            assert "in-process runtime serves the scale identity" in message;
            assert "core" in message;
            assert "different databases" in message;
        } finally {
            _set_env(previous);
        }
    }
}


test "a signing secret that cannot be kept fails the boot, not a request" {
    import from jaclang.scale.server.serve { JacAPIServer }
    with TemporaryDirectory() as tmpdir {
        # A regular file where the .jac data directory has to go.
        wall = os.path.join(tmpdir, "wall");
        Path(wall).write_text("", encoding="utf-8");
        previous = _set_env(
            {
                "JAC_DATA_PATH": wall,
                "KUBERNETES_SERVICE_HOST": None,
                "JAC_IDENTITY_BACKEND": None
            }
        );
        try {
            with testraises(RuntimeError) as exc {
                JacAPIServer(module_name="app", port=0, base_path=tmpdir);
            }
            message = str(exc.value);
            assert "[scale.jwt] secret" in message;
            assert "keep to" in message;
        } finally {
            _set_env(previous);
        }
    }
}
