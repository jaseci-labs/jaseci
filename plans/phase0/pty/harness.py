#!/usr/bin/env python3
"""Phase 6 PTY qualification harness for jac-ai-tui.

Uses stdlib ``pty`` (no pexpect required). Each scenario has a wall-clock
deadline. Writes a JSON summary under ``plans/phase0/pty/results/``.

Recoverable scenarios must exit 0 when this harness is run explicitly or via
``JAC_AI_TUI_PTY_HARNESS=1`` (see ``test_ai_tui_phase6.jac``). The default
structural test suite does not gate on harness success. Signal/EOF scenarios are
characterized only (they validate the process terminates; terminal restore is not
gated on SIGKILL).

Examples::

    python3 plans/phase0/pty/harness.py --list
    python3 plans/phase0/pty/harness.py --scenario boot_quit --deadline 30
    python3 plans/phase0/pty/harness.py --all --deadline 45

Requires a built host at ``jac/jaclang/cli/ai_tui_na/bin/jac-ai-tui``.
Pass ``--build`` to invoke ``build_embed.sh`` when the binary is missing.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import pty
import select
import signal
import struct
import shutil
import subprocess
import sys
import termios
import time
from collections.abc import Callable
from dataclasses import asdict, dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
HOST = REPO / "jac" / "jaclang" / "cli" / "ai_tui_na" / "bin" / "jac-ai-tui"
BUILD_SH = REPO / "jac" / "jaclang" / "cli" / "ai_tui_na" / "build_embed.sh"
RESULTS = Path(__file__).resolve().parent / "results"

# Exit status is not gated for these — we only record that the process ends.
CHARACTERIZE_ONLY = frozenset(
    {
        "boot_sigterm",
        "boot_sighup",
        "boot_eof",
    }
)

ScenarioFn = Callable[[int, bytes, float, list[str], list[bytes]], None]


@dataclass
class ScenarioResult:
    name: str
    ok: bool
    deadline_s: float
    elapsed_s: float
    exit_status: int | None
    notes: list[str] = field(default_factory=list)
    output_tail: str = ""


def _materialize_jac_runtime() -> None:
    """Ensure a fused jac runtime tree exists under ~/.cache/jac/rt."""
    candidates: list[Path] = [
        REPO / "jac" / "zig-out" / "bin" / "jac",
    ]
    jac_env = os.environ.get("JAC_BIN", "").strip()
    if jac_env:
        candidates.append(Path(jac_env))
    jac_bin: str | None = None
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            jac_bin = str(c)
            break
    if jac_bin is None:
        jac_bin = shutil.which("jac")
    if not jac_bin:
        return
    subprocess.run(
        [jac_bin, "--version"],
        cwd=str(REPO),
        capture_output=True,
        timeout=120,
        check=False,
    )


def _resolve_jac_rt_dir() -> str | None:
    cache = Path.home() / ".cache" / "jac" / "rt"
    if not cache.is_dir():
        return None
    best: Path | None = None
    best_mtime = 0.0
    for child in cache.iterdir():
        if not child.is_dir():
            continue
        ok = child / ".ok"
        if not ok.is_file():
            continue
        mtime = ok.stat().st_mtime
        if mtime >= best_mtime:
            best_mtime = mtime
            best = child
    return str(best) if best is not None else None


def _embed_boot_failed(blob: bytes) -> bool:
    text = blob.decode("utf-8", errors="replace").lower()
    needles = (
        "bring-up failed",
        "trailer payload not materialized",
        "jac_engine_boot failed",
        "bootstrap import failed",
    )
    return any(n in text for n in needles)


def _child_env() -> dict[str, str]:
    env = os.environ.copy()
    # Force stub agent: no provider keys or byLLM seams during qualification.
    env.pop("JAC_AI_TUI_BYLLM_SRC", None)
    env.pop("JAC_AI_TUI_DEPS", None)
    env.pop("JAC_AI_TUI_NO_STUB", None)
    env.setdefault("TERM", "xterm-256color")
    debug = RESULTS / "debug.log"
    debug.parent.mkdir(parents=True, exist_ok=True)
    env["JAC_AI_TUI_DEBUG_LOG"] = str(debug)
    rt_dir = _resolve_jac_rt_dir()
    if rt_dir:
        env["JAC_RT_DIR"] = rt_dir
    return env


def _host_argv() -> list[str]:
    debug = RESULTS / "debug.log"
    argv = [str(HOST), "--stub", "--debug-log", str(debug)]
    return argv


def _set_winsize(fd: int, rows: int = 24, cols: int = 80) -> None:
    packed = struct.pack("HHHH", rows, cols, 0, 0)
    try:
        import fcntl

        fcntl.ioctl(fd, termios.TIOCSWINSZ, packed)
    except OSError:
        pass


def _spawn_host() -> tuple[int, int]:
    if not HOST.is_file():
        raise FileNotFoundError(f"missing host binary: {HOST}")
    pid, master = pty.fork()
    if pid == 0:
        os.environ.update(_child_env())
        os.chdir(str(REPO))
        os.execve(str(HOST), _host_argv(), os.environ)
    _set_winsize(master)
    return pid, master


def _drain(master: int, budget_s: float, sink: list[bytes] | None = None) -> bytes:
    end = time.monotonic() + budget_s
    chunks: list[bytes] = []
    while time.monotonic() < end:
        timeout = max(0.0, end - time.monotonic())
        r, _, _ = select.select([master], [], [], min(timeout, 0.2))
        if not r:
            continue
        try:
            data = os.read(master, 4096)
        except OSError:
            break
        if not data:
            break
        chunks.append(data)
    blob = b"".join(chunks)
    if sink is not None and blob:
        sink.append(blob)
    return blob


def _write(master: int, data: bytes) -> None:
    os.write(master, data)


def _wait_pid(pid: int, deadline: float) -> int | None:
    end = time.monotonic() + deadline
    while time.monotonic() < end:
        wpid, status = os.waitpid(pid, os.WNOHANG)
        if wpid == pid:
            if os.WIFEXITED(status):
                return os.WEXITSTATUS(status)
            if os.WIFSIGNALED(status):
                return -os.WTERMSIG(status)
            return status
        time.sleep(0.05)
    return None


def _kill(pid: int, sig: int = signal.SIGTERM) -> None:
    with contextlib.suppress(ProcessLookupError):
        os.kill(pid, sig)


def _quit(master: int, enter: bytes, budget: float, out: list[bytes]) -> None:
    _write(master, b"/quit" + enter)
    _drain(master, min(5.0, budget / 3), out)


def _scenario_boot_quit(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _quit(master, enter, budget, out)


def _scenario_boot_ctrl_c_idle(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _write(master, b"\x03")
    _drain(master, min(2.0, budget / 4), out)
    _quit(master, enter, budget, out)


def _scenario_boot_prompt_stub(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _write(master, b"hello from pty" + enter)
    _drain(master, min(5.0, budget / 3), out)
    _quit(master, enter, budget, out)


def _scenario_boot_stop_then_prompt(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _write(master, b"first turn" + enter)
    _drain(master, min(3.0, budget / 4), out)
    _write(master, b"\x07")  # ctrl-g -> STOP
    _drain(master, min(2.0, budget / 5), out)
    _write(master, b"second turn" + enter)
    _drain(master, min(4.0, budget / 3), out)
    _quit(master, enter, budget, out)


def _scenario_boot_stop_then_immediate_submit(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _write(master, b"turn one" + enter)
    time.sleep(0.05)
    _write(master, b"\x07")
    _write(master, b"turn two" + enter)
    _drain(master, min(6.0, budget / 2), out)
    _quit(master, enter, budget, out)


def _scenario_boot_double_prompt(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _write(master, b"prompt alpha" + enter + b"prompt beta" + enter)
    _drain(master, min(6.0, budget / 2), out)
    _quit(master, enter, budget, out)


def _scenario_boot_reset(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _write(master, b"before reset" + enter)
    _drain(master, min(3.0, budget / 4), out)
    _write(master, b"/reset" + enter)
    _drain(master, min(2.0, budget / 5), out)
    _write(master, b"after reset" + enter)
    _drain(master, min(4.0, budget / 3), out)
    _quit(master, enter, budget, out)


def _scenario_boot_reset_twice(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _write(master, b"/reset" + enter)
    _drain(master, min(1.5, budget / 6), out)
    _write(master, b"/reset" + enter)
    _drain(master, min(1.5, budget / 6), out)
    _write(master, b"ok" + enter)
    _drain(master, min(4.0, budget / 3), out)
    _quit(master, enter, budget, out)


def _scenario_boot_resize(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    _set_winsize(master, 30, 100)
    _drain(master, min(2.0, budget / 4), out)
    _quit(master, enter, budget, out)


def _scenario_boot_input_burst(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    burst = b"abcdefghijklmnopqrstuvwxyz" * 8
    _write(master, burst)
    _drain(master, min(1.0, budget / 8), out)
    _write(master, b"\x1b[B" * 4)
    _write(master, b"burst tail" + enter)
    _drain(master, min(5.0, budget / 3), out)
    _quit(master, enter, budget, out)


def _scenario_boot_sigterm(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    notes.append("SIGTERM sent to child")


def _scenario_boot_sighup(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    notes.append("SIGHUP sent to child")


def _scenario_boot_eof(
    master: int, enter: bytes, budget: float, notes: list[str], out: list[bytes]
) -> None:
    notes.append("master fd closed (tty EOF)")


SCENARIO_HANDLERS: dict[str, ScenarioFn] = {
    "boot_quit": _scenario_boot_quit,
    "boot_ctrl_c_idle": _scenario_boot_ctrl_c_idle,
    "boot_prompt_stub": _scenario_boot_prompt_stub,
    "boot_stop_then_prompt": _scenario_boot_stop_then_prompt,
    "boot_stop_then_immediate_submit": _scenario_boot_stop_then_immediate_submit,
    "boot_double_prompt": _scenario_boot_double_prompt,
    "boot_reset": _scenario_boot_reset,
    "boot_reset_twice": _scenario_boot_reset_twice,
    "boot_resize": _scenario_boot_resize,
    "boot_input_burst": _scenario_boot_input_burst,
    "boot_sigterm": _scenario_boot_sigterm,
    "boot_sighup": _scenario_boot_sighup,
    "boot_eof": _scenario_boot_eof,
}

SCENARIOS = list(SCENARIO_HANDLERS.keys())
RECOVERABLE_SCENARIOS = [n for n in SCENARIOS if n not in CHARACTERIZE_ONLY]


def _ensure_host(build: bool) -> None:
    if HOST.is_file():
        return
    if not build:
        raise FileNotFoundError(
            f"missing host binary: {HOST}\n"
            f"Run: {BUILD_SH}\n"
            "Or re-run with --build"
        )
    if not BUILD_SH.is_file():
        raise FileNotFoundError(f"missing build script: {BUILD_SH}")
    print(f"==> building embed host via {BUILD_SH}", file=sys.stderr)
    subprocess.run([str(BUILD_SH)], cwd=BUILD_SH.parent, check=True)
    if not HOST.is_file():
        raise FileNotFoundError(f"build finished but host missing: {HOST}")


def run_scenario(name: str, deadline_s: float) -> ScenarioResult:
    t0 = time.monotonic()
    notes: list[str] = []
    pid = -1
    master = -1
    out_parts: list[bytes] = []
    handler = SCENARIO_HANDLERS.get(name)
    if handler is None:
        return ScenarioResult(
            name=name,
            ok=False,
            deadline_s=deadline_s,
            elapsed_s=0.0,
            exit_status=None,
            notes=[f"unknown scenario {name!r}"],
        )
    try:
        pid, master = _spawn_host()
        boot_budget = min(15.0, max(4.0, deadline_s / 2))
        _drain(master, boot_budget, out_parts)
        if not out_parts:
            notes.append(
                "no pty output during boot wait (host may still be live)"
            )
        enter = b"\n"
        handler(master, enter, deadline_s, notes, out_parts)
        _drain(master, min(2.0, deadline_s / 8), out_parts)

        if name == "boot_sigterm":
            _kill(pid, signal.SIGTERM)
        elif name == "boot_sighup":
            _kill(pid, signal.SIGHUP)
        elif name == "boot_eof":
            os.close(master)
            master = -1

        remaining = max(0.5, deadline_s - (time.monotonic() - t0))
        status = _wait_pid(pid, remaining)
        if status is None:
            notes.append("deadline exceeded; sending SIGKILL")
            _kill(pid, signal.SIGKILL)
            status = _wait_pid(pid, 2.0)
            ok = False
        elif name in CHARACTERIZE_ONLY:
            ok = status is not None
            notes.append("signal/eof exit characterized (not a restore gate)")
        else:
            ok = status == 0
            if status != 0:
                notes.append(f"unexpected exit status {status}")
        out = b"".join(out_parts)
        if name not in CHARACTERIZE_ONLY and _embed_boot_failed(out):
            ok = False
            notes.append("embed runtime boot failed")
        notes.append(f"captured {len(out)} output bytes")
        tail = out[-500:].decode("utf-8", errors="replace")
        return ScenarioResult(
            name=name,
            ok=bool(ok),
            deadline_s=deadline_s,
            elapsed_s=round(time.monotonic() - t0, 3),
            exit_status=status,
            notes=notes,
            output_tail=tail,
        )
    except Exception as exc:  # noqa: BLE001 — characterization must always report
        if pid > 0:
            _kill(pid, signal.SIGKILL)
        return ScenarioResult(
            name=name,
            ok=False,
            deadline_s=deadline_s,
            elapsed_s=round(time.monotonic() - t0, 3),
            exit_status=None,
            notes=[f"exception: {exc!r}"],
            output_tail=b"".join(out_parts)[-500:].decode("utf-8", errors="replace"),
        )
    finally:
        if master >= 0:
            with contextlib.suppress(OSError):
                os.close(master)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--list", action="store_true", help="Print scenario names")
    ap.add_argument("--scenario", action="append", default=[])
    ap.add_argument("--all", action="store_true", help="Run all scenarios")
    ap.add_argument(
        "--recoverable",
        action="store_true",
        help="Run only recoverable (exit-0) scenarios",
    )
    ap.add_argument("--deadline", type=float, default=35.0)
    ap.add_argument(
        "--build",
        action="store_true",
        help="Build jac-ai-tui via build_embed.sh if missing",
    )
    args = ap.parse_args()

    if args.list:
        for name in SCENARIOS:
            tag = "characterize" if name in CHARACTERIZE_ONLY else "recoverable"
            print(f"{name}\t{tag}")
        return 0

    if args.all:
        names = list(SCENARIOS)
    elif args.recoverable:
        names = list(RECOVERABLE_SCENARIOS)
    elif args.scenario:
        names = list(args.scenario)
    else:
        names = ["boot_quit"]

    try:
        _materialize_jac_runtime()
        _ensure_host(args.build)
    except (FileNotFoundError, subprocess.CalledProcessError) as exc:
        print(f"host unavailable: {exc}", file=sys.stderr)
        return 2

    RESULTS.mkdir(parents=True, exist_ok=True)
    results = [run_scenario(n, args.deadline) for n in names]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    out_path = RESULTS / f"pty-{stamp}.json"
    payload = {
        "host": str(HOST),
        "host_exists": HOST.is_file(),
        "jac_rt_dir": _resolve_jac_rt_dir(),
        "recoverable_only": bool(args.recoverable),
        "results": [asdict(r) for r in results],
    }
    out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {out_path}", file=sys.stderr)
    for r in results:
        mark = "ok" if r.ok else "FAIL"
        print(f"{mark}\t{r.name}\texit={r.exit_status}\t{r.elapsed_s}s", file=sys.stderr)
    recoverable = [r for r in results if r.name not in CHARACTERIZE_ONLY]
    ok = all(r.ok for r in recoverable) if recoverable else all(r.ok for r in results)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
