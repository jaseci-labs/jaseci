"""#8766 on the 0.34 line: with MongoDB unreachable, the memory hierarchy fell
back to SqliteMemory on the pod filesystem -- one store per replica, gone on
the next restart, announced at debug. In a cluster that is data loss, so the
memory has to run without persistence and say so at error level. Off-cluster
the sqlite fallback is the point, hence the env scoping.
"""

import os;
import tempfile;
import unittest.mock;
import jaclang.scale.memory.memory_hierarchy as mh;
import from jaclang.scale.memory.memory_hierarchy {
    PersistenceType, ScaleTieredMemory
}


def _offline_memory(shelf_dir: str) -> ScaleTieredMemory {
    unavailable = unittest.mock.MagicMock();
    unavailable.is_available.return_value = False;
    cfg = unittest.mock.MagicMock();
    cfg.get_database_config.return_value = {
        "shelf_db_path": os.path.join(shelf_dir, "anchor_store.db")
    };
    with unittest.mock.patch.object(
        mh, "RedisBackend", return_value=unavailable
    ), unittest.mock.patch.object(
        mh, "MongoBackend", return_value=unavailable
    ), unittest.mock.patch.object(
        mh, "get_scale_config", return_value=cfg
    ), unittest.mock.patch(
        "jaclang.JacRuntimeInterface.get_persistent_memory", return_value=None
    ) {
        return ScaleTieredMemory(use_cache=False);
    }
}


test "in a cluster with no database, the memory refuses to embed sqlite" {
    prior = os.environ.get("KUBERNETES_SERVICE_HOST");
    # The value a pod sees with default settings (checked in kind).
    os.environ["KUBERNETES_SERVICE_HOST"] = "10.96.0.1";
    try {
        with tempfile.TemporaryDirectory() as tmpdir {
            mem = _offline_memory(tmpdir);
            assert mem.l3 is None , (
                "an embedded store in a pod is per-replica and lost on restart"
            );
            assert mem._persistence_type == PersistenceType.NONE;
            mem.close();
        }
    } finally {
        if prior is None {
            os.environ.pop("KUBERNETES_SERVICE_HOST", None);
        } else {
            os.environ["KUBERNETES_SERVICE_HOST"] = prior;
        }
    }
}


test "off-cluster the sqlite fallback keeps working" {
    prior = os.environ.pop("KUBERNETES_SERVICE_HOST", None);
    try {
        with tempfile.TemporaryDirectory() as tmpdir {
            mem = _offline_memory(tmpdir);
            assert mem.l3 is not None , (
                "off-cluster this must keep the embedded store, or every "
                "laptop run loses its persistence"
            );
            assert mem._persistence_type == PersistenceType.SQLITE;
            mem.close();
        }
    } finally {
        if prior is not None {
            os.environ["KUBERNETES_SERVICE_HOST"] = prior;
        }
    }
}
