"""Real-execution tests for the shared-PVC venv cache (restore/publish/evict).

Every test here drives `jaclang.scale.deploy.target.kubernetes.venv_cache`
directly against a real temp directory standing in for the shared bundle
PVC -- no mocking of the functions under test, matching the pattern
`test_dependencies.jac` already established for `_venv_deps_stale` /
`install_specs`. The concurrency test races real threads publishing to the
same cache root: the atomicity being verified (`os.rename`, `tempfile.
mkdtemp`'s unique names, per-entry `shutil.rmtree`) comes from the
filesystem/OS, not from Python's GIL, and the GIL is released around every
one of those syscalls, so a genuine interleaving of two pods' worth of
restore/publish/evict work is exercised without needing separate processes.
"""

import os;
import shutil;
import tempfile;
import time;
import threading;
import from jaclang.scale.deploy.target.kubernetes.venv_cache {
    is_cache_eligible,
    restore,
    publish
}


def _make_venv(path: str, marker: str = "payload") {
    os.makedirs(os.path.join(path, "lib"), exist_ok=True);
    with open(os.path.join(path, "lib", "marker.txt"), "w") as f {
        f.write(marker);
    }
}


def _venv_marker(path: str) -> str | None {
    marker_file = os.path.join(path, "lib", "marker.txt");
    if not os.path.isfile(marker_file) {
        return None;
    }
    with open(marker_file) as f {
        return f.read();
    }
}


test "is_cache_eligible requires a resolved digest, not a mutable tag" {
    assert is_cache_eligible("jaseci/jaclang@sha256:" + "a" * 64);
    assert not is_cache_eligible("jaseci/jaclang:dev");
    assert not is_cache_eligible("jaseci/jaclang:experimental-1234");
    assert not is_cache_eligible("python:3.12-slim");
    assert not is_cache_eligible("");
}


test "restore is a no-op when the cache entry does not exist" {
    with tempfile.TemporaryDirectory() as td {
        venv_dir = os.path.join(td, "venv");
        restore(os.path.join(td, "cache", "missing"), venv_dir);
        assert not os.path.exists(venv_dir);
    }
}


test "restore rolls back a partial copy instead of leaving a torn venv behind" {
    # If cache_dir is deleted mid-copy by a concurrent eviction (or any other
    # copy failure), shutil.copytree raises after some files have already
    # landed in venv_dir. Leaving that partial state in place is exactly
    # finding 1's failure mode: pip sees some distributions already present
    # in a "venv" that never finished installing and skips them, so jac
    # install itself can't tell the difference from a real cache hit.
    import unittest.mock;
    import jaclang.scale.deploy.target.kubernetes.venv_cache as venv_cache_mod;

    with tempfile.TemporaryDirectory() as td {
        cache_dir = os.path.join(td, "cache", "key1");
        _make_venv(cache_dir, "cached");
        venv_dir = os.path.join(td, "app", "venv");
        def _torn_copy(src: str, dst: str, **kwargs: any) {
            os.makedirs(os.path.join(dst, "lib"), exist_ok=True);
            with open(os.path.join(dst, "lib", "partial.txt"), "w") as f {
                f.write("torn");
            }
            raise OSError("simulated concurrent deletion mid-copy");
        }
        with unittest.mock.patch.object(
            venv_cache_mod.shutil, "copytree", _torn_copy
        ) {
            restore(cache_dir, venv_dir);
        }
        assert not os.path.exists(venv_dir) , (
            "a failed restore must not leave a partial venv behind"
        );
    }
}


test "publish then restore round-trips the venv on a different path" {
    with tempfile.TemporaryDirectory() as td {
        cache_root = os.path.join(td, "cache");
        venv_dir = os.path.join(td, "app", "venv");
        _make_venv(venv_dir, "hello");
        cache_dir = os.path.join(cache_root, "key1");
        publish(venv_dir, cache_dir, cache_root);
        assert os.path.isdir(cache_dir);
        assert os.path.isdir(cache_root);
        restored_dir = os.path.join(td, "restored", "venv");
        restore(cache_dir, restored_dir);
        assert _venv_marker(restored_dir) == "hello";
    }
}


test "publish never overwrites an already-published entry" {
    with tempfile.TemporaryDirectory() as td {
        cache_root = os.path.join(td, "cache");
        cache_dir = os.path.join(cache_root, "key1");
        first_venv = os.path.join(td, "first", "venv");
        _make_venv(first_venv, "first");
        publish(first_venv, cache_dir, cache_root);
        assert _venv_marker(cache_dir) == "first";
        second_venv = os.path.join(td, "second", "venv");
        _make_venv(second_venv, "second");
        publish(second_venv, cache_dir, cache_root);
        # Content-addressed: an existing entry is immutable once published.
        assert _venv_marker(cache_dir) == "first";
    }
}


