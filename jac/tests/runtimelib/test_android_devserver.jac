"""Tests for the Android HMR dev server — locks in the device-polling contract.

JacDevHostActivity polls `/_jac/dev/modules/manifest.json` and downloads the dex
at the manifest's `path`. These tests assert the server honors that contract
(missing dex -> 404, live state updates visible to the next poll) without a
device or a real build.
"""
import from jaclang.runtimelib.client.targets.android.dev_server { publish_hot_module }
import from jaclang.runtimelib.client.targets.android_target { _jac_start_dev_server }
import from pathlib { Path }
import from urllib.request { urlopen }
import from urllib.error { HTTPError }
import from json { loads }

test "dev server serves manifest and dex with live state updates" {
    modules_root = Path("/tmp/_jactest_devserver_modules");
    modules_root.mkdir(parents=True, exist_ok=True);
    state: dict = {"modules_root": str(modules_root)};
    # Port 0 binds a free port; server_address[1] is the actual port.
    httpd = _jac_start_dev_server(0, state);
    port = httpd.server_address[1];
    base = f"http://127.0.0.1:{port}";

    try {
        # Manifest reflects the live state dict.
        m = loads(
            urlopen(base + "/_jac/dev/modules/manifest.json", timeout=3).read().decode()
        );
        assert m["version"] == "";
        assert m["path"] == "";

        # No dex staged yet -> 404.
        try {
            urlopen(base + "/_jac/dev/modules/android/v1/classes.dex", timeout=3);
            assert False , "expected 404 for missing dex";
        } except HTTPError as e {
            assert e.code == 404;
        }

        # Stage a dex and bump the version; the next poll sees both atomically.
        fake = modules_root / "v2" / "classes.dex";
        fake.parent.mkdir(parents=True, exist_ok=True);
        fake.write_bytes(b"dex\n035\0" + b"\x00" * 40);
        publish_hot_module(state, "v2", str(fake));
        m2 = loads(
            urlopen(base + "/_jac/dev/modules/manifest.json", timeout=3).read().decode()
        );
        assert m2["version"] == "v2";
        assert m2["path"] == "/_jac/dev/modules/android/v2/classes.dex";
        data = urlopen(
            base + "/_jac/dev/modules/android/v2/classes.dex", timeout=3
        ).read();
        assert data == fake.read_bytes();

        # Legacy flat dex URL tracks the current module snapshot.
        data_legacy = urlopen(
            base + "/_jac/dev/modules/android/classes.dex", timeout=3
        ).read();
        assert data_legacy == fake.read_bytes();

        # Unknown path -> 404.
        try {
            urlopen(base + "/_jac/dev/other", timeout=3);
            assert False , "expected 404 for unknown path";
        } except HTTPError as e {
            assert e.code == 404;
        }
    } finally {
        httpd.shutdown();
        httpd.server_close();
    }
}
