"""Regression tests for issue 11b: the dev token signing secret must persist.

A dev server that signs with a value it does not keep logs every browser
session out on restart, and the shipped placeholder secret is the same string
in every project, so anyone can mint a token for anyone's dev server. The
secret is generated once per project under .jac/data/ (which is gitignored),
and a deployment that configures its own secret keeps using it.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.server.serving.authcrypt {
    PLACEHOLDER_JWT_SECRET,
    jwt_decode,
    jwt_encode,
    project_signing_secret
}


test "the dev signing secret is generated once and survives a restart" {
    with TemporaryDirectory() as tmpdir {
        first = project_signing_secret(tmpdir);
        secret_path = Path(tmpdir) / ".jac" / "data" / "jwt_secret";
        assert secret_path.exists();
        assert (secret_path.stat().st_mode & 0o777) == 0o600;
        assert len(first) >= 32;
        assert first != PLACEHOLDER_JWT_SECRET;
        # A second call is what the next `jac run` does: read, do not mint.
        assert project_signing_secret(tmpdir) == first;
    }
}


test "a token minted before a restart still validates after one" {
    with TemporaryDirectory() as tmpdir {
        token = jwt_encode({"sub": "alice"}, project_signing_secret(tmpdir));
        claims = jwt_decode(token, project_signing_secret(tmpdir));
        assert claims["sub"] == "alice";
    }
}


test "two projects never share a dev signing secret" {
    with TemporaryDirectory() as one {
        with TemporaryDirectory() as two {
            assert project_signing_secret(one) != project_signing_secret(two);
        }
    }
}


test "an unconfigured project no longer signs with the shipped placeholder" {
    with TemporaryDirectory() as tmpdir {
        reset_scale_config();
        try {
            secret = get_scale_config(Path(tmpdir)).get_jwt_config()["secret"];
            assert secret != PLACEHOLDER_JWT_SECRET;
            assert secret == project_signing_secret(tmpdir);
        } finally {
            reset_scale_config();
        }
    }
}


test "a configured secret wins, so a deployment keeps its own source" {
    with TemporaryDirectory() as tmpdir {
        (Path(tmpdir) / "jac.toml").write_text(
            '[scale.jwt]\nsecret = "deployed-secret"\n', encoding="utf-8"
        );
        reset_scale_config();
        try {
            secret = get_scale_config(Path(tmpdir)).get_jwt_config()["secret"];
            assert secret == "deployed-secret";
            assert not (Path(tmpdir) / ".jac" / "data" / "jwt_secret").exists();
        } finally {
            reset_scale_config();
        }
    }
}
