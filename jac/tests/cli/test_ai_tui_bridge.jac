"""Regression tests for the `jac ai --tui` command bridge + shared helpers.

The command dispatcher (`_dispatch_cmd`) and the env/tty/project helpers live in
`tui_shared` and are imported VERBATIM by the embed host's embedded interpreter
(`ai_tui_na/host_embed.na.jac`), so these tests guard the one wire/env contract
that host runs. The trailing block covers the byLLM provider-error capture in
`ai_agent`, independent of any TUI transport.
"""

import importlib;
import os;
import pytest;
import from pathlib { Path }
import jaclang.cli.ai_agent as ai_mod;
import from jaclang.cli.agent_api { AgentRequest }


obj DummyProc {
    has terminated: bool = False;

    def terminate {
        self.terminated = True;
    }
}


obj DummyStopEvt {
    has stopped: bool = False;

    def set {
        self.stopped = True;
    }

    def is_set -> bool {
        return self.stopped;
    }
}


test "SEND dispatch resolves the UI bridge in dispatcher scope" {
    seen: list[str] = [];
    tui_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    dispatch = getattr(tui_mod, "_dispatch_cmd");
    old_send = getattr(ai_mod, "ui_send");

    def fake_send(prompt: str) -> bool {
        seen.append(prompt);
        return True;
    }

    setattr(ai_mod, "ui_send", fake_send);
    try {
        dispatch("SEND:hi", DummyStopEvt(), DummyProc());
    } finally {
        setattr(ai_mod, "ui_send", old_send);
    }

    assert seen == ["hi"] , f"expected SEND payload to reach ui_send; seen={seen!r}";
}


test "QUIT dispatch resolves ui_stop and tears down a present proc" {
    seen: list[str] = [];
    tui_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    dispatch = getattr(tui_mod, "_dispatch_cmd");
    old_stop = getattr(ai_mod, "ui_stop");

    def fake_stop {
        seen.append("stop");
    }

    setattr(ai_mod, "ui_stop", fake_stop);
    try {
        proc = DummyProc();
        stop_evt = DummyStopEvt();
        # Shared dispatcher signature is (line, stop_evt, proc); proc is optional
        # (None for the in-process backend) and terminated only when present.
        dispatch("QUIT", stop_evt, proc);
        assert stop_evt.is_set();
        assert proc.terminated;
    } finally {
        setattr(ai_mod, "ui_stop", old_stop);
    }

    assert seen == ["stop"] , f"expected QUIT to call ui_stop exactly once; seen={seen!r}";
}


test "_list_project_files enumerates files under a project dir" {
    import tempfile;
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    lister = getattr(shared_mod, "_list_project_files");
    with tempfile.TemporaryDirectory() as d {
        os.makedirs(os.path.join(d, "sub"));
        with open(os.path.join(d, "a.txt"), "w") as f {
            f.write("x");
        }
        with open(os.path.join(d, "sub", "b.txt"), "w") as f {
            f.write("y");
        }
        listing = lister(d);
        names: list[str] = [];
        for line in listing.split("\n") {
            s = line.strip();
            if s {
                names.append(s);
            }
        }
        assert "a.txt" in names , f"expected a.txt in {names!r}";
        has_b: bool = False;
        for n in names {
            if n.endswith("b.txt") {
                has_b = True;
            }
        }
        assert has_b , f"expected b.txt in {names!r}";
    }
}


test "_build_embed_argv passes config as flags (no JAC_AI_* env)" {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    build_argv = getattr(shared_mod, "_build_embed_argv");
    seams = {"src": "/byllm", "deps": "/litellm:/openai"};
    argv = build_argv(
        AgentRequest(tui=True, cwd=os.getcwd(), model="new-model", n_ctx=4096,), seams
    );
    assert "--project" in argv;
    assert os.getcwd() in argv;
    assert "-m" in argv;
    assert "new-model" in argv;
    assert "--n-ctx" in argv;
    assert "4096" in argv;
    assert "--byllm-src" in argv;
    assert "/byllm" in argv;
    assert "--byllm-deps" in argv;
    assert "/litellm:/openai" in argv;
    for key in [
        "JAC_AI_UI_PROJECT",
        "JAC_AI_UI_MODEL",
        "JAC_AI_UI_NCTX",
        "JAC_AI_UI_FILES",
        "JAC_AI_UI_MODEL_PRESETS",
        "JAC_AI_TUI_BYLLM_SRC",
        "JAC_AI_TUI_DEPS",
        "JAC_AI_TUI_NO_STUB",
        "JAC_AI_TUI_DEBUG_LOG",
        "JAC_AI_TUI_REBUILD",
        "JAC_AI_TUI_TTY",

    ] {
        assert key not in os.environ , f"{key} must not be set by launcher";
    }
}


