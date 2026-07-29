import json;
import os;
import sys;

import from jaclang.cli.ai_tui.bridge_schema {
    CMD_KIND_ABORT,
    CMD_KIND_APPLY_SETTINGS,
    CMD_KIND_PROMPT,
    CMD_KIND_RESET,
    DISP_REJECTED,
    DISP_STARTED,
    encode_batch,
    encode_dispose_result,
    encode_receipt,
    encode_snapshot,
    encode_start_result,
    decode_command
}
import from jaclang.cli.ai_tui.session_models {
    CommandError,
    CommandReceipt,
    SessionCommand,
    mutation_dict
}
import from jaclang.cli.ai_tui.tui_session_adapter {
    TuiSessionAdapter,
    make_abort_command,
    make_prompt_command,
    make_reset_command
}
import from jaclang.cli.ai_tui.tui_shared {
    _apply_embed_path_env,
    _cmd_apply,
    _debug_log,
    _resolve_embed_seams,
    _silence_logging_for_tui,
    RECEIPT_OK
}


glob _adapter: TuiSessionAdapter | None = None,
     _poll_count: int = 0;


def _active -> TuiSessionAdapter {
    if _adapter is None {
        raise RuntimeError("embed agent not started");
    }
    return _adapter;
}


def _receipt_obj(receipt: CommandReceipt) -> str {
    err = receipt.error if receipt.error is not None else CommandError();
    return encode_receipt(
        receipt.accepted,
        receipt.disposition,
        command_id=receipt.command_id,
        prompt_id=receipt.prompt_id,
        error_code=err.code,
        error_message=err.message,
        retryable=err.retryable
    );
}


def _agent_ui_meta(stub: bool) -> tuple[str, list[str]] {
    if stub {
        return ("stub", ["stub"]);
    }
    try {
        import from jaclang.cli.ai_agent { ui_settings }
        settings = ui_settings();
        model = str(settings.get("model", "") or "");
        presets: list[str] = [];
        for raw in settings.get("presets", []) or [] {
            name = str(raw or "");
            if name {
                presets.append(name);
            }
        }
        return (model, presets);
    } except Exception {
        return ("", []);
    }
}


def _start_adapter(
    stub: bool, model_name: str = "stub", reason: str = ""
) -> dict[str, any] {
    global _adapter;
    if reason {
        sys.stderr.write(f"jac-ai-tui: using stub agent ({reason})\n");
        sys.stderr.write(
            "  pass --byllm-src=<jac-byllm checkout> and "
            "--byllm-deps=<dep dirs (litellm, openai, ...)> for the real agent.\n"
        );
    }
    adapter = TuiSessionAdapter(cwd=os.getcwd(), stub=stub, model_name=model_name);
    result = adapter.start(
        {"cwd": os.getcwd(), "stub": stub, "model_name": model_name}
    );
    if not result.ok {
        return {"ok": False, "error": result.error or "adapter start failed"};
    }
    _adapter = adapter;
    return {
        "ok": True,
        "session_id": result.session_id,
        "epoch": result.epoch,
        "error": "",
        "wake_fd": result.wake_fd
    };
}


def _start_real(model_name: str, n_ctx: int = 0, project: str = "") -> dict[str, any] {
    import from jaclang.cli.ai_agent { ui_configure }
    import from jaclang.cli.ai_tui.tui_shared { _debug_log }

    _debug_log(
        f"_start_real: ui_configure(model={model_name!r} n_ctx={n_ctx} project={project!r})"
    );
    ui_configure(model_override=model_name, n_ctx=n_ctx, project=project);

    import from jaclang.cli.ai_agent { agent as _agent_rt, agent_model as _am }
    model_name = "";
    try {
        model_name = str(_am.model_name);
    } except Exception {
        model_name = str(_agent_rt.bus.model_name);
    }
    _debug_log(
        f"_start_real: ui_configure done; bus.model_name={_agent_rt.bus.model_name!r} agent_model={model_name!r}"
    );
    return _start_adapter(stub=False, model_name=model_name or "agent");
}


