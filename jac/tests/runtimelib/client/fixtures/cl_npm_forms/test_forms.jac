"""Client test whose mock uses npm specs outside `import ... from`.

The mock imports a stylesheet for side effect and re-exports a name from a
second, unmapped package. Both specs have to be rewritten for bun to resolve
them out of the sealed work dir.
"""

import from "fake-widgets" { widget, helper }

test "a mock survives a side-effect import and a re-export" {
    assert widget.id() == "w1";
}

test "a name re-exported from an unmapped package lands on the proxy" {
    # `helper` comes from the mock, which re-exports it from a package with no
    # mapping of its own -- so it resolves to the Proxy and must not throw.
    helper();
    assert 1 + 1 == 2;
}
