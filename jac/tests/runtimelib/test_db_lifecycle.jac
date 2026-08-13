"""Lifecycle contracts for the shared embedded Postgres cluster (issue #8094).

The runtime creates one database per absolute project path in a cluster shared
by the whole machine. Before these contracts existed databases were only ever
created: internal work (deploy staging, test workers) minted permanent
databases keyed to temp paths, and nothing could ever drop one.

Every test owns an isolated cluster under a temp dir, so nothing here touches
the developer's shared cluster at ~/.cache/jac/pg/main.
"""

import io;
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from typing { Any }

import from jaclang.runtimelib.pgembed { PgRuntime }

glob APP = "node Item {\n"
     "    has name: str;\n"
     "}\n"
     "\n"
     "with entry {\n"
     "    root ++> Item(name=\"x\");\n"
     "    print(\"items\", len([root-->]));\n"
     "}\n",
     BARE_APP = "with entry {\n    print(\"items 0\");\n}\n";


obj Cluster {
    has cache_home: str,
        data_dir: str,
        workspace: str,
        rt: Any,
        bin_dir: str;
}


"""Point a directory at the source tree under test: the launcher otherwise
serves its own embedded jaclang snapshot to child processes."""
def _write_jac_toml(directory: str, name: str) {
    import jaclang;
    src = str(Path(jaclang.__file__).parent.parent);
    Path(os.path.join(directory, "jac.toml")).write_text(
        f"[project]\nname = \"{name}\"\n\n[dev]\njaclang_source = \"{src}\"\n"
    );
}


"""Boot a private cluster whose layout matches $JAC_CACHE_HOME/pg/main."""
def _start_cluster -> Cluster {
    cache_home = tempfile.mkdtemp(prefix="jac-dblife-");
    data_dir = os.path.join(cache_home, "pg", "main");
    workspace = os.path.join(cache_home, "ws");
    os.makedirs(workspace);
    _write_jac_toml(workspace, "dblifews");
    rt = PgRuntime(data_dir=data_dir, database="postgres");
    rt.ensure();
    return Cluster(
        cache_home=cache_home,
        data_dir=data_dir,
        workspace=workspace,
        rt=rt,
        bin_dir=str(rt._bin_dir or "")
    );
}


def _stop_cluster(cluster: Cluster) {
    try {
        cluster.rt.stop();
    } except Exception { }
    shutil.rmtree(cluster.cache_home, ignore_errors=True);
}


def _admin(cluster: Cluster) -> Any {
    import from jaclang.vendor.pgload { connect }
    info = cluster.rt.conninfo();
    return connect(
        info.user,
        host=info.host,
        port=info.port,
        unix_socket_dir=info.unix_socket_dir,
        database="postgres"
    );
}


def _query(cluster: Cluster, sql: str) -> list {
    conn: Any = _admin(cluster);
    try {
        return conn.run(sql);
    } finally {
        conn.close();
    }
}


def _exec(cluster: Cluster, sql: str) {
    conn: Any = _admin(cluster);
    try {
        conn.run(sql);
    } finally {
        conn.close();
    }
}


def _jac_databases(cluster: Cluster) -> set[str] {
    return {
        str(r[0])
        for r in _query(
            cluster, "SELECT datname FROM pg_database WHERE datname LIKE 'jac\\_%'"
        )
    };
}


"""A project directory whose app writes one node into its own store."""
def _seed_project(name: str, app: str = "") -> str {
    proj = tempfile.mkdtemp(prefix=f"jac-{name}-");
    Path(os.path.join(proj, "app.jac")).write_text(app or APP);
    _write_jac_toml(proj, name);
    return proj;
}


def _child_env(cluster: Cluster, scratch: bool) -> dict {
    import jaclang;
    env = dict(os.environ);
    src = str(Path(jaclang.__file__).parent.parent);
    env["PYTHONPATH"] = src + os.pathsep + env.get("PYTHONPATH", "");
    env["JAC_CACHE_HOME"] = cluster.cache_home;
    env["JAC_PG_DIST"] = cluster.bin_dir;
    env.pop("JAC_DB_URL", None);
    if scratch {
        env["JAC_DB_SCRATCH"] = "1";
    } else {
        env.pop("JAC_DB_SCRATCH", None);
    }
    return env;
}


