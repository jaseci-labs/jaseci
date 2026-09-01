"""Tests for the admin portal's opt-in defaults and bootstrap credential policy."""

import os;
import from unittest.mock { patch }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }


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
