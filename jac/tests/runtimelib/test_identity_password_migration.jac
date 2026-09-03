"""Regression tests for issue 12(b): the core identity's password format.

The core server used to write unsalted sha256 hashes, a format the scale
verifier can never accept, so any move between the two stacks stranded every
account. New signups must produce scrypt, and a legacy sha256 row must verify
once and be rehashed in place on that login.
"""

import hashlib;
import from tempfile { TemporaryDirectory }
import from jaclang.server.server { UserManager }
import from jaclang.server.serving.authcrypt {
    hash_password,
    is_legacy_sha256_hash,
    verify_password
}


"""The password hash currently stored for `username`, or '' when absent."""
def _stored_hash(manager: UserManager, username: str) -> str {
    manager._ensure_connection();
    assert manager._conn is not None;
    cursor = manager._conn.execute(
        "SELECT password_hash FROM users WHERE username = ?", (username, )
    );
    row = cursor.fetchone();
    return str(row[0]) if row else "";
}


"""Rewrite `username`'s row the way the pre-scrypt core server wrote it."""
def _write_legacy_hash(manager: UserManager, username: str, password: str) -> str {
    legacy = hashlib.sha256(password.encode()).hexdigest();
    manager._ensure_connection();
    assert manager._conn is not None;
    manager._conn.execute(
        "UPDATE users SET password_hash = ? WHERE username = ?", (legacy, username)
    );
    manager._conn.commit();
    return legacy;
}


test "a new core signup stores a scrypt hash" {
    with TemporaryDirectory() as tmpdir {
        manager = UserManager(base_path=tmpdir);
        manager.create_user("alice", "hunter2");
        stored = _stored_hash(manager, "alice");
        assert stored.startswith("scrypt$");
        assert not is_legacy_sha256_hash(stored);
        assert manager.authenticate("alice", "hunter2") is not None;
        assert manager.authenticate("alice", "wrong") is None;
        manager.close();
    }
}


test "a legacy sha256 row logs in once and is rehashed to scrypt" {
    with TemporaryDirectory() as tmpdir {
        manager = UserManager(base_path=tmpdir);
        manager.create_user("bob", "hunter2");
        legacy = _write_legacy_hash(manager, "bob", "hunter2");
        assert is_legacy_sha256_hash(legacy);
        assert manager.authenticate("bob", "wrong") is None;
        assert _stored_hash(manager, "bob") == legacy;
        result = manager.authenticate("bob", "hunter2");
        assert result is not None;
        assert result["username"] == "bob";
        rehashed = _stored_hash(manager, "bob");
        assert rehashed.startswith("scrypt$");
        assert manager.authenticate("bob", "hunter2") is not None;
        assert manager.authenticate("bob", "wrong") is None;
        manager.close();
    }
}


test "changing a password from a legacy row stores scrypt" {
    with TemporaryDirectory() as tmpdir {
        manager = UserManager(base_path=tmpdir);
        manager.create_user("carol", "old-pass");
        _write_legacy_hash(manager, "carol", "old-pass");
        failed = manager.update_password("carol", "not-it", "new-pass");
        assert "error" in failed;
        changed = manager.update_password("carol", "old-pass", "new-pass");
        assert "error" not in changed;
        assert _stored_hash(manager, "carol").startswith("scrypt$");
        assert manager.authenticate("carol", "new-pass") is not None;
        assert manager.authenticate("carol", "old-pass") is None;
        manager.close();
    }
}


test "the shared verifier accepts a legacy sha256 row" {
    legacy = hashlib.sha256("hunter2".encode()).hexdigest();
    assert is_legacy_sha256_hash(legacy) is True;
    assert verify_password("hunter2", legacy) is True;
    assert verify_password("wrong", legacy) is False;

    modern = hash_password("hunter2");
    assert modern.startswith("scrypt$");
    assert is_legacy_sha256_hash(modern) is False;
    assert verify_password("hunter2", modern) is True;
    assert verify_password("wrong", modern) is False;

    assert is_legacy_sha256_hash("") is False;
    assert is_legacy_sha256_hash("not-a-hash") is False;
    assert verify_password("anything", "") is False;
    assert verify_password("anything", "not-a-hash") is False;
}