"""Run `jac run app.jac` inside *proj* against *cluster*."""
def _run_app(cluster: Cluster, proj: str, scratch: bool = False) -> tuple {
    res = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", os.path.join(proj, "app.jac")],
        cwd=proj,
        env=_child_env(cluster, scratch),
        capture_output=True,
        text=True,
        timeout=600
    );
    return (res.returncode, res.stdout, res.stderr);
}


def _run_python(cluster: Cluster, script: str) -> tuple {
    res = subprocess.run(
        [sys.executable, "-c", script],
        cwd=cluster.workspace,
        env=_child_env(cluster, False),
        capture_output=True,
        text=True,
        timeout=600
    );
    return (res.returncode, res.stdout, res.stderr);
}


"""Run an app in a fresh project and return the database it created."""
def _project_database(cluster: Cluster, name: str, app: str = "") -> tuple[str, str] {
    before = _jac_databases(cluster);
    proj = _seed_project(name, app=app);
    (rc, out, err) = _run_app(cluster, proj);
    assert rc == 0 , f"run in {proj} failed: {err}";
    created = _jac_databases(cluster) - before;
    assert len(created) == 1 , f"expected one new database, got {created}";
    return (proj, sorted(created)[0]);
}


def _capture(body: Any) -> tuple[int, str] {
    captured = io.StringIO();
    saved = sys.stdout;
    sys.stdout = captured;
    try {
        code = body();
    } finally {
        sys.stdout = saved;
    }
    return (int(code), captured.getvalue());
}


test "a scratch-mode run leaves no permanent database behind" {
    cluster = _start_cluster();
    scratch_proj = _seed_project("scratchrun");
    try {
        (proj, db_name) = _project_database(cluster, "plainrun");
        before = _jac_databases(cluster);

        (rc, out, err) = _run_app(cluster, scratch_proj, scratch=True);
        assert rc == 0 , f"scratch run failed: {err}";
        assert "items 1" in out , f"the scratch run never opened a store: {out!r}";

        names = _jac_databases(cluster);
        assert names == before , (
            f"internal (scratch) work left permanent databases behind: "
            f"{names - before}"
        );
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        shutil.rmtree(scratch_proj, ignore_errors=True);
        _stop_cluster(cluster);
    }
}


test "marked scratch bases share one database that dies with the process" {
    cluster = _start_cluster();
    script = (
        "import tempfile;"
        "from jaclang.runtimelib.session import mark_scratch_base;"
        "from jaclang.runtimelib.context import ExecutionContext;"
        "b1 = tempfile.mkdtemp(); b2 = tempfile.mkdtemp();"
        "mark_scratch_base(b1); mark_scratch_base(b2);"
        "c1 = ExecutionContext(base_path_dir=b1);"
        "print('LOC', c1.mem.data_location());"
        "c1.mem.store.kv_put('probe', 'kept');"
        "print('PROBE', c1.mem.store.kv_get('probe'));"
        "c1.close();"
        "c2 = ExecutionContext(base_path_dir=b2);"
        "print('LOC', c2.mem.data_location());"
        "print('PROBE', c2.mem.store.kv_get('probe'));"
        "c2.close()"
    );
    try {
        before = _jac_databases(cluster);
        (rc, out, err) = _run_python(cluster, script);
        assert rc == 0 , f"scratch-base child failed: {err}";
        locs = [
            line.split(" ", 1)[1]
            for line in out.splitlines()
            if line.startswith("LOC ")
        ];
        probes = [
            line.split(" ", 1)[1]
            for line in out.splitlines()
            if line.startswith("PROBE ")
        ];
        assert len(locs) == 2 and len(probes) == 2 , f"child printed {out!r}";
        assert "jac_scratch" in locs[0] , (
            f"a marked scratch base must not open a project database: {locs[0]}"
        );
        assert locs[0] == locs[1] , (
            f"every scratch base in one process shares one database: {locs}"
        );
        assert probes[0] == "kept" , f"the scratch store did not persist a write: {probes}";
        assert probes[1] == "None" , (
            f"a new scratch base must start empty, the way a fresh path did: {probes}"
        );
        names = _jac_databases(cluster);
        assert names == before , f"the scratch database outlived its process: {names}";
    } finally {
        _stop_cluster(cluster);
    }
}


