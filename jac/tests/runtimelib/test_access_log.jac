"""Session access-log compatibility hooks."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }

import from jaclang.project.config {
    JacConfig,
    _parse_toml_data,
    get_explicit_config,
    set_config
}
import from jaclang.server.session {
    Session,
    _access_log_reset_for_tests,
    _tiered_access_log,
    hit_stats_add_checkpoint,
    hit_stats_read_checkpoints,
    hit_stats_reset,
    hit_stats_snapshot
}

obj AccessLogDummyArch {}

obj AccessLogDummyAnchor {
    has archetype: any;
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
