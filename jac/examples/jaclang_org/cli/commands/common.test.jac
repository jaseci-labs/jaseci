import io;
import from contextlib { redirect_stderr }

obj Probe {
    has label: str = "v1",
        pages: int = 3,
        tags: list[str] = ["a", "b"];
}

test "field helpers read objects and dicts alike" {
    p = Probe();
    d = {"label": "v1", "pages": 3, "tags": ["a", "b"]};
    assert str_field(p, "label") == "v1";
    assert str_field(d, "label") == "v1";
    assert int_field(p, "pages") == 3;
    assert int_field(d, "pages") == 3;
    assert list_field(p, "tags") == ["a", "b"];
    assert list_field(d, "tags") == ["a", "b"];
}

test "field helpers default when a field is missing or mistyped" {
    d = {"pages": "three", "tags": "nope"};
    assert str_field(d, "label") == "";
    assert int_field(d, "pages") == 0;
    assert list_field(d, "tags") == [];
    assert str_field(None, "label") == "";
    assert int_field(42, "pages") == 0;
    assert list_field("text", "tags") == [];
}

test "bridge failures map to distinct exit codes and hints" {
    buf = io.StringIO();
    with redirect_stderr(buf) {
        assert explain_bridge_error(
            BridgeUnavailable(
                app="web", name="docs_status", detail="connection refused"
            )
        )
            == EXIT_UNAVAILABLE;
        assert explain_bridge_error(BridgeTimeout(app="social_graph", name="load_feed"))
            == EXIT_TIMEOUT;
        assert explain_bridge_error(
            BridgeRejected(app="social_graph", name="create_tweet", detail="401")
        )
            == EXIT_REJECTED;
        assert explain_bridge_error(
            BridgeError(app="web", name="docs_sync_tick", detail="500")
        )
            == EXIT_FAILURE;
    }
    text = buf.getvalue();
    assert "web.docs_status is not reachable (connection refused)" in text;
    assert START_HINT in text;
    assert "social_graph.load_feed timed out" in text;
    assert "signed-in identity" in text;
    assert "web.docs_sync_tick failed (500)" in text;
}

test "exit codes are distinct" {
    codes = [
        EXIT_OK,
        EXIT_FAILURE,
        EXIT_USAGE,
        EXIT_UNAVAILABLE,
        EXIT_TIMEOUT,
        EXIT_REJECTED
    ];
    assert len(set(codes)) == len(codes);
}
