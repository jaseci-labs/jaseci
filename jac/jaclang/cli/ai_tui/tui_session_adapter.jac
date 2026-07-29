import os;
import time;

import from threading { Event, Thread }

import from jaclang.cli.ai_tui.bridge_schema {
    CMD_KIND_ABORT,
    CMD_KIND_PROMPT,
    CMD_KIND_RESET,
    DISP_REJECTED,
    LIFE_IDLE
}
import from jaclang.cli.ai_tui.session_models {
    CommandError,
    CommandReceipt,
    DisposeResult,
    SessionCommand,
    SessionEventBatch,
    StartResult,
    UiMutation,
    UiSnapshot
}
import from jaclang.cli.ai_tui.ui_event_projector { UiEventProjector }
import from jaclang.cli.ai_tui.event_queue { TuiEventQueue }
import from jaclang.cli.ai_tui.session_event_dispatcher { SessionEventDispatcher }
import from jaclang.cli.ai_tui.core.agent_session_runtime { AgentSessionRuntime }
import from jaclang.cli.ai_tui.wake_pipe { open_wake_pipe }


obj TuiSessionAdapter {
    has cwd: str = "",
        stub: bool = True,
        model_name: str = "stub",
        started: bool = False,
        disposed: bool = False,
        runtime: AgentSessionRuntime | None = None,
        projector: UiEventProjector = UiEventProjector(),
        queue: TuiEventQueue = TuiEventQueue(),
        dispatcher: SessionEventDispatcher | None = None,
        _dispatcher_stop: any = None,
        _dispatcher_thread: any = None,
        _sub: any = None,
        _wake: any = None;

    def start(req: dict[str, any] | None = None) -> StartResult {
        if self.disposed {
            return StartResult(ok=False, error="adapter disposed");
        }
        if self.started and self.runtime is not None {
            snap = self.runtime.snapshot();
            wfd = self._wake.read_fd if self._wake is not None else -1;
            return StartResult(
                ok=True, session_id=snap.session_id, epoch=snap.epoch, wake_fd=wfd
            );
        }
        body: dict[str, any] = req if req is not None else {};
        cwd = str(body.get("cwd", self.cwd) or self.cwd or os.getcwd());
        stub = bool(body.get("stub", self.stub));
        model = str(body.get("model_name", self.model_name) or self.model_name);
        self.cwd = cwd;
        self.stub = stub;
        self.model_name = model;
        self.projector = UiEventProjector();
        self.queue = TuiEventQueue();
        self.queue.epoch = 1;
        # Self-pipe: dispatcher writes on enqueue, native poll(2) reads to wake.
        self._wake = open_wake_pipe();
        if self._wake is not None {
            self.queue.notifier = self._wake;
        }
        self.dispatcher = SessionEventDispatcher(
            projector=self.projector, queue=self.queue
        );
        self._dispatcher_stop = Event();
        self._dispatcher_thread = Thread(target=self._run_dispatcher, daemon=False);
        self.runtime = AgentSessionRuntime(
            cwd=cwd, stub=stub, model_name=model, epoch=1
        );
        self._sub = self.runtime.subscribe(self._on_runtime_event);
        self._dispatcher_thread.start();
        self.started = True;
        snap = self.runtime.snapshot();
        self.projector.state.epoch = snap.epoch;
        wake_fd = self._wake.read_fd if self._wake is not None else -1;
        return StartResult(
            ok=True, session_id=snap.session_id, epoch=snap.epoch, wake_fd=wake_fd
        );
    }

    def submit(cmd: SessionCommand) -> CommandReceipt {
        if self.disposed or self.runtime is None {
            return CommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                command_id=cmd.command_id,
                error=CommandError(code="not_started", message="adapter not started")
            );
        }
        return self.runtime.submit(cmd);
    }

    def poll(cap: int = 64) -> SessionEventBatch {
        if self.queue.closed {
            return SessionEventBatch();
        }
        return self.queue.drain(cap);
    }

    def snapshot -> UiSnapshot {
        return self.projector.snapshot();
    }

    def dispose(reason: str = "dispose", deadline_ms: int = 2000) -> DisposeResult {
        if self.disposed {
            return DisposeResult(ok=True, reason=reason, joined_workers=0);
        }
        self.disposed = True;
        joined = 0;
        timed_out = False;
        timeout_s = max(0.0, deadline_ms / 1000.0);
        deadline = time.monotonic() + timeout_s;
        if self.dispatcher is not None {
            self.dispatcher.close();
            if self._dispatcher_thread is not None {
                remaining = max(0.0, deadline - time.monotonic());
                self._dispatcher_thread.join(remaining);
                if self._dispatcher_thread.is_alive() {
                    timed_out = True;
                } else {
                    joined += 1;
                }
                self._dispatcher_thread = None;
            }
            self.dispatcher = None;
        }
        self._dispatcher_stop = None;
        self.queue.close();
        result = DisposeResult(
            ok=not timed_out, timed_out=timed_out, reason=reason, joined_workers=joined
        );
        if self.runtime is not None {
            remaining = max(0.0, deadline - time.monotonic());
            rt_ms = int(remaining * 1000.0);
            if rt_ms <= 0 {
                rt_ms = 1;
            }
            rt_result = self.runtime.dispose(reason=reason, deadline_ms=rt_ms);
            result.joined_workers += rt_result.joined_workers;
            if rt_result.timed_out {
                result.timed_out = True;
                result.ok = False;
            }
            self.runtime = None;
        }
        self.started = False;
        self._sub = None;
        # Close the pipe only after the dispatcher/feed threads have stopped so
        # no writer touches a closed fd. Native has already detached the read fd.
        if self._wake is not None {
            self._wake.close();
            self._wake = None;
        }
        return result;
    }

    def _run_dispatcher {
        if self.dispatcher is None or self._dispatcher_stop is None {
            return;
        }
        self.dispatcher.run_until(self._dispatcher_stop);
    }

    def _on_runtime_event(event: UiMutation) {
        if self.disposed or self.dispatcher is None {
            return;
        }
        self.dispatcher.enqueue(event);
    }
}


def make_prompt_command(text: str, command_id: str = "") -> SessionCommand {
    return SessionCommand(
        kind=CMD_KIND_PROMPT, command_id=command_id, payload={"text": text}
    );
}


def make_abort_command(command_id: str = "") -> SessionCommand {
    return SessionCommand(kind=CMD_KIND_ABORT, command_id=command_id);
}


def make_reset_command(command_id: str = "") -> SessionCommand {
    return SessionCommand(kind=CMD_KIND_RESET, command_id=command_id);
}
