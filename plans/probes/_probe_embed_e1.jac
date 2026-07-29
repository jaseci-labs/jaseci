import os;
import time;
import importlib;
import json;

def _check(label: str, ok: bool) {
    if ok {
        print("PASS " + label);
    } else {
        print("FAIL " + label);
    }
}

with entry {
    os.environ.pop("JAC_AI_TUI_BYLLM_SRC", None);
    os.environ.pop("JAC_AI_TUI_DEPS", None);
    os.environ.pop("JAC_AI_TUI_NO_STUB", None);
}

glob mod = importlib.import_module("jaclang.cli.ai_tui.embed_agent");
with entry {
    if mod?._adapter is not None {
        mod.stop();
    }
}

glob raw_start = mod.start(
         '{"schema_id":"jac.ai_tui.bridge.v1","kind":"agent_request","stub":true,"model_name":"stub","cwd":"."}'
     );

with entry {
    _check("e1_start_returns_str", isinstance(raw_start, str));
}
glob start_obj = json.loads(raw_start);
with entry {
    _check("e1_start_ok", bool(start_obj.get("ok")));
    _check("e1_adapter_installed", mod?._adapter is not None);
}

glob p1 = mod.poll("64");
with entry {
    _check("e1_poll_returns_str", isinstance(p1, str));
}
glob batch1 = json.loads(p1);
with entry {
    _check("e1_poll_is_batch", batch1.get("kind") == "session_event_batch");

    time.sleep(0.05);
}

glob p2 = mod.poll("64");
with entry {
    _check("e1_poll_after_tick_str", isinstance(p2, str));
}

glob schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema"),
     cmd = schema.encode_command(schema.CMD_KIND_PROMPT, {"text": "probe-hi"}),
     rc = mod.submit(cmd);

with entry {
    _check("e1_submit_returns_str", isinstance(rc, str));
}
glob receipt = json.loads(rc);
with entry {
    _check("e1_submit_accepted", bool(receipt.get("accepted")));
}

glob snap = mod.snapshot();
with entry {
    _check("e1_snapshot_str", isinstance(snap, str));
    _check("e1_snapshot_kind", json.loads(snap).get("kind") == "ui_snapshot");
}

glob t0 = time.time(),
     disp = mod.dispose(
         '{"schema_id":"jac.ai_tui.bridge.v1","kind":"dispose_spec","reason":"e1","deadline_ms":2000}'
     ),
     elapsed = time.time() - t0;

with entry {
    _check("e1_dispose_bounded", elapsed < 5.0);
    _check("e1_dispose_str", isinstance(disp, str));
    _check("e1_adapter_cleared", mod?._adapter is None);

    mod.setup();
    _check("e1_legacy_setup", mod?._adapter is not None);
}

glob legacy_rc = mod.send("SEND:probe-legacy");
with entry {
    _check("e1_legacy_send", isinstance(legacy_rc, str));
    mod.stop();
    mod.stop();
    _check("e1_repeated_stop_safe", True);

    print("E1_MANAGED_DONE");
}
