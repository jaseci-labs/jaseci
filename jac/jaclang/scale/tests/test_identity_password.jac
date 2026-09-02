"""Unit tests for IdentityStorage password hashing/verification."""

import hashlib;
import from jaclang.scale.identity.identity_storage { IdentityStorage }

test "verify_password accepts a legacy sha256 hash so accounts survive a move" {
    sha256_digest = hashlib.sha256("test_password".encode()).hexdigest();
    assert IdentityStorage.verify_password("test_password", sha256_digest) == True;
    assert IdentityStorage.verify_password("wrong", sha256_digest) == False;
}

test "verify_password rejects malformed hashes without raising" {
    assert IdentityStorage.verify_password("anything", "") == False;
    assert IdentityStorage.verify_password("anything", "not-a-hash") == False;
    assert IdentityStorage.verify_password("anything", "$2b$12$abc") == False;
}

test "verify_password round-trips a real scrypt hash" {
    hashed = IdentityStorage.hash_password("hunter2");
    assert hashed.startswith("scrypt$");
    assert IdentityStorage.verify_password("hunter2", hashed) == True;
    assert IdentityStorage.verify_password("nope", hashed) == False;
}
