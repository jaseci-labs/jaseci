"""Server cProfile hooks."""

import cProfile;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.project.config {
    JacConfig,
    ServeConfig,
    _parse_toml_data,
    get_explicit_config,
    set_config
}
import from jaclang.server.server {
    _new_profile,
    _resolve_profile_dir,
    _write_profile
}

test "serve cProfile writes old server reports" {
    old_config = get_explicit_config();
    old_profile_dir = os.environ.get("JAC_PROFILE_DIR");
    try {
        os.environ["JAC_PROFILE_DIR"] = "/tmp/jac-profile-disabled";
        set_config(JacConfig(serve=ServeConfig(profile=False)));
        assert _resolve_profile_dir() is None;

        with TemporaryDirectory() as tmpdir {
            parsed = _parse_toml_data({"serve": {"profile": True}}, None);
            assert parsed.serve.profile is True;
            set_config(parsed);
            os.environ["JAC_PROFILE_DIR"] = tmpdir;
            assert _resolve_profile_dir() == tmpdir;

            profiler = _new_profile();
            profiler.enable();
            total = sum(range(1000));
            profiler.disable();
            assert total == 499500;

            _write_profile(profiler, tmpdir);

            prof_path = Path(tmpdir) / "jac_server.prof";
            txt_path = Path(tmpdir) / "jac_server.txt";
            assert prof_path.exists();
            assert txt_path.exists();
            with open(str(txt_path), "r", errors="replace") as f {
                body = f.read();
            }
            assert "function calls" in body;
        }
    } finally {
        set_config(old_config);
        if old_profile_dir is None {
            os.environ.pop("JAC_PROFILE_DIR", None);
        } else {
            os.environ["JAC_PROFILE_DIR"] = old_profile_dir;
        }
    }
}
