"""Dev-mode generation reseal.

When the compiler source tree changes, every cached module jir goes stale at
once (the compiler digest is part of every module's env fingerprint) and the
module cache starts filling a fresh generation directory. Left alone, that
refill happens lazily: one module at a time, serially, interleaved with
whatever command the user actually ran.

This module replaces the lazy avalanche with one batch rebuild at CLI
dispatch: the newest previous generation directory records exactly which
modules this machine had warm, so we map those jirs back to their source
files and recompile just that working set across forked workers, through the
same compile-and-persist path a lazy miss would take. Modules never cached
before stay lazy. A fresh machine has no previous generation and pays
nothing.

Correctness never depends on this pass: anything it skips or fails simply
recompiles lazily as before. Disable with JAC_DEV_RESEAL=0.
"""

import json;
import os;
import sys;
import time;
import types;
import from pathlib { Path }

glob RESEAL_MARKER: str = ".resealed",
     RESEAL_LOCK: str = ".reseal.lock";

glob _SKIP_COMMANDS: tuple = (
         "",
         "-h",
         "--help",
         "help",
         "version",
         "--version",
         "-V",
         "purge"
     );

glob _unit_program: list = [];

"""One unit through the normal miss path: compile and persist to the module
cache. With keep=False the closure is dropped after so worker RSS stays
flat; keep=True retains the analyzed hub so later units (and forked workers,
via copy-on-write) reuse it instead of re-analyzing shared deps."""
def _compile_unit(
    jac_path: str, collect: bool, keep: bool = False
) -> (types.CodeType | None) {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.cli.workpool { maybe_malloc_trim }

    compiler = Jac.get_compiler();
    if not _unit_program {
        _unit_program.append(JacProgram());
    }
    program = _unit_program[0];
    compiler.unit_collect = collect;
    code = compiler.get_bytecode(full_target=jac_path, target_program=program);
    if not keep {
        program.release_compile_closure(collect=collect);
        compiler.selfhost.program.release_compile_closure(collect=collect);
        maybe_malloc_trim();
    }
    return code;
}

glob _WARM_ROOTS: tuple = (
         "compiler/driver/compiler.jac",
         "compiler/types/type_evaluator.jac",
         "runtime/runtime.jac",
         "cli/commands/execution.jac",
         "lsp/server/server.jac"
     );

"""Retain analyzed closures across units for this process (and, via fork,
its workers): with unit_retain set, get_bytecode's outermost evict_unit is
skipped, so the hub accumulates instead of being rebuilt for every unit."""
def _retain_units -> None {
    import from jaclang.runtime.runtime { JacRuntime as Jac }

    Jac.get_compiler().unit_retain = True;
}

"""Fork-cascade warm-up (prototype, JAC_DEV_RESEAL_WARM=1): analyze a few
broad trunk roots once in the parent, then freeze the heap so forked workers
inherit the warm hub via copy-on-write instead of each re-analyzing shared
closures."""
def _warm_trunk -> None {
    import gc;
    import from jaclang.compiler.driver.jir { _jaclang_pkg_dir }

    trunk_started = time.monotonic();
    for rel in _WARM_ROOTS {
        candidate = os.path.join(_jaclang_pkg_dir, rel.replace("/", os.sep));
        if not os.path.isfile(candidate) {
            continue;
        }
        try {
            _compile_unit(candidate, collect=False, keep=True);
        } except Exception {
            continue;
        }
    }
    gc.freeze();
    sys.stderr.write(
        f"jac: trunk warm-up {time.monotonic() - trunk_started:.1f}s\n"
    );
    sys.stderr.flush();
}

def _reseal_retire(served: int, rss_mb: int) -> bool {
    import from jaclang.cli.workpool { env_int, should_retire }

    return should_retire(
        served,
        env_int("JAC_PRECOMPILE_RECYCLE", 0),
        rss_mb,
        env_int("JAC_PRECOMPILE_RECYCLE_MB", 4096)
    );
}

def _is_generation_name(name: str) -> bool {
    if len(name) != 16 {
        return False;
    }
    for ch in name {
        if ch not in "0123456789abcdef" {
            return False;
        }
    }
    return True;
}

