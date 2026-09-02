"""Regression tests for issue 12(a): which identity stack owns /user/*.

The owner must be a pure function of configuration, resolved for the project
being served rather than for whatever directory the process happens to sit in.
It must never depend on whether an optional import succeeded at boot: the two
stacks keep credentials in different stores (core: sqlite .jac/data/main.db,
scale: Postgres), so a silent flip strands every account created before it.
"""

import os;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang { JacRuntime as Jac }
import from jaclang.server.identity_owner {
    CORE_IDENTITY,
    IDENTITY_BACKEND_ENV,
    SCALE_IDENTITY,
    identity_owner,
    scale_stack_configured,
    scale_stack_installed
}

glob CORE_SERVER_MODULE: str = "jaclang.server.server",
     SCALE_SERVER_MODULE: str = "jaclang.scale.server.serve",
     SCALE_ENV_KEYS: list[str] = [
         "JAC_DB_URL",
         "JAC_SCALE_RUNTIME",
         "JAC_SV_SIBLING",
         IDENTITY_BACKEND_ENV
     ];


"""Apply `values` over the identity-relevant environment, returning the old one."""
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


"""Every identity-relevant variable cleared, so a sibling test cannot leak in."""
def _cleared_env -> dict[str, str | None] {
    return {key: None for key in SCALE_ENV_KEYS};
}


"""A project directory whose jac.toml pins `[serve] identity`."""
def _project_pinning(project_dir: str, owner: str) -> str {
    (Path(project_dir) / "jac.toml").write_text(
        f'[project]\nname = "pinned"\n\n[serve]\nidentity = "{owner}"\n',
        encoding="utf-8"
    );
    return project_dir;
}


test "an unconfigured project resolves to the core identity" {
    previous = _set_env(_cleared_env());
    try {
        assert scale_stack_installed() is True;
        assert scale_stack_configured() is False;
        assert identity_owner() == CORE_IDENTITY;
        assert Jac.get_api_server_class().__module__ == CORE_SERVER_MODULE;
    } finally {
        _set_env(previous);
    }
}


test "a configured database hands /user/* to the scale identity" {
    values = _cleared_env();
    values["JAC_DB_URL"] = "postgresql://identity-owner-test/db";
    previous = _set_env(values);
    try {
        assert scale_stack_configured() is True;
        assert identity_owner() == SCALE_IDENTITY;
        assert Jac.get_api_server_class().__module__ == SCALE_SERVER_MODULE;
    } finally {
        _set_env(previous);
    }
}


test "the owner comes from the served project, not the current directory" {
    with TemporaryDirectory() as tmpdir {
        _project_pinning(tmpdir, CORE_IDENTITY);
        values = _cleared_env();
        values["JAC_DB_URL"] = "postgresql://identity-owner-test/db";
        previous = _set_env(values);
        try {
            assert Path.cwd().resolve() != Path(tmpdir).resolve();
            assert identity_owner() == SCALE_IDENTITY;
            assert identity_owner(tmpdir) == CORE_IDENTITY;
        } finally {
            _set_env(previous);
        }
    }
}


test "a project pinning the scale identity keeps it from another directory" {
    with TemporaryDirectory() as tmpdir {
        _project_pinning(tmpdir, SCALE_IDENTITY);
        previous = _set_env(_cleared_env());
        try {
            assert identity_owner() == CORE_IDENTITY;
            assert identity_owner(tmpdir) == SCALE_IDENTITY;
        } finally {
            _set_env(previous);
        }
    }
}


"""Run `body` as `jac run` would with this base directory and target file."""
def _serving(base_dir: str, target: str, body: Callable[[], None]) {
    previous_base = Jac.get_base_path_dir();
    previous_target = Jac.get_full_target_path();
    Jac.set_base_path(base_dir);
    Jac.set_full_target_path(target);
    try {
        body();
    } finally {
        Jac.set_base_path(previous_base);
        Jac.set_full_target_path(previous_target);
    }
}


