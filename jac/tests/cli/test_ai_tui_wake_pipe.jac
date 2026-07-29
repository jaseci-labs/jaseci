"""Self-pipe wakeup: TuiEventQueue notifier + WakePipe + adapter wake_fd.

Covers the Python-owned half of the event-driven native loop (the native
poll(2) side is exercised by the native selftest harness):
  - a normal enqueue and a snapshot-required overflow each write a wake byte,
  - a flood of notifications never blocks on a full pipe,
  - events arriving after shutdown are discarded without a wake,
  - start() hands back a live read fd and dispose() closes both ends.
"""

import importlib;
import os;
import time;
import from threading { Event, Thread }


def _drain(fd: int) -> int {
    # Count and discard pending bytes on a nonblocking read fd.
    total = 0;
    while True {
        try {
            chunk = os.read(fd, 4096);
        } except BlockingIOError {
            break;
        } except OSError {
            break;
        }
        if not chunk {
            break;
        }
        total += len(chunk);
    }
    return total;
}


def _wait_readable(fd: int, deadline_s: float) -> int {
    while time.monotonic() < deadline_s {
        got = _drain(fd);
        if got > 0 {
            return got;
        }
        time.sleep(0.005);
    }
    return 0;
}


test "WakePipe.notify writes a drainable byte and close is idempotent" {
    wp_mod = importlib.import_module("jaclang.cli.ai_tui.wake_pipe");
    pipe = wp_mod.open_wake_pipe();
    assert pipe is not None;
    assert pipe.read_fd >= 0;
    assert pipe.write_fd >= 0;

    pipe.notify();
    assert _drain(pipe.read_fd) == 1;
    # Drained: nothing left to read.
    assert _drain(pipe.read_fd) == 0;

    pipe.close();
    assert pipe.read_fd == -1;
    assert pipe.write_fd == -1;
    # notify after close and a second close are both safe no-ops.
    pipe.notify();
    pipe.close();
}


test "TuiEventQueue notifies on normal submit and on snapshot overflow" {
    qmod = importlib.import_module("jaclang.cli.ai_tui.event_queue");
    wp_mod = importlib.import_module("jaclang.cli.ai_tui.wake_pipe");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");

    pipe = wp_mod.open_wake_pipe();
    queue = qmod.TuiEventQueue(max_records=2, max_bytes=10_000_000);
    queue.epoch = 1;
    queue.notifier = pipe;

    queue.submit(
        models.UiMutation(kind=bridge.MUT_DIAGNOSTIC, seq=0, epoch=1, text="a")
    );
    assert _drain(pipe.read_fd) == 1;

    # Force overflow (max_records=2): require_snapshot fires exactly one wake.
    queue.submit(
        models.UiMutation(kind=bridge.MUT_DIAGNOSTIC, seq=0, epoch=1, text="b")
    );
    queue.submit(
        models.UiMutation(kind=bridge.MUT_DIAGNOSTIC, seq=0, epoch=1, text="c")
    );
    assert queue.snapshot_required == True;
    assert _drain(pipe.read_fd) >= 1;
    pipe.close();
}


test "flood of notifications never blocks on a full pipe" {
    wp_mod = importlib.import_module("jaclang.cli.ai_tui.wake_pipe");
    pipe = wp_mod.open_wake_pipe();

    # Far more than any pipe buffer (typically 64 KiB): nonblocking write must
    # swallow EAGAIN rather than deadlock the caller.
    i = 0;
    while i < 200_000 {
        pipe.notify();
        i += 1;
    }
    # Still functional: something is readable and draining clears it.
    assert _drain(pipe.read_fd) > 0;
    pipe.close();
}


test "closed queue discards events without waking" {
    qmod = importlib.import_module("jaclang.cli.ai_tui.event_queue");
    wp_mod = importlib.import_module("jaclang.cli.ai_tui.wake_pipe");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");

    pipe = wp_mod.open_wake_pipe();
    queue = qmod.TuiEventQueue();
    queue.epoch = 1;
    queue.notifier = pipe;
    queue.close();

    queue.submit(
        models.UiMutation(kind=bridge.MUT_DIAGNOSTIC, seq=0, epoch=1, text="late")
    );
    assert _drain(pipe.read_fd) == 0;
    pipe.close();
}


test "adapter start returns live wake fd and dispose closes it" {
    ad_mod = importlib.import_module("jaclang.cli.ai_tui.tui_session_adapter");
    adapter = ad_mod.TuiSessionAdapter(cwd=os.getcwd(), stub=True, model_name="stub");
    start = adapter.start({"cwd": os.getcwd(), "stub": True});
    assert start.ok == True;
    assert start.wake_fd >= 0;
    wake_fd = start.wake_fd;

    # Submitting a prompt drives the stub turn, whose mutations flow through the
    # dispatcher -> queue -> notifier and wake the pipe.
    adapter.submit(ad_mod.make_prompt_command("hello"));
    deadline = time.monotonic() + 3.0;
    assert _wait_readable(wake_fd, deadline) > 0;

    result = adapter.dispose(reason="test", deadline_ms=2000);
    assert result.ok == True;
    # Both ends are closed: reading the (now dead) fd raises.
    raised = False;
    try {
        os.read(wake_fd, 1);
    } except OSError {
        raised = True;
    }
    assert raised == True;
}
