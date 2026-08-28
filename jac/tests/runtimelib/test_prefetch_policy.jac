"""Tests for internal prefetch prediction policies."""

import json;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }

import from jaclang.project.config { JacConfig }
import from jaclang.runtime.prefetch_policy { get_prefetch_plan }
import from jaclang.runtime.prefetch_policy_history {
    clear_history_observations,
    record_history_observation
}
import from jaclang.runtime.prefetch_policy_manual {
    clear_manual_prefetch_plans,
    register_manual_prefetch_plan
}

obj PrefetchPolicyDummyWalker {}
obj PrefetchPolicyDummyStart {
    has id: UUID;
}

glob _manual_policy_ids: list = [];

def _manual_policy_generator(request: any) -> list {
    return _manual_policy_ids;
}

test "none prefetch policy returns empty plan" {
    plan = get_prefetch_plan("none", None, None, max_length=10);
    assert plan.ids == [];
}

test "oracle prefetch policy reads UUID list file" {
    id1 = UUID("00000000-0000-0000-0000-000000000001");
    id2 = UUID("00000000-0000-0000-0000-000000000002");
    id3 = UUID("00000000-0000-0000-0000-000000000003");
    with TemporaryDirectory() as raw_tmpdir_obj {
        raw_tmpdir: str = str(raw_tmpdir_obj);
        oracle_file = Path(raw_tmpdir) / "oracle.txt";
        oracle_file.write_text(
            f"# warmup log converted by external tooling\n{id1}\n{id2}\n{id1}\n{id3} # capped out\n"
        );
        cfg = JacConfig();
        cfg.run.prefetch_oracle_file = str(oracle_file);
        plan = get_prefetch_plan("oracle", None, None, max_length=2, config=cfg);
        assert plan.ids == [id1, id2];
    }
}

test "markov prefetch policy reads per-start model plan" {
    start_id = UUID("00000000-0000-0000-0000-000000000100");
    id1 = UUID("00000000-0000-0000-0000-000000000101");
    id2 = UUID("00000000-0000-0000-0000-000000000102");
    id3 = UUID("00000000-0000-0000-0000-000000000103");
    with TemporaryDirectory() as raw_tmpdir_obj {
        raw_tmpdir: str = str(raw_tmpdir_obj);
        model_file = Path(raw_tmpdir) / "markov.json";
        model_file.write_text(
            json.dumps(
                {
                    "version": 1,
                    "policy": "markov",
                    "plans": {
                        str(start_id): {
                            "plan": [str(id1), str(id2), str(id1), str(id3)]
                        }
                    }
                }
            )
        );
        cfg = JacConfig();
        cfg.run.prefetch_markov_file = str(model_file);
        start = PrefetchPolicyDummyStart(id=start_id);
        plan = get_prefetch_plan("markov", None, start, max_length=2, config=cfg);
        assert plan.ids == [id1, id2];
    }
}

test "coaccess prefetch policy reads per-start model plan" {
    start_id = UUID("00000000-0000-0000-0000-000000000200");
    id1 = UUID("00000000-0000-0000-0000-000000000201");
    id2 = UUID("00000000-0000-0000-0000-000000000202");
    id3 = UUID("00000000-0000-0000-0000-000000000203");
    with TemporaryDirectory() as raw_tmpdir_obj {
        raw_tmpdir: str = str(raw_tmpdir_obj);
        model_file = Path(raw_tmpdir) / "coaccess.json";
        model_file.write_text(
            json.dumps(
                {
                    "version": 1,
                    "policy": "coaccess",
                    "plans": {
                        str(start_id): {
                            "plan": [str(id1), str(id2), str(id1), str(id3)]
                        }
                    }
                }
            )
        );
        cfg = JacConfig();
        cfg.run.prefetch_coaccess_file = str(model_file);
        start = PrefetchPolicyDummyStart(id=start_id);
        plan = get_prefetch_plan("coaccess", None, start, max_length=2, config=cfg);
        assert plan.ids == [id1, id2];
    }
}

test "history prefetch policy returns last observed set for walker type" {
    clear_history_observations();
    id1 = UUID("00000000-0000-0000-0000-000000000011");
    id2 = UUID("00000000-0000-0000-0000-000000000012");
    id3 = UUID("00000000-0000-0000-0000-000000000013");
    w = PrefetchPolicyDummyWalker();
    record_history_observation(w, [id1, id2, id1, id3], max_length=10);
    plan = get_prefetch_plan("history", w, None, max_length=2);
    assert plan.ids == [id1, id2];
}

test "manual prefetch policy calls registered walker generator" {
    clear_manual_prefetch_plans();
    _manual_policy_ids.clear();
    id1 = UUID("00000000-0000-0000-0000-000000000021");
    id2 = UUID("00000000-0000-0000-0000-000000000022");
    _manual_policy_ids.extend([id1, id2, id1]);
    register_manual_prefetch_plan(
        "PrefetchPolicyDummyWalker", _manual_policy_generator
    );
    plan = get_prefetch_plan(
        "manual", PrefetchPolicyDummyWalker(), None, max_length=10
    );
    assert plan.ids == [id1, id2];
    clear_manual_prefetch_plans();
}
