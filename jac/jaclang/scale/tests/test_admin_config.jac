"""Tests for the admin portal's opt-in defaults and bootstrap credential policy."""

import os;
import from unittest.mock { patch }
import from jaclang.scale.config.config_loader {
    get_scale_config,
    reset_scale_config,
    resolve_admin_enabled
}


test "admin portal is disabled by default" {
    with patch.dict(os.environ, {}, clear=True) {
        reset_scale_config();
        try {
            admin_config = get_scale_config().get_admin_config();
            assert admin_config["enabled"] is False;
        } finally {
            reset_scale_config();
        }
    }
}


test "admin portal ships no default password" {
    with patch.dict(os.environ, {}, clear=True) {
        reset_scale_config();
        try {
            admin_config = get_scale_config().get_admin_config();
            assert admin_config["default_password"] is None;
        } finally {
            reset_scale_config();
        }
    }
}


test "JAC_ADMIN_ENABLED opts the portal in" {
    with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": "true"}, clear=True) {
        reset_scale_config();
        try {
            assert get_scale_config().get_admin_config()["enabled"] is True;
        } finally {
            reset_scale_config();
        }
    }
}


test "JAC_ADMIN_ENABLED accepts on and surrounding whitespace" {
    for raw in ["on", " True ", "YES", "1"] {
        with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": raw}, clear=True) {
            reset_scale_config();
            try {
                assert get_scale_config().get_admin_config()["enabled"] is True;
            } finally {
                reset_scale_config();
            }
        }
    }
}


test "JAC_ADMIN_ENABLED turns the portal off explicitly" {
    for raw in ["off", "false", "0", "no"] {
        with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": raw}, clear=True) {
            reset_scale_config();
            try {
                assert get_scale_config().get_admin_config()["enabled"] is False;
            } finally {
                reset_scale_config();
            }
        }
    }
}


test "an unrecognized JAC_ADMIN_ENABLED warns and stays disabled" {
    with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": "ture"}, clear=True) {
        with patch("logging.getLogger") as get_logger {
            assert not resolve_admin_enabled(True);
            warning = get_logger.return_value.warning;
            assert warning.call_count == 1;
            assert "JAC_ADMIN_ENABLED" in warning.call_args[0][0];
        }
    }
}


test "an unset or empty JAC_ADMIN_ENABLED leaves jac.toml in charge" {
    for env in [{}, {"JAC_ADMIN_ENABLED": ""}, {"JAC_ADMIN_ENABLED": "   "}] {
        with patch.dict(os.environ, env, clear=True) {
            assert resolve_admin_enabled(True);
            assert not resolve_admin_enabled(False);
        }
    }
}


test "JAC_ADMIN_PASSWORD supplies the bootstrap credential" {
    with patch.dict(os.environ, {"JAC_ADMIN_PASSWORD": "s3cret-boot"}, clear=True) {
        reset_scale_config();
        try {
            admin_config = get_scale_config().get_admin_config();
            assert admin_config["default_password"] == "s3cret-boot";
        } finally {
            reset_scale_config();
        }
    }
}


test "bootstrap honors require_password_reset = false" {
    import from jaclang.scale.identity.user_manager { JacScaleUserManager }
    import from unittest.mock { patch as mock_patch }
    import tempfile;
    import shutil;

    tmp = tempfile.mkdtemp();
    env = {"JAC_ADMIN_ENABLED": "true", "JAC_ADMIN_PASSWORD": "boot-pass-1"};
    with patch.dict(os.environ, env, clear=True) {
        reset_scale_config();
        try {
            cfg = get_scale_config();
            original = cfg.get_admin_config();
            relaxed = dict(original);
            relaxed["require_password_reset"] = False;
            with mock_patch.object(cfg, "get_admin_config", return_value=relaxed) {
                manager = JacScaleUserManager(base_path=tmp);
                result = manager.bootstrap_admin_user();
                assert "error" not in result;
                user_id = result["user_id"];
                assert not manager.requires_password_reset(user_id);
            }
        } finally {
            reset_scale_config();
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }
}


test "bootstrap refuses to provision an admin without a configured password" {
    import from jaclang.scale.identity.user_manager { JacScaleUserManager }
    import tempfile;
    import shutil;

    tmp = tempfile.mkdtemp();
    with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": "true"}, clear=True) {
        reset_scale_config();
        try {
            manager = JacScaleUserManager(base_path=tmp);
            result = manager.bootstrap_admin_user();
            assert "error" in result;
            assert "default_password" in result["error"];
        } finally {
            reset_scale_config();
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }
}


test "rotating through update_password clears a pending reset" {
    import from jaclang.scale.identity.user_manager { JacScaleUserManager }
    import tempfile;
    import shutil;

    tmp = tempfile.mkdtemp();
    env = {"JAC_ADMIN_ENABLED": "true", "JAC_ADMIN_PASSWORD": "boot-pass-1"};
    with patch.dict(os.environ, env, clear=True) {
        reset_scale_config();
        try {
            manager = JacScaleUserManager(base_path=tmp);
            result = manager.bootstrap_admin_user();
            assert "error" not in result;
            user_id = result["user_id"];
            assert manager.requires_password_reset(user_id);

            failed = manager.update_password(user_id, "wrong-pass", "rotated-pass-1");
            assert "error" in failed;
            assert manager.requires_password_reset(user_id);

            rotated = manager.update_password(user_id, "boot-pass-1", "rotated-pass-1");
            assert "error" not in rotated;
            assert not manager.requires_password_reset(user_id);
        } finally {
            reset_scale_config();
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }
}
