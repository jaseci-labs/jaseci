"""Efficiency guard: RedisBackend.batch_get() loads N anchors from L2 with a constant number of Redis commands via a single MGET, not one GET per anchor."""

import contextlib;
import gc;
import os;
import time;
import from pathlib { Path }
import from typing { cast }

import redis;
import from testcontainers.community.mongodb { MongoDbContainer }
import from testcontainers.community.redis { RedisContainer }
import from jaclang.scale.tests.server_support {
    call_walker,
    get_free_port,
    register_user,
    start_server
}

glob FIXTURES_DIR = Path(__file__).parent.parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "race_app.jac";

"""Total call count for the given Redis commands from INFO commandstats."""
def redis_cmd_calls(r: redis.Redis, commands: list[str]) -> int {
    stats = cast(dict, r.info("commandstats"));
    total = 0;
    for command in commands {
        entry = stats.get(f"cmdstat_{command}");
        if entry {
            total += int(entry["calls"]);
        }
    }
    return total;
}

"""Seed `count` anchors, then return the MGET and GET deltas of one steady-state read."""
def measure_l2_reads(
    base_url: str, token: str, redis_client: redis.Redis, count: int
) -> dict[str, int] {
    call_walker(base_url, "BulkCreate", token, {"count": count});
    time.sleep(0.3);
    # Warm-up read so first-touch writes settle into a steady state.
    call_walker(base_url, "ListItems", token);
    time.sleep(0.2);

    mget_before = redis_cmd_calls(redis_client, ["mget"]);
    get_before = redis_cmd_calls(redis_client, ["get"]);
    call_walker(base_url, "ListItems", token);
    time.sleep(0.2);
    return {
        "mget": redis_cmd_calls(redis_client, ["mget"]) - mget_before,
        "get": redis_cmd_calls(redis_client, ["get"]) - get_before
    };
}

"""Reading a small and a large population costs the same number of L2 read commands: the per-anchor marginal cost is ~0 with MGET and ~1 with per-node GET."""
test "batch_get loads N anchors from L2 with a constant number of Redis commands" {
    SMALL_COUNT = 5;
    LARGE_COUNT = 25;

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    redis_container = None;
    mongo_container = None;
    redis_client = None;
    server = None;
    try {
        redis_container = RedisContainer("redis:latest");
        redis_container.start();
        redis_host = redis_container.get_container_host_ip();
        redis_port = redis_container.get_exposed_port(6379);
        redis_url = f"redis://{redis_host}:{redis_port}/0";
        os.environ["REDIS_URL"] = redis_url;

        mongo_container = MongoDbContainer("mongo:latest");
        mongo_container.start();
        os.environ["MONGODB_URI"] = mongo_container.get_connection_url();

        redis_client = cast(redis.Redis, redis.from_url(redis_url));
        port = get_free_port();
        base_url = f"http://localhost:{port}";
        server = start_server(FIXTURES_DIR, JAC_FILE, port);

        token_small = register_user(base_url, "batch_small");
        small = measure_l2_reads(base_url, token_small, redis_client, SMALL_COUNT);

        token_large = register_user(base_url, "batch_large");
        large = measure_l2_reads(base_url, token_large, redis_client, LARGE_COUNT);

        # The batched path is exercised: anchors are read via MGET, never skipped.
        assert small["mget"] >= 1 and large["mget"] >= 1 , (
            f"REDIS BATCH: expected at least one MGET per read "
            f"(small={small['mget']}, large={large['mget']}); "
            "batch_get must load anchors through a single MGET."
        );

        # Constant-cost invariant: total L2 read commands must not scale with N.
        reads_small = small["mget"] + small["get"];
        reads_large = large["mget"] + large["get"];
        marginal = (reads_large - reads_small) / (LARGE_COUNT - SMALL_COUNT);
        assert marginal < 0.5 , (
            f"REDIS BATCH: per-anchor read cost {marginal:.2f} "
            f"(reads_small={reads_small} over {SMALL_COUNT}, "
            f"reads_large={reads_large} over {LARGE_COUNT}). "
            "Expected ~0 for MGET, ~1 for one GET per anchor. "
            "batch_get must issue a single MGET, not N individual GETs."
        );
    } finally {
        if redis_client {
            with contextlib.suppress(Exception) {
                redis_client.close();
            }
        }
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        os.environ.pop("REDIS_URL", None);
        os.environ.pop("MONGODB_URI", None);
        if mongo_container {
            with contextlib.suppress(Exception) {
                mongo_container.stop();
            }
        }
        if redis_container {
            with contextlib.suppress(Exception) {
                redis_container.stop();
            }
        }
        time.sleep(0.3);
        gc.collect();
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}