test "a created database records its owning absolute path" {
    import from jaclang.runtimelib.dbcatalog { REGISTRY_TABLE }
    cluster = _start_cluster();
    try {
        (proj, db_name) = _project_database(cluster, "owned");
        rows = _query(
            cluster,
            f"SELECT owner_path, kind FROM {REGISTRY_TABLE} "
            f"WHERE database = '{db_name}'"
        );
        assert len(rows) == 1 , (
            f"{db_name} recorded no owner in {REGISTRY_TABLE}: {rows}"
        );
        assert str(rows[0][0]) in (os.path.abspath(proj), os.path.realpath(proj)) , (
            f"recorded owner {rows[0][0]!r} is not {proj!r}"
        );
        assert str(rows[0][1]) == "project" , f"kind was {rows[0][1]!r}";
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "db list reports every database without creating one" {
    import from jaclang.cli.commands { db }
    cluster = _start_cluster();
    try {
        (proj, db_name) = _project_database(cluster, "listed");
        before = _jac_databases(cluster);

        (code, text) = _capture(
            lambda { db.db(action="list", data_dir=cluster.data_dir); }
        );
        assert code == 0 , f"db list failed: {text}";
        assert db_name in text , f"db list omitted {db_name}: {text}";
        assert os.path.abspath(proj) in text or os.path.realpath(proj) in text , (
            f"db list omitted the owning path {proj}: {text}"
        );
        assert _jac_databases(cluster) == before , (
            "db list created a database as a side effect"
        );
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "db prune drops orphaned databases only, and only when told to" {
    import from jaclang.cli.commands { db }
    cluster = _start_cluster();
    try {
        (gone, gone_db) = _project_database(cluster, "gone");
        (kept, kept_db) = _project_database(cluster, "kept");
        shutil.rmtree(gone, ignore_errors=True);

        (code, text) = _capture(
            lambda { db.db(action="prune", data_dir=cluster.data_dir); }
        );
        assert code == 0 , f"db prune (dry run) failed: {text}";
        assert gone_db in text , f"the dry run did not name {gone_db}: {text}";
        assert kept_db not in text , (
            f"the dry run named the live project {kept_db}: {text}"
        );
        assert gone_db in _jac_databases(cluster) , "a dry run must not drop anything";

        (code, text) = _capture(
            lambda { db.db(action="prune", data_dir=cluster.data_dir, yes=True); }
        );
        assert code == 0 , f"db prune -y failed: {text}";
        names = _jac_databases(cluster);
        assert gone_db not in names , f"{gone_db} survived prune: {names}";
        assert kept_db in names , (
            f"prune dropped {kept_db} whose owning path still exists: {names}"
        );
        shutil.rmtree(kept, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "db prune reaps a scratch database whose process is gone" {
    import from jaclang.cli.commands { db }
    import from jaclang.runtimelib.dbcatalog { DbKind, REGISTRY_TABLE }
    cluster = _start_cluster();
    dead = subprocess.Popen([sys.executable, "-c", "pass"]);
    dead.wait();
    orphan = f"jac_scratch_{dead.pid}_dead";
    try {
        _exec(cluster, f'CREATE DATABASE "{orphan}"');
        _exec(
            cluster,
            f"INSERT INTO {REGISTRY_TABLE} "
            "(database, kind, owner_path, host, pid) "
            f"VALUES ('{orphan}', '{DbKind.SCRATCH.value}', "
            f"'', '{os.uname().nodename}', {dead.pid})"
        );
        (code, text) = _capture(
            lambda { db.db(action="prune", data_dir=cluster.data_dir, yes=True); }
        );
        assert code == 0 , f"db prune -y failed: {text}";
        assert orphan not in _jac_databases(cluster) , (
            f"{orphan} belongs to dead pid {dead.pid} and must be reaped: {text}"
        );
    } finally {
        _stop_cluster(cluster);
    }
}


test "db prune --empty reclaims pre-tracking databases that hold no data" {
    import from jaclang.cli.commands { db }
    import from jaclang.runtimelib.dbcatalog { REGISTRY_TABLE }
    cluster = _start_cluster();
    try {
        (with_data, data_db) = _project_database(cluster, "legacydata");
        (no_data, bare_db) = _project_database(cluster, "legacybare", app=BARE_APP);
        # Databases created before owner tracking have no registry row at all.
        _exec(
            cluster,
            f"DELETE FROM {REGISTRY_TABLE} WHERE database IN "
            f"('{data_db}', '{bare_db}')"
        );

        (code, text) = _capture(
            lambda { db.db(action="prune", data_dir=cluster.data_dir, yes=True); }
        );
        assert code == 0 , f"db prune -y failed: {text}";
        assert bare_db in _jac_databases(cluster) , (
            "plain prune must leave unattributed databases alone"
        );

        (code, text) = _capture(
            lambda { db.db(
                action="prune", data_dir=cluster.data_dir, yes=True, empty=True
            ); }
        );
        assert code == 0 , f"db prune --empty -y failed: {text}";
        names = _jac_databases(cluster);
        assert bare_db not in names , (
            f"{bare_db} holds no data and --empty should reclaim it: {text}"
        );
        assert data_db in names , (
            f"{data_db} holds user data and must survive --empty: {text}"
        );
        shutil.rmtree(with_data, ignore_errors=True);
        shutil.rmtree(no_data, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "db drop refuses without intent and drops with it" {
    import from jaclang.cli.commands { db }
    cluster = _start_cluster();
    try {
        (proj, db_name) = _project_database(cluster, "dropme");
        (code, text) = _capture(
            lambda { db.db(action="drop", query=db_name, data_dir=cluster.data_dir); }
        );
        assert db_name in _jac_databases(cluster) , (
            f"db drop without --yes must not drop anything: {text}"
        );

        (code, text) = _capture(
            lambda { db.db(
                action="drop", query=db_name, data_dir=cluster.data_dir, yes=True
            ); }
        );
        assert code == 0 , f"db drop -y failed: {text}";
        assert db_name not in _jac_databases(cluster) , f"{db_name} survived db drop";
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "the retention sweep is off by default and sweeps when configured" {
    import from jaclang.runtimelib.dbcatalog { REGISTRY_TABLE }
    cluster = _start_cluster();
    try {
        (proj, db_name) = _project_database(cluster, "stale");
        _exec(
            cluster,
            f"UPDATE {REGISTRY_TABLE} SET last_used_at = now() - interval '90 days' "
            f"WHERE database = '{db_name}'"
        );

        cluster.rt.stop();
        plain = PgRuntime(data_dir=cluster.data_dir, database="postgres");
        plain.ensure();
        cluster.rt = plain;
        assert db_name in _jac_databases(cluster) , (
            f"{db_name} was swept even though retention defaults to off"
        );

        plain.stop();
        sweeping = PgRuntime(
            data_dir=cluster.data_dir, database="postgres", retention_days=30
        );
        sweeping.ensure();
        cluster.rt = sweeping;
        assert db_name not in _jac_databases(cluster) , (
            f"{db_name} is 90 days stale and retention_days=30 must sweep it"
        );
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "retention days come from [database] retention_days, off by default" {
    import from jaclang.runtimelib.session { retention_days_for }
    base = tempfile.mkdtemp(prefix="jac-retention-");
    try {
        assert retention_days_for(base) == 0 , "retention must default to off";
        Path(os.path.join(base, "jac.toml")).write_text(
            "[project]\nname = \"r\"\n\n[database]\nretention_days = 45\n"
        );
        assert retention_days_for(base) == 45 , (
            "[database] retention_days must be honored"
        );
        os.environ["JAC_DB_RETENTION_DAYS"] = "7";
        try {
            assert retention_days_for(base) == 7 , (
                "JAC_DB_RETENTION_DAYS must override jac.toml"
            );
        } finally {
            os.environ.pop("JAC_DB_RETENTION_DAYS", None);
        }
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