test "_embed_byllm_seams always seeds user site-packages for embed host" {
    import site;

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    seams_fn = getattr(shared_mod, "_embed_byllm_seams");
    seams = seams_fn();
    deps = str(seams.get("deps", "") or "");
    user_site = "";
    try {
        user_site = str(site.getusersitepackages() or "");
    } except Exception { }
    assert deps , "expected byllm dep dirs for embed host sys.path seeding";
    if user_site {
        assert user_site in deps.split(os.pathsep) , (
            f"expected user site-packages in deps; deps={deps!r} user_site={user_site!r}"
        );
    }
}


test "_resolve_embed_seams fills missing byllm deps for direct embed launches" {
    import site;

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    resolve_fn = getattr(shared_mod, "_resolve_embed_seams");
    (src, deps) = resolve_fn("", "");
    assert src , "expected auto byllm src for bare embed host launch";
    assert deps , "expected auto byllm deps for bare embed host launch";
    user_site = "";
    try {
        user_site = str(site.getusersitepackages() or "");
    } except Exception { }
    if user_site {
        assert user_site in deps.split(os.pathsep) , (
            f"expected user site-packages in resolved deps; deps={deps!r}"
        );
    }
    (src2, deps2) = resolve_fn("/custom/src", "/custom/deps");
    assert src2 == "/custom/src";
    assert deps2 == "/custom/deps";
}


test "native TUI runtime keeps embed transport dispatch concrete" {
    # Regression for the broken `jac ai --tui --model ...` path: the UI env did
    # carry the model override into the embed host, but the native runtime typed
    # `rt.transport` as the base `Transport`, so `.flush_outbound_cmds()` and
    # `.recv_blob()` resolved to base no-ops. The TUI looked loaded, but sends
    # never reached `ui_send()` and agent frames (including the model-bearing
    # full snapshot) never rendered.
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    cli_dir = Path(shared_mod.__file__).resolve().parent.parent;
    runtime_src = (cli_dir / "ai_tui_na" / "runtime.na.jac").read_text();
    transport_src = (cli_dir / "ai_tui_na" / "transport.na.jac").read_text();
    app_src = (cli_dir / "ai_tui_na" / "interactive_app.na.jac").read_text();
    host_src = (cli_dir / "ai_tui_na" / "host_embed.na.jac").read_text();

    assert "transport: EmbedPyTransport = EmbedPyTransport()" in runtime_src , (
        "TuiRuntime.transport must stay concretely typed as EmbedPyTransport or "
        "native dispatch falls back to Transport's no-op recv/send methods"
    );
    assert "tui: Tui = Tui()" in runtime_src , (
        "TuiRuntime must own a Tui for InteractiveApp production cutover"
    );
    assert "obj EmbedPyTransport(TtyFdTransport)" in transport_src , (
        "Embed transport implementation missing from transport.na.jac"
    );
    assert "import from jacpyembed" not in transport_src , (
        "Phase 4: transport must not import CPython symbols; EmbedRuntime owns them"
    );
    assert "def poll_gil(timeout_ms: int)" in transport_src , (
        "TtyFdTransport must expose poll_gil for tests and injected-key harnesses"
    );
    assert "tty_poll(timeout_ms);" in app_src , (
        "InteractiveApp must poll the tty without virtual dispatch so the Python feed can run"
    );
    assert "_drain_session" in app_src , (
        "InteractiveApp drains typed session batches via EmbedSessionClient"
    );
    assert "InteractiveApp" in host_src , (
        "host_embed production path must run through InteractiveApp"
    );
    assert "app.shutdown();" in host_src , (
        "host_embed teardown must restore the terminal via InteractiveApp.shutdown"
    );
    assert "rt.transport.close_py();" not in host_src , (
        "host teardown must not dispatch through rt.transport after the loop"
    );
    assert "import from jacpyembed" not in host_src , (
        "Phase 4: host_embed must not import jacpyembed; EmbedRuntime owns C-API"
    );
    # Phase 1+4: tty restore precedes managed dispose / conditional finalize.
    finally_i = host_src.rfind("} finally {");
    assert finally_i > 0 , "host _run_embed must have a finally teardown block";
    teardown = host_src[finally_i:];
    shutdown_i = teardown.find("app.shutdown();");
    disp_i = teardown.find("session.dispose(");
    fin_i = teardown.find("finalize_if_safe(");
    assert shutdown_i > 0 , "app.shutdown must run in finally teardown";
    assert disp_i > shutdown_i , "app.shutdown must precede session.dispose (terminal-first quit)";
    assert fin_i > disp_i , "finalize_if_safe must follow dispose";
}


