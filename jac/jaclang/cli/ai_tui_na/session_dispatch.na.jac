# Typed session effect dispatch.

import from .runtime { TuiRuntime }
import from .state { TuiState }
import from .transport { CmdQueue }
import from .embed_session_client { EmbedSessionClient }
import from .input_types { Effect, EffectKind }
import from .ipc_schema { CMD_SEND, CMD_STOP, CMD_RESET, CMD_QUIT, CMD_APPLY }


def _session_live(rt: TuiRuntime) -> bool {
    session = rt.session;
    if session is None {
        return False;
    }
    # TuiRuntime defaults embed an uninitialized EmbedSessionClient; only route
    # through the typed bridge after session.start() succeeds (host_embed).
    return session.started;
}


def apply_effects_rt(rt: TuiRuntime, effects: list[Effect]) {
    state = rt.state;
    session = rt.session;
    use_session = _session_live(rt);
    for e in effects {
        if use_session and session is not None {
            if e.kind == EffectKind.SEND_PROMPT {
                receipt = session.submit_prompt(e.payload);
                session.apply_send_receipt(state, receipt);
            } elif e.kind == EffectKind.STOP {
                session.submit_abort();
            } elif e.kind == EffectKind.RESET {
                session.submit_reset();
            } elif e.kind == EffectKind.APPLY_SETTINGS {
                session.submit_apply_raw(e.payload);
            } elif e.kind == EffectKind.QUIT {
                state.quit_flag = True;
            }
        } else {
            if e.kind == EffectKind.QUIT {
                state.quit_flag = True;
                rt.cmd_queue.send(state.ipc_fd, CMD_QUIT);
            } elif e.kind == EffectKind.STOP {
                rt.cmd_queue.send(state.ipc_fd, CMD_STOP);
            } elif e.kind == EffectKind.RESET {
                rt.cmd_queue.send(state.ipc_fd, CMD_RESET);
            } elif e.kind == EffectKind.SEND_PROMPT {
                rt.cmd_queue.send(state.ipc_fd, CMD_SEND + ":" + e.payload);
            } elif e.kind == EffectKind.APPLY_SETTINGS {
                rt.cmd_queue.send(state.ipc_fd, CMD_APPLY + ":" + e.payload);
            }
        }
    }
}

def apply_effects_host(
    session: EmbedSessionClient,
    state: TuiState,
    cmd_queue: CmdQueue,
    effects: list[Effect]
) {
    rt = TuiRuntime();
    rt.session = session;
    rt.state = state;
    rt.cmd_queue = cmd_queue;
    apply_effects_rt(rt, effects);
}