test "publish leaves no staging directory behind on success" {
    with tempfile.TemporaryDirectory() as td {
        cache_root = os.path.join(td, "cache");
        venv_dir = os.path.join(td, "app", "venv");
        _make_venv(venv_dir);
        publish(venv_dir, os.path.join(cache_root, "key1"), cache_root);
        leftovers = [
            name
            for name in os.listdir(cache_root)
            if name.startswith(".tmp")
        ];
        assert leftovers == [];
    }
}


test "eviction removes the oldest entries but never the cache root itself" {
    with tempfile.TemporaryDirectory() as td {
        cache_root = os.path.join(td, "cache");
        os.makedirs(cache_root);
        # Seed three "old" entries, each large enough to matter, with
        # distinct mtimes so eviction order is deterministic.
        old_dirs = [];
        for i in range(3) {
            entry_dir = os.path.join(cache_root, f"old{i}");
            _make_venv(entry_dir, "x" * (200 * 1024));
            old_dirs.append(entry_dir);
            time.sleep(0.01);
            os.utime(entry_dir, (1000 + i, 1000 + i));
        }
        # Publishing one more entry that pushes the root over budget must
        # evict old0 (oldest) first, keep the root itself, and never touch
        # the entry it just published.
        new_venv = os.path.join(td, "app", "venv");
        _make_venv(new_venv, "y" * (200 * 1024));
        new_cache_dir = os.path.join(cache_root, "new");
        publish(new_venv, new_cache_dir, cache_root, max_root_mb=0);
        assert os.path.isdir(cache_root);
        assert os.path.isdir(new_cache_dir);
        assert not os.path.isdir(old_dirs[0]);
    }
}


test "concurrent publishes from separate threads never corrupt the cache root or collide on staging names" {
    # This is the property findings 1 and 2 were about: an unsynchronized
    # size-triggered `rm -rf` on the shared root, and a `$$`-based staging
    # name that two pods can pick identically. Racing real threads against
    # the same directory exercises exactly the filesystem-level atomicity
    # `publish`/`_evict_if_needed` depend on, not a string match on
    # generated shell.
    with tempfile.TemporaryDirectory() as td {
        cache_root = os.path.join(td, "cache");
        os.makedirs(cache_root);
        # Pre-seed old, large entries with mtimes far in the past so they
        # always sort before any entry a worker publishes "now", regardless
        # of thread interleaving. A tight-but-realistic budget (smaller
        # than the seed total, comfortably larger than six tiny worker
        # payloads) forces eviction to actually run during the race while
        # proving it only ever removes the old seeds, never a sibling's
        # just-published entry -- unlike an all-out max_root_mb=0 budget,
        # which would evict everything including work in progress and
        # isn't a scenario the real 2048MB default can produce.
        for i in range(4) {
            entry_dir = os.path.join(cache_root, f"seed{i}");
            _make_venv(entry_dir, "z" * (100 * 1024));
            os.utime(entry_dir, (1000 + i, 1000 + i));
        }
        tight_budget_mb = 0.15;
        workers = [];
        results = [];
        for i in range(6) {
            venv_src = os.path.join(td, f"src{i}", "venv");
            _make_venv(venv_src, f"worker{i}");
            cache_dir = os.path.join(cache_root, f"key{i}");
            results.append(cache_dir);
            t = threading.Thread(
                target=publish, args=(venv_src, cache_dir, cache_root, tight_budget_mb)
            );
            workers.append(t);
        }
        for t in workers {
            t.start();
        }
        for t in workers {
            t.join(timeout=30);
            assert not t.is_alive();
        }
        # The root itself must have survived every worker's eviction pass.
        assert os.path.isdir(cache_root);
        # Every worker's own entry must be intact and uncorrupted -- not a
        # torn copy, not deleted by a sibling's eviction or staging
        # collision.
        for (i, cache_dir) in enumerate(results) {
            assert os.path.isdir(cache_dir) , f"key{i} missing after the race";
            assert _venv_marker(cache_dir) == f"worker{i}" , (
                f"key{i} corrupted or torn after the race"
            );
        }
        # No worker's staging directory should still exist.
        leftovers = [
            name
            for name in os.listdir(cache_root)
            if name.startswith(".tmp")
        ];
        assert leftovers == [];
    }
}