test "_resolve_jac_build_bin prefers JAC_BIN then repo zig-out binary" {
    import tempfile;
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    resolver = getattr(shared_mod, "_resolve_jac_build_bin");
    pkg_root = Path(shared_mod.__file__).resolve().parent.parent;
    repo_root = pkg_root.parent.parent.parent;
    repo_jac = repo_root / "jac" / "zig-out" / "bin" / "jac";

    with tempfile.NamedTemporaryFile(delete=False) as tmp {
        tmp.write(b"");
        explicit = tmp.name;
    }
    os.chmod(explicit, 0o755);
    prior_jac_bin = os.environ.get("JAC_BIN");
    try {
        os.environ["JAC_BIN"] = explicit;
        assert resolver(pkg_root) == explicit;
        os.environ.pop("JAC_BIN", None);
        if repo_jac.is_file() {
            assert resolver(pkg_root) == str(repo_jac);
        } else {
            assert resolver(pkg_root) is None;
        }
    } finally {
        os.unlink(explicit);
        if prior_jac_bin is None {
            os.environ.pop("JAC_BIN", None);
        } else {
            os.environ["JAC_BIN"] = prior_jac_bin;
        }
    }
}


test "_probe_tty on posix resolves ttyname from first tty stream" {
    import os;
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    probe_tty = getattr(shared_mod, "_probe_tty");

    mock_stream = unittest.mock.MagicMock();
    mock_stream.fileno.return_value = 7;

    with unittest.mock.patch.object(sys, "platform", "linux") {
        with unittest.mock.patch.object(
            shared_mod, "_first_tty_stream", return_value=mock_stream
        ) {
            with unittest.mock.patch.object(
                os, "ttyname", return_value="/dev/pts/42"
            ) as ttyname {
                result = probe_tty();
                assert result["available"] == True , result;
                assert result["device"] == "/dev/pts/42" , result;
                ttyname.assert_called_once_with(7);
            }
        }
    }
}


test "_probe_tty on posix returns available=False when no tty stream" {
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    probe_tty = getattr(shared_mod, "_probe_tty");

    with unittest.mock.patch.object(sys, "platform", "linux") {
        with unittest.mock.patch.object(
            shared_mod, "_first_tty_stream", return_value=None
        ) {
            result = probe_tty();
            assert result["available"] == False , result;
            assert result["device"] == "" , result;
        }
    }
}


test "_probe_tty on posix falls back to empty device when ttyname raises" {
    import os;
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    probe_tty = getattr(shared_mod, "_probe_tty");

    mock_stream = unittest.mock.MagicMock();
    mock_stream.fileno.return_value = 5;

    with unittest.mock.patch.object(sys, "platform", "linux") {
        with unittest.mock.patch.object(
            shared_mod, "_first_tty_stream", return_value=mock_stream
        ) {
            with unittest.mock.patch.object(
                os, "ttyname", side_effect=OSError("not a tty")
            ) {
                result = probe_tty();
                assert result["available"] == True , result;
                assert result["device"] == "" , result;
            }
        }
    }
}


test "na IPC schema mirrors the host wire constants" {
    # The host (ipc_schema.jac) and TUI (ipc_schema.na.jac) carry the wire
    # protocol in two Jac modules with no shared import; this test is the only
    # thing pinning that their wire *values* agree, so a silent drift in either
    # file fails CI instead of corrupting the runtime protocol between the embed
    # host and the native renderer.
    import re;
    import importlib;
    schema = importlib.import_module("jaclang.cli.ai_tui.ipc_schema");
    here = Path(schema.__file__).resolve().parent;
    wire_re = r':\s*str\s*=\s*"([^"]*)"';
    host_vals: set = set(re.findall(wire_re, (here / "ipc_schema.jac").read_text()));
    na_vals: set = set(
        re.findall(
            wire_re, (here.parent / "ai_tui_na" / "ipc_schema.na.jac").read_text()
        )
    );
    for v in host_vals {
        assert v in na_vals , f"wire value {v!r} in ipc_schema.jac missing from ipc_schema.na.jac";
    }
    for v in na_vals {
        assert v in host_vals , f"wire value {v!r} in ipc_schema.na.jac missing from ipc_schema.jac";
    }
}