test "the served project decides the server class, not the current directory" {
    with TemporaryDirectory() as tmpdir {
        _project_pinning(tmpdir, SCALE_IDENTITY);
        entry_file = os.path.join(tmpdir, "who.jac");
        Path(entry_file).write_text("", encoding="utf-8");
        previous = _set_env(_cleared_env());
        try {
            assert identity_owner() == CORE_IDENTITY;
            def _check {
                assert Jac.get_api_server_class().__module__ == SCALE_SERVER_MODULE;
            }
            _serving(tmpdir, entry_file, _check);
        } finally {
            _set_env(previous);
        }
    }
}


test "a nested project keeps its own owner when run from the parent" {
    with TemporaryDirectory() as outer {
        _project_pinning(outer, SCALE_IDENTITY);
        inner = os.path.join(outer, "inner");
        os.makedirs(inner, exist_ok=True);
        _project_pinning(inner, CORE_IDENTITY);
        entry_file = os.path.join(inner, "who.jac");
        Path(entry_file).write_text("", encoding="utf-8");
        previous = _set_env(_cleared_env());
        try {
            assert identity_owner(outer) == SCALE_IDENTITY;
            assert identity_owner(entry_file) == CORE_IDENTITY;
            def _check {
                assert Jac.get_api_server_class().__module__ == CORE_SERVER_MODULE;
            }
            # `jac run inner/who.jac` from the parent: the base path is the
            # parent, the target is the inner project's file.
            _serving(outer, entry_file, _check);
        } finally {
            _set_env(previous);
        }
    }
}


test "an environment setting overrides the project setting" {
    with TemporaryDirectory() as tmpdir {
        _project_pinning(tmpdir, CORE_IDENTITY);
        values = _cleared_env();
        values[IDENTITY_BACKEND_ENV] = SCALE_IDENTITY;
        previous = _set_env(values);
        try {
            assert identity_owner(tmpdir) == SCALE_IDENTITY;
            assert Jac.get_api_server_class().__module__ == SCALE_SERVER_MODULE;
        } finally {
            _set_env(previous);
        }
    }
}


test "an unrecognized environment setting is refused, not guessed" {
    values = _cleared_env();
    values[IDENTITY_BACKEND_ENV] = "bogus";
    previous = _set_env(values);
    try {
        with testraises(ValueError) as exc {
            identity_owner();
        }
        message = str(exc.value);
        assert "bogus" in message;
        assert CORE_IDENTITY in message;
        assert SCALE_IDENTITY in message;
    } finally {
        _set_env(previous);
    }
}


test "an unrecognized jac.toml setting is refused, not guessed" {
    with TemporaryDirectory() as tmpdir {
        _project_pinning(tmpdir, "postgres");
        previous = _set_env(_cleared_env());
        try {
            with testraises(ValueError) as exc {
                identity_owner(tmpdir);
            }
            assert "postgres" in str(exc.value);
        } finally {
            _set_env(previous);
        }
    }
}


test "an unreadable project config is refused, not resolved automatically" {
    with TemporaryDirectory() as tmpdir {
        (Path(tmpdir) / "jac.toml").write_text(
            '[project]\nname = "broken\n', encoding="utf-8"
        );
        previous = _set_env(_cleared_env());
        try {
            with testraises(Exception) as exc {
                identity_owner(tmpdir);
            }
            assert not isinstance(exc.value, AssertionError);
        } finally {
            _set_env(previous);
        }
    }
}


test "a broken scale import fails loudly instead of changing the owner" {
    values = _cleared_env();
    values[IDENTITY_BACKEND_ENV] = SCALE_IDENTITY;
    previous = _set_env(values);
    try {
        with patch.dict(sys.modules, {SCALE_SERVER_MODULE: None}) {
            with testraises(RuntimeError) as exc {
                Jac.get_api_server_class();
            }
            message = str(exc.value);
            assert SCALE_SERVER_MODULE in message;
            assert "identity" in message.lower();
        }
    } finally {
        _set_env(previous);
    }
}
