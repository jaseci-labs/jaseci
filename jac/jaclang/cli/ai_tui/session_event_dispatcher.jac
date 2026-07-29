import from queue { Queue }
import from threading { Event }

import from jaclang.cli.ai_tui.bridge_schema { MUT_SNAPSHOT_REQUIRED }
import from jaclang.cli.ai_tui.session_models { UiMutation }
import from jaclang.cli.ai_tui.ui_event_projector { UiEventProjector }
import from jaclang.cli.ai_tui.event_queue { TuiEventQueue }


glob _POISON: object = object();


obj SessionEventDispatcher {
    has projector: UiEventProjector,
        queue: TuiEventQueue,
        _inbound: Queue = Queue(),
        _closed: bool = False;

    def enqueue(raw: UiMutation) {
        if self._closed {
            return;
        }
        self._inbound.put(raw);
    }

    def close {
        if self._closed {
            return;
        }
        self._closed = True;
        self._inbound.put(_POISON);
    }

    def run_until(stop: Event) {
        # Block on the inbound queue rather than spin on a 50 ms timeout. close()
        # enqueues _POISON, so a shutdown always unblocks this get() promptly.
        while True {
            if stop.is_set() and self._inbound.empty() {
                break;
            }
            item = self._inbound.get();
            if item is _POISON {
                break;
            }
            self._process(item);
        }
    }

    def _process(event: UiMutation) {
        if event.kind == MUT_SNAPSHOT_REQUIRED {
            if event.diagnostic == "legacy_full_frame" {
                return;
            }
            self.queue.require_snapshot(event.diagnostic or "snapshot_required");
            return;
        }
        try {
            projected = self.projector.apply(event);
            for m in projected {
                self.queue.submit(m);
            }
            import from jaclang.cli.ai_tui.tui_shared { _debug_log }
            _debug_log(
                f"SessionEventDispatcher: kind={event.kind} projected={len(
                    projected
                )} " + f"snap_required={self.queue.snapshot_required}"
            );
        } except ValueError as e {
            self.queue.require_snapshot(str(e));
            import from jaclang.cli.ai_tui.tui_shared { _debug_log }
            _debug_log(f"SessionEventDispatcher: ValueError kind={event.kind} msg={e}");
        } except Exception as e {
            self.queue.require_snapshot(f"projector_error:{e}");
            import from jaclang.cli.ai_tui.tui_shared { _debug_log }
            _debug_log(
                f"SessionEventDispatcher: Exception kind={event.kind} msg={e!r}"
            );
        }
    }
}