def _parse_start_request(request: str) -> dict[str, any] {
    if not request or not request.strip() {
        return {};
    }
    data = json.loads(request);
    if not isinstance(data, dict) {
        raise ValueError("start request must be a JSON object");
    }
    return data;
}


def start(request: str = "{}") -> str {
    global _adapter,_poll_count;
    body = _parse_start_request(request);
    byllm_src = str(body.get("byllm_src", "") or "");
    byllm_deps = str(body.get("byllm_deps", "") or "");
    debug_log = str(body.get("debug_log", "") or "");
    (byllm_src, byllm_deps) = _resolve_embed_seams(byllm_src, byllm_deps);
    _apply_embed_path_env(byllm_src, byllm_deps);
    _silence_logging_for_tui(debug_log);
    _poll_count = 0;
    if _adapter is not None {
        try {
            _adapter.dispose(reason="re-start", deadline_ms=1000);
        } except Exception { }
        _adapter = None;
    }
    prefer_stub = bool(body.get("stub", False));
    model_name = str(body.get("model_name", "") or "");
    project = str(body.get("project", "") or body.get("cwd", "") or "");
    n_ctx = 0;
    try {
        n_ctx = int(body.get("n_ctx", 0) or 0);
    } except Exception { }
    _debug_log(
        f"start: stub={prefer_stub!r} model={model_name!r} n_ctx={n_ctx} project={project!r} " + f"byllm_src={byllm_src!r} byllm_deps={byllm_deps!r}"
    );
    if prefer_stub {
        got = _start_adapter(stub=True, model_name=model_name or "stub");
        (active_model, presets) = _agent_ui_meta(True);
        if model_name {
            active_model = model_name;
        }
        return encode_start_result(
            bool(got.get("ok")),
            session_id=str(got.get("session_id", "")),
            epoch=int(got.get("epoch", 0)),
            error=str(got.get("error", "")),
            model_name=active_model or "stub",
            presets=presets,
            wake_fd=int(got.get("wake_fd", -1))
        );
    }
    try {
        got = _start_real(model_name, n_ctx=n_ctx, project=project);
        (active_model, presets) = _agent_ui_meta(False);
        return encode_start_result(
            True,
            session_id=str(got.get("session_id", "")),
            epoch=int(got.get("epoch", 0)),
            model_name=active_model,
            presets=presets,
            wake_fd=int(got.get("wake_fd", -1))
        );
    } except Exception as e {
        _debug_log(f"_start_real failed: {e}");
        if bool(body.get("no_stub", False)) {
            return encode_start_result(False, error=str(e));
        }
        got = _start_adapter(stub=True, model_name="stub", reason=str(e));
        return encode_start_result(
            bool(got.get("ok")),
            session_id=str(got.get("session_id", "")),
            epoch=int(got.get("epoch", 0)),
            error=str(got.get("error", "")),
            model_name="stub",
            presets=["stub"],
            wake_fd=int(got.get("wake_fd", -1))
        );
    }
}


