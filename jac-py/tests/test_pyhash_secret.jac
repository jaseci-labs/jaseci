"""Standalone SipHash secret bootstrap probes."""
import from pyhash { hash_secret_keys_from_seed, str_hash_text, bytes_hash_data, }
import os;

test "pyhash: PYTHONHASHSEED LCG derives SipHash keys" {
    (k0, k1) = hash_secret_keys_from_seed(42);
    assert k0 == 0xdc504fd368cd90af , k0;
    assert k1 == 0xb920bb9ffe99e9c1 , k1;
    (z0, z1) = hash_secret_keys_from_seed(0);
    assert z0 == 0 , z0;
    assert z1 == 0 , z1;
}

test "pyhash: empty buffer hash is zero" {
    assert str_hash_text("") == 0;
    assert bytes_hash_data([]) == 0;
}

test "pyhash: pinned str/bytes digests match the host oracle (PYTHONHASHSEED=0)" {
    # Digests captured from CPython (PYTHONHASHSEED=0, SipHash-1-3, zero key)
    # and cross-checked against an independent pure-Python siphash13
    # reference. These pin the pyhash lane itself; the user-facing builtin
    # ``hash()`` route is gated separately (see test_random_parity.jac's
    # auto-arming pins and TODO item 57 for the route-dependent divergence).
    if os.environ.get("PYTHONHASHSEED") != "0" {
        return;
    }
    assert str_hash_text("spam") == -7643603308804133256 , str_hash_text("spam");
    assert str_hash_text("abc") == -4594863902769663758 , str_hash_text("abc");
    assert str_hash_text("hello world") == -5642461784034726774 , str_hash_text("hello world");
    assert str_hash_text("jac") == 8001078755821552746 , str_hash_text("jac");
    # Non-Latin-1 text takes the UTF-16LE payload lane.
    assert str_hash_text("€") == -5529981157763016009 , str_hash_text("€");
    assert str_hash_text("héllo") == 6395329678795984700 , str_hash_text("héllo");
    assert bytes_hash_data([97, 98, 99]) == -4594863902769663758 , bytes_hash_data([97, 98, 99]);
}