obj CaptureBus {
    has events: list = [];

    def emit(kind: str, fields: dict) {
        ev = {"kind": kind};
        ev.update(fields);
        self.events.append(ev);
    }
}


test "ui output capture dedups provider loguru errors after agent registration" {
    pytest.importorskip("loguru", reason="This test requires loguru to be installed");
    import from jaclang.cli.ai_agent {
        _install_ui_provider_capture,
        register_ui_provider_error
    }
    import from loguru { logger }

    bus = CaptureBus();
    _install_ui_provider_capture(bus);
    register_ui_provider_error(RuntimeError("LLM call failed with APIError: boom"));
    logger.error("LLM call failed with APIError: boom");
    assert len(bus.events) == 0 , bus.events;
    logger.error("LLM AuthenticationError: bad key");
    assert len(bus.events) == 1 , bus.events;
    assert bus.events[0]["kind"] == "error" , bus.events[0];
    assert "provider:" in str(bus.events[0].get("text", "")) , bus.events[0];
}


test "ui output capture dedups when the loguru sink fires before the worker emit" {
    pytest.importorskip("loguru", reason="This test requires loguru to be installed");
    import from jaclang.cli.ai_agent {
        _install_ui_provider_capture,
        register_ui_provider_error
    }
    import from loguru { logger }

    # `_ui_is_duplicate_provider_error` is an impl-annex helper (no decl), reached
    # as a module attribute like the worker's except path resolves it at runtime.
    is_dup = getattr(ai_mod, "_ui_is_duplicate_provider_error");
    # Stale fingerprints from a prior test would poison the 2s dedup window.
    getattr(ai_mod, "_ui_recent_errors").clear();
    bus = CaptureBus();
    _install_ui_provider_capture(bus);

    # Real ordering: byllm logs the failure via loguru *first* (our sink surfaces
    # it), and the re-raised exception only reaches the worker's except block
    # afterwards. byllm labels the loguru record ("LLM AuthenticationError: ...")
    # while the worker sees the bare re-raised message; the fingerprint must
    # collapse both onto one row.
    logger.error("LLM AuthenticationError: litellm bad key 42");
    assert len(bus.events) == 1 , bus.events;

    # Worker except path for the *same* failure -- must not add a second row.
    err_text = "provider: litellm bad key 42";
    if not is_dup(err_text) {
        bus.emit("error", {"text": err_text});
    }
    register_ui_provider_error(RuntimeError("litellm bad key 42"));
    assert len(bus.events) == 1 , bus.events;

    # A genuinely different provider failure still earns its own row.
    err2 = "provider: litellm rate limit on gpt-x";
    if not is_dup(err2) {
        bus.emit("error", {"text": err2});
    }
    assert len(bus.events) == 2 , bus.events;
}


test "ui output capture removes loguru's default sink and gags litellm" {
    pytest.importorskip("loguru", reason="This test requires loguru to be installed");
    import from jaclang.cli.ai_agent { _install_ui_provider_capture }
    import from loguru { logger }

    getattr(ai_mod, "_ui_recent_errors").clear();
    bus = CaptureBus();
    _install_ui_provider_capture(bus);

    # logger.remove() must have dropped loguru's default stderr sink (the one
    # thing a stderr relay can't do), leaving exactly one handler -- ours -- so
    # byllm's logger.error() reaches the bus, not the real terminal. A
    # redirect_stderr probe would be meaningless: loguru binds its sink to the
    # original stderr at import. Single-handler count *plus* the log landing on
    # the bus proves the default stderr sink is gone (count==1 alone wouldn't,
    # since the lone handler could still be the default).
    handlers = logger?._core?.handlers;
    if handlers is not None {
        assert len(handlers) == 1 , len(handlers);
    }
    logger.error("LLM call failed with APIError: routed to bus not tty");
    assert len(bus.events) == 1 , bus.events;
    assert bus.events[0]["kind"] == "error" , bus.events[0];

    # Phase 2b: litellm's stdout footer print() is gated by suppress_debug_info.
    try {
        import litellm;
        assert litellm.suppress_debug_info == True , litellm.suppress_debug_info;
    } except ImportError { }
}


