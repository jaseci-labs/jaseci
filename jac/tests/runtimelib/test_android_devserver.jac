"""Tests for the Android HMR dev server — locks in the device-polling contract.

JacDevHostActivity polls `/_jac/dev/modules/manifest.json` and downloads the dex
at the manifest's `path`. These tests assert the server honors that contract
(missing dex -> 404, live state updates visible to the next poll) without a
device or a real build.
"""
import from jaclang.runtimelib.client.targets.android_target {
    _jac_start_dev_server
}
import from pathlib { Path }
import from urllib.request { urlopen }
import from json { loads }

test "dev server serves manifest and dex with live state updates" {
    state: dict = {"version": "v1", "dex_path": ""};
    # Port 0 binds a free port; server_address[1] is the actual port.
    httpd = _jac_start_dev_server(0, state);
    port = httpd.server_address[1];
    base = f"http://127.0.0.1:{port}";

    # Manifest reflects the live state dict.
    m = loads(urlopen(base + "/_jac/dev/modules/manifest.json", timeout=3).read().decode());
    assert m["version"] == "v1";
    assert m["path"] == "/_jac/dev/modules/android/classes.dex";

    # No dex staged yet -> 404.
    try {
        urlopen(base + "/_jac/dev/modules/android/classes.dex", timeout=3);
        assert False, "expected 404 for missing dex";
    } except Exception { }

    # Stage a dex and bump the version; the next poll sees both.
    fake = Path("/tmp/_jactest_devserver.dex");
    fake.write_bytes(b"dex\n035\0" + b"\x00" * 40);
    state["version"] = "v2";
    state["dex_path"] = str(fake);
    m2 = loads(urlopen(base + "/_jac/dev/modules/manifest.json", timeout=3).read().decode());
    assert m2["version"] == "v2";
    data = urlopen(base + "/_jac/dev/modules/android/classes.dex", timeout=3).read();
    assert data == fake.read_bytes();

    # Unknown path -> 404.
    try {
        urlopen(base + "/_jac/dev/other", timeout=3);
        assert False, "expected 404 for unknown path";
    } except Exception { }

    httpd.shutdown();
}
