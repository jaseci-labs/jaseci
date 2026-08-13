"""Jac-authored mock for the `@fake/telemetry` npm package.

Compiled through the ordinary client pipeline by the cl test runner, so it is
a normal client module: `:pub` is what makes a name importable from the test.
"""

glob:pub EVENTS: list = [];

def:pub track(name: str) -> str {
    EVENTS.append(name);
    return "tracked:" + name;
}

def:pub trackedCount -> int {
    return len(EVENTS);
}
