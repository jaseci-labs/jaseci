"""Client tests whose npm dependencies are replaced by behaving mocks.

`fake-editor` and `@fake/telemetry` are mapped to real modules by this
project's `[test.client.mocks]`; `unmapped-pkg` is not, so it keeps the universal
Proxy stub.  Both paths have to work in the same file.
"""

import from "fake-editor" { editor, recordedPriorities }
import from "@fake/telemetry" { track, trackedCount }
import from "unmapped-pkg" { whatever }

test "a mapped npm module returns real values" {
    picked = await editor.showQuickPick(["3.11", "3.12"]);
    assert picked == "3.12";
}

test "a mapped npm module records what it was called with" {
    editor.createStatusBarItem("left", 100);
    assert recordedPriorities()[0] == 100;
}

test "a jac-authored mock is compiled and staged like any client module" {
    assert track("boot") == "tracked:boot";
    assert trackedCount() == 1;
}

test "an unmapped npm module still falls back to the proxy stub" {
    # The Proxy swallows everything without throwing; that stays the default.
    whatever();
    whatever.deeply.nested.thing();
    assert 1 + 1 == 2;
}
