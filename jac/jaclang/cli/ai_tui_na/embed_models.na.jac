"""Native embed/session value types for EmbedRuntime and EmbedSessionClient."""

obj EmbedResult {
    has ok: bool = False,
        error: str = "";
}


obj BindResult {
    has ok: bool = False,
        error: str = "";
}


obj EmbedCallResult {
    has ok: bool = False,
        value: str = "",
        error: str = "";
}


obj FinalizeResult {
    has finalized: bool = False,
        skipped: bool = False,
        reason: str = "";
}


obj AgentRequest {
    has cwd: str = "",
        stub: bool = True,
        model_name: str = "stub",
        n_ctx: int = 0,
        project: str = "",
        byllm_src: str = "",
        byllm_deps: str = "",
        debug_log: str = "",
        no_stub: bool = False;
}


obj NativeCommandReceipt {
    has accepted: bool = False,
        disposition: str = "rejected",
        command_id: str = "",
        prompt_id: str = "",
        error_code: str = "",
        error_message: str = "";
}


obj NativeStartResult {
    has ok: bool = False,
        session_id: str = "",
        epoch: int = 0,
        error: str = "",
        model_name: str = "",
        presets: list[str] = [],
        wake_fd: int = -1;
}


obj NativeDisposeResult {
    has ok: bool = True,
        timed_out: bool = False,
        reason: str = "",
        joined_workers: int = 0;
}


obj NativeSessionBatch {
    has epoch: int = 0,
        first_seq: int = 0,
        last_seq: int = 0,
        mutations: list[any] = [],
        raw: str = "";
}


obj NativeUiSnapshot {
    has epoch: int = 0,
        base_seq: int = 0,
        lifecycle: str = "idle",
        model_name: str = "",
        active: str = "",
        messages: list[any] = [],
        raw: str = "";
}
