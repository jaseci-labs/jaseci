"""Session access-log compatibility hooks."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }

import from jaclang.project.config {
    JacConfig,
    _parse_toml_data,
    get_explicit_config,
    set_config
}
import from jaclang.data.pgwire {
    selep_trace_reset_for_tests,
    sql_log_reset_for_tests
}
import from jaclang.data.store { PgStore }
import from jaclang.server.session {
    Session,
    _access_log_reset_for_tests,
    _tiered_access_log,
    hit_stats_add_checkpoint,
    hit_stats_read_checkpoints,
    hit_stats_reset,
    hit_stats_snapshot,
    runtime_for_base
}

obj AccessLogDummyArch {}

obj AccessLogDummyAnchor {
    has archetype: any;
}


test "run sql_log records pgwire sql csv" {
    old_config = get_explicit_config();
    try {
        with TemporaryDirectory() as tmpdir {
            log_path = Path(str(tmpdir)) / "sql.csv";
            parsed = _parse_toml_data({"run": {"sql_log": str(log_path)}}, None);
            assert parsed.run.sql_log == str(log_path);
            set_config(parsed);
            sql_log_reset_for_tests();

            lease = runtime_for_base(tmpdir, str(Path(str(tmpdir)) / "sql_app.jac"));
            store = PgStore(
                conninfo=lease.runtime.ensure(), ensure_cb=lease.runtime.ensure
            );
            try {
                rows = store.rows("SELECT CAST(:x AS int)", {"x": 7});
                assert int(rows[0][0]) == 7;
            } finally {
                store.close();
            }
            sql_log_reset_for_tests();

            body = log_path.read_text();
            assert body.startswith(
                "ts_ns,thread_id,database,application_name,elapsed_ms,row_count,"
                "param_count,param_keys,status,error,sql\n"
            );
            assert "SELECT CAST(:x AS int)" in body , body;
            assert ",ok,," in body , body;
        }
    } finally {
        sql_log_reset_for_tests();
        set_config(old_config);
    }
}

test "run selep trace records replayable sql jsonl" {
    old_trace = os.environ.get("JAC_SELEP_TRACE");
    try {
        with TemporaryDirectory() as tmpdir {
            trace_path = Path(str(tmpdir)) / "selep.jsonl";
            os.environ["JAC_SELEP_TRACE"] = str(trace_path);
            selep_trace_reset_for_tests();

            lease = runtime_for_base(tmpdir, str(Path(str(tmpdir)) / "trace_app.jac"));
            store = PgStore(
                conninfo=lease.runtime.ensure(), ensure_cb=lease.runtime.ensure
            );
            try {
                rows = store.rows("SELECT CAST(:x AS int)", {"x": 7});
                assert int(rows[0][0]) == 7;
            } finally {
                store.close();
            }
            selep_trace_reset_for_tests();

            body = trace_path.read_text();
            assert '"sql": "SELECT CAST(:x AS int)"' in body , body;
            assert '"params": {"x": 7}' in body , body;
            assert '"status": "ok"' in body , body;
        }
    } finally {
        selep_trace_reset_for_tests();
        if old_trace is None {
            os.environ.pop("JAC_SELEP_TRACE", None);
        } else {
            os.environ["JAC_SELEP_TRACE"] = old_trace;
        }
    }
}

test "run access_log writes old tier csv and hit stats" {
    old_config = get_explicit_config();
    try {
        with TemporaryDirectory() as tmpdir {
            log_path = Path(str(tmpdir)) / "access.csv";
            parsed = _parse_toml_data({"run": {"access_log": str(log_path)}}, None);
            assert parsed.run.access_log == str(log_path);
            set_config(parsed);
            _access_log_reset_for_tests();
            hit_stats_reset();

            hit_id = UUID("00000000-0000-0000-0000-000000000001");
            miss_id = UUID("00000000-0000-0000-0000-000000000002");
            get_miss_id = UUID("00000000-0000-0000-0000-000000000003");
            _tiered_access_log(
                hit_id,
                "L1",
                AccessLogDummyAnchor(archetype=AccessLogDummyArch())
            );
            _tiered_access_log(miss_id, "MISS");
            assert Session().get(get_miss_id) is None;

            body = log_path.read_text();
            assert body.startswith("id,tier,type\n");
            assert f"{hit_id},L1,AccessLogDummyArch\n" in body;
            assert f"{miss_id},MISS,\n" in body;
            assert f"{get_miss_id},MISS,\n" in body;

            stats = hit_stats_snapshot();
            assert stats["L1"] == 1;
            assert stats["MISS"] == 2;
            hit_stats_add_checkpoint("after_log");
            checkpoints = hit_stats_read_checkpoints();
            assert len(checkpoints) == 1;
            assert checkpoints[0][0] == "after_log";
            assert checkpoints[0][1]["L1"] == 1;
        }
    } finally {
        _access_log_reset_for_tests();
        hit_stats_reset();
        set_config(old_config);
    }
}