def submit(command: str) -> str {
    adapter = _active();
    try {
        data = decode_command(command);
    } except Exception as e {
        return encode_receipt(
            False, DISP_REJECTED, error_code="bad_command", error_message=str(e)
        );
    }
    kind = str(data.get("command", ""));
    command_id = str(data.get("command_id", ""));
    raw_payload = data.get("payload", {});
    body: dict[str, any] = raw_payload if isinstance(raw_payload, dict) else {};

    if kind == CMD_KIND_PROMPT {
        text = str(body.get("text", ""));
        _debug_log(f"submit prompt: {text!r}");
        return _receipt_obj(adapter.submit(make_prompt_command(text, command_id)));
    }
    if kind == CMD_KIND_ABORT {
        return _receipt_obj(adapter.submit(make_abort_command(command_id)));
    }
    if kind == CMD_KIND_RESET {
        return _receipt_obj(adapter.submit(make_reset_command(command_id)));
    }
    if kind == CMD_KIND_APPLY_SETTINGS {
        raw = str(body.get("raw", ""));
        if adapter.stub {
            return encode_receipt(
                False,
                DISP_REJECTED,
                command_id=command_id,
                error_code="stub",
                error_message="apply not supported in stub"
            );
        }
        import from threading { Event }
        try {
            rc = _cmd_apply(raw, Event(), None);
            if rc == RECEIPT_OK {
                return encode_receipt(True, "ok", command_id=command_id);
            }
            return encode_receipt(
                False,
                DISP_REJECTED,
                command_id=command_id,
                error_code="apply_failed",
                error_message=str(rc)
            );
        } except Exception as e {
            return encode_receipt(
                False,
                DISP_REJECTED,
                command_id=command_id,
                error_code="apply_failed",
                error_message=str(e)
            );
        }
    }
    return encode_receipt(
        False,
        DISP_REJECTED,
        command_id=command_id,
        error_code="unknown",
        error_message=kind
    );
}


def poll(cap: str = "64") -> str {
    global _poll_count;
    _poll_count += 1;
    adapter = _active();
    n = 64;
    try {
        n = int(cap);
    } except Exception {
        n = 64;
    }
    if n <= 0 {
        n = 64;
    }
    batch = adapter.poll(n);
    muts: list[any] = [];
    for m in batch.mutations {
        muts.append(mutation_dict(m));
    }
    if _poll_count <= 5 or _poll_count % 100 == 0 {
        _debug_log(
            f"poll typed #{_poll_count} batched={len(muts)} epoch={batch.epoch}"
        );
    }
    return encode_batch(batch.epoch, batch.first_seq, batch.last_seq, muts);
}


def snapshot -> str {
    adapter = _active();
    snap = adapter.snapshot();
    model = snap.model_name or adapter.model_name;
    if not adapter.stub {
        try {
            import from jaclang.cli.ai_agent { agent_model as _am, agent as _agent_rt }
            resolved = str(_am.model_name) or str(_agent_rt.bus.model_name);
            if resolved {
                model = resolved;
            }
        } except Exception { }
    }
    msgs: list[any] = [];
    for m in snap.messages {
        parts: list[any] = [];
        for p in m.parts {
            parts.append(
                {
                    "id": p.id,
                    "part_type": p.part_type,
                    "text": p.text,
                    "tool_name": p.tool_name,
                    "tool_args": p.tool_args,
                    "image_ref": p.image_ref
                }
            );
        }
        msgs.append(
            {"id": m.id, "role": m.role, "created_at": m.created_at, "parts": parts}
        );
    }
    return encode_snapshot(
        snap.epoch,
        snap.base_seq,
        snap.lifecycle,
        msgs,
        model_name=model,
        active=snap.active
    );
}


def dispose(spec: str = "{}") -> str {
    global _adapter;
    reason = "dispose";
    deadline_ms = 2000;
    try {
        data = json.loads(spec) if spec else {};
        if isinstance(data, dict) {
            reason = str(data.get("reason", reason));
            deadline_ms = int(data.get("deadline_ms", deadline_ms));
        }
    } except Exception { }
    if _adapter is None {
        return encode_dispose_result(True, False, reason, 0);
    }
    stub = _adapter.stub;
    if not stub {
        try {
            import from jaclang.cli.ai_agent { ui_stop }
            ui_stop();
        } except Exception as e {
            _debug_log(f"dispose: ui_stop failed: {e}");
        }
    }
    result = _adapter.dispose(reason=reason, deadline_ms=deadline_ms);
    _adapter = None;
    return encode_dispose_result(
        result.ok, result.timed_out, result.reason, result.joined_workers
    );
}


def stop {
    dispose(
        '{"schema_id":"jac.ai_tui.bridge.v1","kind":"dispose_spec","reason":"stop","deadline_ms":2000}'
    );
}
