"""Client test whose mock is found by the tests/__mocks__ convention.

No `[test.client.mocks]` entry exists for `fake-widgets` -- dropping the file
into `tests/__mocks__/` is the whole configuration. The mock itself imports a
stylesheet for side effect and re-exports from a second, unmapped package.
"""

import from "fake-widgets" { widget, helper }

test "a mock found by convention loads and returns real values" {
    assert widget.id() == "w1";
}

test "a name re-exported from an unmapped package lands on the proxy" {
    helper();
    assert 1 + 1 == 2;
}