"""Generation directories other than the current one whose last activity
falls inside the reseal window (default 7 days, JAC_DEV_RESEAL_WINDOW_DAYS).
One generation exists per compiler state, so these together record every
module this machine had warm recently."""
def _recent_generations(cache_root: Path, current: str) -> list[Path] {
    window_raw = os.environ.get("JAC_DEV_RESEAL_WINDOW_DAYS", "").strip();
    window_days = 7.0;
    if window_raw {
        try {
            window_days = max(0.0, float(window_raw));
        } except ValueError {
            window_days = 7.0;
        }
    }
    cutoff = time.time() - window_days * 86400.0;
    found: list[Path] = [];
    try {
        items = list(cache_root.iterdir());
    } except OSError {
        return found;
    }
    for item in items {
        if item.name == current or not _is_generation_name(item.name) {
            continue;
        }
        if not item.is_dir() {
            continue;
        }
        try {
            if item.stat().st_mtime < cutoff {
                continue;
            }
        } except OSError {
            continue;
        }
        found.append(item);
    }
    return found;
}

"""Map recent generations' jir files back to source paths.

Cache filenames are generation-independent (the generation is the directory),
so a candidate source belonged to the recent working set iff its cache
filename exists in any of those generations. Only jaclang-package modules are
candidates; loose out-of-tree files stay lazy."""
def _stale_working_set(prev_gens: list[Path]) -> list[str] {
    import from jaclang.compiler.driver.jir {
        _jaclang_pkg_dir,
        get_module_cache_path,
        is_module_cache_valid
    }
    import from jaclang.dist.precompile_bytecode { find_jac_files }

    cached_names: set[str] = set();
    for gen in prev_gens {
        try {
            for name in os.listdir(str(gen)) {
                if name.endswith(".jir") {
                    cached_names.add(name);
                }
            }
        } except OSError {
            continue;
        }
    }
    if not cached_names {
        return [];
    }
    targets: list[str] = [];
    for src in find_jac_files(_jaclang_pkg_dir) {
        cache_path = get_module_cache_path(src);
        if cache_path.name not in cached_names {
            continue;
        }
        if is_module_cache_valid(src, cache_path) {
            continue;
        }
        targets.append(src);
    }
    return targets;
}

def _write_marker(gen_dir: Path, stats: dict[(str, any)]) -> None {
    import from jaclang.compiler.driver.jir { codegen_cone_digest }

    gen_dir.mkdir(parents=True, exist_ok=True);
    marker = gen_dir / RESEAL_MARKER;
    payload = dict(stats);
    payload["digest"] = codegen_cone_digest();
    payload["ts"] = time.time();
    tmp = marker.with_name(f"{RESEAL_MARKER}.{os.getpid()}.tmp");
    try {
        tmp.write_text(json.dumps(payload, sort_keys=True) + "\n", encoding="utf-8");
        os.replace(str(tmp), str(marker));
    } finally {
        tmp.unlink(missing_ok=True);
    }
}