test "SEND dispatch returns ACCEPTED or REJECTED receipt" {
    tui_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    schema = importlib.import_module("jaclang.cli.ai_tui.ipc_schema");
    dispatch = getattr(tui_mod, "_dispatch_cmd");
    old_send = getattr(ai_mod, "ui_send");

    def fake_ok(prompt: str) -> bool {
        return True;
    }

    def fake_busy(prompt: str) -> bool {
        return False;
    }

    setattr(ai_mod, "ui_send", fake_ok);
    try {
        rc = dispatch("SEND:hi", DummyStopEvt(), DummyProc());
        assert rc == schema.RECEIPT_ACCEPTED , rc;
    } finally {
        setattr(ai_mod, "ui_send", old_send);
    }

    setattr(ai_mod, "ui_send", fake_busy);
    try {
        rc = dispatch("SEND:hi", DummyStopEvt(), DummyProc());
        assert rc == schema.RECEIPT_REJECTED_BUSY , rc;
    } finally {
        setattr(ai_mod, "ui_send", old_send);
    }
}


test "run_ai_agent routes JAC_AI_TUI_BACKEND to embed vs inprocess" {
    import unittest.mock;
    import os;
    import from jaclang { JacRuntime as Jac }
    import from jaclang.cli.agent_api { AgentRequest }

    req = AgentRequest(tui=True);
    seen: list[str] = [];
    prior = os.environ.get("JAC_AI_TUI_BACKEND");

    def fake_inprocess(r: any) -> int {
        seen.append("inprocess");
        return 42;
    }

    def fake_embed(r: any) -> int {
        seen.append("embed");
        return 7;
    }

    try {
        os.environ["JAC_AI_TUI_BACKEND"] = "inprocess";
        with unittest.mock.patch(
            "jaclang.cli.ai_tui.run_tui_in_process.run_tui_in_process", fake_inprocess
        ) {
            with unittest.mock.patch(
                "jaclang.cli.ai_tui.run_tui_embed.run_tui_embed", fake_embed
            ) {
                rc = Jac.run_ai_agent(req);
                assert rc == 42;
                assert seen == ["inprocess"];
            }
        }
        seen.clear();
        os.environ.pop("JAC_AI_TUI_BACKEND", None);
        with unittest.mock.patch(
            "jaclang.cli.ai_tui.run_tui_in_process.run_tui_in_process", fake_inprocess
        ) {
            with unittest.mock.patch(
                "jaclang.cli.ai_tui.run_tui_embed.run_tui_embed", fake_embed
            ) {
                rc = Jac.run_ai_agent(req);
                assert rc == 7;
                assert seen == ["embed"];
            }
        }
    } finally {
        if prior is None {
            os.environ.pop("JAC_AI_TUI_BACKEND", None);
        } else {
            os.environ["JAC_AI_TUI_BACKEND"] = prior;
        }
    }
}


test "Phase 1 native seams: stopping status, no id=-1, pending submission" {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    cli_dir = Path(shared_mod.__file__).resolve().parent.parent;
    state_src = (cli_dir / "ai_tui_na" / "state.na.jac").read_text();
    input_src = (cli_dir / "ai_tui_na" / "input.na.jac").read_text();
    # Post-rearchitecture the submit/pending logic lives in the reducer; the
    # input adapter only maps effects onto the CmdQueue. (This assertion used to
    # read input.na.jac and silently rotted when the code moved.)
    reducer_src = (cli_dir / "ai_tui_na" / "reducer.na.jac").read_text();

    assert "STOPPING" in state_src , "TuiStatus must include STOPPING";
    assert "obj PendingSubmission" in state_src;
    assert "status_blocks_prompt" in state_src;
    assert "upsert_event(-1," not in input_src , "no optimistic id=-1 user row";
    assert "upsert_event(-1," not in reducer_src , "no optimistic id=-1 user row";
    assert "pending_submission" in reducer_src;
    assert "_adopt_pending_user" not in state_src , "id=-1 adoption path must be removed";
}


test "native submit applies receipt on the live typed effect path" {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    cli_dir = Path(shared_mod.__file__).resolve().parent.parent;
    na_dir = cli_dir / "ai_tui_na";
    dispatch_src = (na_dir / "session_dispatch.na.jac").read_text();
    client_src = (na_dir / "embed_session_client.na.jac").read_text();

    assert "receipt = session.submit_prompt(e.payload);" in dispatch_src;
    assert "session.apply_send_receipt(state, receipt);" in dispatch_src;
    assert "def apply_send_receipt(state: TuiState, receipt: NativeCommandReceipt)" in client_src;
    assert "flush_outbound_cmds" not in client_src;
    assert "_dispatch_legacy_cmd" not in client_src;
}