"""Compile the stale working set across forked workers, then stamp the
generation. Returns the run's counters."""
def _run_pool(targets: list[str]) -> dict[(str, any)] {
    import gc;
    import from jaclang.compiler.driver.compiler { COMPILE_GC_THRESHOLDS }
    import from jaclang.cli.workpool {
        WorkPool,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }

    raw_jobs = jobs_setting("precompile", "");
    workers = resolve_jobs(raw_jobs, env_var="JAC_PRECOMPILE_JOBS");
    use_pool = (
        pool_available()
        and not forced_serial(raw_jobs)
        and workers > 1
        and len(targets) > 1
    );
    if (
        not os.environ.get("JAC_GC_NO_COMPILE_BOOST")
        and gc.get_threshold()[0] < COMPILE_GC_THRESHOLDS[0]
    ) {
        gc.set_threshold(*COMPILE_GC_THRESHOLDS);
    }

    counts: dict[str, int] = {"compiled": 0, "reused": 0, "failed": 0};
    total = len(targets);
    started = time.monotonic();
    sys.stderr.write(
        f"jac: compiler changed -- resealing {total} cached modules"
            + (f" ({workers} workers)\n" if use_pool else " (serial)\n")
    );
    sys.stderr.flush();

    warm_setting = os.environ.get("JAC_DEV_RESEAL_WARM", "").strip();
    keep_hub = warm_setting not in ("0", "evict");
    if keep_hub {
        _retain_units();
        if warm_setting == "fork" {
            _warm_trunk();
        }
    }
    warm = targets[0];
    remaining = targets[1:];
    try {
        warm_code = _compile_unit(warm, collect=False, keep=keep_hub);
        counts["compiled" if warm_code is not None else "failed"] += 1;
    } except Exception {
        counts["failed"] += 1;
    }

    def unit_job(request: dict[(str, any)]) -> dict[(str, any)] {
        import from jaclang.compiler.driver.jir {
            get_module_cache_path,
            is_module_cache_valid
        }

        jac_path = str(request["path"]);
        try {
            if is_module_cache_valid(jac_path, get_module_cache_path(jac_path)) {
                return {"status": "reused"};
            }
            code = _compile_unit(jac_path, collect=not use_pool, keep=keep_hub);
            if code is None {
                return {"status": "failed", "message": f"no bytecode: {jac_path}"};
            }
            return {"status": "compiled"};
        } except Exception as e {
            return {"status": "failed", "message": f"{jac_path}: {e}"};
        }
    }

    failures: list[str] = [];

    def on_dispatch(idx: int, path: str) {
        done = counts["compiled"] + counts["reused"] + counts["failed"];
        sys.stderr.write(f"\r  [{done}/{total}] resealing...");
        sys.stderr.flush();
    }

    def on_record(idx: int, record: dict[(str, any)]) -> None {
        result = record.get("result");
        if not isinstance(result, dict) {
            detail = record.get("crash") or record.get("error") or "no result";
            failures.append(f"{remaining[idx]}: {detail}");
            counts["failed"] += 1;
            return;
        }
        status = str(result.get("status") or "failed");
        message = str(result.get("message") or "");
        if status == "failed" and message {
            failures.append(message);
        }
        counts[status] = counts.get(status, 0) + 1;
    }

    if remaining {
        pool = WorkPool(
            items=list(remaining),
            job=unit_job,
            on_record=on_record,
            jobs=min(workers, len(remaining)),
            retire=_reseal_retire,
            on_dispatch=on_dispatch,
            rss_log_env="JAC_PRECOMPILE_RSS_LOG",
            crash_prefix="jac-reseal-crash-"
        );
        if use_pool {
            pool.run();
        } else {
            pool.run_inline();
        }
    }

    elapsed = time.monotonic() - started;
    sys.stderr.write(
        f"\rjac: reseal done in {elapsed:.1f}s"
            + f" ({counts['compiled']} compiled, {counts['reused']} reused,"
            + f" {counts['failed']} failed)\n"
    );
    for line in failures[:5] {
        sys.stderr.write(f"  reseal skip: {line}\n");
    }
    if len(failures) > 5 {
        sys.stderr.write(f"  ... and {len(failures) - 5} more\n");
    }
    sys.stderr.flush();
    return counts;
}

def _reseal_if_stale -> None {
    import from jaclang.compiler.driver.jir { compiler_generation, get_jir_cache_dir }

    cache_root = get_jir_cache_dir() / "modules";
    current = compiler_generation();
    gen_dir = cache_root / current;
    if (gen_dir / RESEAL_MARKER).exists() {
        return;
    }
    prev_gens = _recent_generations(cache_root, current);
    if not prev_gens {
        _write_marker(gen_dir, {"targets": 0});
        return;
    }

    lock_handle: any = None;
    try {
        import fcntl;
        cache_root.mkdir(parents=True, exist_ok=True);
        lock_handle = open(cache_root / RESEAL_LOCK, "w");
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB);
    } except ImportError {
        lock_handle = None;
    } except OSError {
        if lock_handle is not None {
            lock_handle.close();
        }
        return;
    }

    try {
        targets = _stale_working_set(prev_gens);
        if not targets {
            _write_marker(gen_dir, {"targets": 0});
            return;
        }
        counts = _run_pool(targets);
        stats: dict[(str, any)] = {"targets": len(targets)};
        stats.update(counts);
        _write_marker(gen_dir, stats);
    } finally {
        if lock_handle is not None {
            lock_handle.close();
        }
    }
}

"""CLI-dispatch hook: batch-reseal the module cache when the compiler
generation changed. Never raises; anything it cannot do falls back to the
lazy path."""
def maybe_reseal(raw_argv: list[str]) -> None {
    if os.environ.get("JAC_DEV_RESEAL", "1").strip().lower() in ("0", "off", "false") {
        return;
    }
    command = raw_argv[0] if raw_argv else "";
    if command in _SKIP_COMMANDS {
        return;
    }
    try {
        _reseal_if_stale();
    } except Exception as e {
        sys.stderr.write(f"jac: dev reseal skipped ({e})\n");
        sys.stderr.flush();
    }
}
